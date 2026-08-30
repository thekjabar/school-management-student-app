import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// The register, as a month rather than a tally.
///
/// The four figures answer "is this a problem"; the calendar answers "when",
/// which is the question a parent asks next and the one a percentage cannot.
/// Absences are the only days the school records individually, so every other
/// school day in the past is drawn present — which is what the register means.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.child});

  final Child child;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  int _tab = 0;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('quick.attendance')),
            Expanded(
              child: Loader<AttendanceSummary>(
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 20),
                load: () => ParentApi.instance.attendance(widget.child.studentId),
                builder: (context, a) {
                  final good = a.ratePercent >= 95;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card16(
                        padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
                        child: IconFigureStrip(
                          figures: [
                            IconFigure(
                              icon: Icons.verified_user_outlined,
                              label: t('att.present'),
                              value: a.total > 0 ? '${a.ratePercent}%' : '—',
                              caption: t('att.thisTerm'),
                              color: AppTheme.green,
                            ),
                            IconFigure(
                              icon: Icons.event_busy_outlined,
                              label: t('att.absent'),
                              value: '${a.absent}',
                              caption: t('att.thisTerm'),
                              color: AppTheme.amber,
                            ),
                            IconFigure(
                              icon: Icons.schedule_rounded,
                              label: t('att.late'),
                              value: '${a.late}',
                              caption: t('att.thisTerm'),
                              color: AppTheme.blue,
                            ),
                            IconFigure(
                              icon: Icons.track_changes_rounded,
                              // 'Rate' rather than 'Attendance rate': the strip
                              // gives each label a quarter of a phone.
                              label: t('att.rateShort'),
                              value: a.total > 0 ? '${a.ratePercent}%' : '—',
                              caption: t('att.thisTerm'),
                              color: AppTheme.violet,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: kCardGap),

                      PillTabs(
                        tint: tint,
                        index: _tab,
                        onChanged: (i) => setState(() => _tab = i),
                        tabs: [
                          TabSpec(label: t('att.overview'), icon: Icons.grid_view_rounded),
                          TabSpec(label: t('att.calendarView'), icon: Icons.event_available_rounded),
                          TabSpec(label: t('att.statistics'), icon: Icons.bar_chart_rounded),
                        ],
                      ),
                      const SizedBox(height: kCardGap),

                      if (_tab == 2)
                        _Statistics(summary: a)
                      else
                        _MonthCard(
                          month: _month,
                          summary: a,
                          compact: _tab == 0,
                          onMonth: (d) => setState(() => _month = d),
                        ),
                      const SizedBox(height: kCardGap),

                      _RecentCard(summary: a),
                      const SizedBox(height: kCardGap),

                      NoticeBanner(
                        icon: good ? Icons.emoji_events_rounded : Icons.visibility_outlined,
                        color: good ? AppTheme.green : AppTheme.amber,
                        title: good ? t('att.goodJob') : t('attendance.watchThis'),
                        body: tn(
                          good ? 'att.goodJobBody' : 'att.watchBody',
                          widget.child.name.split(' ').first,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * The month
 * ------------------------------------------------------------------------- */

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.summary,
    required this.compact,
    required this.onMonth,
  });

  final DateTime month;
  final AttendanceSummary summary;

  /// Overview puts the legend and the ring beside the grid; the calendar tab
  /// gives the grid the whole card.
  final bool compact;

  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context) {
    final grid = _Grid(month: month, summary: summary, onMonth: onMonth);

    return Card16(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: compact
          ? Column(
              children: [
                grid,
                const SizedBox(height: 12),
                Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _Legend(summary: summary)),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        Text(
                          t('att.rate'),
                          style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 6),
                        PercentRing(
                          percent: summary.ratePercent.toDouble(),
                          color: summary.ratePercent >= 95 ? AppTheme.green : AppTheme.amber,
                          size: 84,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            )
          : grid,
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.month, required this.summary, required this.onMonth});

  final DateTime month;
  final AttendanceSummary summary;
  final ValueChanged<DateTime> onMonth;

  /// Sunday first — the school week here starts on Sunday, and a grid that
  /// starts on Monday puts the weekend in the middle of the row.
  static const _weekStart = DateTime.sunday;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final now = DateTime.now();
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // How many blanks before the 1st.
    final lead = (first.weekday - _weekStart + 7) % 7;

    final marks = <int, String>{};
    for (final e in summary.exceptions) {
      if (e.date.year == month.year && e.date.month == month.month) {
        marks[e.date.day] = e.status;
      }
    }

    return Column(
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
                  fontSize: 15,
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
                    _weekdayShort((_weekStart + i - 1) % 7 + 1),
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row * 7 < lead + daysInMonth; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _Cell(
                    day: row * 7 + col - lead + 1,
                    daysInMonth: daysInMonth,
                    month: month,
                    now: now,
                    status: marks[row * 7 + col - lead + 1],
                    tint: tint,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  String _weekdayShort(int weekday) => t('day.$weekday').characters.take(3).toString();
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
        decoration: BoxDecoration(
          color: AppTheme.canvas,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, size: 18, color: AppTheme.text),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.day,
    required this.daysInMonth,
    required this.month,
    required this.now,
    required this.status,
    required this.tint,
  });

  final int day;
  final int daysInMonth;
  final DateTime month;
  final DateTime now;
  final String? status;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 40);

    final date = DateTime(month.year, month.month, day);
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    // Friday and Saturday are the weekend here.
    final weekend = date.weekday == DateTime.friday || date.weekday == DateTime.saturday;
    final past = !date.isAfter(DateTime(now.year, now.month, now.day));

    Color? dot;
    if (!weekend && past) {
      dot = switch (status) {
        'ABSENT' => AppTheme.rose,
        'LATE' => AppTheme.blue,
        'EXCUSED' => AppTheme.amber,
        _ => AppTheme.green,
      };
    }

    return SizedBox(
      height: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? tint : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday
                    ? Colors.white
                    : weekend
                        ? AppTheme.rose
                        : AppTheme.text,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isToday ? Colors.transparent : (dot ?? Colors.transparent),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    Widget row(Color colour, String label, int n) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.text),
                ),
              ),
              Text(
                n == 1 ? t('att.oneDay') : tn('att.days', n),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          row(AppTheme.green, t('att.present'), summary.present),
          row(AppTheme.rose, t('att.absent'), summary.absent),
          row(AppTheme.blue, t('att.late'), summary.late),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Recent, and the numbers behind it
 * ------------------------------------------------------------------------- */

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final rows = [...summary.exceptions]..sort((a, b) => b.date.compareTo(a.date));

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(title: t('att.recent'), actionLabel: null),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                summary.total > 0 ? t('att.everyDay') : t('att.nothingMarked'),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
            )
          else
            for (var i = 0; i < rows.take(5).length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppTheme.border),
              _DayRow(item: rows[i]),
            ],
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.item});

  final AttendanceException item;

  @override
  Widget build(BuildContext context) {
    final (colour, word, icon) = switch (item.status) {
      'ABSENT' => (AppTheme.rose, t('att.absent'), Icons.cancel_rounded),
      'LATE' => (AppTheme.blue, t('att.late'), Icons.schedule_rounded),
      'EXCUSED' => (AppTheme.amber, t('att.excusedShort'), Icons.event_available_rounded),
      _ => (AppTheme.green, t('att.present'), Icons.check_circle_rounded),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: colour.withValues(alpha: AppTheme.dark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                Text(
                  t('month.${item.date.month}').characters.take(3).toString(),
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: colour),
                ),
                Text(
                  '${item.date.day}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: colour,
                  ),
                ),
                Text(
                  t('day.${item.date.weekday}').characters.take(3).toString(),
                  style: TextStyle(fontSize: 9, color: colour),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Icon(icon, size: 19, color: colour),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  item.minutesLate != null
                      ? tn('att.minutes', item.minutesLate!)
                      : (item.reason ?? t('att.regularHours')),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(word, color: colour),
        ],
      ),
    );
  }
}

class _Statistics extends StatelessWidget {
  const _Statistics({required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final marked = summary.total;

    Widget bar(String label, int n, Color colour) {
      final share = marked == 0 ? 0.0 : n / marked;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12, color: AppTheme.text),
                  ),
                ),
                Text(
                  '$n  ·  ${(share * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colour,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: share.clamp(0, 1),
                minHeight: 7,
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation(colour),
              ),
            ),
          ],
        ),
      );
    }

    return Card16(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(title: t('att.statistics')),
          bar(t('att.present'), summary.present, AppTheme.green),
          bar(t('att.absent'), summary.absent, AppTheme.rose),
          bar(t('att.late'), summary.late, AppTheme.blue),
          if (summary.excused > 0) bar(t('attendance.excused'), summary.excused, AppTheme.amber),
        ],
      ),
    );
  }
}
