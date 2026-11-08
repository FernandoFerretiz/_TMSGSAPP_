import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../../../core/design/sx_design.dart';
import '../controllers/internal_expense_controller.dart';
import '../models/internal_expense_models.dart';
import '../widgets/expense_ui.dart';

/// Alta y edición de un gasto (mismos campos y reglas que el ERP; el servidor valida). Sin argumento
/// crea; con el id del gasto como argumento edita. Devuelve true al guardar.
class InternalExpenseFormScreen extends StatefulWidget {
  const InternalExpenseFormScreen({super.key});

  @override
  State<InternalExpenseFormScreen> createState() => _InternalExpenseFormScreenState();
}

class _InternalExpenseFormScreenState extends State<InternalExpenseFormScreen> {
  late final InternalExpenseController _c;
  final int? _id = Get.arguments is int ? Get.arguments as int : null;

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _supplier = TextEditingController();
  final _amount = TextEditingController();
  final _intervalDays = TextEditingController();
  final _notes = TextEditingController();
  final _postDueRepeat = TextEditingController(text: '3');

  String? _category;
  String? _currency;
  String? _responsible;
  String _kind = 'recurring';
  String _frequency = 'monthly';
  String _semiDay1 = '15';
  String _semiDay2 = '31';
  String? _startsOn;
  String? _firstDueOn;
  String? _endsOn;
  final List<int> _reminderDays = [7, 3, 1];
  bool _postDueEnabled = false;
  final Set<String> _channels = {'in_app'};

  bool _loading = true;
  String _error = '';

  bool get _recurring => _kind == 'recurring';

  @override
  void initState() {
    super.initState();
    _c = Get.find<InternalExpenseController>();
    _init();
  }

  Future<void> _init() async {
    await _c.loadFormData();

    if (_id != null) {
      await _c.loadDetail(_id!);
      final e = _c.detail.value?.expense;
      if (e != null && e.id == _id) _prefill(e);
    } else {
      final today = toIsoDate(DateTime.now());
      _startsOn = today;
      _firstDueOn = today;
    }

    if (mounted) setState(() => _loading = false);
  }

  void _prefill(ExpenseConfig e) {
    _name.text = e.name;
    _description.text = e.description ?? '';
    _supplier.text = e.supplierName ?? '';
    _amount.text = e.estimatedAmount.toStringAsFixed(2);
    _intervalDays.text = e.intervalDays?.toString() ?? '';
    _notes.text = e.notes ?? '';
    _category = e.categoryId?.toString();
    _currency = e.currencyCode;
    _responsible = e.responsibleUserId?.toString();
    _kind = e.kind;
    _frequency = e.frequency ?? 'monthly';
    if (e.semimonthlyDays.length == 2) {
      _semiDay1 = '${e.semimonthlyDays[0]}';
      _semiDay2 = '${e.semimonthlyDays[1]}';
    }
    _startsOn = e.startsOn;
    _firstDueOn = e.firstDueOn;
    _endsOn = e.endsOn;

    _reminderDays
      ..clear()
      ..addAll(e.reminderRules.where((r) => r.daysBefore >= 0).map((r) => r.daysBefore));

    final post = e.reminderRules.where((r) => r.daysBefore < 0);
    _postDueEnabled = post.isNotEmpty;
    if (post.isNotEmpty) _postDueRepeat.text = '${post.first.repeatEveryDays ?? 3}';

    _channels
      ..clear()
      ..addAll(e.reminderChannels.isEmpty ? ['in_app'] : e.reminderChannels);
  }

  @override
  void dispose() {
    for (final t in [_name, _description, _supplier, _amount, _intervalDays, _notes, _postDueRepeat]) {
      t.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _payload() {
    final days = {..._reminderDays}.toList()..sort((a, b) => b.compareTo(a));
    final rules = [
      for (final d in days) {'days_before': d, 'is_active': true},
      if (_postDueEnabled) {'days_before': -1, 'repeat_every_days': int.tryParse(_postDueRepeat.text) ?? 3, 'is_active': true},
    ];

    return {
      'name': _name.text.trim(),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'category_id': _category,
      'supplier_name': _supplier.text.trim().isEmpty ? null : _supplier.text.trim(),
      'estimated_amount': _amount.text.trim().replaceAll(',', '.'),
      'currency_code': _currency,
      'kind': _kind,
      'frequency': _recurring ? _frequency : null,
      'interval_days': _recurring && _frequency == 'custom' ? _intervalDays.text.trim() : null,
      'semimonthly_days': _recurring && _frequency == 'semimonthly' ? [int.parse(_semiDay1), int.parse(_semiDay2)] : null,
      // Un pago único no tiene vigencia: inicia el mismo día que vence.
      'starts_on': _recurring ? _startsOn : _firstDueOn,
      'first_due_on': _firstDueOn,
      'ends_on': _recurring ? _endsOn : null,
      'responsible_user_id': _responsible,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'reminder_rules': rules,
      'reminder_channels': _channels.toList(),
    };
  }

  Future<void> _submit() async {
    setState(() => _error = '');

    final error = await _c.save(_payload(), id: _id);

    if (!mounted) return;

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    Get.back(result: true);
    Get.snackbar(_id == null ? 'Gasto registrado' : 'Gasto actualizado', 'Se guardó correctamente.', backgroundColor: AppColors.royalBlue, colorText: Colors.white);
  }

  Future<void> _addReminder() async {
    final ctrl = TextEditingController(text: '1');
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nuevo recordatorio', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Días antes del vencimiento (0 = el día del vencimiento)', style: TextStyle(color: AppColors.textMedium, fontSize: 14)),
          const SizedBox(height: 10),
          TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true, decoration: fieldDecoration('Ej. 5')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar', style: TextStyle(color: AppColors.textLight, fontSize: 15))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(int.tryParse(ctrl.text)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.royalBlue, foregroundColor: Colors.white),
            child: const Text('Agregar', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (days != null && days >= 0 && days <= 90 && !_reminderDays.contains(days)) {
      setState(() => _reminderDays.add(days));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fd = _c.formData.value;
    final dayOptions = [
      for (var d = 1; d <= 30; d++) Option('$d', '$d'),
      const Option('31', 'Último día del mes'),
    ];

    return Scaffold(
      backgroundColor: Sx.pageBg,
      appBar: SxAppBar(title: Text(_id == null ? 'Nuevo gasto' : 'Editar gasto')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.royalBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Nombre o concepto *'),
                  TextField(controller: _name, style: const TextStyle(fontSize: 15), decoration: fieldDecoration('Ej. Renta de oficina')),
                  const SizedBox(height: 16),
                  const FieldLabel('Categoría'),
                  OptionSelect(options: fd.categories, value: _category, hint: 'Sin categoría', searchable: true, onChanged: (v) => setState(() => _category = v)),
                  const SizedBox(height: 16),
                  const FieldLabel('Proveedor o beneficiario'),
                  TextField(controller: _supplier, style: const TextStyle(fontSize: 15), decoration: fieldDecoration('Opcional')),
                  const SizedBox(height: 16),
                  const FieldLabel('Responsable interno'),
                  OptionSelect(options: fd.users, value: _responsible, hint: 'Sin responsable', searchable: true, onChanged: (v) => setState(() => _responsible = v)),
                  const SizedBox(height: 16),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      flex: 3,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const FieldLabel('Importe estimado *'),
                        TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 15), decoration: fieldDecoration('0.00')),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const FieldLabel('Moneda *'),
                        OptionSelect(options: fd.currencies, value: _currency, hint: 'Moneda', onChanged: (v) => setState(() => _currency = v)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  const FieldLabel('Tipo *'),
                  OptionSelect(
                    options: const [Option('one_time', 'Pago único'), Option('recurring', 'Recurrente')],
                    value: _kind,
                    hint: 'Tipo',
                    onChanged: (v) => setState(() => _kind = v ?? _kind),
                  ),
                  if (_recurring) ...[
                    const SizedBox(height: 16),
                    const FieldLabel('Periodicidad *'),
                    OptionSelect(options: fd.frequencies, value: _frequency, hint: 'Periodicidad', onChanged: (v) => setState(() => _frequency = v ?? _frequency)),
                    if (_frequency == 'custom') ...[
                      const SizedBox(height: 16),
                      const FieldLabel('Cada cuántos días *'),
                      TextField(controller: _intervalDays, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 15), decoration: fieldDecoration('Ej. 45')),
                    ],
                    if (_frequency == 'semimonthly') ...[
                      const SizedBox(height: 16),
                      const FieldLabel('Días del mes en que vence (quincena) *'),
                      Row(children: [
                        Expanded(child: OptionSelect(options: dayOptions, value: _semiDay1, hint: 'Día', onChanged: (v) => setState(() => _semiDay1 = v ?? _semiDay1))),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('y', style: TextStyle(fontSize: 15))),
                        Expanded(child: OptionSelect(options: dayOptions, value: _semiDay2, hint: 'Día', onChanged: (v) => setState(() => _semiDay2 = v ?? _semiDay2))),
                      ]),
                    ],
                    const SizedBox(height: 16),
                    const FieldLabel('Inicio de vigencia *'),
                    DateField(value: _startsOn, hint: 'Selecciona una fecha', onChanged: (v) => setState(() => _startsOn = v)),
                  ],
                  const SizedBox(height: 16),
                  FieldLabel(_recurring ? 'Primer vencimiento *' : 'Fecha de vencimiento *'),
                  DateField(value: _firstDueOn, hint: 'Selecciona una fecha', onChanged: (v) => setState(() => _firstDueOn = v)),
                  if (_recurring) ...[
                    const SizedBox(height: 16),
                    const FieldLabel('Finalización (opcional)'),
                    DateField(value: _endsOn, hint: 'Sin fecha de finalización', clearable: true, onChanged: (v) => setState(() => _endsOn = v)),
                  ],
                  const SizedBox(height: 16),
                  const FieldLabel('Descripción'),
                  TextField(controller: _description, maxLines: 2, style: const TextStyle(fontSize: 15), decoration: fieldDecoration('Opcional')),
                  const Divider(height: 36),
                  const Text('Recordatorios', style: TextStyle(color: AppColors.navyBlue, fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Los avisos se detienen en cuanto se registra el pago.', style: TextStyle(color: AppColors.textMedium, fontSize: 14)),
                  const SizedBox(height: 12),
                  const FieldLabel('Avisar por'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final ch in fd.channels)
                        FilterChip(
                          label: Text(ch.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _channels.contains(ch.value) ? Colors.white : AppColors.textMedium)),
                          selected: _channels.contains(ch.value),
                          selectedColor: AppColors.royalBlue,
                          checkmarkColor: Colors.white,
                          onSelected: (on) => setState(() {
                            if (on) {
                              _channels.add(ch.value);
                            } else if (_channels.length > 1) {
                              _channels.remove(ch.value);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final d in ([..._reminderDays]..sort((a, b) => b.compareTo(a))))
                        InputChip(
                          label: Text(d == 0 ? 'El día del vencimiento' : '$d día(s) antes', style: const TextStyle(fontSize: 14)),
                          onDeleted: () => setState(() => _reminderDays.remove(d)),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 18, color: AppColors.royalBlue),
                        label: const Text('Agregar', style: TextStyle(fontSize: 14, color: AppColors.royalBlue, fontWeight: FontWeight.w600)),
                        onPressed: _addReminder,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _postDueEnabled,
                    onChanged: (v) => setState(() => _postDueEnabled = v ?? false),
                    title: const Text('Avisar también después del vencimiento si sigue sin pagarse', style: TextStyle(fontSize: 14)),
                  ),
                  if (_postDueEnabled)
                    Row(children: [
                      const Text('Repetir cada ', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 70, child: TextField(controller: _postDueRepeat, keyboardType: TextInputType.number, decoration: fieldDecoration(''))),
                      const Text(' días', style: TextStyle(fontSize: 14)),
                    ]),
                  const Divider(height: 36),
                  const FieldLabel('Observaciones'),
                  TextField(controller: _notes, maxLines: 2, style: const TextStyle(fontSize: 15), decoration: fieldDecoration('Opcional')),
                  const SizedBox(height: 24),
                  if (_error.isNotEmpty) ...[ErrorRow(_error), const SizedBox(height: 16)],
                  Obx(() => PrimaryButton(label: _id == null ? 'Guardar gasto' : 'Guardar cambios', isLoading: _c.isSubmitting.value, onPressed: _submit)),
                ],
              ),
            ),
    );
  }
}
