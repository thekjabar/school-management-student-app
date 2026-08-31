import 'package:flutter/material.dart';

import '../../api/parent_api.dart' show Announcement;
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import 'teacher_kit.dart';

/// What the school has told the staff.
///
/// The same announcements table the parent app reads, resolved against a
/// TEACHER's audience instead of a guardian's: the whole school, their campus,
/// the classes they teach, anything aimed at staff, and anything addressed to
/// them by name.
class TeacherMessages extends StatefulWidget {
  const TeacherMessages({super.key});

  @override
  State<TeacherMessages> createState() => _TeacherMessagesState();
}

class _TeacherMessagesState extends State<TeacherMessages> {
  /// Notices read on this phone since the list was fetched.
  ///
  /// A row's `readAt` is final and comes from the server, so the change a tap
  /// makes lives here until the next fetch brings it back with a stamp on it.
  /// Kept across a pull-to-refresh deliberately: if the refresh lands before
  /// the mark does, dropping the set would flick the dots back on.
  final Set<String> _read = {};

  /// A sweep already in flight. Two of them would race the same revert.
  bool _markingAll = false;

  bool _isUnread(Announcement a) => a.readAt == null && !_read.contains(a.id);

  @override
  Widget build(BuildContext context) {
    return Loader<List<Announcement>>(
      tint: Role.teacher.tint,
      padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 18),
      load: () => TeacherApi.instance.announcements(),
      isEmpty: (rows) => rows.isEmpty,
      empty: t('teacher.noAnnouncements'),
      builder: (context, rows) {
        final unread = rows.where(_isUnread).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The heading the teacher's other lists use, with the sweep sitting
            // where "View all" sits on the home screen. It is dropped entirely
            // once everything is read: an action that can only tell you it had
            // nothing to do is furniture.
            SectionRow(
              title: t('msg.fromSchool'),
              actionLabel: unread == 0 ? null : t('msg.markAllRead'),
              actionIcon: unread == 0 ? null : Icons.done_all_rounded,
              onAction: () => _markAll(rows),
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
    );
  }

  /// Opening a notice is reading it.
  ///
  /// The mark goes out as the dialog opens rather than when it closes: a
  /// teacher who reads a notice and switches apps has still read it.
  void _open(Announcement a) {
    if (_isUnread(a)) _markRead(a);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: AppTheme.dark ? 0.62 : 0.34),
      builder: (context) => _NoticeDialog(item: a),
    );
  }

  Future<void> _markRead(Announcement a) async {
    final unread = TeacherApi.instance.unreadAnnouncements;
    setState(() => _read.add(a.id));
    unread.value = unread.value > 0 ? unread.value - 1 : 0;

    try {
      await TeacherApi.instance.markAnnouncementRead(a.id);
    } catch (e) {
      // Put the dot back. The notice is still unread on the server, and a list
      // that quietly disagrees with it is worse than one that never changed.
      if (!mounted) return;
      setState(() => _read.remove(a.id));
      unread.value += 1;
      showNote(context, errorText(e), bad: true);
    }
  }

  Future<void> _markAll(List<Announcement> rows) async {
    if (_markingAll) return;
    final ids = rows.where(_isUnread).map((a) => a.id).toList();
    if (ids.isEmpty) return;

    final unread = TeacherApi.instance.unreadAnnouncements;
    final before = unread.value;
    setState(() {
      _read.addAll(ids);
      _markingAll = true;
    });
    unread.value = 0;

    try {
      final marked = await TeacherApi.instance.markAllAnnouncementsRead();
      if (!mounted) return;
      setState(() => _markingAll = false);
      showNote(context, tn('msg.markedRead', marked));
    } catch (e) {
      if (!mounted) return;
      // Only the ones this sweep claimed — a notice read by hand a minute ago
      // stays read.
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

  final Announcement item;
  final bool unread;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final urgent = item.priority == 'URGENT' || item.priority == 'HIGH';
    final tint = urgent ? AppTheme.rose : Role.teacher.tint;

    return Card16(
      padding: const EdgeInsets.all(14),
      // The card shows three lines of the notice; the rest of it is in the
      // dialog. Not an AlertDialog — that arrives with Material's own radius,
      // its own title size and its own grey button, none of which are this
      // app's.
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
                        // only their weight. Greying them out would say the
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
                // The same dot the shell puts on the Messages tab, at the size
                // it uses there, so the two plainly mean one thing.
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
        ],
      ),
    );
  }
}

/// The whole notice, drawn from the same tokens as the card behind it.
class _NoticeDialog extends StatelessWidget {
  const _NoticeDialog({required this.item});

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final urgent = item.priority == 'URGENT' || item.priority == 'HIGH';
    final tint = urgent ? AppTheme.rose : Role.teacher.tint;

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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SoftButton(
                label: t('common.close'),
                tint: tint,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
