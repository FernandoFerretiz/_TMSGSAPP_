import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
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
            childAspectRatio: 1.1,
            children: [
              HomeActionCard(
                icon: Icons.route_rounded,
                title: 'Viajes',
                subtitle: 'Gestionar rutas',
                onTap: () {/* TODO: navigate to trips */},
              ),
              HomeActionCard(
                icon: Icons.people_rounded,
                title: 'Clientes',
                subtitle: 'Administrar clientes',
                onTap: () {/* TODO */},
              ),
              HomeActionCard(
                icon: Icons.local_shipping_rounded,
                title: 'Transportistas',
                subtitle: 'Administrar flota',
                onTap: () {/* TODO */},
              ),
              HomeActionCard(
                icon: Icons.badge_rounded,
                title: 'Operadores',
                subtitle: 'Gestionar operadores',
                onTap: () {/* TODO */},
              ),
              HomeActionCard(
                icon: Icons.directions_car_rounded,
                title: 'Unidades',
                subtitle: 'Inventario vehicular',
                onTap: () {/* TODO */},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
