import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// Everything the school has sent this family.
///
/// One list, filtered by what the message IS: a notice about the whole school,
/// something for this class, or something urgent. The design draws a second
/// list of teacher conversations beside it — see the note on _Compose for why
/// that is not here.
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key, required this.onRead});

  final VoidCallback onRead;

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  int _tab = 0;
  String _query = '';
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // Opening the tab is reading it, as far as the bell is concerned.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onRead());
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Loader<List<Announcement>>(
      tint: tint,
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 18),
      load: () => ParentApi.instance.announcements(),
      builder: (context, all) {
        final rows = all.where((a) {
          if (_query.isNotEmpty &&
              !a.title.toLowerCase().contains(_query) &&
              !a.body.toLowerCase().contains(_query)) {
            return false;
          }
          return switch (_tab) {
            1 => a.category == 'ANNOUNCEMENT' || a.category == 'EVENT',
            2 => a.category == 'POLICY' || a.category == 'NOTICE',
            3 => a.priority == 'URGENT' || a.priority == 'HIGH',
            _ => true,
          };
        }).toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            return (b.sentAt ?? DateTime(0)).compareTo(a.sentAt ?? DateTime(0));
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title, search and tabs on one card, as the design has them.
            Card16(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _searching
                            ? TextField(
                                autofocus: true,
                                onChanged: (v) =>
                                    setState(() => _query = v.trim().toLowerCase()),
                                decoration: InputDecoration(
                                  hintText: t('common.search'),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 11,
                                  ),
                                ),
                              )
                            : Text(
                                t('nav.messages'),
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                  color: AppTheme.text,
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      _RoundButton(
                        icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                        onTap: () => setState(() {
                          _searching = !_searching;
                          if (!_searching) _query = '';
                        }),
                      ),
                      const SizedBox(width: 8),
                      _RoundButton(
                        icon: Icons.edit_outlined,
                        filled: true,
                        onTap: () => _compose(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  UnderlineTabs(
                    tint: tint,
                    index: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                    tabs: [
                      TabSpec(label: t('msg.all'), icon: Icons.forum_outlined),
                      TabSpec(
                        label: t('msg.announcements'),
                        icon: Icons.campaign_outlined,
                        color: AppTheme.violet,
                      ),
                      TabSpec(
                        label: t('msg.notices'),
                        icon: Icons.description_outlined,
                        color: AppTheme.blue,
                      ),
                      TabSpec(
                        label: t('msg.urgent'),
                        icon: Icons.priority_high_rounded,
                        color: AppTheme.rose,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: kCardGap),

            if (rows.isEmpty)
              Card16(
                padding: const EdgeInsets.symmetric(vertical: 34),
                child: Center(
                  child: Text(
                    t('msg.nothing'),
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              Card16(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: AppTheme.border),
                      _MessageRow(item: rows[i]),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// Writing TO the school is not switched on.
  ///
  /// The design shows teacher conversations and a Quick Chat strip. There is no
  /// messaging service behind this app — announcements travel one way, from the
  /// office outward — so a compose box would open onto nothing and a chat list
  /// would be furniture. Better to say so than to draw an inbox that never
  /// delivers.
  void _compose(BuildContext context) => showNote(context, t('msg.oneWay'));
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.filled = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: filled ? tint : AppTheme.canvas,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: filled ? tint : AppTheme.border),
        ),
        child: Icon(icon, size: 19, color: filled ? Colors.white : AppTheme.text),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * One message
 * ------------------------------------------------------------------------- */

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.item});

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final urgent = item.priority == 'URGENT' || item.priority == 'HIGH';
    final (colour, icon) = switch (item.category) {
      'EVENT' => (AppTheme.green, Icons.event_rounded),
      'POLICY' || 'NOTICE' => (AppTheme.blue, Icons.description_rounded),
      'TRANSPORT' => (AppTheme.amber, Icons.directions_bus_rounded),
      'HEALTH' => (AppTheme.rose, Icons.favorite_rounded),
      _ => (Role.parent.tint, Icons.account_balance_rounded),
    };
    final tint = urgent ? AppTheme.rose : colour;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(item.title),
          content: SingleChildScrollView(child: Text(item.body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t('common.close')),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(urgent ? Icons.priority_high_rounded : icon, size: 22, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.authorName.isEmpty ? t('msg.school') : item.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: tint,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _when(item.sentAt),
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 6),
                if (item.readAt == null)
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Role.parent.tint,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '1',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  )
                else if (item.pinned)
                  Icon(Icons.push_pin_rounded, size: 15, color: AppTheme.amber),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 19, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }

  /// "08:30", "Yesterday", "Mon", then the date — the way a message list reads
  /// time, which is by how recently rather than by when.
  String _when(DateTime? at) {
    if (at == null) return '—';
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final days = midnight.difference(DateTime(at.year, at.month, at.day)).inDays;
    if (days <= 0) return hhmm(at);
    if (days == 1) return t('due.yesterday');
    if (days < 7) return t('day.${at.weekday}').characters.take(3).toString();
    return shortDate(at);
  }
}
