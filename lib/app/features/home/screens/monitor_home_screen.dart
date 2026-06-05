import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../widgets/home_action_card.dart';

class MonitorHomeScreen extends StatelessWidget {
  const MonitorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
          const SizedBox(height: 4),
          const Text(
            'Selecciona la operación que deseas realizar.',
            style: TextStyle(color: AppColors.textMedium, fontSize: 13.5),
          ),
          const SizedBox(height: 24),

          // if (authController.hasPermission('trip.create'))
          HomeActionCard(
            icon: Icons.add_circle_rounded,
            title: 'Dar de alta asignación',
            subtitle: 'Registrar nuevo viaje',
            highlight: true,
            onTap: () {/* TODO: navigate */},
          ),
          const SizedBox(height: 14),

          // if (authController.hasPermission('trip.update'))
          HomeActionCard(
            icon: Icons.swap_horiz_rounded,
            title: 'Cambiar status',
            subtitle: 'Actualizar estado de un viaje',
            onTap: () {/* TODO */},
          ),
          const SizedBox(height: 14),

          HomeActionCard(
            icon: Icons.upload_file_rounded,
            title: 'Cargar documentos',
            subtitle: 'Subir evidencia y documentos',
            onTap: () {/* TODO */},
          ),
          const SizedBox(height: 14),

          // if (authController.hasPermission('trip.index'))
          HomeActionCard(
            icon: Icons.list_alt_rounded,
            title: 'Consultar viajes',
            subtitle: 'Ver historial de viajes',
            onTap: () {/* TODO */},
          ),
        ],
      ),
    );
  }
}
