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
      backgroundColor: const Color(0xFFF3F6FC),
      drawer: const AppSidebar(),
      appBar: _buildAppBar(context, home, auth),
      body: Column(
        children: [
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
      preferredSize: const Size.fromHeight(138),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D47A1), AppColors.royalBlue, AppColors.electricBlue],
            stops: [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Color(0x551565C0),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu_rounded,
                            color: Colors.white, size: 26),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        AppConfig.appName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Obx(
                      () => auth.isLoading.value
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.logout_rounded,
                                  color: Colors.white, size: 22),
                              tooltip: 'Cerrar sesión',
                              onPressed: () =>
                                  _confirmLogout(Get.context!, auth),
                            ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  child: Obx(() => _Greeting(
                        name: home.welcomeName,
                        avatarUrl: auth.currentUser?.avatarUrl,
                        token: TokenManager.token,
                        roleLabel: home.roleLabel,
                      )),
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

class _Greeting extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String? token;
  final String roleLabel;

  const _Greeting({
    required this.name,
    this.avatarUrl,
    this.token,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    final first = name.split(' ').first;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
              color: Colors.white24, shape: BoxShape.circle),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
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
                        color: AppColors.royalBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hola, $first',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(roleLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GenericHome extends StatelessWidget {
  final String name;
  const _GenericHome({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bienvenido, $name',
            style: const TextStyle(
              color: AppColors.navyBlue,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
