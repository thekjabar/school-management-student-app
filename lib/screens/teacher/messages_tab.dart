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
class TeacherMessages extends StatelessWidget {
  const TeacherMessages({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<List<Announcement>>(
      tint: Role.teacher.tint,
      padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 18),
      load: () => TeacherApi.instance.announcements(),
      isEmpty: (rows) => rows.isEmpty,
      empty: t('teacher.noAnnouncements'),
      builder: (context, rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final a in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: kCardGap),
              child: _Notice(item: a),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.item});

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final urgent = item.priority == 'URGENT' || item.priority == 'HIGH';
    final tint = urgent ? AppTheme.rose : Role.teacher.tint;

    return Card16(
      padding: const EdgeInsets.all(14),
      // The card shows three lines of the notice; this is the rest of it. Not
      // an AlertDialog — that arrives with Material's own radius, its own
      // title size and its own grey button, none of which are this app's.
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: AppTheme.dark ? 0.62 : 0.34),
        builder: (context) => Dialog(
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
        ),
      ),
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
                        fontWeight: FontWeight.w800,
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
