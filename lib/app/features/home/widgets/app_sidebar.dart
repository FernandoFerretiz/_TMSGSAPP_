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
      width: 295,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
      ),
      child: Column(
        children: [
          _buildHeader(auth),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: _SidebarItem(
              icon: Icons.logout_rounded,
              label: 'Cerrar sesión',
              iconColor: AppColors.errorRed,
              textColor: AppColors.errorRed,
              onTap: () {
                _close();
                auth.logout();
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(Get.context!).padding.bottom + 14),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _buildHeader(AuthController auth) {
    return Obx(() {
      final user = auth.currentUser;
      final initials = _initials(user?.name ?? '?');

      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
            20, MediaQuery.of(Get.context!).padding.top + 22, 20, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D47A1),
              AppColors.royalBlue,
              AppColors.electricBlue
            ],
            stops: [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35), width: 3),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.royalBlue,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
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
    if (auth.hasRole('operador')) return _operatorItems();
    // Admin/monitorista: sin secciones propias todavía (pendientes de implementar).
    return const SizedBox.shrink();
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
              iconColor: const Color(0xFF2E9E5B),
              textColor: const Color(0xFF2E9E5B),
              onTap: () {
                _close();
                tc?.goToStartTrip();
              },
            ),
          if (isStarted) ...[
            // if (auth.hasPermission('trip.update'))
            _SidebarItem(
              icon: Icons.warning_amber_rounded,
              label: 'Reportar un problema',
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
    final ic = iconColor ?? AppColors.royalBlue;
    final tc = textColor ?? AppColors.textDark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                        ic.withValues(alpha: 0.13), Colors.white),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: ic, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: tc,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
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
          color: AppColors.textLight,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
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
