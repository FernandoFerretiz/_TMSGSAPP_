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

  /// Must be called once before any tracking operation.
  void initialize() => _locationService.initialize();

  /// Runs the full permission chain:
  /// location service enabled → location permission → notification → always/background.
  /// Returns true only when all permissions are granted.
  Future<bool> ensurePermissions() =>
      LocationPermissionService.ensureTrackingPermission();

  /// Starts location tracking for [tripId].
  ///
  /// Guards:
  /// - Returns false immediately if no valid token exists.
  /// - Returns true immediately if tracking is already running (no duplicate).
  /// - Requests all required permissions; returns false if any are denied.
  Future<bool> startTracking({required int tripId}) async {
    final token = TokenManager.token;
    if (token == null || token.isEmpty) return false;

    if (_locationService.isTracking) return true;

    final permitted = await ensurePermissions();
    if (!permitted) return false;

    return _locationService.startTracking(tripId: tripId, token: token);
  }

  /// Stops location tracking and clears persisted task data.
  Future<void> stopTracking() => _locationService.stopTracking();

  /// Whether the foreground service / background task is currently running.
  bool get isTracking => _locationService.isTracking;

  /// Updates the persistent notification text while tracking is active.
  Future<void> updateNotification(String text) =>
      _locationService.updateNotification(text);
}
