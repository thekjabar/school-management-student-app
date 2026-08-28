import 'package:flutter/material.dart';

import '../../api/session.dart';
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';

/// The teacher's own record, their week, and the way out.
class TeacherWeekScreen extends StatelessWidget {
  const TeacherWeekScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.me;

    return Loader<List<TeacherSlot>>(
      tint: Role.teacher.tint,
      load: () => TeacherApi.instance.timetable(),
      builder: (context, slots) {
        final byDay = <String, List<TeacherSlot>>{};
        for (final s in slots) {
          (byDay[s.weekday] ??= []).add(s);
        }
        const order = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
        final days = order.where(byDay.containsKey).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Panel(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Role.teacher.wash,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      (me?.firstName ?? '?').characters.first.toUpperCase(),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Role.teacher.tint),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me?.name ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          me?.phone ?? '',
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          me?.schoolName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SectionHead(t('teacher.yourWeek')),
            if (days.isEmpty)
              Panel(
                child: Text(
                  t('teacher.noLessons'),
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              )
            else
              ...days.map((day) {
                final lessons = [...byDay[day]!]..sort((a, b) => a.period.compareTo(b.period));
                final isToday = day == todayWeekday();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Panel(
                    color: isToday ? Role.teacher.wash : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              humanise(day),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            if (isToday) Tag(t('teacher.today'), color: Role.teacher.tint, background: AppTheme.surface),
                            const Spacer(),
                            Text(
                              '${lessons.length} lesson${lessons.length == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...lessons.map(
                          (l) => Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    clock(l.startMinute),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 3,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: parseHex(l.colorHex, AppTheme.border),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${l.subjectName} · ${l.className}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (l.room != null)
                                  Text(
                                    l.room!,
                                    style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

}
