class HandInFile {
  HandInFile({
    required this.id,
    required this.assetId,
    required this.mime,
    required this.bytes,
    required this.filename,
    required this.readyToOpen,
  });

  final String id;
  final String assetId;
  final String? mime;
  final int? bytes;
  final String? filename;
  final bool readyToOpen;

  factory HandInFile.fromJson(Map<String, dynamic> j) => HandInFile(
        id: (j['id'] ?? '') as String,
        assetId: (j['assetId'] ?? '') as String,
        mime: j['mime'] as String?,
        bytes: (j['bytes'] as num?)?.toInt(),
        filename: j['originalFilename'] as String?,
        readyToOpen: (j['readyToOpen'] ?? false) as bool,
      );
}
