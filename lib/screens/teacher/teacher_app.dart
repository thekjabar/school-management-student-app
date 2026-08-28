import 'package:flutter/material.dart';

import '../../api/session.dart';
import '../../api/teacher_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import 'classes_tab.dart';
import 'exams_tab.dart';
import 'homework_tab.dart';
import 'teacher_account.dart';

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
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const role = Role.teacher;
    final me = Session.instance.me;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: role.wash,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    me == null ? greeting : '$greeting, ${me.firstName}',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${me?.schoolName ?? ''} · ${longDate(DateTime.now())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                  ),
                ],
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
                  TeacherAccountTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _Nav(index: _tab, onChanged: (i) => setState(() => _tab = i)),
    );
  }
}

/// Today: the lessons, in order, with the class each belongs to.
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
                  _Fig(label: 'Classes', value: '${data.profile.classCount}'),
                  _Fig(label: 'Subjects', value: '${data.profile.subjectCount}'),
                  _Fig(label: 'Children', value: '${data.profile.studentCount}'),
                  _Fig(label: 'Today', value: '${todaysLessons.length}'),
                ],
              ),
            ),
            const SectionHead("Today's lessons"),
            if (todaysLessons.isEmpty)
              Panel(
                child: Text(
                  'Nothing timetabled today.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              )
            else
              ...todaysLessons.map((s) => _LessonRow(slot: s)),
            const SectionHead('Your classes'),
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
                        Tag('Homeroom', color: Role.teacher.tint, background: Role.teacher.wash),
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

class _Nav extends StatelessWidget {
  const _Nav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.today_rounded, Icons.today_outlined, 'Today'),
    (Icons.groups_rounded, Icons.groups_outlined, 'Classes'),
    (Icons.assignment_rounded, Icons.assignment_outlined, 'Homework'),
    (Icons.school_rounded, Icons.school_outlined, 'Exams'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              final on = i == index;
              final item = _items[i];
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(on ? item.$1 : item.$2, size: 21, color: on ? Role.teacher.tint : AppTheme.textFaint),
                      const SizedBox(height: 3),
                      Text(
                        item.$3,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                          color: on ? Role.teacher.tint : AppTheme.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
