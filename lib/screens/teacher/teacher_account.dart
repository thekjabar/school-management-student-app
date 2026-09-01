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

/// The days of the school week in the order the Region reads them, which is
/// also the order the timetable endpoint sorts on.
const _order = [
  'SUNDAY',
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
];

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
            // The back tile belongs to the pushed route and to nothing else.
            const _WeekHeader(withBack: true),
            const Expanded(child: TeacherWeek(withHeader: false)),
          ],
        ),
      ),
    );
  }
}

/// The teacher's own record, and their week.
class TeacherWeek extends StatelessWidget {
  const TeacherWeek({super.key, this.withHeader = true});

  /// Draws the title and the week pill above the list.
  ///
  /// True in the bottom bar, where this widget is the whole page and there is
  /// nothing above it to name the screen — and false under [TeacherWeekScreen],
  /// which draws the same header itself with a back tile in it. The tab must
  /// never get that tile: inside the bar there is nothing to pop, and a back
  /// arrow that does nothing is the fault this split was made to fix.
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

              // Every figure below is counted off the rows that came back.
              // Nothing here is a constant dressed up as a statistic.
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

/* ---------------------------------------------------------------------------
 * The week itself
 * ------------------------------------------------------------------------- */

/// Midnight on the Sunday the current week began on.
///
/// DateTime.weekday counts Monday as 1, so Sunday — 7 — is nought days back and
/// every other day is its own number. Built by arithmetic on the calendar
/// fields rather than by subtracting a Duration, so the hour a clock goes
/// forward cannot land the week on the wrong day.
DateTime _weekStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - (now.weekday % 7));
}

/// Five theme colours across seven days.
///
/// Five is all the palette carries that is legible on BOTH canvases, and the
/// cycle is over the fixed week order rather than over the days that happen to
/// have lessons — so no two days that sit next to each other share a colour,
/// and a given day keeps its colour whatever else is on the timetable.
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

/// The back tile, the title, and the week the list is showing.
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

/// The week the timetable below belongs to.
///
/// A LABEL, and deliberately not a control. GET /teacher/timetable takes one
/// optional `weekday` filter and nothing else: the slots it returns are the
/// recurring pattern, resolved server-side against today's date, and they carry
/// a weekday rather than a date. There is no request this app can make for last
/// week or next, so there is no chevron on this pill — a chevron here would be
/// a third dead control shipped on this app in a day. The dates come off the
/// phone's own clock, which is the same place the highlighted day comes from.
class _WeekPill extends StatelessWidget {
  const _WeekPill();

  @override
  Widget build(BuildContext context) {
    final start = _weekStart();
    final end = DateTime(start.year, start.month, start.day + 6);
    // Only one month name when both ends share a month, which is the usual
    // case: "1 – 7 Sep 2026" rather than "1 Sep – 7 Sep 2026".
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

/* ---------------------------------------------------------------------------
 * Who the week belongs to
 * ------------------------------------------------------------------------- */

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
              // Tinted, always. Left to itself CircleInitials hashes the name
              // into a hue of its own, and the teacher app is green.
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
                    // A phone number reads left-to-right even on a Kurdish
                    // screen; mirroring it makes it unusable.
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

/* ---------------------------------------------------------------------------
 * The three figures
 * ------------------------------------------------------------------------- */

/// Days, lessons and classes, counted off the timetable that just loaded.
///
/// Not FigureStrip or IconFigureStrip: the first has no glyph at all and the
/// second draws a 12pt value beside a 22px disc, which is a figure for the foot
/// of a card rather than the three numbers this card exists for.
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

/* ---------------------------------------------------------------------------
 * One day
 * ------------------------------------------------------------------------- */

/// A day of the week, with everything timetabled on it.
///
/// No chevron and no tap: a day on this screen opens nothing today, and this
/// rebuild is a change of presentation rather than of destination. The card
/// therefore promises nothing it cannot do.
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
            // The bar runs the height of the day rather than of one lesson,
            // which is what ties three lessons together as one day.
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

/// The tinted block on the leading side: the day, and the date it falls on.
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
              // weekdayName, not humanise: humanise only sentence-cases the
              // API's enum, so every day on a Kurdish screen read "Sunday",
              // "Monday". Uppercasing is a no-op in the two scripts that have
              // no case, and gives the design's "SUN" in the one that does.
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
