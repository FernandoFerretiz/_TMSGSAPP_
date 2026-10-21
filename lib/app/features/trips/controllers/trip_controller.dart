import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/routes/route_names.dart';
import '../../../core/config/app_config.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../location/controllers/location_controller.dart';
import '../../location/services/tracking_service.dart';
import '../data/trip_service.dart';
import '../models/active_trip_response.dart';
import '../models/checklist_answer.dart';
import '../models/checklist_question.dart';
import '../models/trip_evidence_state.dart';
import '../models/trip_model.dart';
import '../models/trip_status_request.dart';

class TripController extends GetxController {
  final TripService _tripService;
  final TrackingService _trackingService;

  TripController(this._tripService, this._trackingService);

  final isLoading = false.obs;
  final isChangingStatus = false.obs;
  final errorMessage = ''.obs;

  // ── Pre-start flow (documents + seal + checklist + material adicional) ────
  final documentPhotos = <XFile>[].obs;
  final sealPhotos = <XFile>[].obs;
  final sealCode = ''.obs;
  final checklistAnswers = <ChecklistAnswer>[].obs;
  // Evidence photos captured this session for the trip's sujeción materials,
  // keyed by TripAdditionalMaterial id — separate from `hasEvidence` (which
  // reflects what the backend already has from a previous attempt).
  final additionalMaterialPhotos = <int, List<XFile>>{}.obs;

  List<AdditionalMaterialItem> get additionalMaterials =>
      activeTrip?.additionalMaterials ?? const [];

  bool get needsAdditionalMaterialsStep => additionalMaterials.isNotEmpty;

  bool _materialHasEvidence(AdditionalMaterialItem material) =>
      material.hasEvidence ||
      (additionalMaterialPhotos[material.id]?.isNotEmpty ?? false);

  bool get additionalMaterialsCompleted =>
      additionalMaterials.every(_materialHasEvidence);

  int get additionalMaterialsDoneCount =>
      additionalMaterials.where(_materialHasEvidence).length;

  /// Questions come from the active trip (backend-driven, may vary per
  /// trip — e.g. an empty trip skips the seal question).
  List<ChecklistQuestion> get checklistQuestions =>
      activeTrip?.checklistQuestions ?? const [];

  /// True once every question the backend returned for this trip/stage has
  /// an answer. When the backend requires no checklist (or only the seal
  /// question), [checklistQuestions] already comes filtered accordingly —
  /// no separate "requires checklist" check needed here.
  bool get checklistCompleted =>
      checklistQuestions.isEmpty ||
      checklistAnswers.length == checklistQuestions.length;

  bool get needsChecklistStep => checklistQuestions.isNotEmpty;

  /// Whether the "cargar documentos" / "sello" steps should be shown for the
  /// trip's current stage — see TripRequirementResolverService on the backend.
  bool get requiresDocuments =>
      activeTrip?.requirements.requiresDocuments ?? true;

  bool get requiresSeal => activeTrip?.requirements.requiresSeal ?? true;

  bool get startFlowReady =>
      (!requiresDocuments || documentPhotos.isNotEmpty) &&
      (!requiresSeal || sealPhotos.isNotEmpty) &&
      checklistCompleted &&
      additionalMaterialsCompleted;

  bool get finishFlowReady => startFlowReady;

  /// Appends the captured seal code to the free-text notes sent to the
  /// backend — there's no dedicated field for it in the status-change
  /// request, so it travels alongside the operator's notes.
  String composeNotes(String notes) {
    if (sealCode.value.isEmpty) return notes;
    final sealLine = 'Sello: ${sealCode.value}';
    return notes.isEmpty ? sealLine : '$notes\n$sealLine';
  }

  /// Clears any leftover state from a previous start-trip attempt. Called
  /// each time the pre-start hub screen is freshly opened.
  void resetStartTripFlow() {
    documentPhotos.clear();
    sealPhotos.clear();
    sealCode.value = '';
    checklistAnswers.clear();
    additionalMaterialPhotos.clear();
    errorMessage.value = '';
  }

  /// Replaces the captured evidence photos for one sujeción material —
  /// called from [TripAdditionalMaterialsScreen] as the operator picks
  /// photos for each item.
  void setAdditionalMaterialPhotos(int materialId, List<XFile> photos) {
    additionalMaterialPhotos[materialId] = photos;
    additionalMaterialPhotos.refresh();
  }

  List<AdditionalMaterialEvidence> _buildAdditionalMaterialsEvidence() =>
      additionalMaterialPhotos.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => AdditionalMaterialEvidence(
              tripAdditionalMaterialId: e.key, photos: e.value))
          .toList();

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
      if (kDebugMode)
        debugPrint('[TRACKING] Usuario autenticado, consultando viaje activo');
      loadActiveTrip();
    }
  }

  // ── Load active trip ───────────────────────────────────────────────────

  Future<void> loadActiveTrip() async {
    final result = await _fetchActiveTrip();
    if (result == null) return;

    // A trip is trackable when the server confirms it (tracking_enabled),
    // regardless of whether it was started from this app or from the TMS.
    // The server is the sole source of truth here — it also keeps tracking
    // enabled past "finished" for a circuit's outbound leg while the return
    // leg is still pending, a state trip.requiresTracking can't express.
    final shouldTrack = result.hasActiveTrip && result.trackingEnabled;

    if (shouldTrack) {
      if (kDebugMode)
        debugPrint('[TRACKING] Viaje activo encontrado: ${result.trip!.id}');
      final started =
          await _trackingService.startTracking(tripId: result.trip!.id);
      _syncLocationController(started);
    } else if (_trackingService.isTracking) {
      // Backend is the source of truth: if it no longer reports an active
      // trackable trip but we're still tracking, stop.
      if (kDebugMode) debugPrint('[TRACKING] Viaje ya no está activo');
      await _trackingService.returnToIdle();
      _syncLocationController(_trackingService.isTracking);
    }
  }

  /// Re-fetches the trip's requirements (checklist/documents/seal) without
  /// touching GPS tracking — used by the start/finish hub screens so the
  /// operator always sees what's currently needed, without also risking a
  /// tracking start/stop call (a native platform call, not always instant)
  /// on every screen open.
  Future<void> refreshRequirements() => _fetchActiveTrip();

  Future<ActiveTripResponse?> _fetchActiveTrip() async {
    try {
      // Inside the try (not before it): if setting these Rx values ever
      // throws — e.g. "setState()/markNeedsBuild() called during build"
      // when this runs synchronously from a screen's initState() — the
      // finally below still runs and isLoading doesn't get stuck at true.
      isLoading.value = true;
      errorMessage.value = '';
      if (kDebugMode) debugPrint('[TRACKING] Consultando viaje activo');
      final result = await _tripService.getActiveTrip();
      _activeTripResponse.value = result;
      return result;
    } on DioException catch (e) {
      errorMessage.value = 'No se pudo cargar el viaje activo.';
      if (kDebugMode)
        debugPrint('[TripController] loadActiveTrip DioError: $e');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[TripController] loadActiveTrip error: $e');
      return null;
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
          // El backend interpreta esto como "aceptado" (el operador ya subió
          // evidencia/checklist/sello) — "en tránsito" ahora lo dispara el
          // GPS automáticamente, no esta pantalla. Ver TripDepartureDetectionService.
          status: 'accepted',
          latitude: position?.latitude ?? 0.0,
          longitude: position?.longitude ?? 0.0,
          notes: notes,
          evidenceFilePaths: evidenceFilePaths,
          sealPhotoPath: sealPhotos.isEmpty ? null : sealPhotos.first.path,
          sealCode: sealCode.value.isEmpty ? null : sealCode.value,
          checklistAnswers: checklistAnswers,
          additionalMaterialsEvidence: _buildAdditionalMaterialsEvidence(),
        ),
      );

      // Only start background tracking if the server confirms it.
      if (response.trackingEnabled) {
        final started = await _trackingService.startTracking(tripId: trip.id);
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
          sealPhotoPath: sealPhotos.isEmpty ? null : sealPhotos.first.path,
          sealCode: sealCode.value.isEmpty ? null : sealCode.value,
          checklistAnswers: checklistAnswers,
        ),
      );

      // Stop tracking only when the server requests it — it keeps tracking
      // enabled for a circuit's outbound leg until the return leg finishes.
      if (response.shouldStopTracking) {
        await _trackingService.returnToIdle();
        _syncLocationController(_trackingService.isTracking);
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

  // ── Optional estados de patio (reportado / rampa / cargando-descargando) ──
  //
  // A diferencia de startTrip()/finishTrip(), no tienen gating de
  // documentos/checklist/sello — son eventos ligeros de registro (foto
  // opcional + comentario). El mismo trío de estados se reutiliza tanto
  // antes de salir como después de arribar; cuál está disponible en cada
  // momento lo decide el backend (ver ActiveTripResponse.canReportToClient
  // y análogos).

  Future<bool> reportToClient({
    String? notes,
    List<String> evidenceFilePaths = const [],
  }) =>
      _changeOptionalStatus('reported_to_client',
          notes: notes, evidenceFilePaths: evidenceFilePaths);

  Future<bool> markRampAssigned({
    String? notes,
    List<String> evidenceFilePaths = const [],
  }) =>
      _changeOptionalStatus('ramp_assigned',
          notes: notes, evidenceFilePaths: evidenceFilePaths);

  Future<bool> markLoadingUnloading({
    String? notes,
    List<String> evidenceFilePaths = const [],
  }) =>
      _changeOptionalStatus('loading_unloading',
          notes: notes, evidenceFilePaths: evidenceFilePaths);

  Future<bool> _changeOptionalStatus(
    String status, {
    String? notes,
    List<String> evidenceFilePaths = const [],
  }) async {
    final trip = activeTrip;
    if (trip == null) return false;

    isChangingStatus.value = true;
    errorMessage.value = '';
    try {
      final position = await _getCurrentPosition();
      await _tripService.changeStatus(
        trip.id,
        TripStatusRequest(
          status: status,
          latitude: position?.latitude ?? 0.0,
          longitude: position?.longitude ?? 0.0,
          notes: notes,
          evidenceFilePaths: evidenceFilePaths,
        ),
      );

      // Refresca el viaje activo para que la pantalla de progreso muestre
      // de inmediato cuál es el siguiente paso disponible.
      await loadActiveTrip();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _parseError(e);
      return false;
    } catch (e) {
      errorMessage.value = 'Error al actualizar el estado del viaje.';
      if (kDebugMode) {
        debugPrint('[TripController] _changeOptionalStatus error: $e');
      }
      return false;
    } finally {
      isChangingStatus.value = false;
    }
  }

  // ── Navigation helpers ─────────────────────────────────────────────────

  void goToStartTrip() => Get.toNamed(RouteNames.startTrip);

  /// Ventana pre-tránsito (accepted o uno de los 3 opcionales antes de
  /// arribar): no hay concepto de "finalizar" todavía, así que a diferencia
  /// de [goToChangeStatus] no necesita consultar canFinishTrip — solo abre
  /// la pantalla de progreso.
  void goToTripProgress() => Get.toNamed(RouteNames.changeStatus);

  /// Checks with the backend whether the trip can be finalized before
  /// opening the finish-trip screen. A trip "en tránsito" can't skip
  /// straight to finishing — it must reach "arrived" first — so this
  /// redirects to the trip's history instead when it's not allowed yet.
  Future<void> goToChangeStatus() async {
    final trip = activeTrip;
    if (trip == null) return;

    try {
      final result = await _tripService.canFinishTrip(trip.id);

      if (result.canFinish) {
        Get.toNamed(RouteNames.changeStatus);
        return;
      }

     
      Get.toNamed(RouteNames.tripEventHistory, arguments: trip.id);
    } on DioException catch (e) {
      errorMessage.value = _parseError(e);
    } catch (e) {
      errorMessage.value = 'No se pudo verificar si el viaje puede finalizarse.';
      if (kDebugMode) {
        debugPrint('[TripController] goToChangeStatus error: $e');
      }
    }
  }

  // ── Evidencias en el servidor (misma carga que el link web) ──────────────
  //
  // Los archivos, el código de sello y las respuestas del checklist se suben
  // al instante y viven en el servidor; iniciar/finalizar solo confirma el
  // paso cuando el backend dice que ya no falta nada (evidence.gap == null).

  final evidence = Rxn<TripEvidenceState>();
  final isEvidenceBusy = false.obs;
  final evidenceError = ''.obs;

  /// Para iniciar: lo que pide el backend + las fotos del material de
  /// sujeción (que siguen su propio flujo).
  bool get evidenceStartReady =>
      (evidence.value?.ready ?? false) && additionalMaterialsCompleted;

  bool get evidenceFinishReady => evidence.value?.ready ?? false;

  Future<void> loadEvidence() async {
    final trip = activeTrip;
    if (trip == null) return;
    try {
      evidence.value = await _tripService.getEvidence(trip.id);
      evidenceError.value = '';
    } on DioException catch (e) {
      evidenceError.value = _parseError(e);
    } catch (_) {
      evidenceError.value = 'No se pudo cargar la evidencia del viaje.';
    }
  }

  Future<bool> _evidenceAction(
      Future<TripEvidenceState> Function(int tripId) action) async {
    final trip = activeTrip;
    if (trip == null || isEvidenceBusy.value) return false;

    isEvidenceBusy.value = true;
    evidenceError.value = '';
    try {
      evidence.value = await action(trip.id);
      return true;
    } on DioException catch (e) {
      evidenceError.value = _parseError(e);
      return false;
    } catch (e) {
      evidenceError.value = 'No se pudo completar la acción.';
      if (kDebugMode) debugPrint('[TripController] evidence error: $e');
      return false;
    } finally {
      isEvidenceBusy.value = false;
    }
  }

  Future<bool> uploadEvidence(String kind, List<String> paths) =>
      _evidenceAction((id) => _tripService.uploadEvidence(id, kind, paths));

  Future<bool> deleteEvidence(String uuid) =>
      _evidenceAction((id) => _tripService.deleteEvidence(id, uuid));

  Future<bool> saveSealCode(String code) =>
      _evidenceAction((id) => _tripService.saveSealCode(id, code));

  Future<bool> saveChecklistAnswer(
          String questionId, String answer, String? detail) =>
      _evidenceAction((id) =>
          _tripService.saveChecklistAnswer(id, questionId, answer, detail));

  /// Confirma el inicio del viaje con la evidencia que ya está en el
  /// servidor. Mismo manejo de tracking que [startTrip].
  Future<bool> startTripWithEvidence({String? notes}) async {
    final trip = activeTrip;
    if (trip == null) return false;

    isChangingStatus.value = true;
    errorMessage.value = '';
    try {
      final position = await _getCurrentPosition();
      final response = await _tripService.completeStage(
        trip.id,
        'start',
        notes: notes,
        latitude: position?.latitude,
        longitude: position?.longitude,
        additionalMaterials: _buildAdditionalMaterialsEvidence(),
      );

      if (response.trackingEnabled) {
        final started = await _trackingService.startTracking(tripId: trip.id);
        _syncLocationController(started);
      }

      await loadActiveTrip();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _parseError(e);
      return false;
    } catch (e) {
      errorMessage.value = 'Error al iniciar el viaje.';
      if (kDebugMode) debugPrint('[TripController] startTripWithEvidence: $e');
      return false;
    } finally {
      isChangingStatus.value = false;
    }
  }

  /// Finaliza el viaje con la evidencia que ya está en el servidor. Mismo
  /// manejo de tracking que [finishTrip].
  Future<bool> finishTripWithEvidence({String? notes}) async {
    final trip = activeTrip;
    if (trip == null) return false;

    isChangingStatus.value = true;
    errorMessage.value = '';
    try {
      final position = await _getCurrentPosition();
      final response = await _tripService.completeStage(
        trip.id,
        'finish',
        notes: notes,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (response.shouldStopTracking) {
        await _trackingService.returnToIdle();
        _syncLocationController(_trackingService.isTracking);
      }

      await loadActiveTrip();
      return true;
    } on DioException catch (e) {
      errorMessage.value = _parseError(e);
      return false;
    } catch (e) {
      errorMessage.value = 'Error al finalizar el viaje.';
      if (kDebugMode) debugPrint('[TripController] finishTripWithEvidence: $e');
      return false;
    } finally {
      isChangingStatus.value = false;
    }
  }

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
      // Sin timeLimit, getCurrentPosition() puede quedarse esperando
      // indefinidamente un fix de alta precisión (típico con GPS "frío",
      // p.ej. justo después de navegar rápido a esta pantalla) — eso
      // dejaba el loader de iniciar/finalizar viaje pegado para siempre.
      // Al expirar el límite se lanza un TimeoutException, que el catch
      // de abajo convierte en "seguir sin posición" (position = null).
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
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
