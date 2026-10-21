import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/app_config.dart';

/// Shows a bottom sheet letting the user pick "Tomar foto" (camera) or
/// "Elegir de galería" (gallery, multi-select). Returns the picked files,
/// or an empty list if the user cancelled.
Future<List<XFile>> showPhotoSourceSheet(BuildContext context) async {
  final picker = ImagePicker();
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.fieldBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded,
                color: AppColors.royalBlue),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded,
                color: AppColors.royalBlue),
            title: const Text('Elegir de galería'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (source == null) return [];

  if (source == ImageSource.camera) {
    final photo = await picker.pickImage(
        source: ImageSource.camera, imageQuality: 60);
    return photo == null ? [] : [photo];
  }

  return picker.pickMultiImage(imageQuality: 60);
}
