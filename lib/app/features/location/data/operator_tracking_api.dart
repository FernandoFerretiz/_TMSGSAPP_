import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

/// Server-side state of the operator's manual tracking.
class OperatorTrackingState {
  final bool active;
  final bool canStop;

  const OperatorTrackingState({required this.active, required this.canStop});

  factory OperatorTrackingState.fromJson(Map<String, dynamic> json) =>
      OperatorTrackingState(
        active: json['tracking_active'] == true,
        canStop: json['can_stop'] != false,
      );
}

/// Consumes /api/mobile/tracking/* (MobileOperatorTrackingController).
class OperatorTrackingApi {
  final ApiClient _apiClient;

  OperatorTrackingApi(this._apiClient);

  Future<OperatorTrackingState> status() => _call('get', '/api/mobile/tracking');

  Future<OperatorTrackingState> start() =>
      _call('post', '/api/mobile/tracking/start');

  /// Throws a [DioException] (422) when the operator still has an open trip.
  Future<OperatorTrackingState> stop() =>
      _call('post', '/api/mobile/tracking/stop');

  Future<OperatorTrackingState> _call(String method, String path) async {
    final Response response = method == 'get'
        ? await _apiClient.dio.get(path)
        : await _apiClient.dio.post(path);
    return OperatorTrackingState.fromJson(response.data as Map<String, dynamic>);
  }
}
