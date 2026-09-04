import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// What the school has told its drivers and attendants.
///
/// CrewAnnouncementsController has been a complete API since the day it
/// shipped — list, attachments, read, read-all, acknowledge — built
/// specifically because a driver or attendant had no screen anywhere that
/// could read a notice aimed at them. Nothing in the app called it. This is
/// that screen, modelled on the teacher app's Messages list for structure: one
/// list, a read/unread dot, a mark-all-read sweep, and a tap that opens and
/// reads a notice at once.
///
/// It differs from that model in the one place the server does: this
/// controller carries a real acknowledge endpoint, so a notice the office
/// marked as requiring one — a changed release procedure, a road closed to
/// buses — gets an actual "Got it" that reaches the server, the same way the
/// parent app's does, rather than being satisfied by opening it.
///
/// Reached from a button on the driver home header rather than a fifth tab:
/// see the note on `DriverApp._openAnnouncements` for why.
class DriverAnnouncements extends StatefulWidget {
  const DriverAnnouncements({super.key});

  @override
  State<DriverAnnouncements> createState() => _DriverAnnouncementsState();
}

class _DriverAnnouncementsState extends State<DriverAnnouncements> {
  /// Notices read on this phone since the list was fetched.
  ///
  /// A row's `readAt` is final and comes from the server, so the change a tap
  /// makes lives here until the next fetch brings it back with a stamp on it —
  /// the same overlay TeacherMessages keeps for its own list.
  final Set<String> _read = {};

  /// A sweep already in flight. Two of them would race the same revert.
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

  /// Opening a notice is reading it.
  ///
  /// The mark goes out as the dialog opens rather than when it closes: a
  /// driver who reads a notice and switches apps has still read it.
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
      // Put the dot back. The notice is still unread on the server, and a
      // list that quietly disagrees with it is worse than one that never
      // changed.
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
      // Only the ones this sweep claimed — a notice read by hand a minute
      // ago stays read.
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
    // Owed and not yet given — the one thing this list has that the teacher
    // screen it is modelled on does not.
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
                        // Read notices keep their place in the list and lose
                        // only their weight — greying one out would say the
                        // school's notice had expired, which is not what
                        // having read it means.
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

/// The whole notice, drawn from the same tokens as the card behind it.
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
                child: Text(
                  item.body,
                  style: TextStyle(fontSize: 13.5, height: 1.55, color: AppTheme.textMuted),
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

  /// "I have read this and I understand it" — sent only on a notice the
  /// office marked as requiring it. A failure keeps the dialog open rather
  /// than pretending: closing it either way would leave the office's list of
  /// who has not answered still carrying this driver's name.
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
