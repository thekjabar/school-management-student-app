import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/attachments.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

class DriverAnnouncements extends StatefulWidget {
  const DriverAnnouncements({super.key});

  @override
  State<DriverAnnouncements> createState() => _DriverAnnouncementsState();
}

class _DriverAnnouncementsState extends State<DriverAnnouncements> {
  final Set<String> _read = {};

  bool _markingAll = false;

  bool _isUnread(CrewAnnouncement a) => a.readAt == null && !_read.contains(a.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('driver.announcements')),
            Expanded(
              child: Loader<List<CrewAnnouncement>>(
                tint: Role.driver.tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 18),
                load: () => CrewApi.instance.announcements(),
                isEmpty: (rows) => rows.isEmpty,
                empty: t('driver.noAnnouncements'),
                builder: (context, rows) {
                  final unread = rows.where(_isUnread).length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionRow(
                        title: t('msg.fromSchool'),
                        actionLabel: unread == 0 ? null : t('msg.markAllRead'),
                        actionIcon: unread == 0 ? null : Icons.done_all_rounded,
                        onAction: _markingAll ? null : () => _markAll(rows),
                      ),
                      for (final a in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: kCardGap),
                          child: _Notice(
                            item: a,
                            unread: _isUnread(a),
                            onOpen: () => _open(a),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(CrewAnnouncement a) {
    if (_isUnread(a)) _markRead(a);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: AppTheme.dark ? 0.62 : 0.34),
      builder: (context) => _NoticeDialog(item: a),
    );
  }

  Future<void> _markRead(CrewAnnouncement a) async {
    final unread = CrewApi.instance.unreadAnnouncements;
    setState(() => _read.add(a.id));
    unread.value = unread.value > 0 ? unread.value - 1 : 0;

    try {
      await CrewApi.instance.markAnnouncementRead(a.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _read.remove(a.id));
      unread.value += 1;
      showNote(context, errorText(e), bad: true);
    }
  }

  Future<void> _markAll(List<CrewAnnouncement> rows) async {
    if (_markingAll) return;
    final ids = rows.where(_isUnread).map((a) => a.id).toList();
    if (ids.isEmpty) return;

    final unread = CrewApi.instance.unreadAnnouncements;
    final before = unread.value;
    setState(() {
      _read.addAll(ids);
      _markingAll = true;
    });
    unread.value = 0;

    try {
      final marked = await CrewApi.instance.markAllAnnouncementsRead();
      if (!mounted) return;
      setState(() => _markingAll = false);
      showNote(context, tn('msg.markedRead', marked));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _read.removeAll(ids);
        _markingAll = false;
      });
      unread.value = before;
      showNote(context, errorText(e), bad: true);
    }
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.item, required this.unread, required this.onOpen});

  final CrewAnnouncement item;
  final bool unread;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final urgent = item.priority == 'URGENT' || item.priority == 'HIGH';
    final tint = urgent ? AppTheme.rose : Role.driver.tint;
    final needsAck = item.requiresAcknowledgement && item.acknowledgedAt == null;

    return Card16(
      padding: const EdgeInsets.all(14),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  urgent ? Icons.priority_high_rounded : Icons.campaign_outlined,
                  size: 19,
                  color: tint,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.3,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      longDate(item.sentAt),
                      style: TextStyle(fontSize: 10.5, color: AppTheme.textFaint),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 10),
                Semantics(
                  label: t('msg.unread'),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.5, color: AppTheme.textMuted),
          ),
          if (needsAck) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fact_check_outlined, size: 14, color: AppTheme.amber),
                const SizedBox(width: 5),
                Text(
                  t('driver.ackNeeded'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.amber,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NoticeDialog extends StatefulWidget {
  const _NoticeDialog({required this.item});

  final CrewAnnouncement item;

  @override
  State<_NoticeDialog> createState() => _NoticeDialogState();
}

class _NoticeDialogState extends State<_NoticeDialog> {
  bool _acknowledging = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final urgent = item.priority == 'URGENT' || item.priority == 'HIGH';
    final tint = urgent ? AppTheme.rose : Role.driver.tint;
    final needsAck = item.requiresAcknowledgement && item.acknowledgedAt == null;

    return Dialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip36(
                  icon: urgent ? Icons.priority_high_rounded : Icons.campaign_outlined,
                  color: tint,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.3,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        longDate(item.sentAt),
                        style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.body,
                      style: TextStyle(fontSize: 13.5, height: 1.55, color: AppTheme.textMuted),
                    ),
                    if (item.attachmentCount > 0) ...[
                      const SizedBox(height: 16),
                      AttachmentList(
                        count: item.attachmentCount,
                        tint: Role.driver.tint,
                        load: () => CrewApi.instance.announcementAttachments(item.id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (needsAck) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.fact_check_outlined, size: 15, color: AppTheme.amber),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      t('driver.mustAcknowledge'),
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.amber),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            BigButton(
              label: needsAck ? t('msg.gotIt') : t('common.close'),
              color: tint,
              busy: _acknowledging,
              onPressed: _acknowledging ? null : () => _close(needsAck),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _close(bool needsAck) async {
    if (!needsAck) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _acknowledging = true);
    try {
      await CrewApi.instance.acknowledgeAnnouncement(widget.item.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _acknowledging = false);
      showNote(context, errorText(e), bad: true);
    }
  }
}
