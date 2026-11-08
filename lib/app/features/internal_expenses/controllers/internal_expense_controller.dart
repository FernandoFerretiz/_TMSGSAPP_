import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../auth/controllers/auth_controller.dart';
import '../data/internal_expense_service.dart';
import '../models/internal_expense_models.dart';

/// Estado de Gastos internos (listado, resumen, detalle, formulario y calendario). Las reglas y los
/// permisos reales los aplica el servidor; aquí los permisos solo deciden qué botones se muestran.
class InternalExpenseController extends GetxController {
  final InternalExpenseService _service;

  InternalExpenseController(this._service);

  final AuthController _auth = Get.find<AuthController>();

  bool can(String permission) => _auth.hasPermission(permission);

  // ── Resumen ──────────────────────────────────────────────────────────
  final summary = Rxn<ExpenseSummary>();

  Future<void> loadSummary() async {
    try {
      summary.value = await _service.getSummary();
    } catch (_) {
      // El resumen es informativo: si falla, el listado sigue funcionando.
    }
  }

  // ── Listado ──────────────────────────────────────────────────────────
  final items = <ExpenseItem>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final errorMessage = ''.obs;
  final search = ''.obs;
  final paymentStatus = ''.obs; // '' = todos

  int _page = 1;
  bool _hasMore = true;

  Future<void> loadList() async {
    isLoading.value = true;
    errorMessage.value = '';
    _page = 1;
    _hasMore = true;
    try {
      final result = await _service.getExpenses(search: search.value, paymentStatus: paymentStatus.value);
      items.value = result.items;
      _hasMore = result.hasMore;
    } catch (_) {
      errorMessage.value = 'No se pudo cargar la lista de gastos.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || isLoadingMore.value || isLoading.value) return;

    isLoadingMore.value = true;
    try {
      final result = await _service.getExpenses(page: _page + 1, search: search.value, paymentStatus: paymentStatus.value);
      _page += 1;
      _hasMore = result.hasMore;
      items.addAll(result.items);
    } catch (_) {
      // Deja visible la lista actual; el usuario puede volver a deslizar.
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([loadList(), loadSummary()]);
  }

  void setPaymentStatus(String value) {
    paymentStatus.value = value;
    loadList();
  }

  void setSearch(String value) {
    search.value = value.trim();
    loadList();
  }

  // ── Catálogos de formularios ────────────────────────────────────────
  final formData = ExpenseFormData.empty.obs;

  Future<void> loadFormData() async {
    if (formData.value.currencies.isNotEmpty) return;
    try {
      formData.value = await _service.getFormData();
    } catch (_) {
      // Se reintenta la próxima vez que se abra un formulario.
    }
  }

  // ── Detalle ──────────────────────────────────────────────────────────
  final detail = Rxn<ExpenseDetail>();
  final isLoadingDetail = false.obs;
  final detailError = ''.obs;

  Future<void> loadDetail(int id) async {
    isLoadingDetail.value = true;
    detailError.value = '';
    try {
      detail.value = await _service.getDetail(id);
    } on DioException catch (e) {
      detailError.value = e.response?.statusCode == 404 ? 'El gasto ya no existe.' : 'No se pudo cargar el gasto.';
    } catch (_) {
      detailError.value = 'No se pudo cargar el gasto.';
    } finally {
      isLoadingDetail.value = false;
    }
  }

  // ── Acciones (devuelven null si salió bien, o el mensaje de error) ──
  final isSubmitting = false.obs;

  Future<String?> _run(Future<void> Function() action) async {
    isSubmitting.value = true;
    try {
      await action();
      return null;
    } on DioException catch (e) {
      return _parseError(e);
    } catch (_) {
      return 'No se pudo completar la acción.';
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<String?> save(Map<String, dynamic> payload, {int? id}) =>
      _run(() => id == null ? _service.create(payload) : _service.update(id, payload));

  Future<String?> changeStatus(int id, String action) => _run(() => _service.changeStatus(id, action));

  Future<String?> delete(int id) => _run(() => _service.delete(id));

  Future<String?> pay(
    int periodId, {
    required String paidOn,
    required double amount,
    String? paymentMethodId,
    String? reference,
    String? notes,
    bool confirmAdvance = false,
    File? receipt,
  }) =>
      _run(() => _service.pay(
            periodId,
            paidOn: paidOn,
            amount: amount,
            paymentMethodId: paymentMethodId,
            reference: reference,
            notes: notes,
            confirmAdvance: confirmAdvance,
            receipt: receipt,
          ));

  // ── Calendario ───────────────────────────────────────────────────────
  final calendarMonth = DateTime(DateTime.now().year, DateTime.now().month).obs;
  final calendarEntries = <CalendarEntry>[].obs;
  final isLoadingCalendar = false.obs;
  final calendarError = ''.obs;

  Future<void> loadCalendar() async {
    isLoadingCalendar.value = true;
    calendarError.value = '';
    final m = calendarMonth.value;
    try {
      calendarEntries.value = await _service.getCalendar(DateTime(m.year, m.month, 1), DateTime(m.year, m.month + 1, 0));
    } catch (_) {
      calendarError.value = 'No se pudieron cargar los vencimientos.';
    } finally {
      isLoadingCalendar.value = false;
    }
  }

  void moveCalendar(int months) {
    final m = calendarMonth.value;
    calendarMonth.value = DateTime(m.year, m.month + months);
    loadCalendar();
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        return first is List && first.isNotEmpty ? first.first.toString() : first.toString();
      }
      final msg = data['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    if (e.response?.statusCode == 403) return 'No tienes permiso para realizar esta acción.';
    return 'Error ${e.response?.statusCode ?? 'de red'}.';
  }
}
