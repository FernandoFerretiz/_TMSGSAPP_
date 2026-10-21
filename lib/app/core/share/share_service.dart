import 'dart:io';

import 'package:flutter/services.dart';

import 'share_channel.dart';

class ShareResult {
  final bool success;
  final String? errorMessage;

  const ShareResult.success()
      : success = true,
        errorMessage = null;

  const ShareResult.failure(this.errorMessage) : success = false;
}

/// Hands a local file (plus optional text) directly to WhatsApp or
/// Telegram, without going through the system's generic share sheet.
///
/// This is deliberately backed by a native MethodChannel rather than a
/// pub.dev package: sharing to *one specific app* requires building an
/// `ACTION_SEND` intent with `setPackage()` on Android (see
/// `MainActivity.kt`), which no maintained Flutter plugin exposes. iOS has
/// no equivalent public API — see the `shareFile` native implementation in
/// `AppDelegate.swift` for the sanctioned alternative and its limitation.
class ShareService {
  static const _channel = MethodChannel('com.sultanx.tms/share');

  Future<bool> isWhatsAppInstalled() => _isInstalled(ShareChannel.whatsapp);

  Future<bool> isTelegramInstalled() => _isInstalled(ShareChannel.telegram);

  Future<bool> isChannelInstalled(ShareChannel channel) =>
      _isInstalled(channel);

  Future<ShareResult> shareToWhatsApp({required File file, String? text}) =>
      _share(ShareChannel.whatsapp, file: file, text: text);

  Future<ShareResult> shareToTelegram({required File file, String? text}) =>
      _share(ShareChannel.telegram, file: file, text: text);

  Future<ShareResult> shareToChannel(
    ShareChannel channel, {
    required File file,
    String? text,
  }) =>
      _share(channel, file: file, text: text);

  /// Shares several files as a single message (e.g. all of an event's
  /// evidence photos at once) — only Android's ACTION_SEND_MULTIPLE
  /// supports batching into one WhatsApp/Telegram message; iOS'
  /// UIDocumentInteractionController (see AppDelegate.swift) has no
  /// multi-file "Open in…", so there we fall back to sharing just the
  /// first file, same as before this method existed.
  Future<ShareResult> shareFilesToChannel(
    ShareChannel channel, {
    required List<File> files,
    String? text,
  }) {
    if (files.isEmpty) {
      return Future.value(const ShareResult.failure('No hay archivos para compartir.'));
    }
    if (!Platform.isAndroid || files.length == 1) {
      return _share(channel, file: files.first, text: text);
    }
    return _shareMultiple(channel, files: files, text: text);
  }

  /// Shares text with no file attached (e.g. "Compartir resumen" kept
  /// separate from the evidence photos). Android sends a plain
  /// `text/plain` ACTION_SEND; iOS has no file to hand to
  /// UIDocumentInteractionController for this case, so it opens the
  /// channel's own `send?text=`/`msg?text=` URL scheme instead — still one
  /// specific app, not the generic share sheet.
  Future<ShareResult> shareTextToChannel(
    ShareChannel channel, {
    required String text,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('shareText', {
        'packages': channel.androidPackages,
        'scheme': channel.iosScheme,
        'text': text,
      });

      if (ok == true) return const ShareResult.success();
      return ShareResult.failure('${channel.label} no está instalado.');
    } on PlatformException catch (e) {
      return ShareResult.failure(
        e.message ?? 'No se pudo compartir el texto.',
      );
    }
  }

  Future<bool> _isInstalled(ShareChannel channel) async {
    try {
      final result = await _channel.invokeMethod<bool>('isAppInstalled', {
        'packages': channel.androidPackages,
        'scheme': channel.iosScheme,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<ShareResult> _share(
    ShareChannel channel, {
    required File file,
    String? text,
  }) async {
    if (!await file.exists()) {
      return const ShareResult.failure('El archivo no existe.');
    }

    try {
      final ok = await _channel.invokeMethod<bool>('shareFile', {
        'packages': channel.androidPackages,
        'scheme': channel.iosScheme,
        'filePath': file.path,
        'mimeType': _mimeTypeFor(file.path),
        'text': text,
      });

      if (ok == true) return const ShareResult.success();
      return ShareResult.failure('${channel.label} no está instalado.');
    } on PlatformException catch (e) {
      return ShareResult.failure(
        e.message ?? 'No se pudo compartir el archivo.',
      );
    }
  }

  Future<ShareResult> _shareMultiple(
    ShareChannel channel, {
    required List<File> files,
    String? text,
  }) async {
    for (final file in files) {
      if (!await file.exists()) {
        return const ShareResult.failure('Alguno de los archivos no existe.');
      }
    }

    try {
      final ok = await _channel.invokeMethod<bool>('shareFiles', {
        'packages': channel.androidPackages,
        'filePaths': files.map((f) => f.path).toList(),
        'mimeType': _mimeTypeForAll(files),
        'text': text,
      });

      if (ok == true) return const ShareResult.success();
      return ShareResult.failure('${channel.label} no está instalado.');
    } on PlatformException catch (e) {
      return ShareResult.failure(
        e.message ?? 'No se pudo compartir los archivos.',
      );
    }
  }

  /// A single mime type covering every file in the batch — Android's
  /// ACTION_SEND_MULTIPLE only takes one `type`, not one per file.
  String _mimeTypeForAll(List<File> files) {
    final types = files.map((f) => _mimeTypeFor(f.path)).toSet();
    if (types.length == 1) return types.first;
    if (types.every((t) => t.startsWith('image/'))) return 'image/*';
    return '*/*';
  }

  String _mimeTypeFor(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument'
            '.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument'
            '.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }
}
