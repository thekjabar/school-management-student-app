import 'package:flutter/material.dart';

import '../../api/session.dart';
import '../../api/student_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';

const int _lookBackDays = 30;
const int _planWindowDays = 120;
const int _minutesLeast = 5;
const int _minutesMost = 600;
const int _noteMax = 300;

class StudentExamPlannerScreen extends StatefulWidget {
  const StudentExamPlannerScreen({super.key});

  @override
  State<StudentExamPlannerScreen> createState() => _StudentExamPlannerScreenState();
}

class _StudentExamPlannerScreenState extends State<StudentExamPlannerScreen> {
  final GlobalKey<LoaderState<ExamPlanner>> _loader = GlobalKey<LoaderState<ExamPlanner>>();
  int _tab = 0;
  bool _busy = false;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _run(Future<void> Function() job, String said) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
      if (!mounted) return;
      showNote(context, said);
      await _loader.currentState?.reload(quiet: true);
    } catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _plan({ComingExam? exam, List<ComingExam> subjects = const []}) async {
    final asked = await showAppSheet<_Planned>(
      context,
      builder: (_) => _PlanSheet(
        exam: exam,
        subjects: subjects,
        today: _today,
        tint: Role.student.tint,
      ),
    );
    if (asked == null) return;
    await _run(
      () => StudentApi.instance.planRevision(
        plannedFor: asked.day,
        subjectId: asked.subjectId,
        examId: asked.examId,
        minutes: asked.minutes,
        note: asked.note,
      ),
      t('student.revisionAdded'),
    );
  }

  Future<void> _tick(RevisionSession session, bool done) => _run(
        () => StudentApi.instance.changeRevision(session.id, done: done),
        done ? t('student.revisionTick') : t('student.revisionPlan'),
      );

  Future<void> _remove(RevisionSession session) async {
    final sure = await confirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: t('student.revisionRemove'),
      body: t('student.revisionRemoveAsk'),
      confirmLabel: t('student.revisionRemove'),
      confirmIcon: Icons.delete_outline_rounded,
    );
    if (!sure || !mounted) return;
    await _run(
      () => StudentApi.instance.removeRevision(session.id),
      t('student.revisionRemoved'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.student.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Column(
        children: [
          ScreenHeader(title: t('student.examPlanner')),
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 10),
            child: PillTabs(
              tint: tint,
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
              tabs: [
                TabSpec(label: t('student.examsAhead'), icon: Icons.fact_check_outlined),
                TabSpec(label: t('student.revisionPlan'), icon: Icons.menu_book_outlined),
              ],
            ),
          ),
          Expanded(
            child: Loader<ExamPlanner>(
              key: _loader,
              tint: tint,
              padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 28),
              load: () => StudentApi.instance.planner(
                from: _today.subtract(const Duration(days: _lookBackDays)),
              ),
              builder: (context, data) => _tab == 0
                  ? _Exams(
                      exams: data.exams,
                      busy: _busy,
                      onPlan: (exam) => _plan(exam: exam, subjects: data.exams),
                    )
                  : _Plan(
                      plan: data.plan,
                      today: _today,
                      busy: _busy,
                      onAdd: () => _plan(subjects: data.exams),
                      onTick: _tick,
                      onRemove: _remove,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Exams extends StatelessWidget {
  const _Exams({required this.exams, required this.busy, required this.onPlan});

  final List<ComingExam> exams;
  final bool busy;
  final void Function(ComingExam exam) onPlan;

  @override
  Widget build(BuildContext context) {
    if (exams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: NoticeBanner(
          icon: Icons.event_available_outlined,
          title: t('student.examsAhead'),
          body: t('student.examsNone'),
          color: AppTheme.textMuted,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final exam in exams) ...[
          _ExamCard(exam: exam, busy: busy, onPlan: () => onPlan(exam)),
          const SizedBox(height: kCardGap),
        ],
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.busy, required this.onPlan});

  final ComingExam exam;
  final bool busy;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final colour = parseHex(exam.subjectColorHex, AppTheme.rose);
    final soon = exam.daysLeft <= 3;

    return Card16(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip36(icon: subjectIcon(exam.subject), color: colour),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.3,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        exam.subject,
                        if (exam.kind != null) humanise(exam.kind!),
                      ].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(dueWord(exam.daysLeft), color: soon ? AppTheme.rose : colour),
              if (exam.date != null) Pill(shortDate(exam.date), color: AppTheme.textMuted),
              if (exam.startMinute != null)
                Pill(clock12(exam.startMinute!), color: AppTheme.blue),
              if ((exam.room ?? '').isNotEmpty)
                Pill(tv('student.examRoom', {'name': exam.room!}), color: AppTheme.textMuted),
              if (exam.maxScore != null)
                Pill(
                  tv('student.examOutOf', {'name': '${exam.maxScore!.round()}'}),
                  color: AppTheme.violet,
                ),
              if (exam.sessionsPlanned > 0)
                Pill(tn('student.examSessions', exam.sessionsPlanned), color: AppTheme.green),
              if (exam.sessionsDone > 0)
                Pill(tn('student.examSessionsDone', exam.sessionsDone), color: AppTheme.green),
            ],
          ),
          if (!Session.instance.readOnlyHere.value) ...[
            const SizedBox(height: 12),
            BigButton(
              label: t('student.planForExam'),
              color: colour,
              height: 42,
              onPressed: busy ? null : onPlan,
            ),
          ],
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({
    required this.plan,
    required this.today,
    required this.busy,
    required this.onAdd,
    required this.onTick,
    required this.onRemove,
  });

  final RevisionPlan plan;
  final DateTime today;
  final bool busy;
  final VoidCallback onAdd;
  final Future<void> Function(RevisionSession session, bool done) onTick;
  final Future<void> Function(RevisionSession session) onRemove;

  int _dayGap(DateTime? day) {
    if (day == null) return 0;
    return DateTime(day.year, day.month, day.day).difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.student.tint;
    final gone = <RevisionSession>[];
    final now = <RevisionSession>[];
    final later = <RevisionSession>[];
    for (final session in plan.rows) {
      final gap = _dayGap(session.plannedFor);
      if (gap < 0) {
        gone.add(session);
      } else if (gap == 0) {
        now.add(session);
      } else {
        later.add(session);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!Session.instance.readOnlyHere.value)
          BigButton(
            label: t('student.planRevision'),
            color: tint,
            onPressed: busy ? null : onAdd,
          ),
        if (plan.rows.isEmpty) ...[
          const SizedBox(height: kCardGap),
          NoticeBanner(
            icon: Icons.menu_book_outlined,
            title: t('student.revisionPlan'),
            body: t('student.revisionNone'),
            color: AppTheme.textMuted,
          ),
        ] else ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(tn('student.revisionDoneCount', plan.done), color: AppTheme.green),
              Pill(tn('student.revisionMinutesDone', plan.minutesDone), color: AppTheme.blue),
            ],
          ),
        ],
        for (final group in [
          (label: t('student.revisionToday'), rows: now),
          (label: t('student.revisionLater'), rows: later),
          (label: t('student.revisionGone'), rows: gone),
        ])
          if (group.rows.isNotEmpty) ...[
            Heading(group.label),
            for (final session in group.rows) ...[
              _SessionCard(
                session: session,
                busy: busy,
                onTick: () => onTick(session, !session.done),
                onRemove: () => onRemove(session),
              ),
              const SizedBox(height: 8),
            ],
          ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.busy,
    required this.onTick,
    required this.onRemove,
  });

  final RevisionSession session;
  final bool busy;
  final VoidCallback onTick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colour = parseHex(session.subjectColorHex, Role.student.tint);
    final done = session.done;

    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      radius: 15,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (Session.instance.readOnlyHere.value)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Icon(
                done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 24,
                color: done ? AppTheme.green : AppTheme.textFaint,
              ),
            )
          else
            IconButton(
              onPressed: busy ? null : onTick,
              icon: Icon(
                done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 24,
              ),
              color: done ? AppTheme.green : AppTheme.textFaint,
              tooltip: t('student.revisionTick'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.subject ?? t('student.revisionAnySubject'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: done ? AppTheme.textMuted : AppTheme.text,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill(shortDate(session.plannedFor), color: colour),
                    if (session.minutes != null)
                      Pill(tn('student.minutes', session.minutes!), color: AppTheme.blue),
                    if (session.examDate != null)
                      Pill(shortDate(session.examDate), color: AppTheme.rose),
                  ],
                ),
                if ((session.note ?? '').isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    session.note!,
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (!Session.instance.readOnlyHere.value) ...[
            const SizedBox(width: 6),
            IconButton(
              onPressed: busy ? null : onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppTheme.rose,
              tooltip: t('student.revisionRemove'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }
}

class _Planned {
  _Planned({
    required this.day,
    required this.subjectId,
    required this.examId,
    required this.minutes,
    required this.note,
  });

  final DateTime day;
  final String? subjectId;
  final String? examId;
  final int? minutes;
  final String? note;
}

class _PlanSheet extends StatefulWidget {
  const _PlanSheet({
    required this.exam,
    required this.subjects,
    required this.today,
    required this.tint,
  });

  final ComingExam? exam;
  final List<ComingExam> subjects;
  final DateTime today;
  final Color tint;

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  final TextEditingController _minutes = TextEditingController();
  final TextEditingController _note = TextEditingController();
  late DateTime _day = widget.today;
  late String? _subjectId = widget.exam?.subjectId;

  @override
  void dispose() {
    _minutes.dispose();
    _note.dispose();
    super.dispose();
  }

  List<PickOption<String?>> get _subjectOptions {
    final seen = <String>{};
    final options = <PickOption<String?>>[
      PickOption<String?>(value: null, label: t('student.revisionAnySubject')),
    ];
    for (final exam in widget.subjects) {
      final id = exam.subjectId;
      if (id == null || !seen.add(id)) continue;
      options.add(PickOption<String?>(
        value: id,
        label: exam.subject,
        icon: subjectIcon(exam.subject),
      ));
    }
    return options;
  }

  String? get _subjectLabel {
    if (_subjectId == null) return t('student.revisionAnySubject');
    for (final exam in widget.subjects) {
      if (exam.subjectId == _subjectId) return exam.subject;
    }
    return widget.exam?.subject;
  }

  int? get _asked {
    final written = int.tryParse(_minutes.text.trim());
    if (written == null) return null;
    if (written < _minutesLeast || written > _minutesMost) return null;
    return written;
  }

  bool get _minutesWrong => _minutes.text.trim().isNotEmpty && _asked == null;

  Future<void> _pickDay() async {
    final picked = await pickDate(
      context,
      initial: _day,
      first: widget.today,
      last: widget.today.add(const Duration(days: _planWindowDays)),
      tint: widget.tint,
      title: t('student.revisionDay'),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _pickSubject() async {
    final options = _subjectOptions;
    if (options.length < 2) return;
    final picked = await pickOne<String?>(
      context,
      tint: widget.tint,
      title: t('student.revisionSubject'),
      options: options,
      selected: _subjectId,
    );
    if (!mounted) return;
    setState(() => _subjectId = picked);
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final note = _note.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: withBottomInset(context, const EdgeInsets.fromLTRB(20, 12, 20, 24)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              exam == null ? t('student.planRevision') : t('student.planForExam'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppTheme.text,
              ),
            ),
            if (exam != null) ...[
              const SizedBox(height: 4),
              Text(
                [exam.title, exam.subject, shortDate(exam.date)].join('  •  '),
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.45),
              ),
            ],
            const SizedBox(height: 18),
            PickerField(
              label: t('student.revisionDay'),
              value: longDate(_day),
              icon: Icons.event_rounded,
              onTap: _pickDay,
            ),
            const SizedBox(height: 12),
            PickerField(
              label: t('student.revisionSubject'),
              value: _subjectLabel,
              placeholder: t('student.revisionAnySubject'),
              onTap: _pickSubject,
            ),
            const SizedBox(height: 16),
            Text(
              t('student.revisionMinutes'),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 7),
            TextField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 14, color: AppTheme.text),
              decoration: InputDecoration(
                hintText: t('student.revisionMinutes'),
                errorText: _minutesWrong ? t('student.revisionMinutesRange') : null,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t('student.revisionMinutesRange'),
              style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
            ),
            const SizedBox(height: 16),
            Text(
              t('student.revisionNote'),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 7),
            TextField(
              controller: _note,
              maxLines: 3,
              minLines: 2,
              maxLength: _noteMax,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.text),
              decoration: InputDecoration(
                hintText: t('student.revisionNote'),
                counterText: '',
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 18),
            BigButton(
              label: t('student.planRevision'),
              color: widget.tint,
              onPressed: _minutesWrong
                  ? null
                  : () => Navigator.of(context).pop(
                        _Planned(
                          day: _day,
                          subjectId: _subjectId,
                          examId: exam?.id,
                          minutes: _asked,
                          note: note.isEmpty ? null : note,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
