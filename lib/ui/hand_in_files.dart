import 'package:flutter/material.dart';

import '../api/hand_in_file.dart';
import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import 'kit.dart';

String handInFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

IconData handInFileIcon(String? mime) {
  final kind = (mime ?? '').toLowerCase();
  if (kind.startsWith('image/')) return Icons.image_rounded;
  if (kind.contains('pdf')) return Icons.picture_as_pdf_rounded;
  return Icons.insert_drive_file_rounded;
}

class HandInFileRow extends StatelessWidget {
  const HandInFileRow({
    super.key,
    required this.file,
    required this.tint,
    required this.onOpen,
    this.onRemove,
    this.removeTooltip,
    this.busy = false,
  });

  final HandInFile file;
  final Color tint;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;
  final String? removeTooltip;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final size = handInFileSize(file.bytes);
    final caption = [
      if (size.isNotEmpty) size,
      if (!file.readyToOpen) t('msg.fileChecking'),
    ].join('  •  ');

    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      radius: 13,
      onTap: file.readyToOpen ? onOpen : null,
      child: Row(
        children: [
          Icon(
            handInFileIcon(file.mime),
            size: 20,
            color: file.readyToOpen ? tint : AppTheme.textFaint,
          ),
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
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: busy ? null : onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppTheme.rose,
              tooltip: removeTooltip,
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
