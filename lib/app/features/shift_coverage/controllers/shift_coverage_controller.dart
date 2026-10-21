import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../data/shift_coverage_service.dart';
import '../models/coverage_user.dart';
import '../models/shift_coverage.dart';

class ShiftCoverageController extends GetxController {
  final ShiftCoverageService _service;

  ShiftCoverageController(this._service);

  // ── Lista de coberturas ──────────────────────────────────────────────
  final coverages = <ShiftCoverage>[].obs;
  final isLoadingCoverages = false.obs;
  final isLoadingMore = false.obs;
  final coveragesErrorMessage = ''.obs;

  int _page = 1;
  bool _hasMore = true;

  Future<void> loadCoverages() async {
    isLoadingCoverages.value = true;
    coveragesErrorMessage.value = '';
    _page = 1;
    _hasMore = true;
    try {
      final result = await _service.getCoverages(page: _page);
      coverages.value = result.coverages;
      _hasMore = result.hasMore;
    } catch (_) {
      coveragesErrorMessage.value = 'No se pudo cargar la lista de coberturas.';
    } finally {
      isLoadingCoverages.value = false;
    }
  }

  Future<void> loadMoreCoverages() async {
    if (!_hasMore || isLoadingMore.value || isLoadingCoverages.value) return;

    isLoadingMore.value = true;
    try {
      final result = await _service.getCoverages(page: _page + 1);
      _page += 1;
      _hasMore = result.hasMore;
      coverages.addAll(result.coverages);
    } catch (_) {
      // Deja la lista actual visible; el usuario puede intentar scrollear de nuevo.
    } finally {
      isLoadingMore.value = false;
    }
  }

  final _finishingIds = <int>{}.obs;

  bool isFinishing(int id) => _finishingIds.contains(id);

  Future<bool> finishCoverage(int id) async {
    _finishingIds.add(id);
    try {
      await _service.finishCoverage(id);
      await loadCoverages();
      return true;
    } catch (_) {
      Get.snackbar('Error', 'No se pudo finalizar la cobertura.');
      return false;
    } finally {
      _finishingIds.remove(id);
    }
  }

  // ── Formulario: iniciar cobertura ───────────────────────────────────
  final users = <CoverageUser>[].obs;
  final isLoadingUsers = false.obs;
  final selectedUserIds = <int>{}.obs;
  final Rxn<DateTime> endsAt = Rxn<DateTime>();
  final isSubmitting = false.obs;
  final formErrorMessage = ''.obs;

  Future<void> loadUsers() async {
    isLoadingUsers.value = true;
    try {
      users.value = await _service.getUsers();
    } catch (_) {
      formErrorMessage.value = 'No se pudo cargar la lista de usuarios.';
    } finally {
      isLoadingUsers.value = false;
    }
  }

  void toggleUser(int id) {
    if (selectedUserIds.contains(id)) {
      selectedUserIds.remove(id);
    } else {
      selectedUserIds.add(id);
    }
  }

  void resetForm() {
    selectedUserIds.clear();
    endsAt.value = null;
    formErrorMessage.value = '';
  }

  bool get isFormValid => selectedUserIds.isNotEmpty;

  Future<bool> startCoverage({String? reason}) async {
    if (!isFormValid) return false;

    isSubmitting.value = true;
    formErrorMessage.value = '';
    try {
      await _service.startCoverage(
        coversUserIds: selectedUserIds.toList(),
        endsAt: endsAt.value,
        reason: reason,
      );
      return true;
    } on DioException catch (e) {
      formErrorMessage.value = _parseError(e);
      return false;
    } catch (_) {
      formErrorMessage.value = 'No se pudo iniciar la cobertura.';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final first = errors.values.first;
        return first is List && first.isNotEmpty ? first.first.toString() : first.toString();
      }
      final msg = data['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return 'Error ${e.response?.statusCode ?? 'de red'}.';
  }
}
