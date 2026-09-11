import 'package:flutter/material.dart';

import '../../api/session.dart';
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

const _order = [
  'SUNDAY',
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
];

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
            const _WeekHeader(withBack: true),
            const Expanded(child: TeacherWeek(withHeader: false)),
          ],
        ),
      ),
    );
  }
}

class TeacherWeek extends StatelessWidget {
  const TeacherWeek({super.key, this.withHeader = true});

  final bool withHeader;

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.me;
    final start = _weekStart();

    return Column(
      children: [
        if (withHeader) const _WeekHeader(withBack: false),
        Expanded(
          child: Loader<List<TeacherSlot>>(
            tint: Role.teacher.tint,
            load: () => TeacherApi.instance.timetable(),
            builder: (context, slots) {
              final byDay = <String, List<TeacherSlot>>{};
              for (final s in slots) {
                (byDay[s.weekday] ??= []).add(s);
              }
              final days = _order.where(byDay.containsKey).toList();

              final classes = slots
                  .map((s) => s.classId)
                  .where((id) => id.isNotEmpty)
                  .toSet()
                  .length;
              final today = todayWeekday();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Identity(
                    name: me?.name ?? '',
                    phone: me?.phone ?? '',
                    school: me?.schoolName ?? '',
                  ),
                  const SizedBox(height: kCardGap),
                  _Figures(
                    days: days.length,
                    lessons: slots.length,
                    classes: classes,
                  ),
                  const SizedBox(height: 18),
                  SectionRow(title: t('teacher.weekSchedule')),
                  if (days.isEmpty)
                    Card16(
                      child: Text(
                        t('teacher.noLessons'),
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    )
                  else
                    ...days.map((day) {
                      final index = _order.indexOf(day);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DayCard(
                          weekday: day,
                          date: DateTime(start.year, start.month, start.day + index),
                          colour: _dayColour(index),
                          isToday: day == today,
                          lessons: [...byDay[day]!]
                            ..sort((a, b) => a.period.compareTo(b.period)),
                        ),
                      );
                    }),
                  const SizedBox(height: 6),
                  NoticeBanner(
                    icon: Icons.event_note_rounded,
                    title: t('teacher.tip'),
                    body: t('teacher.weekTip'),
                    color: AppTheme.violet,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

DateTime _weekStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - (now.weekday % 7));
}

Color _dayColour(int index) {
  final palette = [
    AppTheme.violet,
    AppTheme.blue,
    AppTheme.green,
    AppTheme.amber,
    AppTheme.rose,
  ];
  return palette[index % palette.length];
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.withBack});

  final bool withBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(kGutter, 6, kGutter, 10),
      child: Row(
        children: [
          if (withBack) ...[
            SquareButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              t('teacher.yourWeek'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppTheme.text,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const _WeekPill(),
        ],
      ),
    );
  }
}

class _WeekPill extends StatelessWidget {
  const _WeekPill();

  @override
  Widget build(BuildContext context) {
    final start = _weekStart();
    final end = DateTime(start.year, start.month, start.day + 6);
    final from = start.month == end.month && start.year == end.year
        ? '${start.day}'
        : shortDate(start);

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 11, 7),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_rounded, size: 13, color: Role.teacher.tint),
          const SizedBox(width: 6),
          Text(
            tv('teacher.weekRange', {
              'from': from,
              'to': '${shortDate(end)} ${end.year}',
            }),
            maxLines: 1,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.name, required this.phone, required this.school});

  final String name;
  final String phone;
  final String school;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleInitials(label: name.isEmpty ? '?' : name, tint: Role.teacher.tint, size: 52),
              PositionedDirectional(
                bottom: -1,
                end: -1,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Role.teacher.tint,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.surface, width: 2),
                  ),
                  child: const Icon(Icons.star_rounded, size: 11, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 3),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    phone,
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                if (school.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.apartment_rounded, size: 13, color: AppTheme.textFaint),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          school,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.days, required this.lessons, required this.classes});

  final int days;
  final int lessons;
  final int classes;

  @override
  Widget build(BuildContext context) {
    Widget rule() => Container(width: 1, height: 34, color: AppTheme.border);

    return Card16(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: _Figure(
              icon: Icons.calendar_month_rounded,
              colour: AppTheme.blue,
              value: '$days',
              caption: t('teacher.days'),
            ),
          ),
          rule(),
          Expanded(
            child: _Figure(
              icon: Icons.menu_book_rounded,
              colour: Role.teacher.tint,
              value: '$lessons',
              caption: t('teacher.lessons'),
            ),
          ),
          rule(),
          Expanded(
            child: _Figure(
              icon: Icons.groups_rounded,
              colour: AppTheme.amber,
              value: '$classes',
              caption: t('teacher.classes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.icon,
    required this.colour,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color colour;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Chip36(
            icon: icon,
            color: colour,
            background: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
            size: 34,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.1,
                    color: AppTheme.text,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      caption,
                      maxLines: 1,
                      style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted, height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.weekday,
    required this.date,
    required this.colour,
    required this.isToday,
    required this.lessons,
  });

  final String weekday;
  final DateTime date;
  final Color colour;
  final bool isToday;
  final List<TeacherSlot> lessons;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: isToday ? Role.teacher.wash : null,
      border: isToday
          ? Role.teacher.tint.withValues(alpha: AppTheme.dark ? 0.45 : 0.25)
          : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.topCenter,
              child: _DayBlock(weekday: weekday, date: date, colour: colour),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: colour,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isToday) ...[
                    Tag(
                      t('teacher.today'),
                      color: Role.teacher.tint,
                      background: AppTheme.surface,
                    ),
                    const SizedBox(height: 7),
                  ],
                  for (var i = 0; i < lessons.length; i++) ...[
                    if (i > 0) const SizedBox(height: 9),
                    _LessonLine(lesson: lessons[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Pill(
                lessons.length == 1
                    ? t('teacher.oneLesson')
                    : tn('teacher.nLessons', lessons.length),
                color: colour,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({required this.weekday, required this.date, required this.colour});

  final String weekday;
  final DateTime date;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              weekdayName(weekday).toUpperCase(),
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                height: 1.15,
                color: colour,
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              shortDate(date),
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1.15,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonLine extends StatelessWidget {
  const _LessonLine({required this.lesson});

  final TeacherSlot lesson;

  @override
  Widget build(BuildContext context) {
    final room = lesson.room;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              clock(lesson.startMinute),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '${lesson.subjectName} · ${lesson.className}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                ),
              ),
            ),
          ],
        ),
        if (room != null && room.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.meeting_room_outlined, size: 12, color: AppTheme.textFaint),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  room,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
