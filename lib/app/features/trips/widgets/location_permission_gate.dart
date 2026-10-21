import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../auth/widgets/gradient_button.dart';

/// Bloquea el flujo de inicio de viaje mientras el operador no tenga
/// concedido el permiso de ubicación "Permitir todo el tiempo" — sin este
/// permiso el tracking GPS del viaje no puede correr en segundo plano, así
/// que no tiene sentido dejarlo avanzar (checklist, documentos, sello) para
/// solo fallar silenciosamente al llegar al botón de confirmar.
class LocationPermissionGate extends StatelessWidget {
  final VoidCallback onEnable;
  const LocationPermissionGate({super.key, required this.onEnable});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: Color(0xFFF57C00),
                size: 42,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Activa la ubicación para continuar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navyBlue,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Debes activar la ubicación todo el tiempo (incluso con la '
              'app en segundo plano) para poder iniciar el viaje. Es lo que '
              'permite compartir tu recorrido mientras estás en tránsito.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMedium,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 30),
            GradientButton(
              label: 'Activar ubicación',
              onPressed: onEnable,
            ),
          ],
        ),
      ),
    );
  }
}
