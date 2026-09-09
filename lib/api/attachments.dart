/// One file the school attached to a notice.
///
/// In its own file rather than beside the parent API because all three apps
/// meet the same thing: an announcement can carry a scanned circular, a consent
/// form or a term timetable, and every audience the office writes to should be
/// able to open it. Three copies of this model is how they come to disagree
/// about which field the URL is in.
class AttachedFile {
  AttachedFile({
    required this.id,
    required this.caption,
    required this.url,
    required this.thumbnailUrl,
    required this.kind,
    required this.mime,
    required this.bytes,
    required this.filename,
  });

  final String id;
  final String? caption;

  /// Where the file actually is. Null where the asset has no readable URL,
  /// which the screen must handle rather than opening about:blank.
  final String? url;
  final String? thumbnailUrl;

  /// IMAGE, DOCUMENT, VIDEO and so on. Decides the icon, not the behaviour.
  final String kind;
  final String? mime;
  final int? bytes;

  /// What the office called it when they uploaded it. The best label there is:
  /// "Trip consent form.pdf" says more than any caption the app could invent.
  final String? filename;

  /// A caption if the office wrote one, otherwise the original filename,
  /// otherwise something rather than a blank row.
  String label(String fallback) {
    final c = caption?.trim();
    if (c != null && c.isNotEmpty) return c;
    final f = filename?.trim();
    if (f != null && f.isNotEmpty) return f;
    return fallback;
  }

  factory AttachedFile.fromJson(Map<String, dynamic> j) {
    final asset = (j['mediaAsset'] ?? const {}) as Map<String, dynamic>;
    return AttachedFile(
      id: (j['id'] ?? '') as String,
      caption: j['caption'] as String?,
      url: asset['url'] as String?,
      thumbnailUrl: asset['thumbnailUrl'] as String?,
      kind: (asset['kind'] ?? 'OTHER') as String,
      mime: asset['mime'] as String?,
      bytes: (asset['bytes'] as num?)?.toInt(),
      filename: asset['originalFilename'] as String?,
    );
  }
}
