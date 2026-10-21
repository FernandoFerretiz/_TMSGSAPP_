import 'package:flutter/foundation.dart';
import '../../../core/location/location_permission_service.dart';
import '../../../core/network/token_manager.dart';
import 'location_service.dart';

/// Unified tracking facade.
///
/// Encapsulates all business-logic rules (token check, permission check,
/// de-duplication guard) so that callers only need a trip ID.
/// Platform differences (Android foreground service vs iOS background location)
/// are handled transparently by [LocationService] / flutter_foreground_task.
class TrackingService {
  final LocationService _locationService;

  TrackingService(this._locationService);

  // Los plugins nativos de permisos (geolocator / permission_handler) no
  // toleran solicitudes concurrentes: en Android, una segunda llamada a
  // requestPermission() mientras la primera sigue esperando el resultado
  // del usuario puede quedarse colgada para siempre (el callback nativo
  // solo se entrega una vez). loadActiveTrip() (pull-to-refresh),
  // startTrip() y finishTrip() pueden disparar start/stopTracking casi al
  // mismo tiempo si el usuario navega rápido — por eso start/stop
  // comparten un único Future en vuelo: una llamada que llega mientras la
  // anterior sigue en curso espera ese mismo resultado en vez de iniciar
  // una segunda cadena de permisos.
  Future<bool>? _inFlightStart;
  Future<void>? _inFlightStop;

  /// Must be called once before any tracking operation.
  void initialize() {
    _locationService.initialize();
    // The server ends trip tracking when the trip is over; the operator's
    // manual tracking must keep going (idle mode, no trip attached).
    _locationService.onServerStopped = () {
      Future.delayed(const Duration(seconds: 1), () => startTracking());
    };
  }

  /// Runs the full permission chain:
  /// location service enabled → location permission → notification → always/background.
  /// Returns true only when all permissions are granted.
  Future<bool> ensurePermissions() =>
      LocationPermissionService.ensureTrackingPermission();

  /// Starts location tracking for [tripId], or idle tracking (no trip) when null.
  ///
  /// Guards:
  /// - Returns false immediately if no valid token exists.
  /// - Returns true immediately if this same trip is already being tracked
  ///   (no duplicate service/timer).
  /// - If a *different* trip is currently being tracked, [LocationService]
  ///   restarts the underlying service for the new trip.
  /// - Requests all required permissions; returns false if any are denied.
  /// - If a start (or stop) is already in flight, awaits that same
  ///   operation instead of starting a second permission request.
  Future<bool> startTracking({int? tripId}) {
    if (_inFlightStart != null) return _inFlightStart!;
    if (_inFlightStop != null) {
      return _inFlightStop!.then((_) => startTracking(tripId: tripId));
    }

    final future = _doStartTracking(tripId: tripId);
    _inFlightStart = future;
    future.whenComplete(() => _inFlightStart = null);
    return future;
  }

  Future<bool> _doStartTracking({int? tripId}) async {
    final token = TokenManager.token;
    if (token == null || token.isEmpty) return false;

    if (_locationService.isTracking &&
        _locationService.currentTripId == tripId) {
      return true;
    }

    final permitted = await ensurePermissions();
    if (!permitted) {
      if (kDebugMode) debugPrint('[TRACKING] Permisos de ubicación denegados');
      return false;
    }

    if (kDebugMode) debugPrint('[TRACKING] Iniciando tracking (trip $tripId)');
    return _locationService.startTracking(tripId: tripId, token: token);
  }

  /// A trip's tracking is over: drop back to idle tracking (no trip) so the
  /// operator stays visible until they stop it manually. No-op when the
  /// service isn't attached to a trip.
  Future<void> returnToIdle() async {
    if (!_locationService.isTracking || _locationService.currentTripId == null) {
      return;
    }
    await startTracking();
  }

  /// Stops location tracking and clears persisted task data.
  Future<void> stopTracking() {
    if (_inFlightStop != null) return _inFlightStop!;
    if (_inFlightStart != null) {
      return _inFlightStart!.then((_) => stopTracking());
    }

    final future = _locationService.stopTracking();
    _inFlightStop = future;
    future.whenComplete(() => _inFlightStop = null);
    return future;
  }

  /// Whether the foreground service / background task is currently running.
  bool get isTracking => _locationService.isTracking;

  /// Updates the persistent notification text while tracking is active.
  Future<void> updateNotification(String text) =>
      _locationService.updateNotification(text);
}
