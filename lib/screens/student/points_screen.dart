import 'package:flutter/material.dart';

import '../../api/student_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

class StudentPointsScreen extends StatelessWidget {
  const StudentPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tint = Role.student.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Column(
        children: [
          ScreenHeader(title: t('student.points')),
          Expanded(
            child: Loader<MyPoints>(
              tint: tint,
              padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 28),
              load: () => StudentApi.instance.points(),
              builder: (context, points) => _Points(points: points),
            ),
          ),
        ],
      ),
    );
  }
}

class _Points extends StatelessWidget {
  const _Points({required this.points});

  final MyPoints points;

  @override
  Widget build(BuildContext context) {
    final house = points.house;
    final colour = parseHex(house?.colorHex, Role.student.tint);
    final bare = points.week.total == 0 && points.term.total == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (house == null)
          NoticeBanner(
            icon: Icons.holiday_village_outlined,
            title: t('student.yourHouse'),
            body: t('student.noHouse'),
            color: AppTheme.textMuted,
          )
        else
          Card16(
            padding: const EdgeInsets.all(16),
            color: colour.withValues(alpha: 0.10),
            border: colour.withValues(alpha: 0.35),
            child: Row(
              children: [
                Chip36(icon: Icons.shield_rounded, color: colour, size: 46),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('student.yourHouse'),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppTheme.textFaint,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        house.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.2,
                          color: AppTheme.text,
                        ),
                      ),
                      if ((house.motto ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          house.motto!,
                          style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.textMuted),
                        ),
                      ],
                      const SizedBox(height: 7),
                      Pill(
                        tn('student.houseTermPoints', _points(house.termPoints)),
                        color: colour,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (bare) ...[
          const SizedBox(height: kCardGap),
          NoticeBanner(
            icon: Icons.emoji_events_outlined,
            title: t('student.points'),
            body: t('student.pointsNone'),
            color: AppTheme.amber,
          ),
        ],
        Heading(t('student.pointsThisWeek')),
        _Window(
          window: points.week,
          colour: AppTheme.blue,
          caption: dayRange(points.week.from, points.week.to),
        ),
        const SizedBox(height: kCardGap),
        Heading(t('student.pointsThisTerm')),
        _Window(
          window: points.term,
          colour: AppTheme.violet,
          caption: termCaption(points.term.termName, points.term.from, points.term.to),
        ),
        Heading(t('student.keepingUp')),
        _Streak(
          icon: Icons.event_available_rounded,
          colour: AppTheme.green,
          days: points.attendanceStreak,
          label: tn('student.daysAtSchool', points.attendanceStreak),
          since: points.attendanceSince,
          none: t('student.noSchoolRun'),
        ),
        const SizedBox(height: kCardGap),
        _Streak(
          icon: Icons.task_alt_rounded,
          colour: AppTheme.amber,
          days: points.homeworkStreak,
          label: tn('student.homeworkOnTime', points.homeworkStreak),
          since: points.homeworkSince,
          none: t('student.noHomeworkRun'),
        ),
      ],
    );
  }
}

String _points(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(1);

class _Window extends StatelessWidget {
  const _Window({required this.window, required this.colour, required this.caption});

  final PointsWindow window;
  final Color colour;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatBox(
                  icon: Icons.emoji_events_outlined,
                  value: _points(window.total),
                  label: t('student.pointsAltogether'),
                  caption: caption,
                  color: colour,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatBox(
                  icon: Icons.person_outline_rounded,
                  value: _points(window.meritPoints),
                  label: t('student.pointsFromTeachers'),
                  caption: '',
                  color: AppTheme.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatBox(
                  icon: Icons.savings_outlined,
                  value: _points(window.bankedPoints),
                  label: t('student.pointsBanked'),
                  caption: '',
                  color: AppTheme.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Streak extends StatelessWidget {
  const _Streak({
    required this.icon,
    required this.colour,
    required this.days,
    required this.label,
    required this.since,
    required this.none,
  });

  final IconData icon;
  final Color colour;
  final int days;
  final String label;
  final DateTime? since;
  final String none;

  @override
  Widget build(BuildContext context) {
    final running = days > 0;

    return Card16(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Chip36(icon: icon, color: running ? colour : AppTheme.textFaint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  running ? label : none,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: AppTheme.text,
                  ),
                ),
                if (running && since != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    tv('student.sinceDay', {'name': shortDate(since)}),
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
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
