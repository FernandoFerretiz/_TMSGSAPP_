import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import '../models/active_trip_response.dart';
import '../models/can_finish_response.dart';
import '../models/checklist_answer.dart';
import '../models/trip_evidence_state.dart';
import '../models/trip_status_request.dart';
import '../models/trip_status_response.dart';

class TripService {
  final ApiClient _apiClient;

  TripService(this._apiClient);

  Future<ActiveTripResponse> getActiveTrip() async {
    final response = await _apiClient.dio.get('/api/mobile/active-trip');
    return ActiveTripResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  /// Whether the trip is currently allowed to move to "finished" (only once
  /// it reached "arrived") — checked before opening the finish-trip screen.
  Future<CanFinishResponse> canFinishTrip(int tripId) async {
    final response =
        await _apiClient.dio.get('/api/mobile/trips/$tripId/can-finish');
    return CanFinishResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Changes the trip status (started, finished, etc.) and returns the full
  /// API response, including [TripStatusResponse.trackingEnabled] and
  /// [TripStatusResponse.shouldStopTracking].
  Future<TripStatusResponse> changeStatus(
      int tripId, TripStatusRequest request) async {
    final Response response;

    final hasFiles = request.evidenceFilePaths.isNotEmpty ||
        request.sealPhotoPath != null ||
        request.checklistAnswers.isNotEmpty ||
        request.additionalMaterialsEvidence.isNotEmpty;

    if (!hasFiles) {
      response = await _apiClient.dio.post(
        '/api/mobile/trips/$tripId/status',
        data: {
          'status': request.status,
          'latitude': request.latitude,
          'longitude': request.longitude,
          if (request.notes != null && request.notes!.isNotEmpty)
            'notes': request.notes,
          if (request.sealCode != null && request.sealCode!.isNotEmpty)
            'seal_code': request.sealCode,
        },
      );
    } else {
      final checklist = await Future.wait(request.checklistAnswers.map(
        (a) async => {
          'question_id': a.questionId,
          'prompt': a.prompt,
          'answer': a.answer,
          if (a.detail != null && a.detail!.isNotEmpty) 'detail': a.detail,
          if (a.photos.isNotEmpty)
            'photos': await Future.wait(
              a.photos.map((f) => MultipartFile.fromFile(f.path)),
            ),
        },
      ));

      final additionalMaterials =
          await Future.wait(request.additionalMaterialsEvidence.map(
        (m) async => {
          'trip_additional_material_id': m.tripAdditionalMaterialId,
          if (m.photos.isNotEmpty)
            'photos': await Future.wait(
              m.photos.map((f) => MultipartFile.fromFile(f.path)),
            ),
        },
      ));

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
        if (request.sealPhotoPath != null)
          'seal_photo': await MultipartFile.fromFile(request.sealPhotoPath!),
        if (request.sealCode != null && request.sealCode!.isNotEmpty)
          'seal_code': request.sealCode,
        if (checklist.isNotEmpty) 'checklist': checklist,
        if (additionalMaterials.isNotEmpty)
          'additional_materials': additionalMaterials,
        // Laravel/PHP solo arma el arreglo si la key trae "[]"; el
        // ListFormat.multi por default de Dio la repite sin corchetes y el
        // backend solo recibe el último archivo (no un arreglo).
      }, ListFormat.multiCompatible);

      response = await _apiClient.dio.post(
        '/api/mobile/trips/$tripId/status',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
    }

    return TripStatusResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Evidencias del viaje (misma carga que el link web) ─────────────────

  TripEvidenceState _evidenceFrom(Response response) => TripEvidenceState.fromJson(
      (response.data as Map<String, dynamic>)['state'] as Map<String, dynamic>);

  Future<TripEvidenceState> getEvidence(int tripId) async {
    final response =
        await _apiClient.dio.get('/api/mobile/trips/$tripId/evidence');
    return _evidenceFrom(response);
  }

  /// Sube archivos al instante; devuelve el estado actualizado.
  Future<TripEvidenceState> uploadEvidence(
      int tripId, String kind, List<String> paths) async {
    final formData = FormData.fromMap({
      'kind': kind,
      'files': await Future.wait(paths.map((p) => MultipartFile.fromFile(p))),
    }, ListFormat.multiCompatible);

    final response = await _apiClient.dio.post(
      '/api/mobile/trips/$tripId/evidence/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return _evidenceFrom(response);
  }

  Future<TripEvidenceState> deleteEvidence(int tripId, String uuid) async {
    final response = await _apiClient.dio
        .delete('/api/mobile/trips/$tripId/evidence/files/$uuid');
    return _evidenceFrom(response);
  }

  Future<TripEvidenceState> saveSealCode(int tripId, String code) async {
    final response = await _apiClient.dio.post(
        '/api/mobile/trips/$tripId/evidence/seal',
        data: {'code': code});
    return _evidenceFrom(response);
  }

  Future<TripEvidenceState> saveChecklistAnswer(
      int tripId, String questionId, String answer, String? detail) async {
    final response = await _apiClient.dio
        .post('/api/mobile/trips/$tripId/evidence/checklist', data: {
      'question_id': int.parse(questionId),
      'answer': answer,
      if (detail != null && detail.isNotEmpty) 'detail': detail,
    });
    return _evidenceFrom(response);
  }

  /// Inicia ("start") o finaliza ("finish") el viaje con la evidencia que ya
  /// está en el servidor. Las fotos de material de sujeción siguen viajando
  /// con la petición, igual que antes.
  Future<TripStatusResponse> completeStage(
    int tripId,
    String stage, {
    String? notes,
    double? latitude,
    double? longitude,
    List<AdditionalMaterialEvidence> additionalMaterials = const [],
  }) async {
    final materials = await Future.wait(additionalMaterials.map(
      (m) async => {
        'trip_additional_material_id': m.tripAdditionalMaterialId,
        if (m.photos.isNotEmpty)
          'photos': await Future.wait(
            m.photos.map((XFile f) => MultipartFile.fromFile(f.path)),
          ),
      },
    ));

    final formData = FormData.fromMap({
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (materials.isNotEmpty) 'additional_materials': materials,
    }, ListFormat.multiCompatible);

    final response = await _apiClient.dio.post(
      '/api/mobile/trips/$tripId/evidence/$stage',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return TripStatusResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
