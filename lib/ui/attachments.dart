import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/attachments.dart';
import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import 'async.dart';

/// The files the school attached to a notice.
///
/// One widget, three audiences. The office has been able to attach a scanned
/// circular, a consent form or a term timetable since announcements were built,
/// and every list route has always carried the COUNT — but nothing in any of
/// the three apps ever fetched the files, so a school could publish a form that
/// no parent, teacher or driver had any way to open.
///
/// Loaded when the notice is opened rather than with the list, because the
/// count is all that is needed to decide whether to draw this at all, and
/// pulling every attachment of every announcement on every open would be a
/// great deal of work for the few that are ever tapped.
class AttachmentList extends StatefulWidget {
  const AttachmentList({
    super.key,
    required this.count,
    required this.load,
    required this.tint,
  });

  /// From the list route, so the caller knows whether to draw this at all.
  final int count;
  final Future<List<AttachedFile>> Function() load;
  final Color tint;

  @override
  State<AttachmentList> createState() => _AttachmentListState();
}

class _AttachmentListState extends State<AttachmentList> {
  List<AttachedFile>? _files;
  bool _failed = false;
  String? _opening;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final files = await widget.load();
      if (mounted) setState(() => _files = files);
    } catch (_) {
      // The notice itself is the thing that matters and it is already on
      // screen. A failed attachment list says so and offers to try again,
      // rather than taking the words down with it.
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open(AttachedFile f) async {
    final url = f.url;
    if (url == null || url.isEmpty) {
      showNote(context, t('msg.fileUnavailable'), bad: true);
      return;
    }
    setState(() => _opening = f.id);
    try {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) showNote(context, t('msg.fileCannotOpen'), bad: true);
    } catch (_) {
      if (mounted) showNote(context, t('msg.fileCannotOpen'), bad: true);
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  static IconData _iconFor(AttachedFile f) {
    final mime = (f.mime ?? '').toLowerCase();
    if (f.kind == 'IMAGE' || mime.startsWith('image/')) return Icons.image_rounded;
    if (f.kind == 'VIDEO' || mime.startsWith('video/')) return Icons.play_circle_rounded;
    if (mime.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (mime.contains('sheet') || mime.contains('excel')) return Icons.table_chart_rounded;
    return Icons.insert_drive_file_rounded;
  }

  /// Sizes as a family reads them, because "2.4 MB" is the difference between
  /// tapping now and waiting for wifi.
  static String _size(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.tint;
    final files = _files;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tn('msg.attachments', widget.count),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 9),
        if (_failed)
          TextButton.icon(
            onPressed: () {
              setState(() => _failed = false);
              _load();
            },
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: Text(t('msg.filesRetry')),
            style: TextButton.styleFrom(foregroundColor: tint, padding: EdgeInsets.zero),
          )
        else if (files == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: tint),
            ),
          )
        else
          for (final f in files)
            InkWell(
              onTap: _opening == null ? () => _open(f) : null,
              borderRadius: BorderRadius.circular(13),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppTheme.canvas,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Icon(_iconFor(f), size: 20, color: tint),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.label(t('msg.fileFallback')),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.text,
                            ),
                          ),
                          if (_size(f.bytes).isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _size(f.bytes),
                              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_opening == f.id)
                      SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2.1, color: tint),
                      )
                    else
                      Icon(Icons.open_in_new_rounded, size: 17, color: AppTheme.textFaint),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
