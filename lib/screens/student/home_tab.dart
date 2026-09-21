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
import 'announcements_screen.dart';
import 'homework_screen.dart';
import 'id_card.dart';

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
          _NextLesson(lesson: day.today.nextSlot, lessons: day.today.slots.length),
          const SizedBox(height: kCardGap),

          QuickActions(
            actions: [
              QuickAction(
                icon: Icons.calendar_month_outlined,
                label: t('student.timetable'),
                color: tint,
                onTap: () => onOpenTab(1),
              ),
              QuickAction(
                icon: Icons.description_outlined,
                label: t('student.homework'),
                color: AppTheme.amber,
                onTap: () => _push(context, const StudentHomeworkScreen()),
              ),
              QuickAction(
                icon: Icons.workspace_premium_outlined,
                label: t('student.marks'),
                color: AppTheme.violet,
                onTap: () => onOpenTab(2),
              ),
              QuickAction(
                icon: Icons.qr_code_2_rounded,
                label: t('student.idCard'),
                color: AppTheme.blue,
                onTap: () => showIdCard(context),
              ),
              QuickAction(
                icon: Icons.campaign_outlined,
                label: t('student.announcements'),
                color: AppTheme.rose,
                onTap: () => _push(context, const StudentAnnouncementsScreen()),
              ),
            ],
          ),
          const SizedBox(height: kCardGap),

          Card16(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionRow(
                  title: t('student.todaySchedule'),
                  actionLabel: t('student.fullTimetable'),
                  onAction: () => onOpenTab(1),
                ),
                if (day.today.slots.isEmpty)
                  _Quiet(text: t('student.nothingToday'))
                else
                  ScheduleTimeline(
                    trailingIcon: Icons.circle_outlined,
                    entries: [
                      for (final s in day.today.slots)
                        ScheduleEntry(
                          time: clock12(s.startMinute),
                          subject: s.subject,
                          teacher: s.teacherName,
                          room: s.room,
                          color: parseHex(s.subjectColorHex, tint),
                        ),
                    ],
                  ),
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
  _Day({required this.today, required this.homework, required this.marks, required this.news});

  final TodayTimetable today;
  final List<Homework> homework;
  final List<Mark> marks;
  final List<StudentNotice> news;

  static Future<_Day> fetch() async {
    final api = StudentApi.instance;
    final results = await Future.wait([
      api.today(),
      api.homework(pageSize: 4),
      api.marks(),
      api.announcements(pageSize: 3),
    ]);

    final marks = results[2] as List<Mark>;
    return _Day(
      today: results[0] as TodayTimetable,
      homework: (results[1] as Paged<Homework>).rows,
      marks: marks.take(3).toList(growable: false),
      news: (results[3] as Paged<StudentNotice>).rows,
    );
  }
}

class _NextLesson extends StatelessWidget {
  const _NextLesson({required this.lesson, required this.lessons});

  final Lesson? lesson;
  final int lessons;

  @override
  Widget build(BuildContext context) {
    final tint = Role.student.tint;
    final next = lesson;

    return Card16(
      padding: const EdgeInsets.all(16),
      color: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  next == null ? Icons.celebration_rounded : subjectIcon(next.subject),
                  size: 19,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  next == null ? t('student.doneForToday') : t('student.nextLesson'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ),
              Text(
                tn('student.lessonsToday', lessons),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            next?.subject ?? t('student.restWell'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.15,
              color: Colors.white,
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                clock12(next.startMinute),
                if ((next.teacherName ?? '').isNotEmpty) next.teacherName!,
                if ((next.room ?? '').isNotEmpty) next.room!,
              ].join('  •  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Colors.white),
            ),
          ],
        ],
      ),
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
