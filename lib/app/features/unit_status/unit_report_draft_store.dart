import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../auth/controllers/auth_controller.dart';

/// Borrador temporal de los comentarios del reporte de unidades, para no
/// perderlos si se sale de la pantalla o se cierra la app antes de generar el
/// reporte. Es por usuario y por cliente, y caduca a las 24 horas.
class UnitReportDraftStore {
  static const _ttl = Duration(hours: 24);

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String _key(int clientId) {
    final userId = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().currentUser?.id
        : null;
    return 'unit_report_draft_${userId ?? 0}_$clientId';
  }

  /// Comentarios guardados (tripId → comentario); vacío si no hay o ya caducó.
  Future<Map<int, String>> load(int clientId) async {
    try {
      final raw = await _storage.read(key: _key(clientId));
      if (raw == null) return {};

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse((data['saved_at'] ?? '').toString());
      if (savedAt == null || DateTime.now().difference(savedAt) > _ttl) {
        await clear(clientId);
        return {};
      }

      final comments = (data['comments'] as Map<String, dynamic>? ?? {});
      return {
        for (final e in comments.entries)
          if (int.tryParse(e.key) != null && e.value.toString().isNotEmpty)
            int.parse(e.key): e.value.toString(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> save(int clientId, Map<int, String> comments) async {
    try {
      if (comments.isEmpty) {
        await clear(clientId);
        return;
      }
      await _storage.write(
        key: _key(clientId),
        value: jsonEncode({
          'saved_at': DateTime.now().toIso8601String(),
          'comments': {for (final e in comments.entries) '${e.key}': e.value},
        }),
      );
    } catch (_) {
      // Sin almacenamiento disponible: el borrador sigue en memoria.
    }
  }

  Future<void> clear(int clientId) async {
    try {
      await _storage.delete(key: _key(clientId));
    } catch (_) {}
  }
}
