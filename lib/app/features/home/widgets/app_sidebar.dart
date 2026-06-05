import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../trips/controllers/trip_controller.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();

    return Drawer(
      width: 285,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.navyBlue, AppColors.darkNavy],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(auth),
              const _SidebarDivider(),
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  children: [
                    // Home — all roles
                    _SidebarItem(
                      icon: Icons.home_rounded,
                      label: 'Inicio',
                      onTap: () => _close(),
                    ),
                    const SizedBox(height: 4),

                    // Role-specific section header
                    _buildRoleSection(auth),
                  ],
                ),
              ),
              const _SidebarDivider(),
              // Logout
              _SidebarItem(
                icon: Icons.logout_rounded,
                label: 'Cerrar sesión',
                iconColor: const Color(0xFFEF9A9A),
                textColor: const Color(0xFFEF9A9A),
                onTap: () {
                  _close();
                  auth.logout();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _buildHeader(AuthController auth) {
    return Obx(() {
      final user = auth.currentUser;
      final initials = _initials(user?.name ?? '?');

      return Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2), width: 1.5),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _RoleBadge(auth.primaryRoleLabel),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Role-specific items ────────────────────────────────────────────────

  Widget _buildRoleSection(AuthController auth) {
    if (auth.hasRole('admin')) return _adminItems();
    if (auth.hasRole('monitorista')) return _monitorItems();
    if (auth.hasRole('operador')) return _operatorItems();
    return const SizedBox.shrink();
  }

  Widget _adminItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Gestión'),
        // if (auth.hasPermission('trip.index'))
        _SidebarItem(
          icon: Icons.route_rounded,
          label: 'Viajes',
          onTap: () => _close(),
        ),
        _SidebarItem(
          icon: Icons.people_rounded,
          label: 'Clientes',
          onTap: () => _close(),
        ),
        _SidebarItem(
          icon: Icons.local_shipping_rounded,
          label: 'Transportistas',
          onTap: () => _close(),
        ),
        _SidebarItem(
          icon: Icons.badge_rounded,
          label: 'Operadores',
          onTap: () => _close(),
        ),
        _SidebarItem(
          icon: Icons.directions_car_rounded,
          label: 'Unidades',
          onTap: () => _close(),
        ),
      ],
    );
  }

  Widget _monitorItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Operaciones'),
        // if (auth.hasPermission('trip.create'))
        _SidebarItem(
          icon: Icons.add_circle_rounded,
          label: 'Nueva asignación',
          onTap: () => _close(),
        ),
        // if (auth.hasPermission('trip.update'))
        _SidebarItem(
          icon: Icons.swap_horiz_rounded,
          label: 'Cambiar status',
          onTap: () => _close(),
        ),
        _SidebarItem(
          icon: Icons.upload_file_rounded,
          label: 'Cargar documentos',
          onTap: () => _close(),
        ),
        // if (auth.hasPermission('trip.index'))
        _SidebarItem(
          icon: Icons.list_alt_rounded,
          label: 'Consultar viajes',
          onTap: () => _close(),
        ),
      ],
    );
  }

  Widget _operatorItems() {
    return Obx(() {
      // TripController may not be registered if operator has no active trip.
      TripController? tc;
      try {
        tc = Get.find<TripController>();
      } catch (_) {}

      final trip = tc?.activeTrip;
      final isAssigned = trip?.isAssigned == true;
      final isStarted = trip?.isStarted == true;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Mi Viaje'),
          _SidebarItem(
            icon: Icons.directions_rounded,
            label: 'Viaje activo',
            onTap: () => _close(),
          ),
          if (isAssigned)
            // if (auth.hasPermission('trip.update'))
            _SidebarItem(
              icon: Icons.play_circle_rounded,
              label: 'Iniciar viaje',
              iconColor: const Color(0xFF81C784),
              textColor: const Color(0xFF81C784),
              onTap: () {
                _close();
                tc?.goToStartTrip();
              },
            ),
          if (isStarted) ...[
            // if (auth.hasPermission('trip.update'))
            _SidebarItem(
              icon: Icons.warning_amber_rounded,
              label: 'Reportar incidencia',
              onTap: () => _close(),
            ),
            _SidebarItem(
              icon: Icons.attach_file_rounded,
              label: 'Enviar evidencia',
              onTap: () => _close(),
            ),
          ],
        ],
      );
    });
  }

  void _close() => Get.back();

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;

  const _SidebarItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final ic = iconColor ?? AppColors.skyBlue;
    final tc = textColor ?? Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: AppColors.electricBlue.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: ic, size: 20),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: tc,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 0, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: AppColors.skyBlue.withValues(alpha: 0.55),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.electricBlue.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.electricBlue.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.skyBlue,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: Colors.white.withValues(alpha: 0.08),
      height: 1,
      indent: 16,
      endIndent: 16,
    );
  }
}
