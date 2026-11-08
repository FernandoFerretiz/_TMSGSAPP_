import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import '../models/trip_log_option.dart';

class TripLogService {
  final ApiClient _apiClient;

  TripLogService(this._apiClient);

  Future<List<TripLogOption>> getOptions() async {
    final response = await _apiClient.dio.get('/api/mobile/trip-log/options');
    final data = (response.data as Map<String, dynamic>)['data'] as List? ?? [];
    return data
        .map((e) => TripLogOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> registerStatus({
    required int tripId,
    required TripLogOption option,
    String? comment,
    double? latitude,
    double? longitude,
    List<XFile> photos = const [],
  }) async {
    final formData = FormData.fromMap({
      if (option.isOther) 'other': '1' else 'option_id': option.id.toString(),
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
      // Sin corchetes manuales: ListFormat.multiCompatible ya agrega "[]"
      // (mismo patrón que IncidentService.reportIncident).
      if (photos.isNotEmpty)
        'photos': await Future.wait(
          photos.map((f) => MultipartFile.fromFile(f.path)),
        ),
    }, ListFormat.multiCompatible);

    await _apiClient.dio.post(
      '/api/mobile/trips/$tripId/log',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }
}
