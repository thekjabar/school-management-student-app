import 'package:flutter/material.dart';

import '../../api/session.dart';
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// The teacher's week as a screen of its own.
///
/// [TeacherWeek] is the same thing without the furniture, for the slot it fills
/// in the bottom bar. The two were one widget, which meant the drawer and the
/// home card pushed a bare Loader onto a route with no Scaffold under it: no
/// canvas, no safe area, and no way back but the system gesture.
class TeacherWeekScreen extends StatelessWidget {
  const TeacherWeekScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('teacher.yourWeek')),
            const Expanded(child: TeacherWeek()),
          ],
        ),
      ),
    );
  }
}

/// The teacher's own record, and their week.
class TeacherWeek extends StatelessWidget {
  const TeacherWeek({super.key});

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
                  // Tinted, always. Left to itself CircleInitials hashes the
                  // name into a hue of its own, and the teacher app is green.
                  CircleInitials(label: me?.name ?? '?', tint: Role.teacher.tint, size: 48),
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
                          // A phone number reads left-to-right even on a
                          // Kurdish screen; mirroring it makes it unusable.
                          textDirection: TextDirection.ltr,
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
                              // weekdayName, not humanise: humanise only
                              // sentence-cases the API's enum, so every day on
                              // a Kurdish screen read "Sunday", "Monday".
                              weekdayName(day),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            if (isToday) Tag(t('teacher.today'), color: Role.teacher.tint, background: AppTheme.surface),
                            const Spacer(),
                            Text(
                              lessons.length == 1
                                  ? t('teacher.oneLesson')
                                  : tn('teacher.nLessons', lessons.length),
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
