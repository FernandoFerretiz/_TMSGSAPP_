import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../../../config/routes/route_names.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../location/controllers/location_controller.dart';
import '../../location/services/tracking_service.dart';
import '../data/trip_service.dart';
import '../models/active_trip_response.dart';
import '../models/trip_model.dart';
import '../models/trip_status_request.dart';

class TripController extends GetxController {
  final TripService _tripService;
  final TrackingService _trackingService;

  TripController(this._tripService, this._trackingService);

  final isLoading = false.obs;
  final isChangingStatus = false.obs;
  final errorMessage = ''.obs;

  final _activeTripResponse = Rxn<ActiveTripResponse>();
  ActiveTripResponse? get activeTripResponse => _activeTripResponse.value;
  TripModel? get activeTrip => _activeTripResponse.value?.trip;
  bool get hasActiveTrip => _activeTripResponse.value?.hasActiveTrip == true;

  @override
  void onInit() {
    super.onInit();
    // Only operators need the active-trip data.
    final auth = Get.find<AuthController>();
    if (auth.hasRole('operador')) {
      loadActiveTrip();
    }
  }

  // ── Load active trip ───────────────────────────────────────────────────

  Future<void> loadActiveTrip() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final result = await _tripService.getActiveTrip();
      _activeTripResponse.value = result;

      // Resume background location if the trip is in a trackable state
      // (started or arrived) and the server says tracking should be enabled.
      if (result.hasActiveTrip &&
          result.trackingEnabled &&
          result.trip?.requiresTracking == true) {
        final started =
            await _trackingService.startTracking(tripId: result.trip!.id);
        _syncLocationController(started);
      }
    } on DioException catch (e) {
      errorMessage.value = 'No se pudo cargar el viaje activo.';
      if (kDebugMode) debugPrint('[TripController] loadActiveTrip DioError: $e');
    } catch (e) {
      if (kDebugMode) debugPrint('[TripController] loadActiveTrip error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Start trip ─────────────────────────────────────────────────────────

  Future<bool> startTrip({
    String? notes,
    List<String> evidenceFilePaths = const [],
  }) async {
    final trip = activeTrip;
    if (trip == null) return false;

    isChangingStatus.value = true;
    errorMessage.value = '';
    try {
      final position = await _getCurrentPosition();
      final response = await _tripService.changeStatus(
        trip.id,
        TripStatusRequest(
          status: 'started',
          latitude: position?.latitude ?? 0.0,
          longitude: position?.longitude ?? 0.0,
          notes: notes,
          evidenceFilePaths: evidenceFilePaths,
        ),
      );

      // Only start background tracking if the server confirms it.
      if (response.trackingEnabled) {
        final started =
            await _trackingService.startTracking(tripId: trip.id);
        _syncLocationController(started);
      }

      await loadActiveTrip();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _parseError(e);
      return false;
    } catch (e) {
      errorMessage.value = 'Error al iniciar el viaje.';
      if (kDebugMode) debugPrint('[TripController] startTrip error: $e');
      return false;
    } finally {
      isChangingStatus.value = false;
    }
  }

  // ── Finish trip ────────────────────────────────────────────────────────

  Future<bool> finishTrip({
    String? notes,
    List<String> evidenceFilePaths = const [],
  }) async {
    final trip = activeTrip;
    if (trip == null) return false;

    isChangingStatus.value = true;
    errorMessage.value = '';
    try {
      final position = await _getCurrentPosition();
      final response = await _tripService.changeStatus(
        trip.id,
        TripStatusRequest(
          status: 'finished',
          latitude: position?.latitude ?? 0.0,
          longitude: position?.longitude ?? 0.0,
          notes: notes,
          evidenceFilePaths: evidenceFilePaths,
        ),
      );

      // Stop tracking when the trip finishes or when the server requests it.
      if (response.shouldStopTracking || true) {
        await _trackingService.stopTracking();
        _syncLocationController(false);
      }

      await loadActiveTrip();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _parseError(e);
      return false;
    } catch (e) {
      errorMessage.value = 'Error al finalizar el viaje.';
      if (kDebugMode) debugPrint('[TripController] finishTrip error: $e');
      return false;
    } finally {
      isChangingStatus.value = false;
    }
  }

  // ── Report incident (stub — endpoint TBD) ─────────────────────────────

  Future<void> reportIncident({
    required String notes,
    List<String> evidenceFilePaths = const [],
  }) async {
    // TODO: implement when /api/mobile/trips/{trip}/incidents endpoint exists.
    Get.snackbar(
      'Próximamente',
      'La funcionalidad de incidencias estará disponible pronto.',
    );
  }

  // ── Navigation helpers ─────────────────────────────────────────────────

  void goToStartTrip() => Get.toNamed(RouteNames.startTrip);

  void goToChangeStatus() => Get.toNamed(RouteNames.changeStatus);

  // ── Private ────────────────────────────────────────────────────────────

  /// Keeps [LocationController.isTracking] in sync after TrackingService calls.
  void _syncLocationController(bool tracking) {
    try {
      Get.find<LocationController>().isTracking.value = tracking;
    } catch (_) {
      // LocationController may not be registered in all contexts.
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return 'Error ${e.response?.statusCode ?? 'de red'}.';
  }
}
