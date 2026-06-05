import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/config/app_config.dart';
import '../../trips/models/location_update.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level entry point for the foreground task isolate.
// Must be a top-level function annotated with @pragma('vm:entry-point').
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void locationServiceCallback() {
  FlutterForegroundTask.setTaskHandler(TmsLocationHandler());
}

/// Runs inside the foreground-service isolate.
/// Re-initializes Dio with the saved token so it can POST locations
/// without needing the main isolate.
class TmsLocationHandler extends TaskHandler {
  Dio? _dio;
  int? _tripId;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final token =
        await FlutterForegroundTask.getData<String>(key: 'token') ?? '';
    final tripIdStr =
        await FlutterForegroundTask.getData<String>(key: 'trip_id') ?? '';
    _tripId = int.tryParse(tripIdStr);

    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
      ),
    );
  }

  // Called every `eventAction` interval (30 s).
  @override
  void onRepeatEvent(DateTime timestamp) {
    _fetchAndSend();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _dio?.close();
  }

  Future<void> _fetchAndSend() async {
    if (_tripId == null || _dio == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final update = LocationUpdate(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed >= 0 ? position.speed : null,
        heading: position.heading >= 0 ? position.heading : null,
        recordedAt: DateTime.now().toIso8601String(),
      );

      final response = await _dio!.post(
        '/api/mobile/trips/$_tripId/locations',
        data: update.toJson(),
      );

      // Server can signal that tracking should stop (e.g. trip finished remotely).
      final data = response.data;
      if (data is Map && data['should_stop_tracking'] == true) {
        if (kDebugMode) debugPrint('[LocationHandler] server requested stop tracking');
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      // Keep service alive even if a single location request fails.
      if (kDebugMode) debugPrint('[LocationHandler] error: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main-isolate service — used by TrackingService → LocationController.
// ─────────────────────────────────────────────────────────────────────────────

class LocationService {
  bool _tracking = false;
  bool get isTracking => _tracking;

  /// Call once at app start via TrackingService.initialize().
  void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'tms_location_channel',
        channelName: 'TMS Ubicación',
        channelDescription:
            'Servicio de seguimiento de ubicación activo mientras el viaje está en curso.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Send location every 30 seconds.
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Starts the background location foreground service for [tripId].
  ///
  /// Permission checks must be done by [TrackingService] before calling this.
  /// [token] is passed into the task isolate via the foreground-task data store.
  Future<bool> startTracking({
    required int tripId,
    required String token,
  }) async {
    if (_tracking) return true;

    // Persist trip context so the isolate can read it on start.
    await FlutterForegroundTask.saveData(
        key: 'trip_id', value: tripId.toString());
    await FlutterForegroundTask.saveData(key: 'token', value: token);

    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'TMS — Viaje en curso',
      notificationText: 'Compartiendo ubicación en tiempo real.',
      callback: locationServiceCallback,
    );

    _tracking = result is ServiceRequestSuccess;
    return _tracking;
  }

  /// Stops the background location service and clears persisted data.
  Future<void> stopTracking() async {
    if (!_tracking) return;
    await FlutterForegroundTask.stopService();
    await FlutterForegroundTask.clearAllData();
    _tracking = false;
  }

  /// Updates the persistent notification text (e.g. when trip status changes).
  Future<void> updateNotification(String text) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'TMS — Viaje en curso',
      notificationText: text,
    );
  }
}
