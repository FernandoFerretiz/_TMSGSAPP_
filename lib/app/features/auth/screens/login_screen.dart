import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../../../config/routes/route_names.dart';
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
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _auth = Get.find<AuthController>();
    // Deferred to after the current frame: mutating errorMessage
    // synchronously here can hit an Obx elsewhere still mid-build during a
    // route transition into this screen, throwing "setState()/
    // markNeedsBuild() called during build".
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _auth.errorMessage.value = '');
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _auth.login(
      identifier: _identifierCtrl.text.trim(),
      password: _passwordCtrl.text,
      // The session must always persist until the user logs out manually.
      rememberMe: true,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_bg.jpg',
            fit: BoxFit.cover,
          ),
          Container(color: AppColors.white.withValues(alpha: 0.93)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 45, 28, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                _buildLogo(),
                const SizedBox(height: 38),
                _buildWelcome(),
                const SizedBox(height: 35),

                // Correo o usuario
                CustomTextField(
                  controller: _identifierCtrl,
                  labelText: 'Correo o usuario',
                  hintText: 'operador@empresa.com o usuario',
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El correo o usuario es requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 19),

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
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(
                        color: AppColors.royalBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 27),

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
                const SizedBox(height: 30),

                Center(
                  child: TextButton(
                    onPressed: () => Get.toNamed(RouteNames.activateAccount),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '¿Tienes un código de activación? Activa tu cuenta',
                      style: TextStyle(
                        color: AppColors.royalBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

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
        ],
      ),
    );
  }

  // ── Logo section ─────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/sultanxtms.png',
      width: double.infinity,
      fit: BoxFit.contain,
    );
  }

  // ── Welcome section ──────────────────────────────────────────────────────

  Widget _buildWelcome() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenido',
          style: TextStyle(
            fontSize: 31,
            height: 1.1,
            letterSpacing: -0.8,
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 9),
        Text(
          'Inicia sesión para comenzar\ntu jornada de trabajo.',
          style: TextStyle(
            color: AppColors.textMedium,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
