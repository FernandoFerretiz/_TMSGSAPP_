import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../data/incident_service.dart';
import '../models/incident_type.dart';

class IncidentController extends GetxController {
  final IncidentService _service;

  IncidentController(this._service);

  final isLoadingCatalog = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  final categories = <IncidentCategory>[].obs;

  final Rxn<IncidentCategory> selectedCategory = Rxn<IncidentCategory>();
  final Rxn<IncidentType> selectedType = Rxn<IncidentType>();
  final Rxn<bool> canContinueTrip = Rxn<bool>();
  final photos = <XFile>[].obs;
  final extraData = <String, String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadCatalog();
  }

  Future<void> loadCatalog() async {
    isLoadingCatalog.value = true;
    errorMessage.value = '';
    try {
      categories.value = await _service.getCatalog();
    } catch (_) {
      errorMessage.value = 'No se pudo cargar el catálogo de problemas.';
    } finally {
      isLoadingCatalog.value = false;
    }
  }

  void selectCategory(IncidentCategory? category) {
    selectedCategory.value = category;
    selectType(null);
  }

  void selectType(IncidentType? type) {
    selectedType.value = type;
    canContinueTrip.value = null;
    photos.clear();
    extraData.clear();
  }

  void setExtraField(String key, String value) {
    extraData[key] = value;
  }

  /// Reinicia todo el formulario — se llama cada vez que se abre la
  /// pantalla, para no arrastrar datos de un reporte anterior.
  void resetForm() {
    selectedCategory.value = null;
    selectedType.value = null;
    canContinueTrip.value = null;
    photos.clear();
    extraData.clear();
    errorMessage.value = '';
  }

  bool get isFormValid {
    final type = selectedType.value;
    if (type == null) return false;
    if (type.requiresPhoto && photos.isEmpty) return false;
    if (type.requiresCanContinueTrip && canContinueTrip.value == null) {
      return false;
    }
    for (final field in type.extraFields) {
      if (field.required && (extraData[field.key]?.trim().isEmpty ?? true)) {
        return false;
      }
    }
    return true;
  }

  Future<bool> submit({required int tripId, String? description}) async {
    final type = selectedType.value;
    if (type == null || !isFormValid) return false;

    isSubmitting.value = true;
    errorMessage.value = '';
    try {
      final position = await _getCurrentPosition();

      await _service.reportIncident(
        tripId: tripId,
        incidentTypeId: type.id,
        description: description,
        canContinueTrip: canContinueTrip.value,
        extraData: Map<String, String>.from(extraData),
        latitude: position?.latitude,
        longitude: position?.longitude,
        accuracy: position?.accuracy,
        photos: photos,
      );

      return true;
    } on DioException catch (e) {
      errorMessage.value = _parseError(e);
      return false;
    } catch (_) {
      errorMessage.value = 'No se pudo reportar el problema.';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      // Ver TripController._getCurrentPosition: sin timeLimit esta llamada
      // puede quedarse esperando un fix GPS indefinidamente.
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
      final errors = data['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        return errors.values.first.toString();
      }
      final msg = data['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return 'Error ${e.response?.statusCode ?? 'de red'}.';
  }
}
