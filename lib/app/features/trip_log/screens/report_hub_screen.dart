import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/routes/route_names.dart';
import '../../../core/design/sx_design.dart';
import '../../home/widgets/home_action_card.dart';

/// "Reportar…": punto de entrada para registrar un Estatus (bitácora del
/// viaje) o reportar un Problema (incidencia).
class ReportHubScreen extends StatelessWidget {
  const ReportHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FC),
      appBar: const SxAppBar(
        title: Text(
          'Reportar…',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            HomeActionCard(
              icon: Icons.pin_drop_rounded,
              title: 'Estatus',
              subtitle: 'En espera de acceso, en rampa, otro…',
              onTap: () => Get.toNamed(RouteNames.tripLogStatus),
            ),
            const SizedBox(height: 12),
            HomeActionCard(
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFFFB74D),
              title: 'Problema',
              subtitle: 'Reporta una incidencia del viaje',
              onTap: () => Get.toNamed(RouteNames.reportIncident),
            ),
          ],
        ),
      ),
    );
  }
}
