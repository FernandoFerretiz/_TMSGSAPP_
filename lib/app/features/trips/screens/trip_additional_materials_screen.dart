import '../../../core/design/sx_design.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../controllers/trip_controller.dart';
import '../models/trip_model.dart';
import '../widgets/photo_source_sheet.dart';

/// Pide evidencia (foto) de cada material de sujeción agregado al viaje —
/// abierta desde la tarjeta "Material adicional" del hub de inicio de
/// viaje, junto a checklist/documentos/sello.
class TripAdditionalMaterialsScreen extends StatelessWidget {
  const TripAdditionalMaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<TripController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FC),
      appBar: SxAppBar(title: const Text(
          'Material adicional',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        )),
      body: Obx(() {
        final materials = tc.additionalMaterials;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Agrega una fotografía de evidencia por cada material de '
              'sujeción cargado en el viaje.',
              style: TextStyle(
                  color: AppColors.textMedium,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 18),
            for (final material in materials) ...[
              _MaterialCard(material: material),
              const SizedBox(height: 16),
            ],
          ],
        );
      }),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final AdditionalMaterialItem material;
  const _MaterialCard({required this.material});

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<TripController>();

    return Obx(() {
      final localPhotos = tc.additionalMaterialPhotos[material.id] ?? const [];
      final isComplete = material.hasEvidence || localPhotos.isNotEmpty;

      Future<void> addPhotos() async {
        final picked = await showPhotoSourceSheet(context);
        if (picked.isEmpty) return;
        tc.setAdditionalMaterialPhotos(material.id, [
          ...localPhotos,
          ...picked,
        ]);
      }

      void removeAt(int index) {
        final updated = [...localPhotos]..removeAt(index);
        tc.setAdditionalMaterialPhotos(material.id, updated);
      }

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isComplete ? AppColors.royalBlue : AppColors.fieldBorder,
            width: isComplete ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.navyBlue.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isComplete
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isComplete ? AppColors.royalBlue : AppColors.textLight,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(material.name,
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (material.quantity != null || material.deliveryLocation != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(
                  [
                    if (material.quantity != null) 'Cantidad: ${material.quantity}',
                    if (material.deliveryLocation != null)
                      'Ubicación: ${material.deliveryLocation}',
                  ].join(' · '),
                  style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: localPhotos.length + 1,
              itemBuilder: (_, i) {
                if (i == localPhotos.length) {
                  return _AddTile(onTap: addPhotos);
                }
                return _ThumbTile(
                  path: localPhotos[i].path,
                  onRemove: () => removeAt(i),
                );
              },
            ),
          ],
        ),
      );
    });
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

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
                color: AppColors.royalBlue, size: 24),
          ),
        ),
      ),
    );
  }
}

class _ThumbTile extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  const _ThumbTile({required this.path, required this.onRemove});

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
            cacheWidth: 160,
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
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: AppColors.errorRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 13),
            ),
          ),
        ),
      ],
    );
  }
}
