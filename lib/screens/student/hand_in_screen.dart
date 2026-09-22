import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/student_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/screen_kit.dart';

const int _textMax = 4000;

class StudentHandInScreen extends StatefulWidget {
  const StudentHandInScreen({super.key, required this.homeworkId});

  final String homeworkId;

  @override
  State<StudentHandInScreen> createState() => _StudentHandInScreenState();
}

class _StudentHandInScreenState extends State<StudentHandInScreen> {
  final GlobalKey<LoaderState<HandIn>> _loader = GlobalKey<LoaderState<HandIn>>();
  bool _busy = false;

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

  Future<void> _send(String text) => _run(
        () => StudentApi.instance.sendHandIn(widget.homeworkId, text),
        t('student.handInSent'),
      );

  Future<void> _addFile() async {
    final tint = Role.student.tint;
    final source = await pickOne<ImageSource>(
      context,
      tint: tint,
      title: t('student.handInAddFile'),
      options: [
        PickOption(
          value: ImageSource.camera,
          label: t('student.handInCamera'),
          icon: Icons.photo_camera_rounded,
        ),
        PickOption(
          value: ImageSource.gallery,
          label: t('student.handInGallery'),
          icon: Icons.photo_library_rounded,
        ),
      ],
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();

    await _run(
      () => StudentApi.instance.addHandInFile(
        widget.homeworkId,
        bytes: bytes,
        filename: picked.name,
        mime: picked.mimeType ?? 'image/jpeg',
      ),
      t('student.handInFileAdded'),
    );
  }

  Future<void> _removeFile(HandInFile file) async {
    final sure = await confirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: t('student.handInRemoveFile'),
      body: file.filename ?? t('msg.fileFallback'),
      confirmLabel: t('student.handInRemoveFile'),
      confirmIcon: Icons.delete_outline_rounded,
    );
    if (!sure || !mounted) return;
    await _run(
      () => StudentApi.instance.removeHandInFile(widget.homeworkId, file.id),
      t('student.handInFileRemoved'),
    );
  }

  Future<void> _openFile(HandInFile file) async {
    try {
      final opened = await StudentApi.instance.openHandInFile(widget.homeworkId, file.assetId);
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
    final tint = Role.student.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Column(
        children: [
          ScreenHeader(title: t('student.handInTitle')),
          Expanded(
            child: Loader<HandIn>(
              key: _loader,
              tint: tint,
              padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 28),
              load: () => StudentApi.instance.handIn(widget.homeworkId),
              builder: (context, data) => _HandInBody(
                data: data,
                busy: _busy,
                onSend: _send,
                onAddFile: _addFile,
                onRemoveFile: _removeFile,
                onOpenFile: _openFile,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HandInBody extends StatelessWidget {
  const _HandInBody({
    required this.data,
    required this.busy,
    required this.onSend,
    required this.onAddFile,
    required this.onRemoveFile,
    required this.onOpenFile,
  });

  final HandIn data;
  final bool busy;
  final Future<void> Function(String text) onSend;
  final Future<void> Function() onAddFile;
  final Future<void> Function(HandInFile file) onRemoveFile;
  final Future<void> Function(HandInFile file) onOpenFile;

  @override
  Widget build(BuildContext context) {
    final work = data.homework;
    final submission = data.submission;
    final colour = parseHex(work.subjectColorHex, AppTheme.amber);
    final marked = submission?.marked ?? false;
    final shut = marked || !work.handInOpen;
    final files = submission?.files ?? const <HandInFile>[];
    final room = work.maxFiles - files.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card16(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Chip36(icon: subjectIcon(work.subject), color: colour),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      work.title,
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
                        work.subject,
                        if (work.dueDate != null) longDate(work.dueDate),
                      ].join('  •  '),
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!work.handInOpen) ...[
          const SizedBox(height: kCardGap),
          NoticeBanner(
            icon: Icons.lock_outline_rounded,
            title: t('student.handIn'),
            body: t('student.handInClosed'),
            color: AppTheme.textMuted,
          ),
        ] else if (marked) ...[
          const SizedBox(height: kCardGap),
          NoticeBanner(
            icon: Icons.workspace_premium_outlined,
            title: t('student.handInYourMark'),
            body: t('student.handInMarked'),
            color: AppTheme.violet,
          ),
        ],
        if (marked && submission != null) ...[
          const SizedBox(height: kCardGap),
          Card16(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TileRow(
                  icon: Icons.workspace_premium_outlined,
                  color: AppTheme.violet,
                  title: t('student.handInYourMark'),
                  subtitle: submission.gradedAt == null
                      ? null
                      : tv('student.handInMarkedOn', {'name': longDate(submission.gradedAt)}),
                  trailing: submission.score == null
                      ? '—'
                      : '${submission.score!.round()} / ${(work.maxScore ?? 0).round()}',
                  trailingColor: AppTheme.violet,
                  last: true,
                ),
                if ((submission.feedback ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    t('student.teacherFeedback'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppTheme.textFaint,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    submission.feedback!,
                    style: TextStyle(fontSize: 13, height: 1.6, color: AppTheme.text),
                  ),
                ],
              ],
            ),
          ),
        ],
        Heading(t('student.handInWrite'), tint: colour),
        _Answer(
          key: ValueKey<String>('answer.${submission?.id ?? 'new'}'),
          initial: submission?.text ?? '',
          shut: shut,
          busy: busy,
          tint: colour,
          again: submission?.submittedAt != null,
          onSend: onSend,
        ),
        Text(
          submission?.submittedAt == null
              ? t('student.handInNotYet')
              : tv('student.handInWhen', {'name': longDate(submission!.submittedAt)}),
          style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.5),
        ),
        Heading(t('student.handInFiles'), tint: colour),
        for (final file in files) ...[
          _FileRow(
            file: file,
            shut: shut,
            busy: busy,
            tint: colour,
            onOpen: () => onOpenFile(file),
            onRemove: () => onRemoveFile(file),
          ),
          const SizedBox(height: 8),
        ],
        if (!shut) ...[
          const SizedBox(height: 2),
          if (room > 0)
            BigButton(
              label: t('student.handInAddFile'),
              color: colour,
              busy: busy,
              onPressed: busy ? null : () => onAddFile(),
            )
          else
            Text(
              t('student.handInFilesFull'),
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          if (room > 0) ...[
            const SizedBox(height: 7),
            Text(
              tn('student.handInFilesLeft', room),
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
          ],
        ] else if (files.isEmpty)
          Text(
            t('student.handInNothing'),
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
      ],
    );
  }
}

class _Answer extends StatefulWidget {
  const _Answer({
    super.key,
    required this.initial,
    required this.shut,
    required this.busy,
    required this.tint,
    required this.again,
    required this.onSend,
  });

  final String initial;
  final bool shut;
  final bool busy;
  final Color tint;
  final bool again;
  final Future<void> Function(String text) onSend;

  @override
  State<_Answer> createState() => _AnswerState();
}

class _AnswerState extends State<_Answer> {
  late final TextEditingController _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final written = _text.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _text,
          enabled: !widget.shut && !widget.busy,
          maxLines: 7,
          minLines: 4,
          maxLength: _textMax,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontSize: 13.5, height: 1.6, color: AppTheme.text),
          decoration: InputDecoration(
            hintText: t('student.handInWrite'),
            counterText: '',
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            '${_text.text.characters.length}/$_textMax',
            style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
          ),
        ),
        if (!widget.shut) ...[
          const SizedBox(height: 10),
          BigButton(
            label: widget.again ? t('student.handInSendAgain') : t('student.handInSend'),
            color: widget.tint,
            busy: widget.busy,
            onPressed: widget.busy || written.isEmpty ? null : () => widget.onSend(written),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.shut,
    required this.busy,
    required this.tint,
    required this.onOpen,
    required this.onRemove,
  });

  final HandInFile file;
  final bool shut;
  final bool busy;
  final Color tint;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  static String _size(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final mime = (file.mime ?? '').toLowerCase();
    final icon = mime.startsWith('image/')
        ? Icons.image_rounded
        : mime.contains('pdf')
            ? Icons.picture_as_pdf_rounded
            : Icons.insert_drive_file_rounded;
    final caption = [
      if (_size(file.bytes).isNotEmpty) _size(file.bytes),
      if (!file.readyToOpen) t('student.handInFileChecking'),
    ].join('  •  ');

    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      radius: 13,
      onTap: file.readyToOpen ? onOpen : null,
      child: Row(
        children: [
          Icon(icon, size: 20, color: file.readyToOpen ? tint : AppTheme.textFaint),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.filename ?? t('msg.fileFallback'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(caption, style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (file.readyToOpen)
            Icon(Icons.open_in_new_rounded, size: 17, color: AppTheme.textFaint),
          if (!shut) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: busy ? null : onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppTheme.rose,
              tooltip: t('student.handInRemoveFile'),
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
