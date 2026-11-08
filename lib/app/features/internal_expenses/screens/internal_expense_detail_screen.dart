import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/routes/route_names.dart';
import '../../../core/config/app_config.dart';
import '../../../core/design/sx_design.dart';
import '../../../core/files/remote_file_downloader.dart';
import '../../../core/network/api_client.dart';
import '../../../shared_components/sultan_share_dialog.dart';
import '../controllers/internal_expense_controller.dart';
import '../models/internal_expense_models.dart';
import '../widgets/expense_ui.dart';
import '../widgets/pay_period_sheet.dart';

/// Detalle de un gasto: configuración, vencimientos y pagos, historial de recordatorios y bitácora.
/// Recibe el id del gasto como argumento de la ruta.
class InternalExpenseDetailScreen extends StatefulWidget {
  const InternalExpenseDetailScreen({super.key});

  @override
  State<InternalExpenseDetailScreen> createState() => _InternalExpenseDetailScreenState();
}

class _InternalExpenseDetailScreenState extends State<InternalExpenseDetailScreen> {
  late final InternalExpenseController _c;
  late final int _id;

  static const _statusLabels = {'active': 'Activo', 'paused': 'Pausado', 'finished': 'Finalizado'};

  @override
  void initState() {
    super.initState();
    _c = Get.find<InternalExpenseController>();
    _id = Get.arguments as int;
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.loadDetail(_id));
  }

  Future<void> _edit() async {
    final saved = await Get.toNamed(RouteNames.internalExpenseForm, arguments: _id);
    if (saved == true) _c.loadDetail(_id);
  }

  Future<void> _changeStatus(String action) async {
    const texts = {
      'pause': ['Pausar gasto', 'No se generarán nuevos vencimientos ni recordatorios mientras esté pausado.'],
      'resume': ['Reactivar gasto', 'Se reanuda desde el próximo vencimiento a partir de hoy, sin generar el atraso de la pausa.'],
      'finish': ['Finalizar gasto', 'Se cancelarán los vencimientos futuros. Esta acción no se puede deshacer.'],
    };

    if (!await _confirm(texts[action]![0], texts[action]![1], 'Confirmar')) return;

    final error = await _c.changeStatus(_id, action);
    if (error != null) {
      _snack('No se pudo completar', error, isError: true);
    } else {
      _c.loadDetail(_id);
    }
  }

  Future<void> _delete() async {
    if (!await _confirm('Eliminar gasto', 'Se cancelarán sus vencimientos pendientes. El historial de pagos se conserva.', 'Eliminar')) return;

    final error = await _c.delete(_id);
    if (error != null) {
      _snack('No se pudo eliminar', error, isError: true);
    } else {
      Get.back();
      _snack('Gasto eliminado', 'Se eliminó correctamente.');
    }
  }

  Future<void> _pay(ExpensePeriod p, String name) async {
    final paid = await startPayment(
      context,
      _c,
      periodId: p.id,
      title: '$name — ${formatDate(p.dueOn)}',
      amount: p.amount,
      currency: p.currencyCode,
      warning: p.payWarning,
    );
    if (paid) _c.loadDetail(_id);
  }

  Future<void> _openReceipt(Receipt r) async {
    try {
      final file = await RemoteFileDownloader(Get.find<ApiClient>().dio).download('/api/mobile/files/${r.uuid}', r.name);
      if (!mounted) return;
      await SultanShareDialog.show(context, file: file);
    } catch (_) {
      _snack('No se pudo abrir el comprobante', 'Revisa tu conexión e inténtalo de nuevo.', isError: true);
    }
  }

  Future<bool> _confirm(String title, String text, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(text, style: const TextStyle(color: AppColors.textMedium, fontSize: 15)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar', style: TextStyle(color: AppColors.textLight, fontSize: 15))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.royalBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _snack(String title, String message, {bool isError = false}) =>
      Get.snackbar(title, message, backgroundColor: isError ? AppColors.errorRed : AppColors.royalBlue, colorText: Colors.white);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sx.pageBg,
      appBar: SxAppBar(
        title: Obx(() => Text(_c.detail.value?.expense.name ?? 'Gasto')),
        actions: [Obx(() => _menu())],
      ),
      body: Obx(() {
        if (_c.isLoadingDetail.value && _c.detail.value == null) {
          return const Center(child: CircularProgressIndicator(color: AppColors.royalBlue));
        }
        if (_c.detailError.value.isNotEmpty) {
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: ErrorRow(_c.detailError.value)));
        }
        final d = _c.detail.value;
        if (d == null || d.expense.id != _id) return const SizedBox.shrink();

        return RefreshIndicator(
          color: AppColors.royalBlue,
          onRefresh: () => _c.loadDetail(_id),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _configCard(d.expense),
              const SizedBox(height: 14),
              SectionCard(title: 'Vencimientos y pagos', child: _periods(d)),
              const SizedBox(height: 14),
              _collapsible('Historial de recordatorios', d.reminders.length, _reminders(d.reminders)),
              const SizedBox(height: 14),
              _collapsible('Bitácora de eventos', d.events.length, _events(d.events)),
            ],
          ),
        );
      }),
    );
  }

  Widget _menu() {
    final e = _c.detail.value?.expense;
    if (e == null) return const SizedBox.shrink();

    final items = <PopupMenuEntry<String>>[
      if (_c.can('internal_expense.edit') && e.status != 'finished') const PopupMenuItem(value: 'edit', child: Text('Editar')),
      if (_c.can('internal_expense.manage_status') && e.status == 'active') const PopupMenuItem(value: 'pause', child: Text('Pausar')),
      if (_c.can('internal_expense.manage_status') && e.status == 'paused') const PopupMenuItem(value: 'resume', child: Text('Reactivar')),
      if (_c.can('internal_expense.manage_status') && e.status != 'finished') const PopupMenuItem(value: 'finish', child: Text('Finalizar')),
      if (_c.can('internal_expense.destroy')) const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: AppColors.errorRed))),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
      onSelected: (v) => switch (v) {
        'edit' => _edit(),
        'delete' => _delete(),
        _ => _changeStatus(v),
      },
      itemBuilder: (_) => items,
    );
  }

  Widget _configCard(ExpenseConfig e) {
    final rules = [...e.reminderRules]..sort((a, b) => b.daysBefore.compareTo(a.daysBefore));
    final channelNames = {'in_app': 'Campana', 'fcm': 'Push'};

    String ruleText(ReminderRule r) => r.daysBefore > 0
        ? '${r.daysBefore} día(s) antes'
        : r.daysBefore == 0
            ? 'El día del vencimiento'
            : 'Después del vencimiento${r.repeatEveryDays != null ? ', cada ${r.repeatEveryDays} días' : ''}';

    return SectionCard(
      title: 'Configuración',
      trailing: StateChip(stateKey: e.status == 'active' ? 'paid' : e.status, label: _statusLabels[e.status] ?? e.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow('Importe estimado', money(e.estimatedAmount, e.currencyCode)),
          InfoRow('Periodicidad', e.periodicity),
          InfoRow('Categoría', e.category ?? '—'),
          InfoRow('Proveedor', e.supplierName ?? '—'),
          InfoRow('Responsable', e.responsible ?? '—'),
          InfoRow('Inicio de vigencia', formatDate(e.startsOn)),
          InfoRow('Primer vencimiento', formatDate(e.firstDueOn)),
          InfoRow('Finalización', formatDate(e.endsOn)),
          InfoRow('Avisos por', e.reminderChannels.map((c) => channelNames[c] ?? c).join(', ')),
          InfoRow('Recordatorios', rules.isEmpty ? '—' : rules.map(ruleText).join('\n')),
          InfoRow('Creado por', '${e.createdBy ?? '—'}, ${formatDate(e.createdAt)}'),
          if (e.description != null && e.description!.isNotEmpty) InfoRow('Descripción', e.description!),
          if (e.notes != null && e.notes!.isNotEmpty) InfoRow('Observaciones', e.notes!),
        ],
      ),
    );
  }

  Widget _periods(ExpenseDetail d) {
    if (d.periods.isEmpty) {
      return const Text('Sin vencimientos', style: TextStyle(color: AppColors.textMedium, fontSize: 14));
    }

    return Column(
      children: [
        for (final p in d.periods)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: alertBackground(p.alert),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.alert == null ? AppColors.fieldBorder : alertBorder(p.alert)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text('Vence ${formatDate(p.dueOn)}', style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w800))),
                  StateChip(stateKey: p.stateKey, label: p.stateLabel),
                ]),
                const SizedBox(height: 4),
                Text('Estimado: ${money(p.amount, p.currencyCode)}', style: const TextStyle(color: AppColors.textMedium, fontSize: 14)),
                if (p.payment != null) ...[
                  const SizedBox(height: 4),
                  Text('Pagado: ${money(p.payment!.amount, p.currencyCode)} el ${formatDate(p.payment!.paidOn)}',
                      style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
                  if (p.payment!.method != null || p.payment!.reference != null)
                    Text([p.payment!.method, if (p.payment!.reference != null) 'Ref. ${p.payment!.reference}'].whereType<String>().join(' · '),
                        style: const TextStyle(color: AppColors.textMedium, fontSize: 14)),
                  for (final r in p.payment!.receipts)
                    InkWell(
                      onTap: () => _openReceipt(r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          const Icon(Icons.attach_file_rounded, size: 18, color: AppColors.royalBlue),
                          const SizedBox(width: 6),
                          Expanded(child: Text(r.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.royalBlue, fontSize: 14, fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ),
                ],
                if (p.canPay) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _pay(p, d.expense.name),
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
      ],
    );
  }

  Widget _collapsible(String title, int count, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text('$title ($count)', style: const TextStyle(color: AppColors.navyBlue, fontSize: 16, fontWeight: FontWeight.w800)),
          children: [child],
        ),
      ),
    );
  }

  Widget _reminders(List<ReminderLog> reminders) {
    if (reminders.isEmpty) return const Text('Sin recordatorios', style: TextStyle(color: AppColors.textMedium, fontSize: 14));

    return Column(
      children: [
        for (final r in reminders)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r.scheduledFor} · ${r.channel}', style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('Vencimiento ${formatDate(r.dueOn)} · ${r.recipient ?? '—'}', style: const TextStyle(color: AppColors.textMedium, fontSize: 14)),
                  if (r.lastError != null) Text(r.lastError!, style: const TextStyle(color: AppColors.errorRed, fontSize: 14)),
                ]),
              ),
              Text('${r.status}${r.attempts > 0 ? ' (${r.attempts})' : ''}', style: const TextStyle(color: AppColors.textMedium, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
    );
  }

  Widget _events(List<EventLog> events) {
    if (events.isEmpty) return const Text('Sin eventos', style: TextStyle(color: AppColors.textMedium, fontSize: 14));

    return Column(
      children: [
        for (final e in events)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.event, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
                  if (e.notes != null && e.notes!.isNotEmpty) Text(e.notes!, style: const TextStyle(color: AppColors.textMedium, fontSize: 14)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(e.by, style: const TextStyle(color: AppColors.textMedium, fontSize: 14)),
                Text(e.at ?? '', style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
              ]),
            ]),
          ),
      ],
    );
  }
}
