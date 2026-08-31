import 'package:flutter/material.dart';

import '../../api/boot.dart';
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import 'classes_tab.dart';
import 'exams_tab.dart';
import 'homework_tab.dart';
import 'teacher_account.dart';

/// What a teacher lands on.
///
/// Ordered by the question each card answers, in the order the day asks them:
/// how much am I teaching today, what do I need to open, what is next, whose
/// class is it, what is due, what is being examined. A dashboard would show all
/// six as figures; this shows the first thing a teacher can act on in each.
class TeacherHome extends StatelessWidget {
  const TeacherHome({super.key, required this.onOpenTab});

  /// For the cards that lead somewhere the SHELL owns — the messages tab, the
  /// week. Everything else is pushed.
  final void Function(int tab) onOpenTab;

  @override
  Widget build(BuildContext context) {
    return Loader<_Today>(
      tint: Role.teacher.tint,
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 18),
      load: () async {
        return _Today.from(await TeacherPayload.fetch());
      },
      builder: (context, day) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroCard(
            lessons: day.today.length,
            onTap: () => _push(context, const TeacherWeekScreen()),
          ),
          const SizedBox(height: kCardGap),

          QuickActions(
            actions: [
              QuickAction(
                icon: Icons.groups_outlined,
                label: t('teacher.myClasses'),
                color: Role.teacher.tint,
                onTap: () => _push(context, const ClassesScreen()),
              ),
              QuickAction(
                icon: Icons.description_outlined,
                label: t('teacher.homework'),
                color: AppTheme.amber,
                onTap: () => _push(context, const HomeworkTab()),
              ),
              QuickAction(
                icon: Icons.assignment_outlined,
                label: t('teacher.exams'),
                color: AppTheme.rose,
                onTap: () => _push(context, const ExamsTab()),
              ),
              QuickAction(
                icon: Icons.verified_user_outlined,
                label: t('teacher.attendance'),
                color: AppTheme.blue,
                onTap: () => _register(context, day.classes),
              ),
              QuickAction(
                icon: Icons.bookmark_border_rounded,
                label: t('teacher.gradebook'),
                color: AppTheme.violet,
                onTap: () => _push(context, const ExamsTab()),
              ),
              QuickAction(
                icon: Icons.chat_bubble_outline_rounded,
                label: t('teacher.messages'),
                color: AppTheme.textMuted,
                onTap: () => onOpenTab(1),
              ),
            ],
          ),
          const SizedBox(height: kCardGap),

          // ---- Today's schedule --------------------------------------------
          Card16(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Role.teacher.tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        size: 17,
                        color: Role.teacher.tint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SectionRow(
                        title: t('teacher.todaySchedule'),
                        actionLabel: t('teacher.fullTimetable'),
                        onAction: () => _push(context, const TeacherWeekScreen()),
                      ),
                    ),
                  ],
                ),
                if (day.today.isEmpty)
                  _Quiet(text: t('teacher.nothingToday'))
                else
                  ScheduleTimeline(
                    trailingIcon: Icons.more_vert_rounded,
                    onTap: (i) => _lessonSheet(context, day.today[i], day.classes),
                    entries: [
                      for (final s in day.today)
                        ScheduleEntry(
                          time: clock12(s.startMinute),
                          subject: s.subjectName,
                          teacher: s.className,
                          room: s.room,
                          color: parseHex(s.colorHex, Role.teacher.tint),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: kCardGap),

          // ---- The classes -------------------------------------------------
          _ClassesCard(classes: day.classes),
          const SizedBox(height: kCardGap),

          // ---- What is due, and what is being examined ---------------------
          _TasksCard(homework: day.dueSoon),
          const SizedBox(height: kCardGap),
          _ExamsCard(exams: day.examsSoon),
          const SizedBox(height: kCardGap),
          const _TipCard(),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  /// The register needs a class. One class and it opens straight into it;
  /// several and it asks which — rather than opening a list of classes whose
  /// only purpose is to be tapped once.
  static Future<void> _register(BuildContext context, List<TeachingSlot> classes) async {
    if (classes.isEmpty) return;
    if (classes.length == 1) {
      _push(context, RegisterScreen(slot: classes.first));
      return;
    }
    final picked = await pickOne<String>(
      context,
      title: t('teacher.takeRegister'),
      tint: Role.teacher.tint,
      options: classes
          .map((c) => PickOption(
                value: c.assignmentId,
                label: '${c.className} · ${c.subjectName}',
                subtitle: '${c.studentCount} ${t('teacher.children')}',
                icon: Icons.groups_rounded,
              ))
          .toList(),
    );
    if (picked == null || !context.mounted) return;
    _push(context, RegisterScreen(slot: classes.firstWhere((c) => c.assignmentId == picked)));
  }

  /// What can be done with the lesson in front of you.
  static Future<void> _lessonSheet(
    BuildContext context,
    TeacherSlot slot,
    List<TeachingSlot> classes,
  ) async {
    final owned = classes.where((c) => c.classId == slot.classId).toList();
    final picked = await pickOne<String>(
      context,
      title: '${slot.subjectName} · ${slot.className}',
      tint: Role.teacher.tint,
      options: [
        PickOption(
          value: 'register',
          label: t('teacher.takeRegister'),
          icon: Icons.how_to_reg_rounded,
        ),
        PickOption(
          value: 'homework',
          label: t('teacher.setHomework'),
          icon: Icons.assignment_add,
        ),
      ],
    );
    if (picked == null || !context.mounted) return;
    if (picked == 'register' && owned.isNotEmpty) {
      _push(context, RegisterScreen(slot: owned.first));
    } else if (picked == 'homework') {
      _push(context, const HomeworkTab());
    }
  }
}

/// Everything the screen needs, fetched together.
class _Today {
  _Today({
    required this.profile,
    required this.slots,
    required this.classes,
    required this.homework,
    required this.exams,
  });

  /// The same five answers, however they arrived — fetched here, or
  /// prefetched during the splash. The screen must not be able to tell.
  factory _Today.from(TeacherPayload p) => _Today(
        profile: p.profile,
        slots: p.slots,
        classes: p.classes,
        homework: p.homework,
        exams: p.exams,
      );

  final TeacherProfile profile;
  final List<TeacherSlot> slots;
  final List<TeachingSlot> classes;
  final List<TeacherHomework> homework;
  final List<TeacherExam> exams;

  List<TeacherSlot> get today {
    final name = todayWeekday();
    final rows = slots.where((s) => s.weekday == name).toList()
      ..sort((a, b) => (a.startMinute ?? a.period * 60).compareTo(b.startMinute ?? b.period * 60));
    return rows;
  }

  /// Work still ahead of its due date, soonest first. Homework whose date has
  /// passed is a marking job, not an upcoming task, and belongs on the homework
  /// screen where it can be opened.
  List<TeacherHomework> get dueSoon {
    final midnight = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final rows = homework.where((h) => !h.dueDate.isBefore(midnight)).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return rows.take(3).toList();
  }

  List<TeacherExam> get examsSoon {
    final midnight = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final rows = exams.where((e) => !e.date.isBefore(midnight)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return rows.take(2).toList();
  }
}

/* ---------------------------------------------------------------------------
 * The hero
 * ------------------------------------------------------------------------- */

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.lessons, required this.onTap});

  final int lessons;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final deep = AppTheme.dark ? Role.teacher.tint : AppTheme.teacherDeep;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: AppTheme.dark
              ? [const Color(0xFF0F1D1B), const Color(0xFF13251F)]
              : [const Color(0xFFF6F9F5), const Color(0xFFE9F2E7)],
        ),
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(
          color: AppTheme.dark ? const Color(0xFF223228) : const Color(0xFFE4EFE2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              PositionedDirectional(
                end: 0,
                top: 0,
                bottom: 0,
                width: box.maxWidth * 0.48,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // A daylight photograph on a night-time card glares. The
                    // multiply takes it down to the brightness of the surface it
                    // is sitting on rather than removing it.
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        AppTheme.dark ? const Color(0xFF6E7A72) : Colors.transparent,
                        AppTheme.dark ? BlendMode.modulate : BlendMode.dst,
                      ),
                      child: Image.asset(
                        'assets/art/teacher_desk.png',
                        fit: BoxFit.cover,
                        alignment: AlignmentDirectional.centerEnd,
                      ),
                    ),
                    // Cropping the picture to fill the card also crops the
                    // faded edge it was exported with, which left a hard
                    // vertical line down the middle of the card. This puts the
                    // fade back, over whatever the crop happens to be.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: AlignmentDirectional.centerStart,
                          end: AlignmentDirectional.centerEnd,
                          stops: const [0, 0.38],
                          colors: [
                            AppTheme.dark
                                ? const Color(0xFF11201C)
                                : const Color(0xFFEFF5EE),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
                child: SizedBox(
                  width: box.maxWidth * 0.55,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.dark ? const Color(0xFF1B2C24) : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          size: 20,
                          color: Role.teacher.tint,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t('teacher.todayYouHave'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lessons == 0
                                  ? t('teacher.noLessonsToday')
                                  : lessons == 1
                                      ? t('teacher.oneLesson')
                                      : tn('teacher.nLessons', lessons),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: lessons == 0 ? 17 : 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.7,
                                height: 1.12,
                                color: deep,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 26,
                              height: 3.5,
                              decoration: BoxDecoration(
                                color: Role.teacher.tint,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: onTap,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsetsDirectional.fromSTEB(13, 10, 9, 10),
                                decoration: BoxDecoration(
                                  color: deep,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        t('teacher.viewTimetable'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 17,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * The classes
 * ------------------------------------------------------------------------- */

class _ClassesCard extends StatelessWidget {
  const _ClassesCard({required this.classes});

  final List<TeachingSlot> classes;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(
            title: t('teacher.myClasses'),
            actionLabel: classes.isEmpty ? null : t('home.viewAll'),
            actionIcon: null,
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClassesScreen()),
            ),
          ),
          if (classes.isEmpty)
            _Quiet(text: t('teacher.noClasses'))
          else
            for (var i = 0; i < classes.take(3).length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppTheme.border),
              _ClassRow(slot: classes[i]),
            ],
          const SizedBox(height: 12),
          // The office owns the class list; this says where to go rather than
          // pretending a teacher can add one and failing at the server.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('teacher.classNotEditable'))),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Role.teacher.tint.withValues(alpha: AppTheme.dark ? 0.14 : 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t('teacher.addClass'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Role.teacher.tint,
                      ),
                    ),
                  ),
                  Icon(Icons.add_circle_outline_rounded, size: 17, color: Role.teacher.tint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.slot});

  final TeachingSlot slot;

  @override
  Widget build(BuildContext context) {
    final tint = parseHex(slot.colorHex, Role.teacher.tint);
    // "6A" rather than an icon: a teacher with five classes tells them apart
    // by the name, and five identical group glyphs make that harder, not
    // easier. The last word is the part that differs — "Grade 6A" and
    // "Grade 6B" share everything before it.
    final words = slot.className.trim().split(RegExp(r'\s+'));
    final short = words.isEmpty ? '' : words.last;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ClassRosterScreen(slot: slot)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                short.isEmpty ? '?' : short,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: tint,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.className,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    slot.subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${slot.studentCount}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.text,
                  ),
                ),
                Text(
                  t('teacher.students'),
                  style: TextStyle(fontSize: 10, color: AppTheme.textFaint),
                ),
              ],
            ),
            Icon(Icons.chevron_right_rounded, size: 19, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Tasks and exams
 * ------------------------------------------------------------------------- */

class _TasksCard extends StatelessWidget {
  const _TasksCard({required this.homework});

  final List<TeacherHomework> homework;

  @override
  Widget build(BuildContext context) {
    final midnight = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(
            title: t('teacher.upcomingTasks'),
            actionLabel: homework.isEmpty ? null : t('home.viewAll'),
            actionIcon: null,
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HomeworkTab()),
            ),
          ),
          if (homework.isEmpty)
            _Quiet(text: t('teacher.noTasks'))
          else
            for (var i = 0; i < homework.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == homework.length - 1 ? 0 : 12),
                child: _TaskRow(
                  item: homework[i],
                  days: homework[i].dueDate.difference(midnight).inDays,
                ),
              ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.item, required this.days});

  final TeacherHomework item;
  final int days;

  @override
  Widget build(BuildContext context) {
    // Red when it lands within two days, green when there is room. The colour
    // is the whole point of putting a date on the right of the row.
    final urgent = days <= 2;
    final colour = urgent ? AppTheme.rose : Role.teacher.tint;
    final chip = parseHex(item.colorHex, AppTheme.amber);

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: chip.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(subjectIcon(item.subjectName), size: 18, color: chip),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${item.subjectName} — ${item.className}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              shortDate(item.dueDate),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: colour),
            ),
            Text(
              t('teacher.dueLabel'),
              style: TextStyle(fontSize: 9.5, color: AppTheme.textFaint),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExamsCard extends StatelessWidget {
  const _ExamsCard({required this.exams});

  final List<TeacherExam> exams;

  @override
  Widget build(BuildContext context) {
    final midnight = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(
            title: t('teacher.upcomingExams'),
            actionLabel: exams.isEmpty ? null : t('home.viewAll'),
            actionIcon: null,
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExamsTab()),
            ),
          ),
          if (exams.isEmpty)
            _Quiet(text: t('teacher.noExams'))
          else
            for (var i = 0; i < exams.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == exams.length - 1 ? 0 : 10),
                child: _ExamRow(
                  exam: exams[i],
                  days: exams[i].date.difference(midnight).inDays,
                ),
              ),
        ],
      ),
    );
  }
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({required this.exam, required this.days});

  final TeacherExam exam;
  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.violet.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.description_outlined, size: 18, color: AppTheme.violet),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${exam.subjectName} — ${exam.className}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.textFaint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  longDate(exam.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.violet.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  days <= 0
                      ? t('teacher.today2')
                      : days == 1
                          ? t('teacher.tomorrow')
                          : tn('teacher.daysLeft', days),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.violet,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * The tip
 * ------------------------------------------------------------------------- */

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: Role.teacher.tint.withValues(alpha: AppTheme.dark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: 0,
            top: 0,
            child: Icon(
              Icons.format_quote_rounded,
              size: 26,
              color: Role.teacher.tint.withValues(alpha: 0.28),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 17, color: Role.teacher.tint),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('teacher.tipOfDay'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      t('teacher.tipBody'),
                      style: TextStyle(fontSize: 11, height: 1.45, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ),
    );
  }
}
