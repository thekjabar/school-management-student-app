import 'package:flutter/material.dart';

import '../../api/session.dart';
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import 'classes_tab.dart';
import 'exams_tab.dart';
import 'teacher_drawer.dart';
import 'homework_tab.dart';

/// The teacher app.
///
/// Four tabs, in the order a teaching day actually runs: what is on today, the
/// classes and their registers, the work set, the marks. Nothing here is a
/// dashboard — a teacher has five minutes between lessons and needs to land on
/// the thing they came for.
class TeacherApp extends StatefulWidget {
  const TeacherApp({super.key});

  @override
  State<TeacherApp> createState() => _TeacherAppState();
}

class _TeacherAppState extends State<TeacherApp> {
  // Held so the header's menu button can open the drawer: the Scaffold that
  // owns it is built by this method, so there is no context above it to ask.
  final _scaffold = GlobalKey<ScaffoldState>();
  int _tab = 0;

  List<NavItem> get _nav => [
        NavItem(Icons.today_rounded, Icons.today_outlined, t('teacher.today')),
        NavItem(Icons.groups_rounded, Icons.groups_outlined, t('teacher.classes')),
        NavItem(Icons.assignment_rounded, Icons.assignment_outlined, t('teacher.homework')),
        NavItem(Icons.school_rounded, Icons.school_outlined, t('teacher.exams')),
      ];

  @override
  Widget build(BuildContext context) {
    const role = Role.teacher;
    final me = Session.instance.me;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? t('greet.morning')
        : hour < 17
            ? t('greet.afternoon')
            : t('greet.evening');

    return Scaffold(
      key: _scaffold,
      backgroundColor: AppTheme.canvas,
      // The account left the bottom bar. Five items is past the point where a
      // bar is scanned rather than read, and the fifth was the one nobody
      // needed during a lesson.
      drawer: const TeacherDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RoleHeader(
              role: role,
              greeting: greeting,
              name: me?.name ?? '',
              onAvatar: () => _scaffold.currentState?.openDrawer(),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  shortDate(DateTime.now()),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: role.tint,
                  ),
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  _TodayTab(),
                  ClassesTab(),
                  HomeworkTab(),
                  ExamsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        items: _nav,
        index: _tab,
        tint: role.tint,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context) {
    return Loader<({TeacherProfile profile, List<TeacherSlot> slots, List<TeachingSlot> classes})>(
      tint: Role.teacher.tint,
      load: () async {
        final results = await Future.wait([
          TeacherApi.instance.me(),
          TeacherApi.instance.timetable(),
          TeacherApi.instance.classes(),
        ]);
        return (
          profile: results[0] as TeacherProfile,
          slots: results[1] as List<TeacherSlot>,
          classes: results[2] as List<TeachingSlot>,
        );
      },
      builder: (context, data) {
        final today = todayWeekday();
        final todaysLessons = data.slots.where((s) => s.weekday == today).toList()
          ..sort((a, b) => a.period.compareTo(b.period));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Panel(
              child: Row(
                children: [
                  _Fig(label: t('teacher.classes'), value: '${data.profile.classCount}'),
                  _Fig(label: t('teacher.subjects'), value: '${data.profile.subjectCount}'),
                  _Fig(label: t('teacher.children'), value: '${data.profile.studentCount}'),
                  _Fig(label: t('teacher.today'), value: '${todaysLessons.length}'),
                ],
              ),
            ),
            const SectionHead("Today's lessons"),
            if (todaysLessons.isEmpty)
              Panel(
                child: Text(
                  t('teacher.nothingToday'),
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              )
            else
              ...todaysLessons.map((s) => _LessonRow(slot: s)),
            SectionHead(t('teacher.yourClasses')),
            ...data.classes.map((c) => _ClassRow(slot: c)),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.slot});

  final TeacherSlot slot;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final minutesNow = now.hour * 60 + now.minute;
    // A lesson is "now" for its forty-five minutes. Highlighting it saves a
    // teacher working out which row they are standing in.
    final live = slot.startMinute != null &&
        minutesNow >= slot.startMinute! &&
        minutesNow < slot.startMinute! + 45;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Panel(
        color: live ? Role.teacher.wash : null,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clock(slot.startMinute),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: live ? Role.teacher.tint : AppTheme.text,
                    ),
                  ),
                  Text('P${slot.period}', style: TextStyle(fontSize: 11, color: AppTheme.textFaint)),
                ],
              ),
            ),
            Container(
              width: 4,
              height: 34,
              decoration: BoxDecoration(
                color: parseHex(slot.colorHex, AppTheme.border),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slot.subjectName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    '${slot.className}${slot.room != null ? ' · ${slot.room}' : ''}',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (live) Tag('Now', color: AppTheme.surface, background: Role.teacher.tint),
          ],
        ),
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.slot});

  final TeachingSlot slot;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconChip(
              icon: Icons.groups_rounded,
              color: parseHex(slot.colorHex, Role.teacher.tint),
              background: AppTheme.canvas,
              size: 34,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${slot.className} · ${slot.subjectName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                      ),
                      if (slot.isHomeroom) ...[
                        const SizedBox(width: 7),
                        Tag(t('teacher.homeroom'), color: Role.teacher.tint, background: Role.teacher.wash),
                      ],
                    ],
                  ),
                  Text(
                    '${slot.studentCount} children${slot.room != null ? ' · ${slot.room}' : ''}',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
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

class _Fig extends StatelessWidget {
  const _Fig({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

