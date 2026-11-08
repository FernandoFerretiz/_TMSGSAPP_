import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../controllers/circuit_trip_form_controller.dart';
import '../data/circuit_trip_service.dart';

/// Antes de crear el viaje: si alguna caja escrita no está registrada, pide
/// confirmar que no es un error y permite registrarla en el momento con los
/// mismos datos que el backoffice (placas, NIV, año y marca, obligatorios).
class TruckboxRegistrationFlow {
  /// Devuelve true si se puede continuar con el envío; false si el usuario
  /// eligió corregir o cerró el registro.
  static Future<bool> run(BuildContext context, CircuitTripFormController c) async {
    c.isSubmitting.value = true;
    final missing = await c.findMissingTruckboxes();
    c.isSubmitting.value = false;

    for (final box in missing) {
      if (!context.mounted) return false;

      final register = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ConfirmDialog(number: box.number),
      );
      if (register != true) return false;

      if (!context.mounted) return false;
      final done = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _RegisterSheet(controller: c, box: box),
      );
      if (done != true) return false;
    }
    return true;
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String number;
  const _ConfirmDialog({required this.number});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(color: Color(0xFFFFF3E0), shape: BoxShape.circle),
        child: const Icon(Icons.inventory_2_rounded, color: Color(0xFFEF6C00), size: 28),
      ),
      title: Text('La caja $number no está registrada',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: const Text(
        'Confirma que no se trate de un error al escribir el número. '
        'Si es correcta, regístrala ahora para continuar.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMedium, height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.royalBlue,
            side: const BorderSide(color: AppColors.royalBlue),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Corregir', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.royalBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Registrar ahora', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _RegisterSheet extends StatefulWidget {
  final CircuitTripFormController controller;
  final MissingTruckbox box;
  const _RegisterSheet({required this.controller, required this.box});

  @override
  State<_RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<_RegisterSheet> {
  final _plates = TextEditingController();
  final _niv = TextEditingController();
  final _year = TextEditingController();
  final _brand = TextEditingController();
  late String? _owner = widget.box.owner;
  bool _saving = false;
  String? _error;

  bool get _ready =>
      _owner != null &&
      _plates.text.trim().isNotEmpty &&
      _niv.text.trim().isNotEmpty &&
      _brand.text.trim().isNotEmpty &&
      (int.tryParse(_year.text.trim()) ?? 0) >= 1950;

  @override
  void dispose() {
    _plates.dispose();
    _niv.dispose();
    _year.dispose();
    _brand.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_ready || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await widget.controller.registerTruckbox(
      number: widget.box.number,
      owner: _owner!,
      plates: _plates.text,
      serialNumber: _niv.text,
      year: _year.text,
      brand: _brand.text,
    );

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      Get.snackbar('Caja registrada', 'La caja ${widget.box.number} quedó registrada.',
          backgroundColor: AppColors.royalBlue, colorText: Colors.white);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
      );

  Widget _field(String label, TextEditingController c,
          {TextInputType? type,
          TextCapitalization caps = TextCapitalization.characters,
          List<TextInputFormatter>? formatters}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: type,
          textCapitalization: caps,
          inputFormatters: formatters,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: AppColors.textDark, fontSize: 14),
          decoration: _decoration('$label *'),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Registrar caja ${widget.box.number}',
                  style: const TextStyle(
                      color: AppColors.navyBlue, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Todos los datos son obligatorios.',
                  style: TextStyle(color: AppColors.textMedium, fontSize: 13)),
              const SizedBox(height: 16),
              const Text('¿De quién es la caja? *',
                  style: TextStyle(
                      color: AppColors.navyBlue, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _ownerChip('Del cliente', 'client')),
                  const SizedBox(width: 10),
                  Expanded(child: _ownerChip('Del transportista', 'transporter')),
                ],
              ),
              const SizedBox(height: 16),
              _field('Placas', _plates),
              _field('NIV', _niv),
              _field('Año', _year,
                  type: TextInputType.number,
                  caps: TextCapitalization.none,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ]),
              _field('Marca', _brand, caps: TextCapitalization.words),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.royalBlue,
                        side: const BorderSide(color: AppColors.royalBlue),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _ready && !_saving ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.royalBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.fieldBorder,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Registrar caja',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownerChip(String label, String value) {
    final selected = _owner == value;
    return InkWell(
      onTap: _saving ? null : () => setState(() => _owner = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.royalBlue : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? AppColors.royalBlue : AppColors.fieldBorder, width: 1.5),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textMedium,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            )),
      ),
    );
  }
}
