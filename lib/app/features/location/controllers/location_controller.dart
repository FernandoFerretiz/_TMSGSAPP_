import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/tracking_service.dart';

/// Reactive GetX wrapper around [TrackingService].
/// Exposes observable state so the UI can react to tracking changes.
class LocationController extends GetxController {
  final TrackingService _service;

  LocationController(this._service);

  final isTracking = false.obs;
  final permissionDenied = false.obs;

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
}
