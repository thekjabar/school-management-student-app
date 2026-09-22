import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/client.dart';
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/hand_in_files.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';

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
                        homeworkId: sheet.id,
                        handInOpen: sheet.handInOpen,
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
  const _HomeworkMarkEntry({
    super.key,
    required this.row,
    required this.homeworkId,
    required this.handInOpen,
    required this.maxScore,
    required this.onChanged,
  });

  final HomeworkSheetRow row;
  final String homeworkId;
  final bool handInOpen;
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

  void _showHandIn() {
    showAppSheet<void>(
      context,
      builder: (_) => _HandInSheet(row: widget.row, homeworkId: widget.homeworkId),
    );
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
                      Text(
                        [
                          row.code,
                          if (row.marked) tv('teacher.markedOn', {'name': shortDate(row.gradedAt)}),
                        ].join('  •  '),
                        style: TextStyle(fontSize: 10.5, color: AppTheme.textFaint),
                      ),
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
            if (widget.handInOpen) ...[
              const SizedBox(height: 6),
              _HandInLine(row: row, onOpen: _showHandIn),
            ],
          ],
        ),
      ),
    );
  }
}

class _HandInLine extends StatelessWidget {
  const _HandInLine({required this.row, required this.onOpen});

  final HomeworkSheetRow row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (!row.handedIn) {
      return Text(
        t('teacher.handInNothing'),
        style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
      );
    }

    final caption = [
      t('teacher.handInWork'),
      if (row.submittedAt != null) tv('teacher.handInAt', {'name': shortDate(row.submittedAt)}),
    ].join('  •  ');

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.attach_file_rounded, size: 15, color: Role.teacher.tint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Role.teacher.tint,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 17, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}

class _HandInSheet extends StatefulWidget {
  const _HandInSheet({required this.row, required this.homeworkId});

  final HomeworkSheetRow row;
  final String homeworkId;

  @override
  State<_HandInSheet> createState() => _HandInSheetState();
}

class _HandInSheetState extends State<_HandInSheet> {
  Future<void> _open(HandInFile file) async {
    try {
      final opened = await TeacherApi.instance.openHandInFile(widget.homeworkId, file.assetId);
      final url = opened.url;
      if (url == null || url.isEmpty) {
        if (mounted) showNote(context, t('msg.fileUnavailable'), bad: true);
        return;
      }
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) showNote(context, t('msg.fileCannotOpen'), bad: true);
    } catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final tint = Role.teacher.tint;
    final written = (row.handedInText ?? '').trim();

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
              row.name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.3,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                row.code,
                if (row.submittedAt != null)
                  tv('teacher.handInAt', {'name': longDate(row.submittedAt)}),
                if (row.marked) tv('teacher.markedOn', {'name': longDate(row.gradedAt)}),
              ].join('  •  '),
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.5),
            ),
            if (written.isEmpty && row.files.isEmpty) ...[
              const SizedBox(height: 18),
              Text(
                t('teacher.handInNothing'),
                style: TextStyle(fontSize: 13.5, color: AppTheme.textMuted),
              ),
            ],
            if (written.isNotEmpty) ...[
              Heading(t('teacher.handInWords'), tint: tint),
              Card16(
                padding: const EdgeInsets.all(14),
                child: Text(
                  written,
                  style: TextStyle(fontSize: 13.5, height: 1.65, color: AppTheme.text),
                ),
              ),
            ],
            if (row.files.isNotEmpty) ...[
              Heading(tn('msg.attachments', row.files.length), tint: tint),
              for (final file in row.files) ...[
                HandInFileRow(file: file, tint: tint, onOpen: () => _open(file)),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
