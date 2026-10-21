import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../../../core/design/sx_design.dart';
import '../controllers/auth_controller.dart';
import '../widgets/custom_text_field.dart';

/// Pantalla exclusiva de la app: activa la cuenta de un operador/contacto
/// invitado sin correo, usando el username y el PIN de 6 dígitos que el
/// admin le entregó en persona (ver AuthController::activate en el backend,
/// Api/Mobile — no hay equivalente web para este caso).
class ActivateAccountScreen extends StatefulWidget {
  const ActivateAccountScreen({super.key});

  @override
  State<ActivateAccountScreen> createState() => _ActivateAccountScreenState();
}

class _ActivateAccountScreenState extends State<ActivateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();
  bool _obscurePassword = true;

  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _auth = Get.find<AuthController>();
    // Deferred to after the current frame: mutating errorMessage
    // synchronously here can hit an Obx elsewhere still mid-build during
    // the route transition into this screen (e.g. the login screen's own
    // error banner), throwing "setState()/markNeedsBuild() called during
    // build" — same fix already applied in StartTripScreen.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _auth.errorMessage.value = '');
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _pinCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _auth.activate(
      identifier: _identifierCtrl.text.trim(),
      pin: _pinCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sx.pageBg,
      resizeToAvoidBottomInset: true,
      appBar: const SxAppBar(title: Text('Activar cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: Sx.softShadow,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  CustomTextField(
                    controller: _identifierCtrl,
                    labelText: 'Usuario o correo',
                    hintText: 'El que te dio tu administrador',
                    prefixIcon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'El usuario o correo es requerido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 19),
                  CustomTextField(
                    controller: _pinCtrl,
                    labelText: 'Código de activación',
                    hintText: '6 dígitos',
                    prefixIcon: Icons.pin_outlined,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'El código es requerido';
                      }
                      if (v.trim().length != 6) {
                        return 'El código tiene 6 dígitos';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 19),
                  CustomTextField(
                    controller: _passwordCtrl,
                    labelText: 'Nueva contraseña',
                    hintText: '••••••••',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
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
                      if (v.length < 8) {
                        return 'Mínimo 8 caracteres';
                      }
                      if (!RegExp(r'[a-z]').hasMatch(v)) {
                        return 'Debe incluir al menos 1 minúscula';
                      }
                      if (!RegExp(r'[A-Z]').hasMatch(v)) {
                        return 'Debe incluir al menos 1 mayúscula';
                      }
                      if (!RegExp(r'[0-9]').hasMatch(v)) {
                        return 'Debe incluir al menos 1 número';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 19),
                  CustomTextField(
                    controller: _passwordConfirmCtrl,
                    labelText: 'Confirma tu contraseña',
                    hintText: '••••••••',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) {
                      if (v != _passwordCtrl.text) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '¿Tu código expiró? Pídele a tu administrador que te '
                      'genere uno nuevo desde el panel.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 19),
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
                  Obx(() => SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _auth.isLoading.value ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.royalBlue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFCFD8E8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          child: _auth.isLoading.value
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Text('Activar cuenta'),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activa tu cuenta',
          style: TextStyle(
            fontSize: 24,
            height: 1.1,
            letterSpacing: -0.6,
            color: AppColors.navyBlue,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 9),
        Text(
          'Usa el usuario y el código de 6 dígitos que te dio tu '
          'administrador para elegir tu contraseña y entrar por primera vez.',
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
