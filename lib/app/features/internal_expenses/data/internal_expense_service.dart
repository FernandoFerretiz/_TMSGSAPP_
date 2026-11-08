import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/internal_expense_models.dart';

/// API móvil de Gastos internos (/api/mobile/internal-expenses). Las reglas viven en el servidor.
class InternalExpenseService {
  final ApiClient _api;

  InternalExpenseService(this._api);

  static const _base = '/api/mobile/internal-expenses';

  Map<String, dynamic> _data(Response r) => Map<String, dynamic>.from((r.data as Map)['data'] as Map);

  Future<ExpenseSummary> getSummary() async {
    final r = await _api.dio.get('$_base/summary');
    return ExpenseSummary.fromJson(_data(r));
  }

  Future<ExpenseFormData> getFormData() async {
    final r = await _api.dio.get('$_base/form-data');
    return ExpenseFormData.fromJson(_data(r));
  }

  Future<ExpensePage> getExpenses({int page = 1, String? search, String? paymentStatus, List<String>? status}) async {
    final r = await _api.dio.get(_base, queryParameters: {
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
      if (paymentStatus != null && paymentStatus.isNotEmpty) 'payment_status': paymentStatus,
      if (status != null && status.isNotEmpty) 'status[]': status,
    });
    final body = Map<String, dynamic>.from(r.data as Map);
    final meta = Map<String, dynamic>.from((body['meta'] as Map?) ?? const {});

    return ExpensePage(
      items: (body['data'] as List? ?? const []).map((e) => ExpenseItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      currentPage: (meta['current_page'] as int?) ?? page,
      lastPage: (meta['last_page'] as int?) ?? page,
    );
  }

  Future<ExpenseDetail> getDetail(int id) async {
    final r = await _api.dio.get('$_base/$id');
    return ExpenseDetail.fromJson(_data(r));
  }

  Future<List<CalendarEntry>> getCalendar(DateTime start, DateTime end) async {
    String d(DateTime x) => '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';

    final r = await _api.dio.get('$_base/calendar', queryParameters: {'start': d(start), 'end': d(end)});
    return ((r.data as Map)['data'] as List? ?? const [])
        .map((e) => CalendarEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> create(Map<String, dynamic> payload) => _api.dio.post(_base, data: payload);

  Future<void> update(int id, Map<String, dynamic> payload) => _api.dio.put('$_base/$id', data: payload);

  Future<void> delete(int id) => _api.dio.delete('$_base/$id');

  /// action: pause | resume | finish
  Future<void> changeStatus(int id, String action) => _api.dio.post('$_base/$id/$action');

  Future<void> pay(
    int periodId, {
    required String paidOn,
    required double amount,
    String? paymentMethodId,
    String? reference,
    String? notes,
    bool confirmAdvance = false,
    File? receipt,
  }) async {
    final form = FormData.fromMap({
      'paid_on': paidOn,
      'amount': amount,
      if (paymentMethodId != null && paymentMethodId.isNotEmpty) 'payment_method_id': paymentMethodId,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (confirmAdvance) 'confirm_advance': 1,
      if (receipt != null) 'receipt': await MultipartFile.fromFile(receipt.path, filename: receipt.path.split('/').last),
    });

    await _api.dio.post('$_base/periods/$periodId/pay', data: form, options: Options(contentType: 'multipart/form-data'));
  }
}
