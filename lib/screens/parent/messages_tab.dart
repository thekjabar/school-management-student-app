import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../i18n/strings.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';

/// What the school has told this family.
///
/// The office aims each notice at a scope — the whole school, a grade, a class,
/// a bus route — and the server works out which of those apply to THIS family's
/// children. So a grade 4 consent form does not appear for a family whose
/// children are in grades 1 and 6, and nobody has to scroll past it.
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key, this.onRead});

  final VoidCallback? onRead;

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  @override
  Widget build(BuildContext context) {
    return Loader<List<Announcement>>(
      tint: Role.parent.tint,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      load: () async {
        final rows = await ParentApi.instance.announcements();
        // Opening the tab is reading them, as far as the bell is concerned.
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.onRead?.call());
        return rows;
      },
      isEmpty: (rows) => rows.isEmpty,
      empty: t('msg.none'),
      builder: (context, rows) {
        final pinned = rows.where((r) => r.pinned).toList();
        final rest = rows.where((r) => !r.pinned).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pinned.isNotEmpty) ...[
              Heading(t('msg.pinned')),
              ...pinned.map((n) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _NoticeCard(notice: n),
                  )),
            ],
            if (rest.isNotEmpty) Heading(pinned.isEmpty ? t('msg.fromSchool') : t('msg.earlier')),
            ...rest.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _NoticeCard(notice: n),
                )),
          ],
        );
      },
    );
  }
}

class _NoticeCard extends StatefulWidget {
  const _NoticeCard({required this.notice});

  final Announcement notice;

  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;
    final urgent = n.priority == 'HIGH' || n.priority == 'CRITICAL';

    final (Color colour, IconData icon) = switch (n.category) {
      'BILLING' => (AppTheme.violet, Icons.receipt_long_rounded),
      'TRIP_STATUS' || 'DELAY' => (AppTheme.amber, Icons.directions_bus_rounded),
      'ACADEMIC' => (AppTheme.blue, Icons.school_rounded),
      'SAFETY_CRITICAL' => (AppTheme.rose, Icons.warning_rounded),
      _ => urgent ? (AppTheme.rose, Icons.priority_high_rounded) : (Role.parent.tint, Icons.campaign_rounded),
    };

    return Card16(
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip36(icon: icon, color: colour, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (n.pinned) ...[
                          Icon(Icons.push_pin_rounded, size: 13, color: colour),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            n.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (n.sentAt != null) _ago(n.sentAt!),
                        if (n.authorName.isNotEmpty) n.authorName,
                      ].join(' · '),
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              if (urgent) ...[
                const SizedBox(width: 8),
                Pill(t('msg.important'), color: AppTheme.rose),
              ],
            ],
          ),
          const SizedBox(height: 11),
          Text(
            n.body,
            maxLines: _open ? null : 2,
            overflow: _open ? null : TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, height: 1.55, color: AppTheme.textMuted),
          ),
          if (!_open && n.body.length > 110) ...[
            const SizedBox(height: 6),
            Text(
              t('msg.readMore'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Role.parent.tint),
            ),
          ],
          if (n.requiresAcknowledgement) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppTheme.amberSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.assignment_turned_in_rounded, size: 16, color: AppTheme.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // Said rather than shown as a button, because the paper
                      // form is what the school actually needs back.
                      t('msg.needsReply'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _ago(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 60) return tn('msg.minutesAgo', diff.inMinutes.clamp(1, 59));
    if (diff.inHours < 24) return tn('msg.hoursAgo', diff.inHours);
    if (diff.inDays == 1) return t('msg.yesterday');
    if (diff.inDays < 30) return tn('msg.daysAgo', diff.inDays);
    return longDate(at);
  }
}
