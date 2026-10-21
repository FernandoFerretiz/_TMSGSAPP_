import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../../../config/routes/route_names.dart';
import '../widgets/home_action_card.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Panel de Administración',
            style: TextStyle(
              color: AppColors.navyBlue,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gestiona todos los recursos del sistema.',
            style: TextStyle(color: AppColors.textMedium, fontSize: 13.5),
          ),
          const SizedBox(height: 24),

          // if (authController.hasPermission('trip.index'))
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.95,
            children: [
              HomeActionCard(
                icon: Icons.route_rounded,
                title: 'Nuevo viaje de circuito',
                subtitle: 'Dar de alta una vuelta con formulario',
                onTap: () => Get.toNamed(RouteNames.circuitTripForm),
              ),
              HomeActionCard(
                icon: Icons.history_rounded,
                title: 'Historial de viajes',
                subtitle: 'Historial de cambios de estado y problemas por viaje',
                onTap: () => Get.toNamed(RouteNames.tripHistoryList),
              ),
              HomeActionCard(
                icon: Icons.swap_horiz_rounded,
                title: 'Cobertura de turno',
                subtitle: 'Cubrir a otro usuario del organigrama',
                onTap: () => Get.toNamed(RouteNames.shiftCoverageList),
              ),
              HomeActionCard(
                icon: Icons.event_note_rounded,
                title: 'Últimos eventos',
                subtitle: 'Cambios de estado, incidencias y detenciones',
                onTap: () => Get.toNamed(RouteNames.lastEvents),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
