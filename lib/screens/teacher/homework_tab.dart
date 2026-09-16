import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';
import 'homework_marks.dart';

class HomeworkTab extends StatefulWidget {
  const HomeworkTab({super.key});

  @override
  State<HomeworkTab> createState() => _HomeworkTabState();
}

class _HomeworkTabState extends State<HomeworkTab> {
  final _loaderKey = GlobalKey<LoaderState<List<TeacherHomework>>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _set,
        backgroundColor: Role.teacher.tint,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(t('teacher.setHomework')),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('teacher.homework')),
            Expanded(
              child: Loader<List<TeacherHomework>>(
                key: _loaderKey,
                tint: Role.teacher.tint,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                load: () => TeacherApi.instance.homework(),
                isEmpty: (rows) => rows.isEmpty,
                empty: t('teacher.noHomeworkYet'),
                builder: (context, rows) {
                  final drafts = rows.where((h) => h.publishedAt == null).toList();
                  final live = rows.where((h) => h.publishedAt != null).toList()
                    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (drafts.isNotEmpty) ...[
                        SectionHead(t('teacher.notPublished')),
                        ...drafts.map((h) => _Card(
                              item: h,
                              onPublish: () => _publish(h),
                              onMark: null,
                            )),
                      ],
                      if (live.isNotEmpty) SectionHead(t('teacher.alreadySet')),
                      ...live.map((h) => _Card(item: h, onPublish: null, onMark: () => _mark(h))),
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

  Future<void> _publish(TeacherHomework h) async {
    try {
      await TeacherApi.instance.publishHomework(h.id);
      _loaderKey.currentState?.reload();
      if (mounted) showNote(context, t('teacher.published'));
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    }
  }

  Future<void> _mark(TeacherHomework h) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HomeworkMarksScreen(homework: h)),
    );
    _loaderKey.currentState?.reload();
  }

  Future<void> _set() async {
    final count = await showAppSheet<int>(
      context,
      builder: (_) => const _SetSheet(),
    );
    if (count != null && count > 0) {
      _loaderKey.currentState?.reload();
      if (mounted) showNote(context, count > 1 ? tn('teacher.homeworkSetMany', count) : t('teacher.homeworkSet'));
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.item, required this.onPublish, required this.onMark});

  final TeacherHomework item;
  final VoidCallback? onPublish;
  final VoidCallback? onMark;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = item.dueDate.difference(today).inDays;
    final late = days < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 34,
                  decoration: BoxDecoration(
                    color: parseHex(item.colorHex, Role.teacher.tint),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.className} · ${item.subjectName}',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Tag(
                  dueWord(days),
                  color: late ? AppTheme.rose : AppTheme.textMuted,
                  background: late ? AppTheme.roseSoft : AppTheme.neutralSoft,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_rounded, size: 13, color: AppTheme.textFaint),
                const SizedBox(width: 5),
                Text(
                  '${tn('teacher.setOn', shortDate(item.assignedOn))} · ${tn('teacher.dueOn', longDate(item.dueDate))}',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                ),
              ],
            ),
            if (onPublish != null) ...[
              const SizedBox(height: 12),
              BigButton(
                label: t('teacher.publishToFamilies'),
                color: Role.teacher.tint,
                height: 42,
                onPressed: onPublish,
              ),
            ],
            if (onMark != null) ...[
              const SizedBox(height: 12),
              BigButton(
                label: t('teacher.markHomework'),
                color: Role.teacher.tint,
                height: 42,
                onPressed: onMark,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetSheet extends StatefulWidget {
  const _SetSheet();

  @override
  State<_SetSheet> createState() => _SetSheetState();
}

class _SetSheetState extends State<_SetSheet> {
  List<TeachingSlot> _classes = [];
  TeachingSlot? _slot;
  final Set<String> _alsoFor = {};
  int? _maxScore;
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime _due = DateTime.now().add(const Duration(days: 2));
  int _minutes = 30;
  bool _busy = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final classes = await TeacherApi.instance.classes();
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _slot = classes.isNotEmpty ? classes.first : null;
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
    if (slot == null) return;
    if (_title.text.trim().length < 2) {
      setState(() => _error = t('teacher.titleHint'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final count = await TeacherApi.instance.setHomeworkForClasses(
        classIds: [slot.classId, ..._alsoFor],
        subjectId: slot.subjectId,
        title: _title.text.trim(),
        description: _description.text.trim(),
        dueDate: _due,
        estimatedMinutes: _minutes,
        maxScore: _maxScore,
      );
      if (mounted) Navigator.of(context).pop(count);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _otherClasses() {
    final slot = _slot;
    if (slot == null) return const [];
    final others = _classes
        .where((c) => c.subjectId == slot.subjectId && c.classId != slot.classId)
        .fold<Map<String, TeachingSlot>>({}, (map, c) => map..putIfAbsent(c.classId, () => c))
        .values
        .toList();
    if (others.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      _Label(t('teacher.alsoSetFor')),
      Text(t('teacher.alsoSetForHint'), style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: others
            .map((c) => FilterChip(
                  label: Text(c.className),
                  selected: _alsoFor.contains(c.classId),
                  selectedColor: Role.teacher.tint.withValues(alpha: 0.18),
                  onSelected: (on) => setState(() => on ? _alsoFor.add(c.classId) : _alsoFor.remove(c.classId)),
                ))
            .toList(),
      ),
    ];
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
        padding: withBottomInset(context, const EdgeInsets.fromLTRB(18, 12, 18, 22)),
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
                t('teacher.setHomework'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
              else if (_classes.isEmpty)
                Text(t('teacher.noClassForWork'))
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
                    if (picked != null) {
                      setState(() {
                        _slot = picked;
                        _alsoFor.clear();
                      });
                    }
                  },
                ),
                ..._otherClasses(),
                const SizedBox(height: 16),
                _Label(t('teacher.maxMark')),
                PickerField(
                  label: '',
                  value: _maxScore == null ? t('teacher.notMarked') : '$_maxScore',
                  onTap: () async {
                    final picked = await pickOne<int>(
                      context,
                      title: t('teacher.maxMark'),
                      tint: Role.teacher.tint,
                      selected: _maxScore ?? 0,
                      options: [
                        PickOption(value: 0, label: t('teacher.notMarked')),
                        ...const [5, 10, 20, 50, 100].map((m) => PickOption(value: m, label: '$m')),
                      ],
                    );
                    if (picked != null) setState(() => _maxScore = picked == 0 ? null : picked);
                  },
                ),
                const SizedBox(height: 16),
                _Label(t('teacher.title')),
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: t('teacher.titleExample')),
                ),
                const SizedBox(height: 16),
                _Label(t('teacher.whatToDo')),
                TextField(
                  controller: _description,
                  maxLines: 3,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: t('teacher.whatToDoExample'),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _Label(t('teacher.due'))),
                    const SizedBox(width: 12),
                    Expanded(child: _Label(t('teacher.howLong'))),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await pickDate(
                            context,
                            initial: _due,
                            first: DateTime.now(),
                            last: DateTime.now().add(const Duration(days: 180)),
                            tint: Role.teacher.tint,
                          );
                          if (picked != null) setState(() => _due = picked);
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
                                shortDate(_due),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PickerField(
                        label: '',
                        value: tn('teacher.minutes', _minutes),
                        onTap: () async {
                          final picked = await pickOne<int>(
                            context,
                            title: t('teacher.howLong'),
                            tint: Role.teacher.tint,
                            selected: _minutes,
                            options: const [15, 20, 30, 45, 60, 90]
                                .map((m) => PickOption(value: m, label: tn('teacher.minutes', m)))
                                .toList(),
                          );
                          if (picked != null) setState(() => _minutes = picked);
                        },
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
                  label: t('teacher.setIt'),
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
