import 'dart:io';

import 'package:flutter/services.dart';

import 'incoming_shared_file.dart';

/// Bridges native "SultanX received a shared file from another app" events
/// to Dart. Backed by the SEND intent-filter declared on MainActivity (see
/// AndroidManifest.xml) — Android only for now: making SultanX a share
/// target on iOS requires a separate Share Extension Xcode target, which
/// can't be added through source-file edits alone.
class ReceiveShareService {
  static const _methodChannel = MethodChannel('com.sultanx.tms/share');
  static const _eventChannel = EventChannel('com.sultanx.tms/share_events');

  /// Fires for each share received while the app is already running.
  Stream<IncomingSharedFile> get onShareReceived => _eventChannel
      .receiveBroadcastStream()
      .map((event) => _toIncomingFile(event))
      .where((file) => file != null)
      .cast<IncomingSharedFile>();

  /// Covers the cold-start case: the app was launched directly by the
  /// SEND intent, before any Dart listener could exist. Call once during
  /// app startup — the native side clears it after returning it.
  Future<IncomingSharedFile?> takePending() async {
    try {
      final result = await _methodChannel.invokeMethod(
        'takePendingSharedFile',
      );
      return _toIncomingFile(result);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  IncomingSharedFile? _toIncomingFile(dynamic event) {
    if (event is! Map) return null;
    final path = event['filePath'] as String?;
    if (path == null || path.isEmpty) return null;

    return IncomingSharedFile(
      file: File(path),
      mimeType: event['mimeType'] as String?,
      text: event['text'] as String?,
    );
  }
}
