import 'package:flutter/material.dart';

import '../../api/student_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/motion.dart';
import 'student_kit.dart';

class StudentWeek extends StatelessWidget {
  const StudentWeek({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<_Timetable>(
      tint: Role.student.tint,
      padding: clearOfTheBar(context, const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 18)),
      load: _Timetable.fetch,
      empty: t('timetable.none'),
      isEmpty: (week) => week.days.every((d) => d.slots.isEmpty),
      builder: (context, week) => _Week(days: week.days, className: week.className),
    );
  }
}

class _Timetable {
  _Timetable({required this.days, required this.className});

  final List<TimetableDay> days;
  final String? className;

  static Future<_Timetable> fetch() async {
    final api = StudentApi.instance;
    final results = await Future.wait([api.week(), api.me()]);
    return _Timetable(
      days: results[0] as List<TimetableDay>,
      className: (results[1] as StudentProfile).schoolClass?.name,
    );
  }
}

class _Week extends StatefulWidget {
  const _Week({required this.days, required this.className});

  final List<TimetableDay> days;
  final String? className;

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

    final isToday = _weekday == todayWeekday();
    final subtitle = [
      if (slots.isNotEmpty) tn('student.lessonCount', slots.length),
      if ((widget.className ?? '').isNotEmpty) widget.className!,
    ].join('  •  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DayChips(
          labels: [for (final d in widget.days) weekdayName(d.weekday)],
          selected: widget.days.indexWhere((d) => d.weekday == _weekday),
          onPick: (i) => setState(() => _weekday = widget.days[i].weekday),
          tint: tint,
        ),
        const SizedBox(height: kCardGap),
        Rise(
          index: 0,
          child: Card16(
            padding: EdgeInsets.fromLTRB(14, 13, 14, slots.isEmpty ? 14 : 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            weekdayName(_weekday),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: AppTheme.text,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StudentSectionLabel(t('student.todaySchedule')),
                          const SizedBox(height: 3),
                          Text(
                            shortDate(DateTime.now()),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 11),
                if (slots.isEmpty)
                  Text(
                    t('timetable.nothingThatDay'),
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.45),
                  )
                else
                  ScheduleTimeline(
                    trailingIcon: Icons.circle_outlined,
                    entries: [for (final s in slots) lessonEntry(s, tint)],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
