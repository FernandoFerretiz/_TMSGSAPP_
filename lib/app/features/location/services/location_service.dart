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

  // Called every `eventAction` interval (default 30 s).
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

      await _dio!.post(
        '/api/mobile/trips/$_tripId/locations',
        data: update.toJson(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[LocationHandler] error: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main-isolate service — used by LocationController.
// ─────────────────────────────────────────────────────────────────────────────

class LocationService {
  bool _tracking = false;
  bool get isTracking => _tracking;

  /// Call once at app start (in main() or GlobalBinding).
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

  /// Requests location permission. Returns true if granted.
  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<LocationPermission> getPermissionStatus() =>
      Geolocator.checkPermission();

  /// Starts the background location foreground service for [tripId].
  /// [token] is the current Bearer token — it's passed into the task isolate.
  /// Returns true if the service started successfully.
  Future<bool> startTracking({
    required int tripId,
    required String token,
  }) async {
    if (_tracking) return true;

    final hasPermission = await requestPermission();
    if (!hasPermission) return false;

    // Pass trip context into the task isolate via foreground-task data store.
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

  /// Stops the background location service.
  Future<void> stopTracking() async {
    if (!_tracking) return;
    await FlutterForegroundTask.stopService();
    await FlutterForegroundTask.clearAllData();
    _tracking = false;
  }

  /// Updates the notification text (e.g. when trip status changes).
  Future<void> updateNotification(String text) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'TMS — Viaje en curso',
      notificationText: text,
    );
  }
}
