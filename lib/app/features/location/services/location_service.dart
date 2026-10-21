import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/tracking_config.dart';
import '../data/location_queue_store.dart';
import '../models/location_sample.dart';

/// Message sent from the foreground-task isolate to the main isolate via
/// [FlutterForegroundTask.sendDataToMain] when the server requests that
/// tracking stop (e.g. trip finished remotely). Lets [LocationService]
/// reconcile its state even though the service was stopped from the
/// isolate directly.
const String kTrackingStoppedByServerMessage = 'tracking_stopped_by_server';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level entry point for the foreground task isolate.
// Must be a top-level function annotated with @pragma('vm:entry-point').
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void locationServiceCallback() {
  FlutterForegroundTask.setTaskHandler(TmsLocationHandler());
}

/// Runs inside the foreground-service isolate.
///
/// Captures GPS fixes frequently via [Geolocator.getPositionStream] (every
/// [TrackingConfig.captureIntervalSeconds]) into a durable local queue
/// ([LocationQueueStore], sqflite — owned exclusively by this isolate), and
/// flushes the queue to the server as a single batched POST every
/// [TrackingConfig.locationUpdateIntervalSeconds] (the existing
/// `flutter_foreground_task` repeat-event tick). This keeps HTTP request
/// frequency unchanged while capture granularity increases.
///
/// A batch is only removed from the queue once the server acknowledges it —
/// a failed flush (offline, timeout) leaves the points queued for the next
/// tick, with simple backoff after repeated failures.
class TmsLocationHandler extends TaskHandler {
  static const _uuid = Uuid();

  Dio? _dio;
  int? _tripId;
  final LocationQueueStore _queue = LocationQueueStore();
  StreamSubscription<Position>? _positionSub;

  /// Latest fix while no trip is attached (idle tracking): only the most
  /// recent position is reported, nothing is queued.
  Position? _lastIdlePosition;

  bool _isFlushing = false;
  int _consecutiveFailures = 0;
  int _skipTicks = 0;

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
        // Shorter than the app-wide AppConfig timeout: a stalled attempt
        // here must not overlap the next 15s flush tick.
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    if (kDebugMode) debugPrint('[TRACKING] Iniciando tracking (trip $_tripId)');
    _startCapture();
  }

  void _startCapture() {
    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration:
            const Duration(seconds: TrackingConfig.captureIntervalSeconds),
        // Deliberately NOT set: a foregroundNotificationConfig here would
        // spin up a second, competing Android foreground service alongside
        // flutter_foreground_task's own.
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: false,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onPosition, onError: (Object e) {
      if (kDebugMode) debugPrint('[TRACKING] Error en stream de posición: $e');
    });

    // Give the stream a moment to deliver a first fix, then attempt an
    // initial flush instead of waiting for the first 15s repeat-event tick.
    Future.delayed(
      const Duration(seconds: TrackingConfig.captureIntervalSeconds),
      _flush,
    );
  }

  Future<void> _onPosition(Position position) async {

    // Drop only unambiguous non-fix sentinels some platforms emit before a
    // real lock — never a quality judgement on an actual fix (that lives
    // server-side, see LocationQualityService, and never deletes evidence).
    final isSentinel =
        (position.latitude == 0 && position.longitude == 0) ||
            position.accuracy == 0;
    if (isSentinel) return;

    if (_tripId == null) {
      _lastIdlePosition = position;
      return;
    }

    final sample = LocationSample(
      tripId: _tripId!,
      locationUuid: _uuid.v4(),
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed >= 0 ? position.speed : null,
      heading: position.heading >= 0 ? position.heading : null,
      recordedAt: position.timestamp,
    );

    await _queue.enqueue(sample);
    await _queue.trimToMax(TrackingConfig.maxQueuedPoints);
  }

  // Called every `eventAction` interval (TrackingConfig.locationUpdateIntervalSeconds).
  // This is the server-communication tick — capture (above) runs independently
  // and more frequently, but only this tick ever results in an HTTP request.
  @override
  void onRepeatEvent(DateTime timestamp) {
    _flush();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positionSub?.cancel();
    // Best-effort final flush before tearing down, then drop whatever
    // remains — a stopped/switched trip's leftover backlog isn't retried.
    await _flush();
    if (_tripId != null) {
      await _queue.clearForTrip(_tripId!);
    }
    _dio?.close();
  }

  /// Idle tracking (no trip): one lightweight heartbeat with the latest fix.
  Future<void> _pingIdle() async {
    final position = _lastIdlePosition;
    if (_isFlushing || _dio == null || position == null) return;

    _isFlushing = true;
    try {
      await _dio!.post(
        '/api/mobile/tracking/ping',
        data: {'latitude': position.latitude, 'longitude': position.longitude},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[TRACKING] Error en ping sin viaje: $e');
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _flush() async {
    if (_tripId == null) return _pingIdle();
    if (_isFlushing || _dio == null) return;

    if (_skipTicks > 0) {
      _skipTicks--;
      if (kDebugMode) {
        debugPrint('[TRACKING] Backoff activo, saltando intento de envío');
      }
      return;
    }

    final batch =
        await _queue.oldestBatch(limit: TrackingConfig.maxBatchSize);
    if (batch.isEmpty) return;

    _isFlushing = true;
    try {
      if (kDebugMode) {
        debugPrint(
            '[TRACKING] Enviando lote de ${batch.length} ubicaciones (trip $_tripId)');
      }
      final response = await _dio!.post(
        '/api/mobile/trips/$_tripId/locations',
        data: {'locations': batch.map((s) => s.toApiJson()).toList()},
      );

      // Only the server-acknowledged points are removed — a partial/failed
      // response leaves everything queued for the next tick.
      await _queue.deleteByUuids(batch.map((s) => s.locationUuid).toList());
      _consecutiveFailures = 0;
      if (kDebugMode) debugPrint('[TRACKING] Lote confirmado por el servidor');

      final data = response.data;
      if (data is Map && data['should_stop_tracking'] == true) {
        if (kDebugMode) {
          debugPrint('[TRACKING] Viaje ya no está activo (servidor solicitó detener)');
        }
        FlutterForegroundTask.sendDataToMain(kTrackingStoppedByServerMessage);
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      // Nothing is deleted from the queue — the batch simply stays pending
      // and is retried (with backoff) on a later tick. Keeps the service
      // alive across transient connectivity loss instead of dropping data.
      _consecutiveFailures++;
      _skipTicks = _backoffSkipTicksFor(_consecutiveFailures);
      if (kDebugMode) {
        debugPrint('[TRACKING] Error al enviar lote (quedará en cola): $e');
      }
    } finally {
      _isFlushing = false;
    }
  }

  /// Simple backoff reusing the existing 15s tick as the only clock: no
  /// failures → try every tick (~15s); 3+ consecutive → skip one (~30s);
  /// 6+ → skip three (~60s). Resets to 0 on the next successful flush.
  int _backoffSkipTicksFor(int failures) {
    if (failures >= 6) return 3;
    if (failures >= 3) return 1;
    return 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main-isolate service — used by TrackingService → LocationController.
// ─────────────────────────────────────────────────────────────────────────────

class LocationService {
  bool _tracking = false;
  int? _trackingTripId;
  bool _dataCallbackRegistered = false;

  /// Invoked when the server asked the task isolate to stop (trip over).
  /// [TrackingService] uses it to fall back to idle tracking.
  VoidCallback? onServerStopped;

  bool get isTracking => _tracking;

  /// The trip currently being tracked, or null if no tracking is active.
  int? get currentTripId => _trackingTripId;

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
        eventAction: ForegroundTaskEventAction.repeat(
          TrackingConfig.locationUpdateIntervalSeconds * 1000,
        ),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    // Reconcile main-isolate state when the task isolate stops itself
    // (server-requested stop) — otherwise `_tracking` would go stale.
    if (!_dataCallbackRegistered) {
      FlutterForegroundTask.addTaskDataCallback(_onTaskData);
      _dataCallbackRegistered = true;
    }
  }

  void _onTaskData(Object data) {
    if (data == kTrackingStoppedByServerMessage) {
      if (kDebugMode) debugPrint('[TRACKING] Deteniendo tracking (confirmado por el servidor)');
      _tracking = false;
      _trackingTripId = null;
      onServerStopped?.call();
    }
  }

  /// Starts the background location foreground service for [tripId].
  ///
  /// Permission checks must be done by [TrackingService] before calling this.
  /// [token] is passed into the task isolate via the foreground-task data store.
  Future<bool> startTracking({
    int? tripId,
    required String token,
  }) async {
    if (_tracking && _trackingTripId == tripId) return true;

    // The native service can survive a Dart-isolate restart (app killed and
    // reopened) even though this fresh LocationService instance thinks it
    // isn't tracking yet.
    if (await FlutterForegroundTask.isRunningService) {
      final savedTripIdStr =
          await FlutterForegroundTask.getData<String>(key: 'trip_id') ?? '';
      if (savedTripIdStr == (tripId?.toString() ?? '')) {
        // Already tracking this same trip — just resync local state,
        // no need to restart the native service.
        _tracking = true;
        _trackingTripId = tripId;
        return true;
      }
      // A different trip is running (or state is stale) — the isolate only
      // reads trip_id once in onStart, so it must be restarted to pick up
      // the new trip. Its onDestroy callback flushes/clears its own queue
      // before this call returns.
      if (kDebugMode) {
        debugPrint('[TRACKING] Reiniciando tracking para nuevo viaje (trip $tripId)');
      }
      await FlutterForegroundTask.stopService();
      await FlutterForegroundTask.clearAllData();
    }

    // Persist trip context so the isolate can read it on start.
    await FlutterForegroundTask.saveData(
        key: 'trip_id', value: tripId?.toString() ?? '');
    await FlutterForegroundTask.saveData(key: 'token', value: token);

    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: tripId == null ? 'TMS — Rastreo activo' : 'TMS — Viaje en curso',
      notificationText: 'Compartiendo ubicación en tiempo real.',
      callback: locationServiceCallback,
    );

    _tracking = result is ServiceRequestSuccess;
    _trackingTripId = _tracking ? tripId : null;
    return _tracking;
  }

  /// Stops the background location service and clears persisted data.
  /// The task isolate's own `onDestroy` handles flushing/clearing its
  /// local queue before the service actually stops.
  Future<void> stopTracking() async {
    if (!_tracking) return;
    if (kDebugMode) debugPrint('[TRACKING] Deteniendo tracking');
    await FlutterForegroundTask.stopService();
    await FlutterForegroundTask.clearAllData();
    _tracking = false;
    _trackingTripId = null;
  }

  /// Updates the persistent notification text (e.g. when trip status changes).
  Future<void> updateNotification(String text) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'TMS — Viaje en curso',
      notificationText: text,
    );
  }
}
