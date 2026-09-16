import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart' show AiAnswer;
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/assistant_kit.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/screen_kit.dart';

class TeacherAssistantScreen extends StatefulWidget {
  const TeacherAssistantScreen({super.key});

  @override
  State<TeacherAssistantScreen> createState() => _TeacherAssistantScreenState();
}

class _TeacherAssistantScreenState extends State<TeacherAssistantScreen> {
  final _text = TextEditingController();
  final _turns = <AssistantTurn>[];

  int _tab = 0;
  bool _busy = false;
  bool _seeded = false;
  int _remaining = 0;
  String? _resetsOn;

  AiTeacherClass? _class;
  ClassStudent? _student;
  List<ClassStudent> _students = const [];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _ready {
    if (_text.text.trim().isEmpty) return false;
    if (_tab == 1) return _class != null;
    if (_tab == 2) return _class != null && _student != null;
    return true;
  }

  Future<void> _pickClass(List<AiTeacherClass> classes) async {
    final picked = await pickOne<String>(
      context,
      title: t('tai.chooseClass'),
      tint: Role.teacher.tint,
      selected: _class?.classId,
      options: [
        for (final c in classes)
          PickOption(
            value: c.classId,
            label: c.name,
            subtitle: c.subjects.join(' · '),
            icon: Icons.groups_rounded,
          ),
      ],
    );
    if (picked == null || !mounted) return;
    final chosen = classes.firstWhere((c) => c.classId == picked);
    setState(() {
      _class = chosen;
      _student = null;
      _students = const [];
    });
    await _loadStudents(chosen.classId);
  }

  Future<void> _loadStudents(String classId) async {
    try {
      final rows = await TeacherApi.instance.students(classId);
      if (mounted && _class?.classId == classId) setState(() => _students = rows);
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    }
  }

  Future<void> _pickStudent() async {
    if (_students.isEmpty) return;
    final picked = await pickOne<String>(
      context,
      title: t('tai.chooseStudent'),
      tint: Role.teacher.tint,
      selected: _student?.studentId,
      options: [
        for (final s in _students)
          PickOption(
            value: s.studentId,
            label: s.name,
            subtitle: s.rollNumber,
            icon: Icons.person_outline_rounded,
          ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _student = _students.firstWhere((s) => s.studentId == picked));
  }

  Future<void> _ask() async {
    final asked = _text.text.trim();
    if (!_ready || _busy) return;
    final kind = _tab;
    setState(() => _busy = true);
    try {
      final answer = switch (kind) {
        1 => await TeacherApi.instance.aiClassReport(classId: _class!.classId, question: asked),
        2 => await TeacherApi.instance.aiStudentReport(
            classId: _class!.classId,
            studentId: _student!.studentId,
            question: asked,
          ),
        _ => await TeacherApi.instance.aiQuestion(question: asked),
      };
      if (!mounted) return;
      setState(() {
        _turns.insert(
          0,
          AssistantTurn(
            question: asked,
            answer: answer.answer,
            ok: answer.ok,
            icon: _iconFor(kind),
          ),
        );
        _text.clear();
        _apply(answer);
      });
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _apply(AiAnswer answer) {
    if (answer.remaining != null) _remaining = answer.remaining!;
    if (answer.resetsOn != null) _resetsOn = answer.resetsOn;
  }

  static IconData _iconFor(int tab) => switch (tab) {
        1 => Icons.groups_outlined,
        2 => Icons.person_search_outlined,
        _ => Icons.edit_note_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('tai.title')),
            Expanded(
              child: Loader<AiTeacherOverview>(
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 28),
                load: TeacherApi.instance.aiOverview,
                builder: (context, overview) {
                  if (!overview.available) {
                    return AssistantQuiet(icon: Icons.cloud_off_rounded, text: t('tai.unavailable'));
                  }
                  _limitsFrom(overview);
                  final spent = _remaining <= 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PillTabs(
                        tint: tint,
                        index: _tab,
                        onChanged: (i) => setState(() => _tab = i),
                        tabs: [
                          TabSpec(label: t('tai.tab.question'), icon: Icons.edit_note_outlined),
                          TabSpec(label: t('tai.tab.classReport'), icon: Icons.groups_outlined),
                          TabSpec(label: t('tai.tab.studentReport'), icon: Icons.person_search_outlined),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _leadFor(_tab),
                        style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 12),
                      if (_tab > 0)
                        overview.classes.isEmpty
                            ? AssistantQuiet(icon: Icons.groups_outlined, text: t('tai.noClasses'))
                            : Card16(
                                child: Column(
                                  children: [
                                    _ChooserRow(
                                      icon: Icons.groups_rounded,
                                      label: t('tai.pickClass'),
                                      value: _class?.name,
                                      onTap: () => _pickClass(overview.classes),
                                    ),
                                    if (_tab == 2) ...[
                                      Divider(height: 18, color: AppTheme.border),
                                      _ChooserRow(
                                        icon: Icons.person_outline_rounded,
                                        label: t('tai.pickStudent'),
                                        value: _student?.name,
                                        onTap: _students.isEmpty ? null : _pickStudent,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                      if (_tab > 0) const SizedBox(height: kCardGap),
                      Card16(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AssistantField(
                              controller: _text,
                              hint: _hintFor(_tab),
                              enabled: !_busy && !spent,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    teacherAllowanceLine(_remaining, overview.limit, _resetsOn),
                                    style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textFaint),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton(
                                  onPressed: _busy || spent || !_ready ? null : _ask,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: tint,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                                  ),
                                  child: Text(_busy ? t('tai.thinking') : t('tai.ask')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: kCardGap),
                      if (_turns.isEmpty)
                        AssistantQuiet(
                          icon: Icons.auto_awesome_outlined,
                          text: t('tai.nothingAsked'),
                          note: t('tai.scopeNote'),
                        )
                      else
                        for (final turn in _turns) ...[
                          AssistantTurnCard(turn: turn),
                          const SizedBox(height: kCardGap),
                        ],
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

  void _limitsFrom(AiTeacherOverview overview) {
    if (_seeded) return;
    _seeded = true;
    _remaining = overview.remaining;
    _resetsOn = overview.resetsOn;
  }

  static String _leadFor(int tab) => switch (tab) {
        1 => t('tai.classLead'),
        2 => t('tai.studentLead'),
        _ => t('tai.questionLead'),
      };

  static String _hintFor(int tab) => switch (tab) {
        1 => t('tai.classHint'),
        2 => t('tai.studentHint'),
        _ => t('tai.questionHint'),
      };
}

String teacherAllowanceLine(int remaining, int limit, String? resetsOn) {
  if (remaining > 0) return tv('tai.left', {'left': remaining, 'limit': limit});
  return resetsOn == null ? t('tai.spent') : tv('tai.spentUntil', {'when': resetsOn});
}

class _ChooserRow extends StatelessWidget {
  const _ChooserRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chosen = value != null && value!.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppTheme.textFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              chosen ? value! : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: chosen ? FontWeight.w700 : FontWeight.w500,
                color: chosen ? AppTheme.text : AppTheme.textMuted,
              ),
            ),
          ),
          Icon(Icons.expand_more_rounded, size: 19, color: AppTheme.textFaint),
        ],
      ),
    );
  }
}
