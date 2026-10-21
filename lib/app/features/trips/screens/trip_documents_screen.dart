import '../../../core/design/sx_design.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../controllers/trip_controller.dart';
import '../widgets/photo_source_sheet.dart';

/// Thumbnail grid for evidence photos, used by the "Cargar documentos" step
/// of the start/finish-trip hub screens.
class TripDocumentsScreen extends StatelessWidget {
  const TripDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<TripController>();
    final photos = tc.documentPhotos;

    Future<void> addPhotos() async {
      final picked = await showPhotoSourceSheet(context);
      if (picked.isNotEmpty) photos.addAll(picked);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FC),
      appBar: SxAppBar(title: const Text(
          'Cargar documentos',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        )),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agrega fotografías de los documentos del viaje. Puedes '
              'tomar una foto nueva o elegir alguna ya tomada.',
              style: TextStyle(
                  color: AppColors.textMedium,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Obx(() {
                final files = photos;
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: files.length + 1,
                  itemBuilder: (_, i) {
                    if (i == files.length) {
                      return _AddTile(onTap: addPhotos);
                    }
                    return _ThumbTile(
                      path: files[i].path,
                      onRemove: () => photos.removeAt(i),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
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
                color: AppColors.royalBlue, size: 28),
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
