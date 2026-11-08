import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../controllers/internal_expense_controller.dart';
import 'expense_ui.dart';

/// Registro de pago de un vencimiento. Si el servidor mandó una advertencia de pago por adelantado
/// ([warning]) se pide confirmación antes de abrir el formulario, y el servidor la vuelve a exigir.
/// Devuelve true si se registró el pago.
Future<bool> startPayment(
  BuildContext context,
  InternalExpenseController controller, {
  required int periodId,
  required String title,
  required double amount,
  required String currency,
  String? warning,
}) async {
  if (warning != null && warning.isNotEmpty) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pago por adelantado', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(warning, style: const TextStyle(color: AppColors.textMedium, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textLight, fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.royalBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Registrar de todos modos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ],
      ),
    );

    if (proceed != true || !context.mounted) return false;
  }

  controller.loadFormData();

  final paid = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _PaySheet(
      controller: controller,
      periodId: periodId,
      title: title,
      amount: amount,
      currency: currency,
      confirmAdvance: warning != null && warning.isNotEmpty,
    ),
  );

  return paid == true;
}

class _PaySheet extends StatefulWidget {
  final InternalExpenseController controller;
  final int periodId;
  final String title;
  final double amount;
  final String currency;
  final bool confirmAdvance;

  const _PaySheet({
    required this.controller,
    required this.periodId,
    required this.title,
    required this.amount,
    required this.currency,
    required this.confirmAdvance,
  });

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  late final TextEditingController _amount;
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String _paidOn = toIsoDate(DateTime.now());
  String? _method;
  File? _receipt;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.amount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    final path = result?.files.single.path;
    if (path != null) setState(() => _receipt = File(path));
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Escribe un importe mayor a cero.');
      return;
    }

    setState(() => _error = '');

    final error = await widget.controller.pay(
      widget.periodId,
      paidOn: _paidOn,
      amount: amount,
      paymentMethodId: _method,
      reference: _reference.text.trim(),
      notes: _notes.text.trim(),
      confirmAdvance: widget.confirmAdvance,
      receipt: _receipt,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    Navigator.of(context).pop(true);
    Get.snackbar('Pago registrado', 'Se registró correctamente.', backgroundColor: AppColors.royalBlue, colorText: Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Registrar pago', style: TextStyle(color: AppColors.navyBlue, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(widget.title, style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w600)),
            Text('Importe estimado: ${money(widget.amount, widget.currency)}', style: const TextStyle(color: AppColors.textMedium, fontSize: 14)),
            const SizedBox(height: 18),
            const FieldLabel('Fecha de pago *'),
            DateField(
              value: _paidOn,
              hint: 'Selecciona una fecha',
              lastDate: DateTime.now(),
              onChanged: (v) => setState(() => _paidOn = v ?? _paidOn),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Importe pagado *'),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 15),
              decoration: fieldDecoration('0.00'),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Método de pago'),
            Obx(() => OptionSelect(
                  options: c.formData.value.paymentMethods,
                  value: _method,
                  hint: 'Sin especificar',
                  onChanged: (v) => setState(() => _method = v),
                )),
            const SizedBox(height: 16),
            const FieldLabel('Referencia o folio'),
            TextField(controller: _reference, style: const TextStyle(fontSize: 15), decoration: fieldDecoration('Opcional')),
            const SizedBox(height: 16),
            const FieldLabel('Comprobante (PDF, JPG o PNG, máx. 10 MB)'),
            OutlinedButton.icon(
              onPressed: _pickReceipt,
              icon: const Icon(Icons.attach_file_rounded, color: AppColors.royalBlue),
              label: Text(_receipt == null ? 'Adjuntar archivo' : _receipt!.path.split('/').last,
                  overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.royalBlue, fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: AppColors.royalBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Observaciones'),
            TextField(controller: _notes, maxLines: 2, style: const TextStyle(fontSize: 15), decoration: fieldDecoration('Opcional')),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 16),
              ErrorRow(_error),
            ],
            const SizedBox(height: 22),
            Obx(() => PrimaryButton(label: 'Registrar pago', isLoading: c.isSubmitting.value, onPressed: _submit)),
          ],
        ),
      ),
    );
  }
}
