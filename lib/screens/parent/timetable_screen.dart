import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// The week, one day at a time.
///
/// A table rather than a list of cards, because a timetable is read by
/// scanning DOWN a column — what time, then what subject — and cards force the
/// eye to zig-zag. The rail down the left is what makes the gaps visible, and
/// the gaps are where the breaks are.
class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key, required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('quick.timetable')),
            Expanded(child: TimetableTab(child: child, showChildCard: true)),
          ],
        ),
      ),
    );
  }
}

/// The body, so the shell can host it as a tab as well as a pushed screen.
class TimetableTab extends StatefulWidget {
  const TimetableTab({super.key, required this.child, this.showChildCard = false});

  final Child child;
  final bool showChildCard;

  @override
  State<TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<TimetableTab> {
  String? _day;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Loader<List<DayOfLessons>>(
      tint: tint,
      padding: EdgeInsets.zero,
      load: () => ParentApi.instance.timetable(widget.child.studentId),
      builder: (context, week) {
        // The school's own week, in the order it runs — Sunday first here.
        const order = [
          'SUNDAY',
          'MONDAY',
          'TUESDAY',
          'WEDNESDAY',
          'THURSDAY',
          'FRIDAY',
          'SATURDAY',
        ];
        final days = [
          for (final name in order)
            ...week.where((d) => d.weekday == name),
        ];
        if (days.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                t('teacher.noLessons'),
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ),
          );
        }

        final today = todayWeekday();
        final selected = _day ??
            (days.any((d) => d.weekday == today) ? today : days.first.weekday);
        final day = days.firstWhere(
          (d) => d.weekday == selected,
          orElse: () => days.first,
        );
        final lessons = [...day.lessons]
          ..sort((a, b) => (a.startMinute ?? 0).compareTo(b.startMinute ?? 0));
        final firstBell = lessons.isEmpty ? null : lessons.first.startMinute;

        // A Column, not a ListView: Loader already scrolls what it is given,
        // and a viewport inside a viewport has no height to expand into.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The wash and the illustration behind the top of the page, exactly
            // as the design has them: the child card sits ON the tint, not on
            // a white band above it.
            if (widget.showChildCard)
              // The card on the left, the calendar on the right, in a block
              // tall enough to hold the whole illustration — no negative
              // offsets, so nothing is clipped and both scroll together.
              SizedBox(
                height: 124,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PositionedDirectional(
                      end: -6,
                      top: -4,
                      // A transparent cut-out, so there is no crop rectangle to
                      // hide and it can sit as large as the design has it.
                      child: Image.asset('assets/art/calendar_scene.png', width: 162),
                    ),
                    PositionedDirectional(
                      start: 0,
                      end: 140,
                      top: 8,
                      child: ChildCard(
                        name: widget.child.name,
                        // Just the code. The card is half the page here, and
                        // "Student ID:" is four syllables of label on a line
                        // with room for the label or the value, not both.
                        line: '${widget.child.className}  •  ${widget.child.code}',
                        tint: tint,
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: _DayStrip(
                days: days,
                selected: selected,
                today: today,
                onPick: (w) => setState(() => _day = w),
              ),
            ),
            const SizedBox(height: kCardGap),

            if (firstBell != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kGutter),
                child: NoticeBanner(
                  icon: Icons.schedule_rounded,
                  color: tint,
                  title: tn('tt.startsAt', clock12(firstBell)),
                  body: tn('tt.haveGreatDay', widget.child.name.split(' ').first),
                ),
              ),
              const SizedBox(height: kCardGap),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: _Table(lessons: lessons),
            ),
            const SizedBox(height: kCardGap),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: NoticeBanner(
                icon: Icons.event_note_rounded,
                color: tint,
                title: t('tt.checkRegularly'),
                body: t('tt.timingsChange'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

/* ---------------------------------------------------------------------------
 * The days
 * ------------------------------------------------------------------------- */

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.days,
    required this.selected,
    required this.today,
    required this.onPick,
  });

  final List<DayOfLessons> days;
  final String selected;
  final String today;
  final void Function(String weekday) onPick;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    // The date each weekday falls on THIS week, so the strip reads "Tue 29 Aug"
    // rather than asking a parent to work it out.
    final now = DateTime.now();
    DateTime dateFor(String weekday) {
      const map = {
        'MONDAY': 1,
        'TUESDAY': 2,
        'WEDNESDAY': 3,
        'THURSDAY': 4,
        'FRIDAY': 5,
        'SATURDAY': 6,
        'SUNDAY': 7,
      };
      // Forward from today, never back: computing inside the current ISO week
      // put Monday five days in the PAST beside a Sunday one day ahead, which
      // is a timetable nobody can use.
      final target = map[weekday] ?? now.weekday;
      final delta = (target - now.weekday + 7) % 7;
      return now.add(Duration(days: delta));
    }

    return Card16(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 30, color: AppTheme.border),
            Expanded(
              child: GestureDetector(
                onTap: () => onPick(days[i].weekday),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: days[i].weekday == selected
                        ? tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          weekdayName(days[i].weekday),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: days[i].weekday == selected ? tint : AppTheme.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          days[i].weekday == today
                              ? t('tt.today')
                              : shortDate(dateFor(days[i].weekday)),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: days[i].weekday == today
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: days[i].weekday == selected ? tint : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month_rounded, size: 14, color: tint),
                const SizedBox(width: 5),
                Text(
                  t('tt.thisWeek'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: tint,
                  ),
                ),
                Icon(Icons.expand_more_rounded, size: 15, color: tint),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * The day
 * ------------------------------------------------------------------------- */

class _Table extends StatelessWidget {
  const _Table({required this.lessons});

  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return Card16(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            t('tt.nothingOn'),
            style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
        ),
      );
    }

    // Where the day stops for a while. Anything over ten minutes between the
    // end of one lesson and the start of the next is a break a child would
    // notice, and the design gives it a row of its own.
    final rows = <Widget>[];
    for (var i = 0; i < lessons.length; i++) {
      final l = lessons[i];
      /*
       * The end the school set, not one made up from the start.
       *
       * This was `(l.startMinute ?? 0) + 45`, which invented a length no
       * timetable had agreed to — and did something worse on an ordinary slot.
       * startMinute and endMinute are only set when a slot DEVIATES from the
       * school's period grid; a normal lesson has both null and takes its times
       * from the bell schedule. So the row read "—" for the start and "00:45"
       * for the end: nought minutes past midnight, plus forty-five.
       *
       * The server sends endMinute and it was never read. Where both are null
       * there is no honest time to show, so the row shows none rather than a
       * number that looks like one.
       */
      final ends = l.endMinute;
      rows.add(_LessonRow(lesson: l, endMinute: ends, first: i == 0, last: i == lessons.length - 1));

      if (i < lessons.length - 1) {
        final nextStart = lessons[i + 1].startMinute;
        if (ends != null && nextStart != null && nextStart - ends >= 10) {
          rows.add(_BreakRow(from: ends, to: nextStart));
        } else {
          rows.add(Divider(height: 1, color: AppTheme.border, indent: 86, endIndent: 14));
        }
      }
    }

    return Card16(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                SizedBox(width: 44, child: _Head(t('tt.time'))),
                const SizedBox(width: 14),
                Expanded(flex: 6, child: _Head(t('tt.subject'))),
                Expanded(flex: 5, child: _Head(t('tt.teacher'))),
                SizedBox(width: 44, child: _Head(t('tt.room'))),
              ],
            ),
          ),
          ...rows,
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.endMinute,
    required this.first,
    required this.last,
  });

  final Lesson lesson;
  /// Null when the school has not set one - an ordinary slot takes its times
  /// from the period grid, and inventing start+45 printed a time nobody agreed.
  final int? endMinute;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colour = parseHex(lesson.colorHex, AppTheme.violet);

    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 44,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      clock(lesson.startMinute),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                    ),
                    // No dash and no second time when the school has not set
                    // an end: a lone '—' under the start reads as a fault.
                    if (endMinute != null)
                      Text('–', style: TextStyle(fontSize: 10, color: AppTheme.textFaint)),
                    if (endMinute != null)
                    Text(
                      clock(endMinute),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // The rail: a dot per lesson on a line that runs the whole day.
            SizedBox(
              width: 14,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1.5,
                        color: first ? Colors.transparent : AppTheme.border,
                      ),
                    ),
                  ),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1.5,
                        color: last ? Colors.transparent : AppTheme.border,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(subjectIcon(lesson.subject), size: 19, color: colour),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Shrunk to fit rather than wrapped: "Mathematics"
                          // broken across two lines as "Mathematic / s" is
                          // worse than the same word one point smaller.
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                lesson.subject,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  height: 1.2,
                                  color: AppTheme.text,
                                ),
                              ),
                            ),
                          ),
                          // The teacher's full name, as the design has it. The
                          // column to the right carries the short form beside
                          // their face; the room is already a pill two columns
                          // over and printing it here as well said nothing.
                          if ((lesson.teacher ?? '').isNotEmpty)
                            Text(
                              lesson.teacher!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  CircleInitials(label: lesson.teacher ?? '—', size: 26),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _short(lesson.teacher),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 44,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _room(lesson.room),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: colour,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "101" out of "Room 101". The column is a pill the width of a thumb and
  /// the word "Room" is already the heading above it.
  String _room(String? room) {
    if (room == null || room.trim().isEmpty) return '—';
    final parts = room.trim().split(RegExp(r'\s+'));
    return parts.last;
  }

  /// "Ms. Rojin" out of "Rojin Ahmed Barzani" — the column is 4/13ths of a
  /// phone and a full Kurdish name is three words long.
  String _short(String? full) {
    if (full == null || full.trim().isEmpty) return '—';
    return full.trim().split(RegExp(r'\s+')).first;
  }
}

class _BreakRow extends StatelessWidget {
  const _BreakRow({required this.from, required this.to});

  final int from;
  final int to;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppTheme.amber.withValues(alpha: AppTheme.dark ? 0.12 : 0.07),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_cafe_rounded, size: 19, color: AppTheme.amber),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('tt.break'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.text,
                  ),
                ),
                Text(
                  '${clock12(from)} – ${clock12(to)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(tn('tt.minutes', to - from), color: AppTheme.amber),
        ],
      ),
    );
  }
}
