import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/active_trip_response.dart';
import '../models/location_update.dart';
import '../models/trip_status_request.dart';

class TripService {
  final ApiClient _apiClient;

  TripService(this._apiClient);

  Future<ActiveTripResponse> getActiveTrip() async {
    final response = await _apiClient.dio.get('/api/mobile/active-trip');
    return ActiveTripResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  /// Changes the trip status (started, finished, etc.).
  /// Evidence files are sent as multipart/form-data when present.
  Future<void> changeStatus(int tripId, TripStatusRequest request) async {
    if (request.evidenceFilePaths.isEmpty) {
      await _apiClient.dio.post(
        '/api/mobile/trips/$tripId/status',
        data: {
          'status': request.status,
          'latitude': request.latitude,
          'longitude': request.longitude,
          if (request.notes != null && request.notes!.isNotEmpty)
            'notes': request.notes,
        },
      );
    } else {
      final formData = FormData.fromMap({
        'status': request.status,
        'latitude': request.latitude.toString(),
        'longitude': request.longitude.toString(),
        if (request.notes != null && request.notes!.isNotEmpty)
          'notes': request.notes,
        'evidence_files': await Future.wait(
          request.evidenceFilePaths
              .map((path) => MultipartFile.fromFile(path)),
        ),
      });

      await _apiClient.dio.post(
        '/api/mobile/trips/$tripId/status',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
    }
  }

  /// Sends a single location update to the server.
  Future<void> sendLocation(int tripId, LocationUpdate update) async {
    await _apiClient.dio.post(
      '/api/mobile/trips/$tripId/locations',
      data: update.toJson(),
    );
  }
}
