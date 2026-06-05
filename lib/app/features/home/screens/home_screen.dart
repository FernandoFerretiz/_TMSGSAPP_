import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/token_manager.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../widgets/app_sidebar.dart';
import 'admin_home_screen.dart';
import 'monitor_home_screen.dart';
import 'operator_home_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    final auth = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      drawer: const AppSidebar(),
      appBar: _buildAppBar(context, home, auth),
      body: Column(
        children: [
          // Thin accent bar under the app bar
          Container(height: 3, color: AppColors.electricBlue),
          Expanded(
            child: Obx(() {
              if (home.isAdmin) return const AdminHomeScreen();
              if (home.isMonitorista) return const MonitorHomeScreen();
              if (home.isOperador) return const OperatorHomeScreen();
              return _GenericHome(name: home.welcomeName);
            }),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    HomeController home,
    AuthController auth,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navyBlue, AppColors.royalBlue],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu_rounded,
                        color: Colors.white, size: 24),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                const Expanded(
                  child: Text(
                    AppConfig.appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Obx(() => _UserChip(
                      name: home.welcomeName,
                      avatarUrl: auth.currentUser?.avatarUrl,
                      token: TokenManager.token,
                      roleLabel: home.roleLabel,
                    )),
                Obx(
                  () => auth.isLoading.value
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.logout_rounded,
                              color: Colors.white, size: 20),
                          tooltip: 'Cerrar sesión',
                          onPressed: () =>
                              _confirmLogout(Get.context!, auth),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthController auth) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: TextStyle(color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              auth.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.royalBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cerrar sesión',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _UserChip extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String? token;
  final String roleLabel;

  const _UserChip({
    required this.name,
    this.avatarUrl,
    this.token,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    final first = name.split(' ').first;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar circle
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.electricBlue,
          backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
              ? NetworkImage(
                  avatarUrl!,
                  headers: token != null
                      ? {'Authorization': 'Bearer $token'}
                      : null,
                )
              : null,
          child: (avatarUrl == null || avatarUrl!.isEmpty)
              ? Text(
                  first.isNotEmpty ? first[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(first,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text(roleLabel,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: 10.5)),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _GenericHome extends StatelessWidget {
  final String name;
  const _GenericHome({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Bienvenido, $name',
        style: const TextStyle(
          color: AppColors.navyBlue,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
