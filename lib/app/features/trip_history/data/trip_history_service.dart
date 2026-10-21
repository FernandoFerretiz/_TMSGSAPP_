import '../../../core/network/api_client.dart';
import '../models/trip_event.dart';
import '../models/trip_evidence_file.dart';
import '../models/trip_filter_option.dart';
import '../models/trip_summary.dart';

class TripPage {
  final List<TripSummary> trips;
  final int currentPage;
  final int lastPage;

  const TripPage({
    required this.trips,
    required this.currentPage,
    required this.lastPage,
  });

  bool get hasMore => currentPage < lastPage;
}

class TripHistoryDetail {
  final TripSummary trip;
  final List<TripEvent> events;
  final List<TripEvidenceFile> documents;

  const TripHistoryDetail({
    required this.trip,
    required this.events,
    this.documents = const [],
  });
}

class TripStatusOption {
  final int id;
  final String code;
  final String name;

  const TripStatusOption({required this.id, required this.code, required this.name});

  factory TripStatusOption.fromJson(Map<String, dynamic> json) => TripStatusOption(
        id: int.parse(json['id'].toString()),
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
      );
}

class TripStatusCatalog {
  final int? currentStatusId;
  final List<TripStatusOption> statuses;

  const TripStatusCatalog({this.currentStatusId, required this.statuses});
}

class TripOperatorOption {
  final int id;
  final String name;
  final bool trackingActive;

  const TripOperatorOption(
      {required this.id, required this.name, required this.trackingActive});

  factory TripOperatorOption.fromJson(Map<String, dynamic> json) =>
      TripOperatorOption(
        id: int.parse(json['id'].toString()),
        name: (json['name'] ?? '').toString(),
        trackingActive: json['tracking_active'] == true,
      );
}

class TripOperatorCatalog {
  final int? currentOperatorId;
  final List<TripOperatorOption> operators;

  const TripOperatorCatalog({this.currentOperatorId, required this.operators});
}

class TripHistoryService {
  final ApiClient _apiClient;

  TripHistoryService(this._apiClient);

  Future<TripPage> getTrips({
    int page = 1,
    TripHistoryFilters filters = const TripHistoryFilters(),
  }) async {
    final response = await _apiClient.dio.get(
      '/api/mobile/trips',
      queryParameters: {'page': page, ...filters.toQueryParameters()},
    );
    final body = response.data as Map<String, dynamic>;
    final data = (body['data'] as List? ?? []);
    final meta = (body['meta'] as Map<String, dynamic>?) ?? const {};

    return TripPage(
      trips: data
          .map((e) => TripSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: (meta['current_page'] as int?) ?? page,
      lastPage: (meta['last_page'] as int?) ?? page,
    );
  }

  Future<TripFilterOptions> getFilterOptions() async {
    final response = await _apiClient.dio.get('/api/mobile/trips/filters');
    final body = response.data as Map<String, dynamic>;
    return TripFilterOptions.fromJson(body['data'] as Map<String, dynamic>);
  }

  // Feed de "Últimos eventos": cambios de estado, incidencias y detenciones
  // across todos los viajes visibles para el usuario (mismo scope que
  // getTrips), aunque no le haya llegado el push (p.ej. si no estaba en
  // turno) — ver GET /mobile/events.
  Future<List<TripEvent>> getRecentEvents({int limit = 50}) async {
    final response = await _apiClient.dio.get(
      '/api/mobile/events',
      queryParameters: {'limit': limit},
    );
    final body = response.data as Map<String, dynamic>;
    final data = (body['data'] as List? ?? []);

    return data
        .map((e) => TripEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TripHistoryDetail> getHistory(int tripId) async {
    final response =
        await _apiClient.dio.get('/api/mobile/trips/$tripId/history');
    final body = response.data as Map<String, dynamic>;
    final events = (body['events'] as List? ?? []);
    final documents = (body['documents'] as List? ?? []);

    return TripHistoryDetail(
      trip: TripSummary.fromJson(body['trip'] as Map<String, dynamic>),
      events: events
          .map((e) => TripEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      documents: documents
          .map((e) => TripEvidenceFile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<TripStatusCatalog> getStatusCatalog(int tripId) async {
    final response = await _apiClient.dio.get('/api/mobile/trips/$tripId/statuses');
    final data = response.data['data'] as Map<String, dynamic>;
    return TripStatusCatalog(
      currentStatusId: int.tryParse(data['current_status_id']?.toString() ?? ''),
      statuses: (data['statuses'] as List? ?? [])
          .map((e) => TripStatusOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> overrideStatus(int tripId, int statusId, String? comments) async {
    await _apiClient.dio.post(
      '/api/mobile/trips/$tripId/status-override',
      data: {'status_id': statusId, if (comments != null) 'comments': comments},
    );
  }

  Future<TripOperatorCatalog> getOperatorOptions(int tripId) async {
    final response =
        await _apiClient.dio.get('/api/mobile/trips/$tripId/operators');
    final data = response.data['data'] as Map<String, dynamic>;
    return TripOperatorCatalog(
      currentOperatorId:
          int.tryParse(data['current_operator_id']?.toString() ?? ''),
      operators: (data['operators'] as List? ?? [])
          .map((e) => TripOperatorOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> changeOperator(int tripId, int operatorId,
      {bool confirmWithoutTracking = false}) async {
    await _apiClient.dio.post(
      '/api/mobile/trips/$tripId/operator',
      data: {
        'operator_id': operatorId,
        if (confirmWithoutTracking) 'confirm_without_tracking': true,
      },
    );
  }
}
