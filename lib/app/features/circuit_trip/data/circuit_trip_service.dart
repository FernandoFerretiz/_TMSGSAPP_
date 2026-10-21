import '../../../core/network/api_client.dart';
import '../models/circuit_trip_models.dart';

class CircuitTripSubmitResult {
  final int? outboundTripId;
  final int? returnTripId;

  const CircuitTripSubmitResult({this.outboundTripId, this.returnTripId});

  factory CircuitTripSubmitResult.fromJson(Map<String, dynamic> json) =>
      CircuitTripSubmitResult(
        outboundTripId: json['outbound_trip_id'] as int?,
        returnTripId: json['return_trip_id'] as int?,
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
    return data
        .map((e) => ClientCircuitOption.fromJson(e as Map<String, dynamic>))
        .toList();
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
    return data
        .map((e) => CircuitOperatorOption.fromJson(e as Map<String, dynamic>))
        .toList();
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
    final response =
        await _apiClient.dio.get('/api/mobile/circuit-trips/additional-materials');
    final data = (response.data['data'] as List? ?? []);
    return data
        .map((e) => AdditionalMaterialOption.fromJson(e as Map<String, dynamic>))
        .toList();
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

  Future<void> update(int tripId, Map<String, dynamic> payload) async {
    await _apiClient.dio.put('/api/mobile/circuit-trips/$tripId', data: payload);
  }
}
