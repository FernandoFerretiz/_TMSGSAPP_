import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../data/trip_history_service.dart';
import '../models/trip_event.dart';
import '../models/trip_evidence_file.dart';
import '../models/trip_filter_option.dart';
import '../models/trip_summary.dart';

class TripHistoryController extends GetxController {
  final TripHistoryService _service;

  TripHistoryController(this._service);

  // ── Lista de viajes ──────────────────────────────────────────────────
  final trips = <TripSummary>[].obs;
  final isLoadingTrips = false.obs;
  final isLoadingMore = false.obs;
  final tripsErrorMessage = ''.obs;

  int _page = 1;
  bool _hasMore = true;

  // ── Filtros (transportista, operador, fecha de finalización) ──────────
  final filters = const TripHistoryFilters().obs;
  final filterOptions = const TripFilterOptions().obs;
  final isLoadingFilterOptions = false.obs;

  Future<void> loadFilterOptions() async {
    if (filterOptions.value.transporters.isNotEmpty ||
        filterOptions.value.operators.isNotEmpty) {
      return;
    }
    isLoadingFilterOptions.value = true;
    try {
      filterOptions.value = await _service.getFilterOptions();
    } catch (_) {
      // Los selects quedan vacíos; el usuario puede reabrir el panel de
      // filtros para reintentar.
    } finally {
      isLoadingFilterOptions.value = false;
    }
  }

  Future<void> applyFilters(TripHistoryFilters newFilters) async {
    filters.value = newFilters;
    await loadTrips();
  }

  Future<void> clearFilters() async {
    if (filters.value.isEmpty) return;
    filters.value = const TripHistoryFilters();
    await loadTrips();
  }

  Future<void> loadTrips() async {
    isLoadingTrips.value = true;
    tripsErrorMessage.value = '';
    _page = 1;
    _hasMore = true;
    try {
      final result = await _service.getTrips(page: _page, filters: filters.value);
      trips.value = result.trips;
      _hasMore = result.hasMore;
    } catch (_) {
      tripsErrorMessage.value = 'No se pudo cargar la lista de viajes.';
    } finally {
      isLoadingTrips.value = false;
    }
  }

  Future<void> loadMoreTrips() async {
    if (!_hasMore || isLoadingMore.value || isLoadingTrips.value) return;

    isLoadingMore.value = true;
    try {
      final result = await _service.getTrips(
        page: _page + 1,
        filters: filters.value,
      );
      _page += 1;
      _hasMore = result.hasMore;
      trips.addAll(result.trips);
    } catch (_) {
      // Deja la lista actual visible; el usuario puede intentar scrollear de nuevo.
    } finally {
      isLoadingMore.value = false;
    }
  }

  // ── Últimos eventos (feed cross-viaje) ────────────────────────────────
  final recentEvents = <TripEvent>[].obs;
  final isLoadingRecentEvents = false.obs;
  final recentEventsErrorMessage = ''.obs;

  Future<void> loadRecentEvents() async {
    isLoadingRecentEvents.value = true;
    recentEventsErrorMessage.value = '';
    try {
      recentEvents.value = await _service.getRecentEvents();
    } catch (_) {
      recentEventsErrorMessage.value = 'No se pudieron cargar los eventos.';
    } finally {
      isLoadingRecentEvents.value = false;
    }
  }

  // ── Historial de un viaje ────────────────────────────────────────────
  final Rxn<TripSummary> tripHeader = Rxn<TripSummary>();
  final events = <TripEvent>[].obs;
  final documents = <TripEvidenceFile>[].obs;
  final isLoadingHistory = false.obs;
  final historyErrorMessage = ''.obs;

  Future<void> loadHistory(int tripId) async {
    isLoadingHistory.value = true;
    historyErrorMessage.value = '';
    try {
      final detail = await _service.getHistory(tripId);
      tripHeader.value = detail.trip;
      events.value = detail.events;
      documents.value = detail.documents;
    } catch (_) {
      historyErrorMessage.value = 'No se pudo cargar el historial del viaje.';
    } finally {
      isLoadingHistory.value = false;
    }
  }

  // ── Cambio manual de estatus (admin/monitorista) ─────────────────────
  Future<TripStatusCatalog> loadStatusCatalog(int tripId) =>
      _service.getStatusCatalog(tripId);

  /// Devuelve null si salió bien, o el mensaje de error.
  Future<String?> changeStatus(int tripId, int statusId, String? comments) async {
    try {
      await _service.overrideStatus(tripId, statusId, comments);
      await loadHistory(tripId);
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
      return 'No se pudo cambiar el estatus.';
    } catch (_) {
      return 'No se pudo cambiar el estatus.';
    }
  }

  // ── Cambio de operador del viaje (quien tenga el permiso en el ERP) ──────
  Future<TripOperatorCatalog> loadOperatorOptions(int tripId) =>
      _service.getOperatorOptions(tripId);

  /// Devuelve null si salió bien, o el mensaje de error.
  Future<String?> changeOperator(int tripId, int operatorId,
      {bool confirmWithoutTracking = false}) async {
    try {
      await _service.changeOperator(tripId, operatorId,
          confirmWithoutTracking: confirmWithoutTracking);
      await loadHistory(tripId);
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
        if (data['message'] != null) return data['message'].toString();
      }
      return 'No se pudo cambiar el operador.';
    } catch (_) {
      return 'No se pudo cambiar el operador.';
    }
  }
}
