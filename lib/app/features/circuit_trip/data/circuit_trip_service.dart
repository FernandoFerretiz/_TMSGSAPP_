import '../../../core/network/api_client.dart';
import '../models/circuit_trip_models.dart';

class CircuitTripSubmitResult {
  final int? outboundTripId;
  final int? returnTripId;
  final List<int> intermediateTripIds;

  const CircuitTripSubmitResult({
    this.outboundTripId,
    this.returnTripId,
    this.intermediateTripIds = const [],
  });

  factory CircuitTripSubmitResult.fromJson(Map<String, dynamic> json) => CircuitTripSubmitResult(
        outboundTripId: json['outbound_trip_id'] as int?,
        returnTripId: json['return_trip_id'] as int?,
        intermediateTripIds:
            (json['intermediate_trip_ids'] as List? ?? []).map((e) => (e as num).toInt()).toList(),
      );
}

class MissingTruckbox {
  final String number;
  final String? owner; // 'client' | 'transporter' | null

  const MissingTruckbox({required this.number, this.owner});

  factory MissingTruckbox.fromJson(Map<String, dynamic> json) => MissingTruckbox(
        number: (json['number'] ?? '').toString(),
        owner: json['owner']?.toString(),
      );
}

/// Consume /api/mobile/circuit-trips/* — ver MobileCircuitTripController y
/// CircuitTripFormService en el backend, que replican paso a paso el flujo
/// de alta de circuito del chatbot.
class CircuitTripService {
  final ApiClient _apiClient;

  CircuitTripService(this._apiClient);

  Future<List<CircuitOption>> getClients() async {
    final response = await _apiClient.dio.get('/api/mobile/circuit-trips/clients');
    final data = (response.data['data'] as List? ?? []);
    return data.map((e) => CircuitOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ClientCircuitOption>> getCircuits(int clientId) async {
    final response = await _apiClient.dio.get(
      '/api/mobile/circuit-trips/circuits',
      queryParameters: {'client_id': clientId},
    );
    final data = (response.data['data'] as List? ?? []);
    return data.map((e) => ClientCircuitOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CircuitOperatorOption>> getOperators({
    required int clientId,
    required int clientCircuitId,
  }) async {
    final response = await _apiClient.dio.get(
      '/api/mobile/circuit-trips/operators',
      queryParameters: {'client_id': clientId, 'client_circuit_id': clientCircuitId},
    );
    final data = (response.data['data'] as List? ?? []);
    return data.map((e) => CircuitOperatorOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<OperatorLegResolution> resolveOperator({
    required int clientId,
    required int clientCircuitId,
    required int operatorId,
    bool confirmWithoutTracking = false,
  }) async {
    final response = await _apiClient.dio.get(
      '/api/mobile/circuit-trips/resolve-operator',
      queryParameters: {
        'client_id': clientId,
        'client_circuit_id': clientCircuitId,
        'operator_id': operatorId,
        if (confirmWithoutTracking) 'confirm_without_tracking': 1,
      },
    );
    return OperatorLegResolution.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<List<AddressOption>> getDestinationOptions({
    required int clientCircuitId,
    required int originId,
  }) async {
    final response = await _apiClient.dio.get(
      '/api/mobile/circuit-trips/destination-options',
      queryParameters: {'client_circuit_id': clientCircuitId, 'origin_id': originId},
    );
    final data = (response.data['data'] as List? ?? []);
    return data.map((e) => AddressOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AdditionalMaterialOption>> getAdditionalMaterials() async {
    final response = await _apiClient.dio.get('/api/mobile/circuit-trips/additional-materials');
    final data = (response.data['data'] as List? ?? []);
    return data.map((e) => AdditionalMaterialOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> getReturnOriginRouteType({
    required int clientId,
    required int clientCircuitId,
    required int originId,
  }) async {
    final response = await _apiClient.dio.get(
      '/api/mobile/circuit-trips/return-origin-route-type',
      queryParameters: {
        'client_id': clientId,
        'client_circuit_id': clientCircuitId,
        'origin_id': originId,
      },
    );
    return (response.data['data']['route_type_id'] as num).toInt();
  }

  /// Cajas (de las indicadas) que aún no están registradas.
  Future<List<MissingTruckbox>> checkTruckboxes({
    required int clientId,
    required int transporterId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _apiClient.dio.post(
      '/api/mobile/truckboxes/check',
      data: {'client_id': clientId, 'transporter_id': transporterId, 'items': items},
    );
    return (response.data['missing'] as List? ?? [])
        .map((e) => MissingTruckbox.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Registra una caja con sus datos (placas, NIV, año, marca: todos obligatorios).
  Future<void> registerTruckbox(Map<String, dynamic> payload) async {
    await _apiClient.dio.post('/api/mobile/truckboxes', data: payload);
  }

  Future<CircuitTripSubmitResult> submit(Map<String, dynamic> payload) async {
    final response = await _apiClient.dio.post(
      '/api/mobile/circuit-trips',
      data: payload,
    );
    return CircuitTripSubmitResult.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  /// Datos de un viaje de circuito ya existente para precargar el
  /// formulario en modo edición.
  Future<TripEditData> getForEdit(int tripId) async {
    final response = await _apiClient.dio.get('/api/mobile/circuit-trips/$tripId');
    return TripEditData.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Elimina un movimiento intermedio o el fin; el siguiente pasa a salir del
  /// destino del anterior (ver CircuitTripFormService::removeMovement).
  Future<void> removeMovement(int tripId) async {
    await _apiClient.dio.delete('/api/mobile/circuit-trips/$tripId/movement');
  }

  Future<void> update(int tripId, Map<String, dynamic> payload) async {
    await _apiClient.dio.put('/api/mobile/circuit-trips/$tripId', data: payload);
  }
}
