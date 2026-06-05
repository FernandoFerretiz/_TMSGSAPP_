import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../controllers/auth_controller.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _auth = Get.find<AuthController>();
    // Clear any leftover error from a previous attempt.
    _auth.errorMessage.value = '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _auth.login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      rememberMe: _rememberMe,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.navyBlue,
      resizeToAvoidBottomInset: true,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Gradient background
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
              child: SizedBox.expand(),
            ),

            // Decorative circles — top area
            Positioned(
              top: -55,
              right: -45,
              child: _Circle(size: 220, alpha: 0.07),
            ),
            Positioned(
              top: 55,
              left: -65,
              child: _Circle(size: 175, alpha: 0.055),
            ),
            Positioned(
              top: 150,
              right: 55,
              child: _Circle(size: 72, alpha: 0.10),
            ),
            Positioned(
              top: 30,
              left: 80,
              child: _Circle(size: 42, alpha: 0.08),
            ),

            // Content on top
            SafeArea(
              child: Column(
                children: [
                  // Brand area — fixed height
                  SizedBox(
                    height: size.height * 0.29,
                    child: Center(child: _buildBrand()),
                  ),

                  // White curved card — fills remaining space
                  Expanded(child: _buildCard()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Brand section ──────────────────────────────────────────────────────

  Widget _buildBrand() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo1x1.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          AppConfig.appName,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Portal para Operadores',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.60),
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ── White card with organic curve ──────────────────────────────────────

  Widget _buildCard() {
    return ClipPath(
      clipper: _TopCurveClipper(),
      child: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Iniciar Sesión',
                  style: TextStyle(
                    color: AppColors.navyBlue,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Accede con tus credenciales',
                  style: TextStyle(
                    color: AppColors.textMedium,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 30),

                // Email
                CustomTextField(
                  controller: _emailCtrl,
                  labelText: 'Correo electrónico',
                  hintText: 'operador@empresa.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El correo es requerido';
                    }
                    if (!GetUtils.isEmail(v.trim())) {
                      return 'Ingresa un correo válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password
                CustomTextField(
                  controller: _passwordCtrl,
                  labelText: 'Contraseña',
                  hintText: '••••••••',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'La contraseña es requerida';
                    }
                    if (v.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Remember me
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          activeColor: AppColors.royalBlue,
                          side: const BorderSide(
                              color: AppColors.textLight, width: 1.5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Recordarme en este dispositivo',
                        style: TextStyle(
                          color: AppColors.textMedium,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),

                // Error banner
                Obx(() {
                  final msg = _auth.errorMessage.value;
                  if (msg.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFEF9A9A),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.errorRed,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              msg,
                              style: const TextStyle(
                                color: AppColors.errorRed,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Login button
                Obx(() => GradientButton(
                      onPressed: _auth.isLoading.value ? null : _submit,
                      isLoading: _auth.isLoading.value,
                      label: 'Iniciar sesión',
                    )),
                const SizedBox(height: 22),

                Center(
                  child: Text(
                    '¿Problemas para acceder? Contacta al administrador del sistema.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
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

// ── Helpers ────────────────────────────────────────────────────────────────

class _Circle extends StatelessWidget {
  final double size;
  final double alpha;

  const _Circle({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: alpha),
          width: 1.5,
        ),
        color: Colors.white.withValues(alpha: alpha * 0.28),
      ),
    );
  }
}

/// Clips the top of the white card into a soft organic wave.
class _TopCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 46);
    path.quadraticBezierTo(size.width * 0.26, 4, size.width * 0.5, 26);
    path.quadraticBezierTo(size.width * 0.74, 48, size.width, 16);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
