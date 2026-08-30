import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/pickers.dart';

/// Work set, and the form for setting more.
///
/// Draft and published are shown apart, because they are different things to a
/// family: a draft is invisible to them, and a teacher who believes they have
/// set homework when they have only drafted it will be told otherwise on
/// Monday morning by thirty children.
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
      body: Loader<List<TeacherHomework>>(
        key: _loaderKey,
        tint: Role.teacher.tint,
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
                    )),
              ],
              const SectionHead('Set'),
              ...live.map((h) => _Card(item: h, onPublish: null)),
              const SizedBox(height: 80),
            ],
          );
        },
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

  Future<void> _set() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SetSheet(),
    );
    if (saved == true) {
      _loaderKey.currentState?.reload();
      if (mounted) showNote(context, t('teacher.homeworkSet'));
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.item, required this.onPublish});

  final TeacherHomework item;
  final VoidCallback? onPublish;

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
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton(
                  onPressed: onPublish,
                  style: FilledButton.styleFrom(
                    backgroundColor: Role.teacher.tint,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                  child: Text(t('teacher.publishToFamilies')),
                ),
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
        _error = e.toString();
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
      await TeacherApi.instance.setHomework(
        classId: slot.classId,
        subjectId: slot.subjectId,
        title: _title.text.trim(),
        description: _description.text.trim(),
        dueDate: _due,
        estimatedMinutes: _minutes,
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
                    if (picked != null) setState(() => _slot = picked);
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
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Label('Due'),
                          GestureDetector(
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label(t('teacher.howLong')),
                          PickerField(
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
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: Role.teacher.tint,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : Text(
                            t('teacher.setIt'),
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
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
