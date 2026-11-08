import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../../../core/design/sx_design.dart';
import '../../auth/widgets/gradient_button.dart';
import '../../trips/controllers/trip_controller.dart';
import '../../trips/widgets/photo_source_sheet.dart';
import '../controllers/trip_log_controller.dart';
import '../models/trip_log_option.dart';

/// Registra un estatus en la bitácora del viaje. Las opciones se eligen en una
/// pantalla completa con filas grandes (pensado para operadores a los que se
/// les dificulta un menú desplegable pequeño).
class TripLogStatusScreen extends StatefulWidget {
  const TripLogStatusScreen({super.key});

  @override
  State<TripLogStatusScreen> createState() => _TripLogStatusScreenState();
}

class _TripLogStatusScreenState extends State<TripLogStatusScreen> {
  final _commentCtrl = TextEditingController();

  late final TripLogController _lc;
  late final TripController _tc;

  @override
  void initState() {
    super.initState();
    _lc = Get.find<TripLogController>();
    _tc = Get.find<TripController>();
    _lc.resetForm();
    _lc.loadOptions();
    _commentCtrl.addListener(() => _lc.comment.value = _commentCtrl.text);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickOption() async {
    final picked = await Navigator.of(context).push<TripLogOption>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _OptionPickerScreen(
          options: _lc.options.toList(),
          selected: _lc.selected.value,
        ),
      ),
    );
    if (picked != null) _lc.selected.value = picked;
  }

  Future<void> _submit() async {
    final trip = _tc.activeTrip;
    if (trip == null) return;

    final success = await _lc.submit(tripId: trip.id);

    if (success && mounted) {
      Get.back();
      Get.snackbar(
        'Estatus registrado',
        'Se guardó en la bitácora del viaje.',
        backgroundColor: AppColors.royalBlue,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FC),
      appBar: const SxAppBar(
        title: Text(
          'Estatus',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: Obx(() {
        if (_lc.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.royalBlue),
          );
        }

        if (_lc.options.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _lc.errorMessage.value.isNotEmpty
                    ? _lc.errorMessage.value
                    : 'No hay opciones de estatus disponibles.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMedium),
              ),
            ),
          );
        }

        final option = _lc.selected.value;
        final commentMissing = option != null &&
            option.requiresComment &&
            _lc.comment.value.trim().isEmpty;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Label('¿En qué punto vas?'),
              const SizedBox(height: 8),
              _PickField(option: option, onTap: _pickOption),
              if (option != null) ...[
                const SizedBox(height: 22),
                _Label(option.isOther
                    ? 'Escribe el estatus'
                    : option.requiresComment
                        ? 'Comentario (obligatorio)'
                        : 'Comentario (opcional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _commentCtrl,
                  maxLines: 4,
                  style:
                      const TextStyle(color: AppColors.textDark, fontSize: 17),
                  decoration: _fieldDecoration(
                    'Escribe aquí los detalles…',
                    error: commentMissing,
                  ),
                ),
                if (commentMissing)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      option.isOther
                          ? 'Escribe el estatus que quieres reportar.'
                          : 'Este estatus requiere comentario.',
                      style: const TextStyle(
                          color: AppColors.errorRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
              const SizedBox(height: 22),
              const _Label('Foto (opcional)'),
              const SizedBox(height: 8),
              _PhotoField(lc: _lc),
              if (_lc.errorMessage.value.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_lc.errorMessage.value,
                    style: const TextStyle(
                        color: AppColors.errorRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 26),
              GradientButton(
                label: 'Guardar',
                isLoading: _lc.isSubmitting.value,
                onPressed: _lc.isFormValid && !_lc.isSubmitting.value
                    ? _submit
                    : null,
              ),
            ],
          ),
        );
      }),
    );
  }
}

InputDecoration _fieldDecoration(String hint, {bool error = false}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(
        color: error ? AppColors.errorRed : AppColors.fieldBorder, width: 2),
  );
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.fieldFill,
    contentPadding: const EdgeInsets.all(14),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
          color: error ? AppColors.errorRed : AppColors.royalBlue, width: 2),
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: AppColors.navyBlue, fontSize: 15, fontWeight: FontWeight.w800));
}

/// Campo grande que abre el selector a pantalla completa.
class _PickField extends StatelessWidget {
  final TripLogOption? option;
  final VoidCallback onTap;
  const _PickField({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fieldFill,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightBlue, width: 2),
          ),
          child: Row(
            children: [
              Text(option?.icon ?? '📍', style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option?.name ?? 'Toca para elegir',
                      style: TextStyle(
                        color: option == null
                            ? AppColors.textMedium
                            : AppColors.textDark,
                        fontSize: 19,
                        fontWeight:
                            option == null ? FontWeight.w700 : FontWeight.w800,
                      ),
                    ),
                    if (option != null)
                      const Text('Toca para cambiar',
                          style: TextStyle(
                              color: AppColors.textMedium,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.royalBlue, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoField extends StatelessWidget {
  final TripLogController lc;
  const _PhotoField({required this.lc});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () async {
              final picked = await showPhotoSourceSheet(context);
              if (picked.isNotEmpty) lc.photos.addAll(picked);
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.lightBlue, width: 2),
              ),
              child: Row(
                children: [
                  const Text('📷', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Obx(() => Text(
                          lc.photos.isEmpty
                              ? 'Tomar o elegir foto'
                              : '${lc.photos.length} ${lc.photos.length == 1 ? 'foto seleccionada' : 'fotos seleccionadas'}',
                          style: const TextStyle(
                              color: AppColors.textMedium,
                              fontSize: 17,
                              fontWeight: FontWeight.w700),
                        )),
                  ),
                ],
              ),
            ),
          ),
        ),
        Obx(() {
          if (lc.photos.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < lc.photos.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(lc.photos[i].path),
                            width: 72, height: 72, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => lc.photos.removeAt(i),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Selector a pantalla completa: una opción por fila, grande, un toque elige y
/// cierra.
class _OptionPickerScreen extends StatelessWidget {
  final List<TripLogOption> options;
  final TripLogOption? selected;
  const _OptionPickerScreen({required this.options, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FC),
      appBar: const SxAppBar(
        title: Text(
          '¿En qué punto vas?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Toca una opción para elegirla.',
                  style: TextStyle(
                      color: AppColors.textMedium,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final o = options[i];
                final isSelected =
                    selected != null && selected!.id == o.id && selected!.isOther == o.isOther;
                final warn = o.requiresComment && !o.isOther;

                return Material(
                  color: isSelected ? const Color(0xFFEAF2FF) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  elevation: 0,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(o),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 84),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.royalBlue
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1565C0)
                                .withValues(alpha: 0.14),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: warn
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFE3EEFF),
                              shape: BoxShape.circle,
                            ),
                            child: Text(o.icon,
                                style: const TextStyle(fontSize: 28)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(o.name,
                                    style: const TextStyle(
                                        color: AppColors.textDark,
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800)),
                                if (warn)
                                  const Text('Requiere comentario',
                                      style: TextStyle(
                                          color: AppColors.errorRed,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_rounded,
                                color: AppColors.royalBlue, size: 30),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
