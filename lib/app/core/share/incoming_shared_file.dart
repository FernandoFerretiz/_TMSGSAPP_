import 'dart:io';

/// A file another app (WhatsApp, Galería, Archivos…) handed to SultanX via
/// the system's share sheet.
class IncomingSharedFile {
  final File file;
  final String? mimeType;
  final String? text;

  const IncomingSharedFile({required this.file, this.mimeType, this.text});
}
