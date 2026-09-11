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

  final String? url;
  final String? thumbnailUrl;

  final String kind;
  final String? mime;
  final int? bytes;

  final String? filename;

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
