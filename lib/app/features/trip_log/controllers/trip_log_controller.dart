import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../data/trip_log_service.dart';
import '../models/trip_log_option.dart';

class TripLogController extends GetxController {
  final TripLogService _service;

  TripLogController(this._service);

  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  final options = <TripLogOption>[].obs;
  final Rxn<TripLogOption> selected = Rxn<TripLogOption>();
  final photos = <XFile>[].obs;
  final comment = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadOptions();
  }

  Future<void> loadOptions() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      // "Otro" siempre va al final y no viene del backend.
      options.value = [...await _service.getOptions(), TripLogOption.other];
    } catch (_) {
      errorMessage.value = 'No se pudieron cargar las opciones de estatus.';
    } finally {
      isLoading.value = false;
    }
  }

  void resetForm() {
    selected.value = null;
    photos.clear();
    comment.value = '';
    errorMessage.value = '';
  }

  /// Misma regla que el backend (TripLogService): la opción elegida puede
  /// exigir comentario; "Otro" exige el texto.
  bool get isFormValid {
    final option = selected.value;
    if (option == null) return false;
    if (option.requiresComment && comment.value.trim().isEmpty) return false;
    return true;
  }

  Future<bool> submit({required int tripId}) async {
    final option = selected.value;
    if (option == null || !isFormValid) return false;

    isSubmitting.value = true;
    errorMessage.value = '';
    try {
      final position = await _getCurrentPosition();

      await _service.registerStatus(
        tripId: tripId,
        option: option,
        comment: comment.value.trim(),
        latitude: position?.latitude,
        longitude: position?.longitude,
        photos: photos,
      );

      return true;
    } on DioException catch (e) {
      errorMessage.value = _parseError(e);
      return false;
    } catch (_) {
      errorMessage.value = 'No se pudo registrar el estatus.';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
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
        final first = errors.values.first;
        return first is List && first.isNotEmpty
            ? first.first.toString()
            : first.toString();
      }
      final msg = data['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return 'No se pudo registrar el estatus.';
  }
}
