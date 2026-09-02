import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import 'assignments_screen.dart';
import 'homework_detail.dart';
import 'timetable_screen.dart';

/// The child's month, and one day of it in full.
///
/// Every dot is something the school actually put in the diary — a lesson, a
/// piece of work due, an exam, a notice. The grid answers "is there anything
/// this week"; the list under it answers "what, and when".
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key, required this.child});

  final Child child;

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  int _view = 0;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Loader<_Diary>(
      tint: tint,
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 20),
      load: () async {
        final r = await Future.wait([
          ParentApi.instance.timetable(widget.child.studentId),
          ParentApi.instance.homework(widget.child.studentId),
          ParentApi.instance.results(widget.child.studentId),
          ParentApi.instance.announcements(),
        ]);
        return _Diary(
          week: r[0] as List<DayOfLessons>,
          homework: r[1] as List<HomeworkItem>,
          exams: r[2] as List<ExamResultItem>,
          notices: r[3] as List<Announcement>,
        );
      },
      builder: (context, diary) {
        final events = diary.on(_day);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('nav.calendar'),
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      color: AppTheme.text,
                    ),
                  ),
                ),
                _TodayButton(
                  onTap: () => setState(() {
                    final now = DateTime.now();
                    _day = now;
                    _month = DateTime(now.year, now.month);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),

            PillTabs(
              tint: tint,
              index: _view,
              onChanged: (i) => setState(() => _view = i),
              tabs: [
                TabSpec(label: t('cal.month'), icon: Icons.calendar_month_rounded),
                TabSpec(label: t('cal.week'), icon: Icons.view_week_rounded),
                TabSpec(label: t('cal.agenda'), icon: Icons.format_list_bulleted_rounded),
              ],
            ),
            const SizedBox(height: kCardGap),

            if (_view == 0) ...[
              _MonthCard(
                month: _month,
                day: _day,
                diary: diary,
                onMonth: (d) => setState(() => _month = d),
                onDay: (d) => setState(() => _day = d),
              ),
              const SizedBox(height: kCardGap),
              _DayCard(day: _day, events: events, child: widget.child),
            ] else if (_view == 1)
              _WeekCard(
                day: _day,
                diary: diary,
                onDay: (d) => setState(() => _day = d),
                child: widget.child,
              )
            else
              _AgendaCard(diary: diary, child: widget.child),

            if (diary.nextHoliday != null) ...[
              const SizedBox(height: kCardGap),
              _HolidayCard(notice: diary.nextHoliday!),
            ],
          ],
        );
      },
    );
  }
}

/* ---------------------------------------------------------------------------
 * What is in the diary
 * ------------------------------------------------------------------------- */

enum EventKind { lesson, assignment, exam, notice }

class DiaryEvent {
  const DiaryEvent({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.at,
    this.startMinute,
    this.endMinute,
    this.where,
    this.colour,
    this.homework,
  });

  final EventKind kind;
  final String title;
  final String subtitle;
  final DateTime at;
  final int? startMinute;
  final int? endMinute;
  final String? where;
  final Color? colour;
  final HomeworkItem? homework;

  Color get tint =>
      colour ??
      switch (kind) {
        EventKind.lesson => AppTheme.violet,
        EventKind.assignment => AppTheme.blue,
        EventKind.exam => AppTheme.amber,
        EventKind.notice => AppTheme.green,
      };

  IconData get icon => switch (kind) {
        EventKind.lesson => Icons.menu_book_rounded,
        EventKind.assignment => Icons.assignment_turned_in_outlined,
        EventKind.exam => Icons.description_outlined,
        EventKind.notice => Icons.campaign_outlined,
      };

  String get label => switch (kind) {
        EventKind.lesson => t('cal.class'),
        EventKind.assignment => t('cal.assignment'),
        EventKind.exam => t('cal.exam'),
        EventKind.notice => t('cal.event'),
      };
}

class _Diary {
  _Diary({
    required this.week,
    required this.homework,
    required this.exams,
    required this.notices,
  });

  final List<DayOfLessons> week;
  final List<HomeworkItem> homework;
  final List<ExamResultItem> exams;
  final List<Announcement> notices;

  static const _weekdays = {
    DateTime.monday: 'MONDAY',
    DateTime.tuesday: 'TUESDAY',
    DateTime.wednesday: 'WEDNESDAY',
    DateTime.thursday: 'THURSDAY',
    DateTime.friday: 'FRIDAY',
    DateTime.saturday: 'SATURDAY',
    DateTime.sunday: 'SUNDAY',
  };

  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Everything happening on one day, in the order it happens.
  List<DiaryEvent> on(DateTime day) {
    final events = <DiaryEvent>[];

    final name = _weekdays[day.weekday];
    for (final d in week.where((d) => d.weekday == name)) {
      for (final l in d.lessons) {
        events.add(DiaryEvent(
          kind: EventKind.lesson,
          title: l.subject,
          subtitle: [l.teacher, l.room].whereType<String>().join('  •  '),
          at: day,
          startMinute: l.startMinute,
          // The end the school set. start+45 invented a length no timetable
          // agreed to, and on an ordinary slot - where both are null because
          // the times come from the bell schedule - it printed 00:45.
          endMinute: l.endMinute,
          where: l.room,
          colour: parseHex(l.colorHex, AppTheme.violet),
        ));
      }
    }

    for (final h in homework.where((h) => _same(h.dueDate, day))) {
      events.add(DiaryEvent(
        kind: EventKind.assignment,
        title: h.title,
        subtitle: h.subject,
        at: h.dueDate,
        homework: h,
      ));
    }

    for (final e in exams.where((e) => _same(e.date, day))) {
      events.add(DiaryEvent(
        kind: EventKind.exam,
        title: e.examTitle,
        subtitle: e.subject,
        at: e.date,
      ));
    }

    for (final n in notices.where((n) => n.sentAt != null && _same(n.sentAt!, day))) {
      events.add(DiaryEvent(
        kind: EventKind.notice,
        title: n.title,
        subtitle: n.authorName,
        at: n.sentAt!,
      ));
    }

    events.sort((a, b) => (a.startMinute ?? 9999).compareTo(b.startMinute ?? 9999));
    return events;
  }

  /// The dots under a date: one per KIND, not one per event, or a busy
  /// Wednesday becomes an unreadable smear.
  List<Color> dots(DateTime day) {
    final kinds = <EventKind>{for (final e in on(day)) e.kind};
    return [
      for (final k in EventKind.values)
        if (kinds.contains(k))
          switch (k) {
            EventKind.lesson => AppTheme.violet,
            EventKind.assignment => AppTheme.blue,
            EventKind.exam => AppTheme.amber,
            EventKind.notice => AppTheme.green,
          },
    ];
  }

  /// The next notice the school marked as a closure or a holiday.
  Announcement? get nextHoliday {
    final now = DateTime.now();
    final rows = notices
        .where((n) =>
            (n.category == 'HOLIDAY' || n.category == 'CLOSURE') &&
            n.sentAt != null &&
            n.sentAt!.isAfter(now.subtract(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => a.sentAt!.compareTo(b.sentAt!));
    return rows.isEmpty ? null : rows.first;
  }
}

/* ---------------------------------------------------------------------------
 * The month
 * ------------------------------------------------------------------------- */

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: AppTheme.dark ? Border.all(color: AppTheme.border) : null,
          boxShadow: AppTheme.dark
              ? null
              : const [BoxShadow(color: Color(0x0A101828), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_rounded, size: 15, color: AppTheme.text),
            const SizedBox(width: 7),
            Text(
              t('tt.today'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.day,
    required this.diary,
    required this.onMonth,
    required this.onDay,
  });

  final DateTime month;
  final DateTime day;
  final _Diary diary;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final now = DateTime.now();
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Sunday first: the school week starts on Sunday here.
    final lead = (first.weekday - DateTime.sunday + 7) % 7;

    return Card16(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              _Arrow(
                icon: Icons.chevron_left_rounded,
                onTap: () => onMonth(DateTime(month.year, month.month - 1)),
              ),
              Expanded(
                child: Text(
                  monthYear(month),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppTheme.text,
                  ),
                ),
              ),
              _Arrow(
                icon: Icons.chevron_right_rounded,
                onTap: () => onMonth(DateTime(month.year, month.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      t('dayShort.${(DateTime.sunday + i - 1) % 7 + 1}'),
                      style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var row = 0; row * 7 < lead + daysInMonth; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _Cell(
                      date: DateTime(month.year, month.month, row * 7 + col - lead + 1),
                      inMonth: row * 7 + col - lead + 1 >= 1 &&
                          row * 7 + col - lead + 1 <= daysInMonth,
                      selected: _Diary._same(
                        DateTime(month.year, month.month, row * 7 + col - lead + 1),
                        day,
                      ),
                      today: _Diary._same(
                        DateTime(month.year, month.month, row * 7 + col - lead + 1),
                        now,
                      ),
                      dots: diary.dots(
                        DateTime(month.year, month.month, row * 7 + col - lead + 1),
                      ),
                      tint: tint,
                      onTap: onDay,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.canvas,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Key(colour: AppTheme.violet, label: t('cal.class')),
                _Key(colour: AppTheme.blue, label: t('cal.assignment')),
                _Key(colour: AppTheme.amber, label: t('cal.exam')),
                _Key(colour: AppTheme.green, label: t('cal.event')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.colour, required this.label});

  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted)),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: AppTheme.canvas, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: AppTheme.text),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.date,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.dots,
    required this.tint,
    required this.onTap,
  });

  final DateTime date;
  final bool inMonth;
  final bool selected;
  final bool today;
  final List<Color> dots;
  final Color tint;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    // Friday and Saturday are the weekend here, and the design marks them red.
    final weekend = date.weekday == DateTime.friday || date.weekday == DateTime.saturday;

    return GestureDetector(
      onTap: inMonth ? () => onTap(date) : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 42,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? tint : Colors.transparent,
                shape: BoxShape.circle,
                border: today && !selected
                    ? Border.all(color: tint.withValues(alpha: 0.6), width: 1.5)
                    : null,
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected || today ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : !inMonth
                          ? AppTheme.textFaint
                          : weekend
                              ? AppTheme.rose
                              : AppTheme.text,
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final c in dots.take(3))
                    Container(
                      width: 4.5,
                      height: 4.5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : c,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * The day
 * ------------------------------------------------------------------------- */

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.events, required this.child});

  final DateTime day;
  final List<DiaryEvent> events;
  final Child child;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  longDate(day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppTheme.text,
                  ),
                ),
              ),
              Text(
                events.length == 1
                    ? t('cal.oneEvent')
                    : tn('cal.nEvents', events.length),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Role.parent.tint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                t('cal.nothingOn'),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
            )
          else
            for (final e in events) _EventRow(event: e, child: child),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.child});

  final DiaryEvent event;
  final Child child;

  @override
  Widget build(BuildContext context) {
    final colour = event.tint;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final hw = event.homework;
        if (hw != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => HomeworkDetail(item: hw, childName: child.name)),
          );
        } else if (event.kind == EventKind.lesson) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TimetableScreen(child: child)),
          );
        } else if (event.kind == EventKind.assignment) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AssignmentsScreen(child: child)),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The coloured spine, which is what makes a day of six things
              // read as four kinds at a glance.
              Container(
                width: 3.5,
                decoration: BoxDecoration(
                  color: colour,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 11),
              if (event.startMinute != null) ...[
                SizedBox(
                  width: 54,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        clock12(event.startMinute),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                      Text(
                        clock12(event.endMinute),
                        style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                  shape: BoxShape.circle,
                ),
                child: Icon(event.icon, size: 19, color: colour),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppTheme.text,
                      ),
                    ),
                    if (event.subtitle.isNotEmpty)
                      Text(
                        event.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Center(child: StatusChip(event.label, color: colour)),
              Center(
                child: Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * The other two views
 * ------------------------------------------------------------------------- */

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.day,
    required this.diary,
    required this.onDay,
    required this.child,
  });

  final DateTime day;
  final _Diary diary;
  final ValueChanged<DateTime> onDay;
  final Child child;

  @override
  Widget build(BuildContext context) {
    // The seven days around the chosen one, Sunday first.
    final start = day.subtract(Duration(days: (day.weekday - DateTime.sunday + 7) % 7));

    return Column(
      children: [
        for (var i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: kCardGap),
            child: _DayCard(
              day: start.add(Duration(days: i)),
              events: diary.on(start.add(Duration(days: i))),
              child: child,
            ),
          ),
      ],
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.diary, required this.child});

  final _Diary diary;
  final Child child;

  @override
  Widget build(BuildContext context) {
    // The next fortnight, skipping the days with nothing in them — which is
    // what an agenda is FOR.
    final now = DateTime.now();
    final days = <DateTime>[];
    for (var i = 0; i < 14; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      if (diary.on(d).isNotEmpty) days.add(d);
    }

    if (days.isEmpty) {
      return Card16(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            t('cal.nothingAhead'),
            style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final d in days)
          Padding(
            padding: const EdgeInsets.only(bottom: kCardGap),
            child: _DayCard(day: d, events: diary.on(d), child: child),
          ),
      ],
    );
  }
}

class _HolidayCard extends StatelessWidget {
  const _HolidayCard({required this.notice});

  final Announcement notice;

  @override
  Widget build(BuildContext context) {
    final days = notice.sentAt == null
        ? 0
        : notice.sentAt!.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.rose.withValues(alpha: AppTheme.dark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.rose.withValues(alpha: AppTheme.dark ? 0.22 : 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.event_busy_rounded, size: 20, color: AppTheme.rose),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('cal.upcomingHoliday'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.rose,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  notice.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppTheme.text),
                ),
                Text(
                  longDate(notice.sentAt),
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(
            days <= 0 ? t('due.today') : tn('cal.daysLeft', days),
            color: AppTheme.rose,
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.rose),
        ],
      ),
    );
  }
}
