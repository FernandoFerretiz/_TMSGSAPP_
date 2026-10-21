import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import '../models/incident_type.dart';

class IncidentService {
  final ApiClient _apiClient;

  IncidentService(this._apiClient);

  Future<List<IncidentCategory>> getCatalog() async {
    final response = await _apiClient.dio.get('/api/mobile/incident-catalog');
    final data = (response.data as Map<String, dynamic>)['data'] as List? ?? [];
    return data
        .map((e) => IncidentCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> reportIncident({
    required int tripId,
    required int incidentTypeId,
    String? description,
    bool? canContinueTrip,
    Map<String, String> extraData = const {},
    double? latitude,
    double? longitude,
    double? accuracy,
    List<XFile> photos = const [],
  }) async {
    final formData = FormData.fromMap({
      'incident_type_id': incidentTypeId.toString(),
      if (description != null && description.isNotEmpty)
        'description': description,
      if (canContinueTrip != null) 'can_continue_trip': canContinueTrip ? '1' : '0',
      for (final entry in extraData.entries)
        if (entry.value.isNotEmpty) 'extra_data[${entry.key}]': entry.value,
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
      if (accuracy != null) 'accuracy': accuracy.toString(),
      if (photos.isNotEmpty)
        // Sin corchetes manuales: ListFormat.multiCompatible ya le agrega
        // "[]" a cada item de la lista (photos[]=...). Ponerlo también acá
        // duplicaba el corchete (photos[][]=...) y Laravel terminaba
        // recibiendo "photos.0" como un array anidado en vez de un archivo
        // — mismo patrón que TripService.changeStatus con "evidence_files".
        'photos': await Future.wait(
          photos.map((f) => MultipartFile.fromFile(f.path)),
        ),
    }, ListFormat.multiCompatible);

    await _apiClient.dio.post(
      '/api/mobile/trips/$tripId/incidents',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }
}
