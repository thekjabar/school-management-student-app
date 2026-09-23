import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/student_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../awards_screen.dart';
import 'announcements_screen.dart';
import 'exam_planner_screen.dart';
import 'hand_in_screen.dart';
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
            lessons: day.today.slots.length,
            onOpen: () => onOpenTab(1),
          ),
          const SizedBox(height: kCardGap),

          StudentTiles(
            tiles: [
              StudentTile(
                icon: Icons.calendar_month_rounded,
                label: t('student.timetable'),
                color: tint,
                onTap: () => onOpenTab(1),
              ),
              StudentTile(
                icon: Icons.description_rounded,
                label: t('student.homework'),
                color: AppTheme.amber,
                onTap: () => _push(context, const StudentHomeworkScreen()),
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

          if (day.glance != null) ...[
            _Glance(
              glance: day.glance!,
              handInOn: day.features.homeworkHandIn,
              onHandIn: (id) => _push(context, StudentHandInScreen(homeworkId: id)),
            ),
            const SizedBox(height: kCardGap),
          ],

          SectionRow(
            title: t('student.todaySchedule'),
            actionLabel: t('student.fullTimetable'),
            onAction: () => onOpenTab(1),
          ),
          Card16(
            padding: const EdgeInsets.fromLTRB(10, 4, 14, 4),
            child: day.today.slots.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 0, 12),
                    child: _Quiet(text: t('student.nothingToday')),
                  )
                : ScheduleTimeline(
                    trailingIcon: Icons.circle_outlined,
                    entries: [
                      for (final s in day.today.slots) lessonEntry(s, tint),
                    ],
                  ),
          ),
          const SizedBox(height: kCardGap),

          Card16(
            padding: EdgeInsets.fromLTRB(14, 14, 14, day.homework.isEmpty ? 14 : 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionRow(
                  title: t('student.homeworkDue'),
                  actionLabel: t('student.seeAll'),
                  onAction: () => _push(context, const StudentHomeworkScreen()),
                ),
                if (day.homework.isEmpty)
                  _Quiet(text: t('student.noHomework'))
                else
                  for (var i = 0; i < day.homework.length; i++)
                    TileRow(
                      icon: subjectIcon(day.homework[i].subject),
                      color: parseHex(day.homework[i].subjectColorHex, AppTheme.amber),
                      title: day.homework[i].title,
                      subtitle: day.homework[i].subject,
                      trailing: dueWord(day.homework[i].daysLeft),
                      trailingColor:
                          day.homework[i].daysLeft < 1 ? AppTheme.rose : AppTheme.textMuted,
                      last: i == day.homework.length - 1,
                      onTap: () => _push(context, const StudentHomeworkScreen()),
                    ),
              ],
            ),
          ),
          const SizedBox(height: kCardGap),

          if (day.marks.isNotEmpty) ...[
            Card16(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionRow(
                    title: t('student.recentMarks'),
                    actionLabel: t('student.seeAll'),
                    onAction: () => onOpenTab(2),
                  ),
                  for (var i = 0; i < day.marks.length; i++)
                    TileRow(
                      icon: subjectIcon(day.marks[i].subject),
                      color: parseHex(day.marks[i].subjectColorHex, AppTheme.violet),
                      title: day.marks[i].subject,
                      subtitle: day.marks[i].examTitle,
                      trailing: day.marks[i].wasAbsent
                          ? t('marks.absent')
                          : '${_trim(day.marks[i].score)} / ${_trim(day.marks[i].maxScore)}',
                      trailingSub: percent(day.marks[i].percent),
                      trailingColor:
                          day.marks[i].isPass == false ? AppTheme.rose : AppTheme.green,
                      last: i == day.marks.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: kCardGap),
          ],

          Card16(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionRow(
                  title: t('student.latestNews'),
                  actionLabel: t('student.seeAll'),
                  onAction: () => _push(context, const StudentAnnouncementsScreen()),
                ),
                if (day.news.isEmpty)
                  _Quiet(text: t('student.noNews'))
                else
                  UpdatesFeed(
                    entries: [
                      for (final n in day.news)
                        UpdateEntry(
                          icon: Icons.campaign_rounded,
                          category: humanise(n.category),
                          title: n.title,
                          when: shortDate(n.sentAt),
                          color: n.priority == 'URGENT' ? AppTheme.rose : AppTheme.blue,
                          onTap: () => _push(context, const StudentAnnouncementsScreen()),
                        ),
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

String _trim(double? value) {
  if (value == null) return '—';
  return value == value.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(1);
}

class _Day {
  _Day({
    required this.features,
    required this.today,
    required this.glance,
    required this.homework,
    required this.marks,
    required this.news,
  });

  final StudentFeatures features;
  final TodayTimetable today;
  final TodayGlance? glance;
  final List<Homework> homework;
  final List<Mark> marks;
  final List<StudentNotice> news;

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
      api.homework(pageSize: 4),
      api.marks(),
      api.announcements(pageSize: 3),
      _orNothing(api.glance),
    ]);

    final marks = results[3] as List<Mark>;
    return _Day(
      features: (results[0] as StudentProfile).features,
      today: results[1] as TodayTimetable,
      glance: results[5] as TodayGlance?,
      homework: (results[2] as Paged<Homework>).rows,
      marks: marks.take(3).toList(growable: false),
      news: (results[4] as Paged<StudentNotice>).rows,
    );
  }
}

class _Glance extends StatelessWidget {
  const _Glance({required this.glance, required this.handInOn, required this.onHandIn});

  final TodayGlance glance;
  final bool handInOn;
  final void Function(String homeworkId) onHandIn;

  String? get _marked {
    switch (glance.attendanceStatus) {
      case null:
        return null;
      case 'PRESENT':
        return t('student.markedPresentToday');
      case 'LATE':
        return tn('student.markedLateToday', glance.minutesLate ?? 0);
      case 'ABSENT':
        return t('student.markedAbsentToday');
      default:
        return humanise(glance.attendanceStatus!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.student.tint;
    final next = glance.nextClass;
    final exam = glance.nextExam;
    final marked = _marked;

    final inLesson = next != null && next.inProgress && next.minutesLeft != null;

    final pills = <Widget>[
      if (next != null && !next.inProgress && next.minutesUntilStart != null)
        Pill(tn('student.startsInMinutes', next.minutesUntilStart!), color: tint),
      if (glance.classesLeft > 1)
        Pill(tn('student.lessonsLeft', glance.classesLeft), color: AppTheme.blue),
      if (glance.classesLeft == 1)
        Pill(t('student.lastLessonOfDay'), color: AppTheme.amber),
    ];

    if (!inLesson && pills.isEmpty && marked == null && exam == null && glance.dueToday.isEmpty) {
      return const SizedBox.shrink();
    }

    final rest = pills.isNotEmpty || marked != null || exam != null || glance.dueToday.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inLesson) _nowCard(next, tint),
        if (inLesson && rest) const SizedBox(height: kCardGap),
        if (rest)
          Card16(
            padding: EdgeInsets.fromLTRB(14, 14, 14, glance.dueToday.isEmpty ? 14 : 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pills.isNotEmpty)
                  Wrap(spacing: 6, runSpacing: 6, children: pills),
                if (marked != null) ...[
                  if (pills.isNotEmpty) const SizedBox(height: 10),
                  Text(
                    marked,
                    style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
                  ),
                ],
                if (exam != null) ...[
                  const SizedBox(height: 12),
                  TileRow(
                    icon: Icons.fact_check_outlined,
                    color: parseHex(exam.subjectColorHex, AppTheme.rose),
                    title: exam.title,
                    subtitle: '${t('student.nextExam')}  •  ${exam.subject}',
                    trailing: dueWord(exam.daysLeft),
                    trailingColor: exam.daysLeft <= 3 ? AppTheme.rose : AppTheme.textMuted,
                    last: true,
                  ),
                ],
                if (glance.dueToday.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  StudentSectionLabel(t('student.dueToday')),
                  const SizedBox(height: 6),
                  for (var i = 0; i < glance.dueToday.length; i++)
                    TileRow(
                      icon: subjectIcon(glance.dueToday[i].subject),
                      color: parseHex(glance.dueToday[i].subjectColorHex, AppTheme.amber),
                      title: glance.dueToday[i].title,
                      subtitle: glance.dueToday[i].subject,
                      trailing: glance.dueToday[i].handedIn != null
                          ? t('student.handedIn')
                          : glance.dueToday[i].handInOpen && handInOn
                              ? t('student.handIn')
                              : null,
                      trailingColor: glance.dueToday[i].handedIn != null
                          ? AppTheme.green
                          : AppTheme.blue,
                      last: i == glance.dueToday.length - 1,
                      onTap: handInOn && glance.dueToday[i].handInOpen
                          ? () => onHandIn(glance.dueToday[i].id)
                          : null,
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _nowCard(Lesson next, Color tint) {
    final start = next.startMinute;
    final end = next.endMinute;
    final span = start != null && end != null ? end - start : 0;
    return NowCard(
      minutesLeft: next.minutesLeft!,
      fraction: span > 0 ? next.minutesLeft! / span : 1,
      subject: next.subject,
      under: [
        if ((next.teacherName ?? '').isNotEmpty) next.teacherName!,
        if ((next.room ?? '').isNotEmpty) next.room!,
      ].join('  •  '),
      color: parseHex(next.subjectColorHex, tint),
    );
  }
}

class _NextLesson extends StatelessWidget {
  const _NextLesson({required this.lesson, required this.lessons, required this.onOpen});

  final Lesson? lesson;
  final int lessons;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final next = lesson;

    return StudentHero(
      label: next == null ? t('student.doneForToday') : t('student.nextLesson'),
      title: next?.subject ?? t('student.restWell'),
      badge: lessons == 0 ? null : tn('student.lessonsTodayCount', lessons),
      facts: next == null
          ? const []
          : [
              (Icons.schedule_rounded, clock12(next.startMinute)),
              if ((next.room ?? '').isNotEmpty) (Icons.meeting_room_rounded, next.room!),
            ],
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
