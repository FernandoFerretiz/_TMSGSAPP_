import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/routes/route_names.dart';
import '../../../core/config/app_config.dart';
import '../../../core/design/sx_design.dart';
import '../controllers/internal_expense_controller.dart';
import '../models/internal_expense_models.dart';
import '../widgets/expense_ui.dart';
import '../widgets/pay_period_sheet.dart';

/// Gastos internos (flavor staff): resumen por moneda, filtros y listado. Los renglones vencidos o que
/// vencen hoy van en rojo y los próximos a vencer en naranja (lo decide el servidor, igual que en el ERP).
class InternalExpensesListScreen extends StatefulWidget {
  const InternalExpensesListScreen({super.key});

  @override
  State<InternalExpensesListScreen> createState() => _InternalExpensesListScreenState();
}

class _InternalExpensesListScreenState extends State<InternalExpensesListScreen> {
  late final InternalExpenseController _c;
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  static const _filters = <String, String>{
    '': 'Todos',
    'overdue': 'Vencidos',
    'due_today': 'Vencen hoy',
    'due_soon': 'Por vencer',
    'pending': 'Pendientes',
  };

  @override
  void initState() {
    super.initState();
    _c = Get.find<InternalExpenseController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.refreshAll());
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) _c.loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final saved = await Get.toNamed(RouteNames.internalExpenseForm);
    if (saved == true) _c.refreshAll();
  }

  Future<void> _open(ExpenseItem item) async {
    await Get.toNamed(RouteNames.internalExpenseDetail, arguments: item.id);
    _c.refreshAll();
  }

  Future<void> _pay(ExpenseItem item) async {
    final paid = await startPayment(
      context,
      _c,
      periodId: item.nextPeriodId!,
      title: '${item.name} — ${formatDate(item.nextDueOn)}',
      amount: item.nextAmount ?? item.estimatedAmount,
      currency: item.currencyCode,
      warning: item.payWarning,
    );
    if (paid) _c.refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sx.pageBg,
      appBar: SxAppBar(
        title: const Text('Gastos internos'),
        actions: [
          IconButton(
            tooltip: 'Calendario de vencimientos',
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => Get.toNamed(RouteNames.internalExpenseCalendar),
          ),
        ],
      ),
      floatingActionButton: _c.can('internal_expense.create')
          ? FloatingActionButton.extended(
              onPressed: _create,
              backgroundColor: AppColors.royalBlue,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Nuevo gasto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.royalBlue,
        onRefresh: _c.refreshAll,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Obx(() => _SummaryGrid(summary: _c.summary.value)),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: _c.setSearch,
              style: const TextStyle(fontSize: 15),
              decoration: fieldDecoration('Buscar por nombre o proveedor').copyWith(
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.royalBlue),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textLight),
                  onPressed: () {
                    _searchCtrl.clear();
                    _c.setSearch('');
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: Obx(() => ListView(
                    scrollDirection: Axis.horizontal,
                    children: _filters.entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(e.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _c.paymentStatus.value == e.key ? Colors.white : AppColors.textMedium)),
                                selected: _c.paymentStatus.value == e.key,
                                selectedColor: AppColors.royalBlue,
                                backgroundColor: Colors.white,
                                showCheckmark: false,
                                onSelected: (_) => _c.setPaymentStatus(e.key),
                              ),
                            ))
                        .toList(),
                  )),
            ),
            const SizedBox(height: 14),
            Obx(() {
              if (_c.isLoading.value) {
                return const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: AppColors.royalBlue)));
              }
              if (_c.errorMessage.value.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(children: [
                    ErrorRow(_c.errorMessage.value),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(onPressed: _c.loadList, icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar')),
                  ]),
                );
              }
              if (_c.items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No hay gastos con ese filtro.', style: TextStyle(color: AppColors.textMedium, fontSize: 15))),
                );
              }

              return Column(
                children: [
                  for (final item in _c.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ExpenseCard(item: item, onTap: () => _open(item), onPay: item.canPay ? () => _pay(item) : null),
                    ),
                  if (_c.isLoadingMore.value)
                    const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.royalBlue, strokeWidth: 2))),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final ExpenseSummary? summary;

  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;

    return Column(
      children: [
        Row(children: [
          Expanded(child: _SummaryTile(title: 'Vencidos y que vencen hoy', amounts: s?.overdue, color: const Color(0xFFC62828))),
          const SizedBox(width: 10),
          Expanded(child: _SummaryTile(title: 'Próximos a vencer', amounts: s?.dueSoon, color: const Color(0xFFEF6C00))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _SummaryTile(title: 'Pendiente de pago', amounts: s?.pendingTotal, color: AppColors.royalBlue)),
          const SizedBox(width: 10),
          Expanded(child: _SummaryTile(title: 'Pagado este mes', amounts: s?.paidThisMonth, color: const Color(0xFF2E7D32))),
        ]),
        if (s != null && s.upcomingByMonth.isNotEmpty) ...[
          const SizedBox(height: 10),
          SectionCard(
            title: 'Por pagar en los próximos meses',
            child: Column(
              children: [
                for (final m in s.upcomingByMonth)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Text(_monthLabel(m.month), style: const TextStyle(color: AppColors.textMedium, fontSize: 14))),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [for (final a in m.byCurrency) Text(money(a.amount, a.currency), style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w700))],
                      ),
                    ]),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _monthLabel(String key) {
    const names = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    final parts = key.split('-');
    final label = '${names[int.parse(parts[1]) - 1]} ${parts[0]}';
    return label[0].toUpperCase() + label.substring(1);
  }
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final List<CurrencyAmount>? amounts;
  final Color color;

  const _SummaryTile({required this.title, required this.amounts, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMedium, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (amounts == null)
            const Text('…', style: TextStyle(fontSize: 15))
          else if (amounts!.isEmpty)
            const Text('—', style: TextStyle(color: AppColors.textLight, fontSize: 15))
          else
            for (final a in amounts!)
              Text(money(a.amount, a.currency), style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final ExpenseItem item;
  final VoidCallback onTap;
  final VoidCallback? onPay;

  const _ExpenseCard({required this.item, required this.onTap, required this.onPay});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: alertBackground(item.alert),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: alertBorder(item.alert)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(item.name, style: const TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.w800, height: 1.25)),
                ),
                const SizedBox(width: 8),
                StateChip(stateKey: item.stateKey, label: item.stateLabel),
              ]),
              const SizedBox(height: 6),
              Text(
                [item.category, item.supplierName, item.periodicity].where((e) => e != null && e.isNotEmpty).join(' · '),
                style: const TextStyle(color: AppColors.textMedium, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Text(money(item.nextAmount ?? item.estimatedAmount, item.currencyCode),
                      style: const TextStyle(color: AppColors.navyBlue, fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                if (item.nextDueOn != null) ...[
                  const Icon(Icons.event_rounded, size: 18, color: AppColors.textMedium),
                  const SizedBox(width: 4),
                  Text(formatDate(item.nextDueOn), style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ]),
              if (onPay != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onPay,
                    icon: const Icon(Icons.payments_rounded, size: 18),
                    label: const Text('Registrar pago', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
