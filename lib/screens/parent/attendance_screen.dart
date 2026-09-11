import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

typedef BandLook = ({Color colour, IconData icon, String title});

BandLook attendanceBand(String? band) => switch (band) {
      'OK' => (colour: AppTheme.green, icon: Icons.emoji_events_rounded, title: t('att.bandOk')),
      'WATCH' => (
          colour: AppTheme.amber,
          icon: Icons.visibility_outlined,
          title: t('att.bandWatch')
        ),
      'CONCERN' => (
          colour: AppTheme.rose,
          icon: Icons.support_agent_rounded,
          title: t('att.bandConcern')
        ),
      _ => (
          colour: AppTheme.blue,
          icon: Icons.hourglass_bottom_rounded,
          title: t('att.bandUnknown')
        ),
    };

String attendanceBandBody(AttendanceTrend trend, String name, String term) =>
    switch (trend.band) {
      'OK' => tv('att.bandOkBody', {'name': name, 'term': term}),
      'WATCH' => tv('att.bandWatchBody', {
          'name': name,
          'n': percent(trend.missedPercent),
          'term': term,
        }),
      'CONCERN' => tv('att.bandConcernBody', {
          'name': name,
          'n': percent(trend.missedPercent),
          'term': term,
        }),
      _ => tv('att.bandUnknownBody', {
          'name': name,
          'n': trend.daysMarked,
          'term': term,
        }),
    };

typedef _Trended = ({AttendanceSummary summary, AttendanceTrend trend});

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
              child: Loader<_Trended>(
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 20),
                load: () async {
                  final api = ParentApi.instance;
                  final both = await Future.wait([
                    api.attendance(widget.child.studentId),
                    api.attendanceTrend(widget.child.studentId),
                  ]);
                  return (
                    summary: both[0] as AttendanceSummary,
                    trend: both[1] as AttendanceTrend,
                  );
                },
                builder: (context, data) {
                  final a = data.summary;
                  final trend = data.trend;
                  final term = termCaption(trend.termName, trend.from, trend.to);
                  final look = attendanceBand(trend.band);
                  final previous = trend.previous;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card16(
                        padding: const EdgeInsets.fromLTRB(12, 13, 12, 11),
                        child: Column(
                          children: [
                            IconFigureStrip(
                              figures: [
                                IconFigure(
                                  icon: Icons.verified_user_outlined,
                                  label: t('att.present'),
                                  value: percent(trend.attendanceRate),
                                  caption: term,
                                  color: AppTheme.green,
                                ),
                                IconFigure(
                                  icon: Icons.event_busy_outlined,
                                  label: t('att.absent'),
                                  value: '${trend.absent}',
                                  caption: term,
                                  color: AppTheme.rose,
                                ),
                                IconFigure(
                                  icon: Icons.schedule_rounded,
                                  label: t('att.late'),
                                  value: '${trend.late}',
                                  caption: term,
                                  color: AppTheme.blue,
                                ),
                                IconFigure(
                                  icon: Icons.pie_chart_outline_rounded,
                                  label: t('att.missed'),
                                  value: percent(trend.missedPercent),
                                  caption: term,
                                  color: look.colour,
                                ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            Divider(height: 1, color: AppTheme.border),
                            const SizedBox(height: 9),
                            _CoverageLine(trend: trend),
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

                      if (_tab == 2) ...[
                        _TrendCard(trend: trend),
                        const SizedBox(height: kCardGap),
                        if (previous?.termName != null) ...[
                          _CompareCard(trend: trend, previous: previous!, term: term),
                          const SizedBox(height: kCardGap),
                        ],
                        _Statistics(summary: a),
                      ] else
                        _MonthCard(
                          month: _month,
                          summary: a,
                          rate: trend.attendanceRate,
                          rateColour: look.colour,
                          compact: _tab == 0,
                          onMonth: (d) => setState(() => _month = d),
                        ),
                      const SizedBox(height: kCardGap),

                      _RecentCard(summary: a),
                      const SizedBox(height: kCardGap),

                      NoticeBanner(
                        icon: look.icon,
                        color: look.colour,
                        title: look.title,
                        body: attendanceBandBody(
                          trend,
                          widget.child.name.split(' ').first,
                          term,
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

class _CoverageLine extends StatelessWidget {
  const _CoverageLine({required this.trend});

  final AttendanceTrend trend;

  @override
  Widget build(BuildContext context) {
    final line = trend.expectedSchoolDays > 0
        ? tv('att.registersTaken', {
            'n': trend.daysMarked,
            'm': trend.expectedSchoolDays,
          })
        : tn('att.registersMarked', trend.daysMarked);

    return Row(
      children: [
        Icon(Icons.fact_check_outlined, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            line,
            style: TextStyle(fontSize: 11, height: 1.3, color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});

  final AttendanceTrend trend;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final months = trend.byMonth.where((m) => m.monthNumber > 0).toList();

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(title: t('att.trend')),
          if (months.isEmpty)
            Text(
              t('att.nothingMarked'),
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            )
          else
            SizedBox(
              height: 104,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final m in months)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                percent(m.attendanceRate),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.text,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 62,
                              alignment: Alignment.bottomCenter,
                              decoration: BoxDecoration(
                                color: AppTheme.border,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: m.daysMarked == 0 || m.attendanceRate == null
                                  ? null
                                  : FractionallySizedBox(
                                      widthFactor: 1,
                                      heightFactor:
                                          (m.attendanceRate! / 100).clamp(0.06, 1.0),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: tint,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                t('monthShort.${m.monthNumber}'),
                                style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Text(
            t('att.missedIncludesExcused'),
            style: TextStyle(fontSize: 10.5, height: 1.35, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.trend,
    required this.previous,
    required this.term,
  });

  final AttendanceTrend trend;
  final AttendanceTermFigures previous;
  final String term;

  @override
  Widget build(BuildContext context) {
    final (word, colour) = switch (trend.direction) {
      'BETTER' => (t('att.better'), AppTheme.green),
      'WORSE' => (t('att.worse'), AppTheme.rose),
      'SAME' => (t('att.same'), AppTheme.blue),
      _ => (t('att.noComparison'), AppTheme.textMuted),
    };

    Widget row(String label, double? missed, bool strong) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                    color: strong ? AppTheme.text : AppTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                percent(missed),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: strong ? AppTheme.text : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        );

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(
            title: tv('att.comparedWith', {'term': previous.termName ?? '—'}),
            dense: true,
          ),
          Text(
            t('att.missedShare'),
            style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
          ),
          row(term, trend.missedPercent, true),
          Divider(height: 1, color: AppTheme.border),
          row(previous.termName ?? '—', previous.missedPercent, false),
          const SizedBox(height: 9),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Pill(word, color: colour),
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.summary,
    required this.rate,
    required this.rateColour,
    required this.compact,
    required this.onMonth,
  });

  final DateTime month;
  final AttendanceSummary summary;

  final double? rate;
  final Color rateColour;

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
                        if (rate == null)
                          SizedBox(
                            width: 84,
                            height: 84,
                            child: Center(
                              child: Text(
                                '—',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          )
                        else
                          PercentRing(percent: rate!, color: rateColour, size: 84),
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

  static const _weekStart = DateTime.sunday;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final now = DateTime.now();
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

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

  String _weekdayShort(int weekday) => t('dayShort.$weekday');
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
    final weekend = date.weekday == DateTime.friday || date.weekday == DateTime.saturday;
    final past = !date.isAfter(DateTime(now.year, now.month, now.day));

    Color? dot;
    if (!weekend && past) {
      dot = switch (status) {
        'ABSENT' => AppTheme.rose,
        'LATE' => AppTheme.blue,
        'EXCUSED' => AppTheme.amber,
        'LEFT_EARLY' => AppTheme.violet,
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
          if (summary.leftEarly > 0)
            row(AppTheme.violet, t('att.leftEarly'), summary.leftEarly),
        ],
      ),
    );
  }
}

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
      'LEFT_EARLY' => (AppTheme.violet, t('att.leftEarly'), Icons.logout_rounded),
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
                  t('monthShort.${item.date.month}'),
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
                  t('dayShort.${item.date.weekday}'),
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
          if (summary.leftEarly > 0) bar(t('att.leftEarly'), summary.leftEarly, AppTheme.violet),
        ],
      ),
    );
  }
}
