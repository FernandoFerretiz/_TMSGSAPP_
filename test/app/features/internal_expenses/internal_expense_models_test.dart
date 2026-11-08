import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sultanx_tms/app/features/internal_expenses/models/internal_expense_models.dart';

// Los fixtures son respuestas REALES de la API (/api/mobile/internal-expenses) generadas desde las pruebas del
// backend. Si el servidor cambia la forma de la respuesta, estas pruebas avisan que la app debe ajustarse (paridad).
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/app/features/internal_expenses/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('el listado se interpreta con alerta y estado decididos por el servidor', () {
    final body = _fixture('list');
    final items = (body['data'] as List).map((e) => ExpenseItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    expect(items.length, 3);

    final renta = items.firstWhere((i) => i.name == 'Renta');
    expect(renta.alert, 'danger');
    expect(renta.stateKey, 'overdue');
    expect(renta.canPay, isTrue);
    expect(renta.estimatedAmount, 25000);
    expect(renta.currencyCode, 'MXN');
    expect(renta.nextPeriodId, isNotNull);

    // Orden del servidor: el vencimiento más cercano primero.
    expect(items.first.name, 'Renta');
    expect((body['meta'] as Map)['last_page'], 1);
  });

  test('el resumen separa los importes por moneda', () {
    final s = ExpenseSummary.fromJson(Map<String, dynamic>.from(_fixture('summary')['data'] as Map));

    expect(s.overdue.single.currency, 'MXN');
    expect(s.overdue.single.amount, 25000);
    expect(s.pendingTotal.map((a) => a.currency).toSet(), {'MXN', 'USD'});
    expect(s.upcomingByMonth, isNotEmpty);
  });

  test('los catálogos del formulario traen canales, monedas y periodicidades', () {
    final f = ExpenseFormData.fromJson(Map<String, dynamic>.from(_fixture('form_data')['data'] as Map));

    expect(f.currencies.map((o) => o.value), containsAll(['MXN', 'USD']));
    expect(f.channels.map((o) => o.value), ['in_app', 'fcm']);
    expect(f.frequencies.map((o) => o.value), containsAll(['weekly', 'semimonthly', 'fortnightly', 'monthly', 'custom']));
    expect(f.categories, isNotEmpty);
  });

  test('el detalle trae configuración, vencimientos con su pago, recordatorios y bitácora', () {
    final d = ExpenseDetail.fromJson(Map<String, dynamic>.from(_fixture('detail')['data'] as Map));

    expect(d.expense.name, 'Internet');
    expect(d.expense.currencyCode, 'USD');
    expect(d.expense.reminderChannels, ['in_app', 'fcm']);
    expect(d.expense.reminderRules.map((r) => r.daysBefore), containsAll([7, 3, 1]));

    final paid = d.periods.firstWhere((p) => p.payment != null);
    expect(paid.stateKey, 'paid');
    expect(paid.payment!.amount, 1299);
    expect(paid.payment!.reference, 'F-1');

    final open = d.periods.firstWhere((p) => p.payment == null);
    expect(open.canPay, isTrue);
    expect(d.events, isNotEmpty);
    expect(d.reminders, isNotEmpty);
  });

  test('el calendario trae los vencimientos del rango con su alerta', () {
    final entries = (_fixture('calendar')['data'] as List).map((e) => CalendarEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    expect(entries.map((e) => e.name), containsAll(['Internet', 'Seguro']));
    expect(entries.every((e) => e.dueOn.startsWith('2026-03')), isTrue);
  });
}
