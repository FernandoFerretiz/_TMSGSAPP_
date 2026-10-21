import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../data/operator_tracking_api.dart';
import '../services/tracking_service.dart';

/// Reactive GetX wrapper around [TrackingService].
/// Exposes observable state so the UI can react to tracking changes.
class LocationController extends GetxController {
  final TrackingService _service;
  final OperatorTrackingApi _api;

  LocationController(this._service, this._api);

  final isTracking = false.obs;
  final permissionDenied = false.obs;

  /// True while a manual start/stop request is in flight.
  final isToggling = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _service.initialize();
  }

  /// Starts tracking for [tripId].
  /// Token is obtained internally by [TrackingService] — no token parameter needed.
  Future<void> startTracking({required int tripId}) async {
    if (isTracking.value) return;

    final started = await _service.startTracking(tripId: tripId);

    isTracking.value = started;
    if (!started) {
      permissionDenied.value = true;
      if (kDebugMode) {
        debugPrint('[LocationController] Could not start tracking — '
            'check location permissions or token.');
      }
    }
  }

  Future<void> stopTracking() async {
    await _service.stopTracking();
    isTracking.value = false;
    permissionDenied.value = false;
  }

  Future<void> updateNotification(String text) =>
      _service.updateNotification(text);

  Future<bool> ensurePermissions() => _service.ensurePermissions();

  // ── Manual tracking ("Iniciar / Detener rastreo") ──────────────────────

  /// Reconciles with the server: if it says tracking is active but the
  /// device isn't reporting (app restarted), resume idle tracking.
  Future<void> syncWithServer() async {
    try {
      final state = await _api.status();
      if (state.active && !_service.isTracking) {
        isTracking.value = await _service.startTracking();
      } else {
        isTracking.value = _service.isTracking;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[LocationController] sync failed: $e');
    }
  }

  Future<void> startManual() async {
    if (isToggling.value || isTracking.value) return;
    isToggling.value = true;
    errorMessage.value = '';
    try {
      final started = await _service.startTracking();
      if (!started) {
        permissionDenied.value = true;
        errorMessage.value =
            'No se pudo iniciar el rastreo. Revisa los permisos de ubicación.';
        return;
      }
      permissionDenied.value = false;
      try {
        await _api.start();
        isTracking.value = true;
      } catch (e) {
        await _service.stopTracking();
        errorMessage.value = _message(e, 'No se pudo iniciar el rastreo.');
      }
    } finally {
      isToggling.value = false;
    }
  }

  /// The server is the authority: it refuses (422) while a trip is open.
  Future<void> stopManual() async {
    if (isToggling.value || !isTracking.value) return;
    isToggling.value = true;
    errorMessage.value = '';
    try {
      await _api.stop();
      await _service.stopTracking();
      isTracking.value = false;
    } catch (e) {
      errorMessage.value = _message(e, 'No se pudo detener el rastreo.');
    } finally {
      isToggling.value = false;
    }
  }

  String _message(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
        if (data['message'] != null) return data['message'].toString();
      }
    }
    return fallback;
  }
}
