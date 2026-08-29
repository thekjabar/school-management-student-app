import 'package:flutter/material.dart';

import '../../api/parent_api.dart' show Announcement;
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';

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
