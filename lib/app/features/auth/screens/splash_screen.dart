import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../controllers/auth_controller.dart';

/// AuthGate: shown on cold start.
/// Animates in, then delegates auth check to AuthController,
/// which navigates to /home or /login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
    );
    _anim.forward();

    // Give the animation time to play before checking auth.
    Future.delayed(const Duration(milliseconds: 1800), () {
      Get.find<AuthController>().checkAuthStatus();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/images/splash_white2.png',
            fit: BoxFit.cover,
          ),
        
          Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App icon
                  
                  const Text(
                    
                    AppConfig.appName,
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 28,
                      
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sistema de Gestión de Transporte',
                    style: TextStyle(
                      color: AppColors.textMedium,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 64),
                  Obx(() {
                    final auth = Get.find<AuthController>();
                    if (!auth.authCheckFailed.value) return const SizedBox.shrink();
                    return Column(
                      children: [
                        const Text(
                          'No se pudo conectar con el servidor.\nTu sesión sigue guardada.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMedium, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: auth.checkAuthStatus,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    );
                  }),
                  Obx(() => Get.find<AuthController>().authCheckFailed.value
                      ? const SizedBox.shrink()
                      : const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.royalBlue,
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}
