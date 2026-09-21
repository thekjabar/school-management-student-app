import 'package:flutter/material.dart';

import '../../api/student_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';

class StudentWeek extends StatelessWidget {
  const StudentWeek({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<List<TimetableDay>>(
      tint: Role.student.tint,
      padding: clearOfTheBar(context, const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 18)),
      load: StudentApi.instance.week,
      empty: t('timetable.none'),
      isEmpty: (days) => days.every((d) => d.slots.isEmpty),
      builder: (context, days) => _Week(days: days),
    );
  }
}

class _Week extends StatefulWidget {
  const _Week({required this.days});

  final List<TimetableDay> days;

  @override
  State<_Week> createState() => _WeekState();
}

class _WeekState extends State<_Week> {
  late String _weekday = _initial();

  String _initial() {
    final today = todayWeekday();
    if (widget.days.any((d) => d.weekday == today)) return today;
    return widget.days.isEmpty ? today : widget.days.first.weekday;
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.student.tint;
    final day = widget.days.where((d) => d.weekday == _weekday).firstOrNull;
    final slots = day?.slots ?? const <Lesson>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.days.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final d = widget.days[i];
              final on = d.weekday == _weekday;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _weekday = d.weekday),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: on ? tint : AppTheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: on ? tint : AppTheme.border),
                  ),
                  child: Text(
                    weekdayName(d.weekday),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : AppTheme.textMuted,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: kCardGap),
        Card16(
          padding: EdgeInsets.fromLTRB(14, 14, 14, slots.isEmpty ? 14 : 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionRow(title: weekdayName(_weekday)),
              if (slots.isEmpty)
                Text(
                  t('timetable.nothingThatDay'),
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.45),
                )
              else
                ScheduleTimeline(
                  trailingIcon: Icons.circle_outlined,
                  entries: [
                    for (final s in slots)
                      ScheduleEntry(
                        time: clock12(s.startMinute),
                        subject: s.subject,
                        teacher: s.teacherName,
                        room: s.room,
                        color: parseHex(s.subjectColorHex, tint),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
