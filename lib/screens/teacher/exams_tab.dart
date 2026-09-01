import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/session.dart';
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/screen_kit.dart';
import 'teacher_kit.dart';

/// Exams, and the mark sheet behind each one.
///
/// Entering marks and RELEASING them are two separate actions here, because
/// they are two separate permissions on the server and two genuinely different
/// decisions. A mark typed wrong is fixed in a minute; a mark released wrong is
/// on three hundred phones before the teacher has put the pen down.
class ExamsTab extends StatefulWidget {
  const ExamsTab({super.key});

  @override
  State<ExamsTab> createState() => _ExamsTabState();
}

class _ExamsTabState extends State<ExamsTab> {
  final _loaderKey = GlobalKey<LoaderState<List<TeacherExam>>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: Role.teacher.tint,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(t('teacher.newTest')),
      ),
      // Always pushed, never a tab, so it carries its own way back.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('teacher.exams')),
            Expanded(
              child: Loader<List<TeacherExam>>(
                key: _loaderKey,
                tint: Role.teacher.tint,
                load: () => TeacherApi.instance.exams(),
                isEmpty: (rows) => rows.isEmpty,
                empty: t('teacher.noTestsYet'),
                builder: (context, rows) {
                  final sorted = [...rows]..sort((a, b) => b.date.compareTo(a.date));
                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      ...sorted.map(
                        (e) => _ExamCard(
                          exam: e,
                          onOpen: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => MarksScreen(exam: e)),
                            );
                            _loaderKey.currentState?.reload();
                          },
                        ),
                      ),
                      const SizedBox(height: 80),
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

  Future<void> _create() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewExamSheet(),
    );
    if (saved == true) {
      _loaderKey.currentState?.reload();
      if (mounted) showNote(context, t('teacher.testCreated'));
    }
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.onOpen});

  final TeacherExam exam;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final published = exam.publishedAt != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Panel(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: parseHex(exam.colorHex, Role.teacher.tint),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exam.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                      const SizedBox(height: 2),
                      Text(
                        '${exam.className} · ${exam.subjectName} · ${shortDate(exam.date)}',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Tag(
                  published ? t('teacher.released') : humanise(exam.state),
                  color: published ? AppTheme.green : AppTheme.amber,
                  background: published ? AppTheme.greenSoft : AppTheme.amberSoft,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.edit_note_rounded, size: 15, color: AppTheme.textFaint),
                const SizedBox(width: 6),
                Text(
                  tv('teacher.markedOutOf', {
                    'n': exam.resultCount,
                    'max': exam.maxScore,
                  }),
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, color: AppTheme.textFaint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The mark sheet.
class MarksScreen extends StatefulWidget {
  const MarksScreen({super.key, required this.exam});

  final TeacherExam exam;

  @override
  State<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends State<MarksScreen> {
  final _loaderKey = GlobalKey<LoaderState<({bool published, num maxScore, List<MarkRow> rows})>>();
  List<MarkRow> _rows = [];
  bool _dirty = false;
  bool _saving = false;
  bool _published = false;

  /// Whether this teacher may release marks to families.
  ///
  /// Entering a mark and releasing it are two permissions on purpose. At most
  /// schools here the teacher marks and the office releases, once the whole
  /// year group is in — a class whose marks appear three days before the class
  /// next door starts a row nobody needs.
  bool get _mayRelease => Session.instance.me?.can('academic.grade.publish') ?? false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await TeacherApi.instance.saveMarks(widget.exam.id, _rows);
      if (!mounted) return;
      setState(() => _dirty = false);
      showNote(context, t('teacher.marksSaved'));
      _loaderKey.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish() async {
    final yes = await confirmDialog(
      context,
      icon: Icons.visibility_rounded,
      tone: AppTheme.green,
      title: t('teacher.releaseAsk'),
      body: t('teacher.releaseWarning'),
      confirmLabel: t('teacher.release'),
      confirmIcon: Icons.send_rounded,
      cancelLabel: t('teacher.notYet'),
    );
    if (!yes || !mounted) return;

    try {
      await TeacherApi.instance.publishMarks(widget.exam.id);
      if (!mounted) return;
      showNote(context, t('teacher.marksReleased'));
      _loaderKey.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final marked = _rows.where((r) => r.score != null || r.wasAbsent).length;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: BigButton(
                  label: tn('teacher.saveCount', '$marked/${_rows.length}'),
                  color: Role.teacher.tint,
                  height: 50,
                  busy: _saving,
                  onPressed: _dirty ? _save : null,
                ),
              ),
              if (_mayRelease) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: SoftButton(
                    label: _published ? t('teacher.released') : t('teacher.release'),
                    tint: AppTheme.green,
                    height: 50,
                    onTap: _published || _dirty ? null : _publish,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: widget.exam.title),
            Expanded(
              child: Loader<({bool published, num maxScore, List<MarkRow> rows})>(
                key: _loaderKey,
                tint: Role.teacher.tint,
                load: () async {
                  final data = await TeacherApi.instance.marks(widget.exam.id);
                  _rows = data.rows;
                  _published = data.published;
                  return data;
                },
                isEmpty: (d) => d.rows.isEmpty,
                empty: t('teacher.noRoster'),
                builder: (context, data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: data.published ? AppTheme.greenSoft : AppTheme.amberSoft,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            data.published ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            size: 17,
                            color: data.published ? AppTheme.green : AppTheme.amber,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              data.published
                                  ? t('teacher.familiesSeeMarks')
                                  : _mayRelease
                                      ? t('teacher.onlyYouSee')
                                      : t('teacher.officeReleases'),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: data.published ? AppTheme.green : AppTheme.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...data.rows.map(
                      (r) => _MarkEntry(
                        row: r,
                        maxScore: data.maxScore,
                        onChanged: () => setState(() => _dirty = true),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkEntry extends StatefulWidget {
  const _MarkEntry({required this.row, required this.maxScore, required this.onChanged});

  final MarkRow row;
  final num maxScore;
  final VoidCallback onChanged;

  @override
  State<_MarkEntry> createState() => _MarkEntryState();
}

class _MarkEntryState extends State<_MarkEntry> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.row.score?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                widget.row.rollNumber ?? '',
                style: TextStyle(fontSize: 12, color: AppTheme.textFaint, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  Text(widget.row.code, style: TextStyle(fontSize: 10.5, color: AppTheme.textFaint)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Absent is not a score of zero, and conflating them ruins an
            // average. It gets its own toggle.
            GestureDetector(
              onTap: () {
                setState(() {
                  widget.row.wasAbsent = !widget.row.wasAbsent;
                  if (widget.row.wasAbsent) {
                    widget.row.score = null;
                    _controller.clear();
                  }
                });
                widget.onChanged();
              },
              child: Container(
                width: 34,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.row.wasAbsent ? AppTheme.rose : AppTheme.roseSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  t('teacher.absentShort'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: widget.row.wasAbsent ? Colors.white : AppTheme.rose,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 62,
              child: TextField(
                controller: _controller,
                enabled: !widget.row.wasAbsent,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '/${widget.maxScore}',
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  isDense: true,
                ),
                onChanged: (value) {
                  final parsed = num.tryParse(value);
                  // Out-of-range marks are rejected here rather than by the
                  // server, so a slipped digit is caught while the paper is
                  // still in front of the teacher.
                  widget.row.score =
                      parsed != null && parsed >= 0 && parsed <= widget.maxScore ? parsed : null;
                  widget.onChanged();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What kind of test this is, in the reader's language.
///
/// The API speaks in enum names because they are stable across releases, and
/// humanise only sentence-cases them — which left a Kurdish teacher choosing
/// between six English words. Falls back to humanise so a kind the server adds
/// after this release still reads as a word rather than as a missing key.
String _kindName(String kind) {
  final key = 'teacher.kind.$kind';
  final label = t(key);
  return label == key ? humanise(kind) : label;
}

class _NewExamSheet extends StatefulWidget {
  const _NewExamSheet();

  @override
  State<_NewExamSheet> createState() => _NewExamSheetState();
}

class _NewExamSheetState extends State<_NewExamSheet> {
  static const _kinds = ['QUIZ', 'MONTHLY', 'MIDTERM', 'FINAL', 'PRACTICAL', 'ORAL'];

  List<TeachingSlot> _classes = [];
  TeachingSlot? _slot;
  String? _termId;
  String _kind = 'QUIZ';
  final _title = TextEditingController();
  DateTime _date = DateTime.now();
  int _maxScore = 100;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        TeacherApi.instance.classes(),
        TeacherApi.instance.currentTermId(),
      ]);
      if (!mounted) return;
      setState(() {
        _classes = results[0] as List<TeachingSlot>;
        _termId = results[1] as String?;
        _slot = _classes.isNotEmpty ? _classes.first : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final slot = _slot;
    final termId = _termId;
    if (slot == null) return;
    if (termId == null) {
      setState(() => _error = t('teacher.noTerm'));
      return;
    }
    if (_title.text.trim().length < 2) {
      setState(() => _error = t('teacher.testNameHint'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await TeacherApi.instance.createExam(
        classId: slot.classId,
        subjectId: slot.subjectId,
        termId: termId,
        title: _title.text.trim(),
        kind: _kind,
        date: _date,
        maxScore: _maxScore,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t('teacher.newTest'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
              else if (_classes.isEmpty)
                Text(t('teacher.noClassForTest'))
              else ...[
                _Label(t('teacher.classAndSubject')),
                PickerField(
                  label: '',
                  value: _slot == null ? null : '${_slot!.className} · ${_slot!.subjectName}',
                  placeholder: t('pick.choose'),
                  onTap: () async {
                    final picked = await pickOne<TeachingSlot>(
                      context,
                      title: t('teacher.classAndSubject'),
                      tint: Role.teacher.tint,
                      selected: _slot,
                      options: _classes
                          .map((c) => PickOption(
                                value: c,
                                label: c.className,
                                subtitle: c.subjectName,
                                icon: Icons.groups_rounded,
                              ))
                          .toList(),
                    );
                    if (picked != null) setState(() => _slot = picked);
                  },
                ),
                const SizedBox(height: 16),
                _Label(t('teacher.testName')),
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: t('teacher.testNameExample')),
                ),
                const SizedBox(height: 16),
                _Label(t('teacher.kind')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kinds.map((k) {
                    final on = k == _kind;
                    return GestureDetector(
                      onTap: () => setState(() => _kind = k),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: on ? Role.teacher.tint : AppTheme.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: on ? Role.teacher.tint : AppTheme.border),
                        ),
                        child: Text(
                          _kindName(k),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: on ? Colors.white : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  // Top, not centre. Two fields side by side are read as one
                  // row; centring makes the taller one hang over the shorter at
                  // both ends and the labels stop lining up.
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label(t('teacher.dueDate')),
                          GestureDetector(
                            onTap: () async {
                              final picked = await pickDate(
                                context,
                                initial: _date,
                                first: DateTime.now().subtract(const Duration(days: 30)),
                                last: DateTime.now().add(const Duration(days: 180)),
                                tint: Role.teacher.tint,
                              );
                              if (picked != null) setState(() => _date = picked);
                            },
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 15, color: AppTheme.textFaint),
                                  const SizedBox(width: 9),
                                  Text(
                                    shortDate(_date),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label(t('teacher.outOf')),
                          PickerField(
                            label: '',
                            value: '$_maxScore',
                            onTap: () async {
                              final picked = await pickOne<int>(
                                context,
                                title: t('teacher.outOf'),
                                tint: Role.teacher.tint,
                                selected: _maxScore,
                                options: const [10, 20, 25, 50, 100]
                                    .map((m) => PickOption(value: m, label: '$m'))
                                    .toList(),
                              );
                              if (picked != null) setState(() => _maxScore = picked);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: AppTheme.rose, fontSize: 12.5)),
                ],
                const SizedBox(height: 16),
                BigButton(
                  label: t('teacher.create'),
                  color: Role.teacher.tint,
                  height: 50,
                  busy: _busy,
                  onPressed: _save,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, left: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
      ),
    );
  }
}
