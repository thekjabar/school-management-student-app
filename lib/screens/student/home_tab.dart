import 'package:flutter/material.dart';

import '../../api/student_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../awards_screen.dart';
import 'exam_planner_screen.dart';
import 'homework_screen.dart';
import 'points_screen.dart';
import 'student_kit.dart';

class StudentHome extends StatelessWidget {
  const StudentHome({super.key, required this.onOpenTab});

  final void Function(int tab) onOpenTab;

  @override
  Widget build(BuildContext context) {
    final tint = Role.student.tint;

    return Loader<_Day>(
      tint: tint,
      padding: clearOfTheBar(context, const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 18)),
      load: _Day.fetch,
      builder: (context, day) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NextLesson(
            lesson: day.today.nextSlot,
            onOpen: () => onOpenTab(1),
          ),
          const SizedBox(height: kCardGap),

          StudentTiles(
            tiles: [
              StudentTile(
                icon: Icons.description_rounded,
                label: t('student.homework'),
                color: AppTheme.amber,
                onTap: () => _push(context, const StudentHomeworkScreen()),
              ),
              StudentTile(
                icon: Icons.calendar_month_rounded,
                label: t('student.timetable'),
                color: tint,
                onTap: () => onOpenTab(1),
              ),
              StudentTile(
                icon: Icons.workspace_premium_rounded,
                label: t('student.marks'),
                color: AppTheme.blue,
                onTap: () => onOpenTab(2),
              ),
              if (day.features.examPlanner)
                StudentTile(
                  icon: Icons.fact_check_rounded,
                  label: t('student.examPlanner'),
                  color: AppTheme.rose,
                  onTap: () => _push(context, const StudentExamPlannerScreen()),
                ),
              if (day.features.housePoints)
                StudentTile(
                  icon: Icons.shield_rounded,
                  label: t('student.points'),
                  color: AppTheme.green,
                  onTap: () => _push(context, const StudentPointsScreen()),
                ),
              if (day.features.awards)
                StudentTile(
                  icon: Icons.emoji_events_rounded,
                  label: t('student.awards'),
                  color: AppTheme.amber,
                  onTap: () => _push(
                    context,
                    AwardsScreen(
                      load: StudentApi.instance.awards,
                      words: studentAwardsWords,
                      tint: tint,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: kCardGap),

          if (day.glance?.nextClass case final now? when now.inProgress && now.minutesLeft != null) ...[
            _NowNow(lesson: now),
            const SizedBox(height: kCardGap),
          ],

          Card16(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionRow(
                  title: t('student.homeSchedule'),
                  actionLabel: t('student.viewFullTimetable'),
                  onAction: () => onOpenTab(1),
                ),
                if (day.today.slots.isEmpty)
                  _Quiet(text: t('student.nothingToday'))
                else
                  ScheduleTimeline(
                    trailingIcon: Icons.circle_outlined,
                    entries: [
                      for (var i = 0; i < day.today.slots.length; i++)
                        lessonEntry(day.today.slots[i], tint, finished: i < _doneBefore(day.today)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

int _doneBefore(TodayTimetable today) {
  final slots = today.slots;
  final current = slots.indexWhere((s) => s.inProgress);
  if (current >= 0) return current;
  final next = today.nextSlot;
  if (next != null) {
    final at = slots.indexWhere((s) => s.startMinute == next.startMinute && s.subject == next.subject);
    return at >= 0 ? at : 0;
  }
  final now = DateTime.now();
  final minute = now.hour * 60 + now.minute;
  final firstStart = slots.isEmpty ? null : slots.first.startMinute;
  return firstStart != null && minute > firstStart ? slots.length : 0;
}

class _Day {
  _Day({required this.features, required this.today, required this.glance});

  final StudentFeatures features;
  final TodayTimetable today;
  final TodayGlance? glance;

  static Future<T?> _orNothing<T>(Future<T> Function() job) async {
    try {
      return await job();
    } catch (_) {
      return null;
    }
  }

  static Future<_Day> fetch() async {
    final api = StudentApi.instance;
    final results = await Future.wait([
      api.me(),
      api.today(),
      _orNothing(api.glance),
    ]);
    return _Day(
      features: (results[0] as StudentProfile).features,
      today: results[1] as TodayTimetable,
      glance: results[2] as TodayGlance?,
    );
  }
}

class _NowNow extends StatelessWidget {
  const _NowNow({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final tint = Role.student.tint;
    final where = [lesson.subject, if ((lesson.room ?? '').isNotEmpty) lesson.room!].join('  •  ');
    return Card16(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('student.nowIn'),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SoftPill(text: tn('student.minutesLeft', lesson.minutesLeft!), color: tint),
              _SoftPill(text: where, color: tint),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoftPill extends StatelessWidget {
  const _SoftPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.dark ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _NextLesson extends StatelessWidget {
  const _NextLesson({required this.lesson, required this.onOpen});

  final Lesson? lesson;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final next = lesson;
    final line = next == null
        ? null
        : [ltrIsolated(clock12(next.startMinute)), if ((next.room ?? '').isNotEmpty) ltrIsolated(next.room!)].join('  •  ');

    return StudentHero(
      label: next == null ? t('student.doneForToday') : t('student.nextLesson'),
      title: next?.subject ?? t('student.restWell'),
      line: line,
      openLabel: next == null ? null : t('student.viewLesson'),
      onOpen: next == null ? null : onOpen,
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 12),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.45),
      ),
    );
  }
}
