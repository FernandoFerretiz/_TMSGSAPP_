import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/location_service.dart';

/// Wraps LocationService as a GetX controller so the rest of the app
/// can reactively observe tracking state.
class LocationController extends GetxController {
  final LocationService _service;

  LocationController(this._service);

  final isTracking = false.obs;
  final permissionDenied = false.obs;

  @override
  void onInit() {
    super.onInit();
    _service.initialize();
  }

  Future<void> startTracking({
    required int tripId,
    required String token,
  }) async {
    if (isTracking.value) return;

    final started = await _service.startTracking(
      tripId: tripId,
      token: token,
    );

    isTracking.value = started;
    if (!started) {
      permissionDenied.value = true;
      if (kDebugMode) {
        debugPrint('[LocationController] Could not start tracking — '
            'check location permissions.');
      }
    }
  }

  Future<void> stopTracking() async {
    await _service.stopTracking();
    isTracking.value = false;
  }

  Future<void> updateNotification(String text) =>
      _service.updateNotification(text);
}
