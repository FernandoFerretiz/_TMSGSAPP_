import '../../../core/design/sx_design.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../../trips/controllers/trip_controller.dart';
import '../../trips/widgets/photo_source_sheet.dart';
import '../controllers/incident_controller.dart';
import '../models/incident_type.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _descriptionCtrl = TextEditingController();

  late final IncidentController _ic;
  late final TripController _tc;

  @override
  void initState() {
    super.initState();
    _ic = Get.find<IncidentController>();
    _tc = Get.find<TripController>();
    _ic.resetForm();
    _ic.loadCatalog();
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final trip = _tc.activeTrip;
    if (trip == null) return;

    final success = await _ic.submit(
      tripId: trip.id,
      description: _descriptionCtrl.text.trim(),
    );

    if (success && mounted) {
      Get.back();
      Get.snackbar(
        'Problema reportado',
        'Se registró correctamente.',
        backgroundColor:
          AppColors.royalBlue, 
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FC),
      appBar: SxAppBar(title: const Text(
          'Reportar un problema',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        )),
      body: Obx(() {
        if (_ic.isLoadingCatalog.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.royalBlue),
          );
        }

        if (_ic.categories.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _ic.errorMessage.value.isNotEmpty
                    ? _ic.errorMessage.value
                    : 'No hay tipos de problema disponibles.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMedium),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Label('Categoría'),
              const SizedBox(height: 8),
              _StyledDropdown<IncidentCategory>(
                value: _ic.selectedCategory.value,
                hint: 'Selecciona una categoría',
                items: _ic.categories,
                itemLabel: (c) => c.name,
                onChanged: _ic.selectCategory,
              ),
              const SizedBox(height: 18),
              const _Label('Tipo de problema'),
              const SizedBox(height: 8),
              _StyledDropdown<IncidentType>(
                value: _ic.selectedType.value,
                hint: 'Selecciona un tipo',
                items: _ic.selectedCategory.value?.types ?? const [],
                itemLabel: (t) => t.name,
                onChanged: _ic.selectType,
              ),
              if (_ic.selectedType.value?.description?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  _ic.selectedType.value!.description!,
                  style:
                      const TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
              ],
              if (_ic.selectedType.value != null) ...[
                const SizedBox(height: 22),
                const _Label('Detalles (opcional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionCtrl,
                  maxLines: 3,
                  style:
                      const TextStyle(color: AppColors.textDark, fontSize: 14),
                  decoration: _fieldDecoration('Describe lo ocurrido...'),
                ),
                if (_ic.selectedType.value!.requiresCanContinueTrip) ...[
                  const SizedBox(height: 22),
                  const _Label('¿Es posible continuar el viaje?'),
                  const SizedBox(height: 8),
                  _YesNoSelector(
                    value: _ic.canContinueTrip.value,
                    onChanged: (v) => _ic.canContinueTrip.value = v,
                  ),
                ],
                if (_ic.selectedType.value!.extraFields.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  ..._ic.selectedType.value!.extraFields.map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label(field.required
                              ? '${field.label} *'
                              : field.label),
                          const SizedBox(height: 8),
                          TextFormField(
                            style: const TextStyle(
                                color: AppColors.textDark, fontSize: 14),
                            decoration: _fieldDecoration(field.label),
                            onChanged: (v) => _ic.setExtraField(field.key, v),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                _Label(_ic.selectedType.value!.requiresPhoto
                    ? 'Fotografías *'
                    : 'Fotografías (opcional)'),
                const SizedBox(height: 8),
                _PhotosGrid(controller: _ic),
                const SizedBox(height: 26),
                Obx(() {
                  final err = _ic.errorMessage.value;
                  if (err.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ErrorRow(err),
                  );
                }),
                Obx(() {
                  final canSubmit = _ic.isFormValid;
                  return _SubmitButton(
                    isLoading: _ic.isSubmitting.value,
                    enabled: canSubmit && !_ic.isSubmitting.value,
                    onPressed: _submit,
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancelar',
                        style: TextStyle(color: AppColors.textMedium)),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
        filled: true,
        fillColor: AppColors.fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.royalBlue, width: 2),
        ),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.navyBlue,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _StyledDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Evita el assert de Flutter cuando el valor seleccionado ya no está
    // en la lista actual de items (ej. al cambiar de categoría).
    final safeValue = items.contains(value) ? value : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: safeValue,
          isExpanded: true,
          hint: Text(hint,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.royalBlue),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemLabel(item),
                        style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ))
              .toList(),
          onChanged: items.isEmpty ? null : onChanged,
        ),
      ),
    );
  }
}

class _YesNoSelector extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool> onChanged;

  const _YesNoSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ChoiceChipButton(
            label: 'Sí',
            selected: value == true,
            color: const Color(0xFF2E7D32),
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ChoiceChipButton(
            label: 'No',
            selected: value == false,
            color: AppColors.errorRed,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : AppColors.fieldFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? color : AppColors.fieldBorder, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : AppColors.textMedium,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotosGrid extends StatelessWidget {
  final IncidentController controller;
  const _PhotosGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) {
      Future<void> addPhotos() async {
        final picked = await showPhotoSourceSheet(context);
        if (picked.isNotEmpty) controller.photos.addAll(picked);
      }

      return Obx(() {
        final files = controller.photos;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: files.length + 1,
          itemBuilder: (_, i) {
            if (i == files.length) {
              return _AddPhotoTile(onTap: addPhotos);
            }
            return _PhotoThumbTile(
              path: files[i].path,
              onRemove: () => controller.photos.removeAt(i),
            );
          },
        );
      });
    });
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fieldFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: const Center(
            child: Icon(Icons.add_photo_alternate_rounded,
                color: AppColors.royalBlue, size: 28),
          ),
        ),
      ),
    );
  }
}

class _PhotoThumbTile extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  const _PhotoThumbTile({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: 200,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.fieldFill,
              child:
                  const Icon(Icons.image_outlined, color: AppColors.textLight),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.errorRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isLoading;
  final bool enabled;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.isLoading,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? AppColors.buttonGradient
              : const LinearGradient(
                  colors: [Color(0xFF90A4AE), Color(0xFFB0BEC5)],
                ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Reportar un problema',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  const _ErrorRow(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.errorRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
