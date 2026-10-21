/// A shareable evidence/document file attached to a trip or a trip event
/// (incident photos, POD, evidencia de carga/entrega, etc.). The [url]
/// points at the backend's public storage disk.
class TripEvidenceFile {
  final int id;
  final String name;
  final String? label;
  final String? mimeType;
  final int? size;
  final String url;
  // True when the backend flagged this file as the security seal photo
  // (see TripDocument.flags) — not used for anything yet, just carried
  // through in case it's needed later.
  final bool isSealPhoto;

  const TripEvidenceFile({
    required this.id,
    required this.name,
    required this.url,
    this.label,
    this.mimeType,
    this.size,
    this.isSealPhoto = false,
  });

  bool get isImage => (mimeType ?? '').startsWith('image/');

  factory TripEvidenceFile.fromJson(Map<String, dynamic> json) =>
      TripEvidenceFile(
        id: json['id'] as int,
        name: (json['name'] ?? '').toString(),
        label: json['label']?.toString(),
        mimeType: json['mime_type']?.toString(),
        size: json['size'] as int?,
        url: (json['url'] ?? '').toString(),
        isSealPhoto: json['is_seal_photo'] == true,
      );
}
