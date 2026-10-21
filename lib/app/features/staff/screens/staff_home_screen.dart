import '../../../core/design/sx_design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/routes/route_names.dart';
import '../../../core/config/app_config.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/widgets/home_action_card.dart';

/// Landing screen of the staff flavor.
class StaffHomeScreen extends StatelessWidget {
  const StaffHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sx.pageBg,
      appBar: SxAppBar(
        title: const Text('TMS Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: Get.find<AuthController>().logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acciones Rápidas',
              style: TextStyle(
                color: AppColors.navyBlue,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            HomeActionCard(
              icon: Icons.add_circle_rounded,
              title: 'Crear asignación',
              subtitle: 'Dar de alta un nuevo viaje',
              highlight: true,
              onTap: () => Get.toNamed(RouteNames.circuitTripForm),
            ),
            const SizedBox(height: 14),
            HomeActionCard(
              icon: Icons.list_alt_rounded,
              title: 'Viajes',
              subtitle: 'Consultar viajes y su historial',
              onTap: () => Get.toNamed(RouteNames.tripHistoryList),
            ),
            const SizedBox(height: 14),
            HomeActionCard(
              icon: Icons.event_note_rounded,
              title: 'Historial de eventos',
              subtitle: 'Cambios de estado, incidencias y detenciones',
              onTap: () => Get.toNamed(RouteNames.lastEvents),
            ),
          ],
        ),
      ),
    );
  }
}
