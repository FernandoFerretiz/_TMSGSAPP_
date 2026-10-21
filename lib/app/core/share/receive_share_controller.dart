import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/routes/route_names.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/trips/controllers/trip_controller.dart';
import '../config/app_config.dart';
import 'incoming_shared_file.dart';
import 'receive_share_service.dart';

/// Routes a file shared into SultanX from another app (WhatsApp, Galería…)
/// based on the current user's role:
///  - operador with an active trip → queued into "Cargar documentos",
///    reusing the exact same list/screen the manual photo picker feeds.
///  - admin/monitorista → acknowledged with a message; a dedicated pending
///    inbox for non-operator roles is intentionally out of scope for now.
class ReceiveShareController extends GetxController {
  final ReceiveShareService _service;

  ReceiveShareController(this._service);

  @override
  void onInit() {
    super.onInit();
    _service.onShareReceived.listen(_handleIncoming);
    _checkPendingFromColdStart();
  }

  Future<void> _checkPendingFromColdStart() async {
    final pending = await _service.takePending();
    if (pending != null) _handleIncoming(pending);
  }

  void _handleIncoming(IncomingSharedFile shared) {
    final auth = Get.find<AuthController>();

    if (!auth.hasRole('operador')) {
      Get.snackbar(
        'Archivo recibido',
        'Quedó registrado. La bandeja para tu rol estará disponible '
            'próximamente.',
        backgroundColor: AppColors.royalBlue,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    TripController? tripController;
    try {
      tripController = Get.find<TripController>();
    } catch (_) {
      tripController = null;
    }

    if (tripController == null || !tripController.hasActiveTrip) {
      Get.snackbar(
        'No se pudo adjuntar',
        'No tienes un viaje activo para agregar este archivo.',
        backgroundColor: AppColors.errorRed,
        colorText: Colors.white,
      );
      return;
    }

    tripController.documentPhotos.add(XFile(shared.file.path));
    Get.snackbar(
      'Evidencia añadida',
      'El archivo se agregó a "Cargar documentos" del viaje activo.',
      backgroundColor: AppColors.royalBlue,
      colorText: Colors.white,
    );
    Get.toNamed(RouteNames.tripDocuments);
  }
}
