import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

const homeworkStates = ['SUBMITTED', 'LATE', 'NOT_SUBMITTED', 'EXCUSED'];

String homeworkStateLabel(String status) => switch (status) {
      'SUBMITTED' || 'GRADED' => t('teacher.handedIn'),
      'LATE' => t('teacher.handedInLate'),
      'EXCUSED' => t('teacher.excused'),
      _ => t('teacher.notHandedIn'),
    };

class HomeworkMarksScreen extends StatefulWidget {
  const HomeworkMarksScreen({super.key, required this.homework});

  final TeacherHomework homework;

  @override
  State<HomeworkMarksScreen> createState() => _HomeworkMarksScreenState();
}

class _HomeworkMarksScreenState extends State<HomeworkMarksScreen> {
  final _loaderKey = GlobalKey<LoaderState<HomeworkSheet>>();
  HomeworkSheet? _sheet;
  bool _saving = false;

  Future<void> _save() async {
    final sheet = _sheet;
    if (sheet == null) return;
    setState(() => _saving = true);
    try {
      await TeacherApi.instance.saveHomeworkMarks(sheet);
      if (!mounted) return;
      showNote(context, t('teacher.marksSaved'));
      _loaderKey.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final changed = _sheet?.changedEntries().length ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BigButton(
            label: tn('teacher.saveCount', changed),
            color: Role.teacher.tint,
            height: 50,
            busy: _saving,
            onPressed: changed > 0 ? _save : null,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: widget.homework.title,
              subtitle: '${widget.homework.className} · ${widget.homework.subjectName}',
            ),
            Expanded(
              child: Loader<HomeworkSheet>(
                key: _loaderKey,
                tint: Role.teacher.tint,
                load: () async {
                  final sheet = await TeacherApi.instance.homeworkSheet(widget.homework.id);
                  _sheet = sheet;
                  return sheet;
                },
                isEmpty: (sheet) => sheet.rows.isEmpty,
                empty: t('teacher.noRoster'),
                builder: (context, sheet) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    if (sheet.maxScore == null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.amberSoft,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          t('teacher.homeworkNoMarks'),
                          style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.text),
                        ),
                      ),
                    ...sheet.rows.map(
                      (row) => _HomeworkMarkEntry(
                        key: ValueKey(row.studentId),
                        row: row,
                        maxScore: sheet.maxScore,
                        onChanged: () => setState(() {}),
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

class _HomeworkMarkEntry extends StatefulWidget {
  const _HomeworkMarkEntry({super.key, required this.row, required this.maxScore, required this.onChanged});

  final HomeworkSheetRow row;
  final num? maxScore;
  final VoidCallback onChanged;

  @override
  State<_HomeworkMarkEntry> createState() => _HomeworkMarkEntryState();
}

class _HomeworkMarkEntryState extends State<_HomeworkMarkEntry> {
  late final TextEditingController _controller = TextEditingController(text: widget.row.score?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final max = widget.maxScore;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    row.rollNumber ?? '',
                    style: TextStyle(fontSize: 12, color: AppTheme.textFaint, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      Text(row.code, style: TextStyle(fontSize: 10.5, color: AppTheme.textFaint)),
                    ],
                  ),
                ),
                if (max != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 62,
                    child: TextField(
                      controller: _controller,
                      enabled: row.status != 'EXCUSED',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '/$max',
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        final parsed = num.tryParse(value.trim());
                        row.score = parsed != null && parsed >= 0 && parsed <= max ? parsed : null;
                        widget.onChanged();
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: homeworkStates.map((state) {
                final selected = row.status == state || (state == 'SUBMITTED' && row.status == 'GRADED');
                return ChoiceChip(
                  label: Text(homeworkStateLabel(state), style: const TextStyle(fontSize: 11.5)),
                  selected: selected,
                  selectedColor: Role.teacher.tint.withValues(alpha: 0.18),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    if (selected) return;
                    setState(() {
                      row.status = state;
                      if (state == 'EXCUSED' || state == 'NOT_SUBMITTED') {
                        row.score = null;
                        _controller.clear();
                      }
                    });
                    widget.onChanged();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
