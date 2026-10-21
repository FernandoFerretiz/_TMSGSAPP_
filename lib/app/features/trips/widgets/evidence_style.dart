import 'package:flutter/material.dart';

/// Tokens de diseño de la página web de evidencias
/// (resources/views/_ERP/trips/public_evidence.blade.php) — la pantalla de
/// iniciar/finalizar viaje los usa para verse idéntica.
class Ev {
  static const navy = Color(0xFF1565C0);
  static const orange = Color(0xFFF59E0B);
  static const orangeDark = Color(0xFF1565C0);
  static const orangeSoft = Color(0xFFEAF2FF);
  static const green = Color(0xFF16A34A);
  static const greenSoft = Color(0xFFECFDF3);
  static const red = Color(0xFFDC2626);
  static const gray50 = Color(0xFFF8FAFC);
  static const gray100 = Color(0xFFF1F5F9);
  static const gray200 = Color(0xFFE2E8F0);
  static const gray300 = Color(0xFFCBD5E1);
  static const gray500 = Color(0xFF64748B);
  static const gray700 = Color(0xFF334155);
  static const text = Color(0xFF172033);
  static const pageBg = Color(0xFFF3F6FC);
  static const radius = 22.0;

  static List<BoxShadow> get shadow => [
        BoxShadow(
          color: navy.withValues(alpha: 0.08),
          blurRadius: 28,
          offset: const Offset(0, 8),
        ),
      ];
}

/// Borde punteado como el `border:1.5px dashed` de las tarjetas de carga.
class DashedRRectBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color background;
  final double radius;

  const DashedRRectBorder({
    super.key,
    required this.child,
    required this.color,
    required this.background,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(color: color, background: background, radius: radius),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  final Color background;
  final double radius;

  _DashedPainter(
      {required this.color, required this.background, required this.radius});

  // Tarjeta blanca con sombra suave (estilo nuevo); si la tarjeta está
  // "completa" (borde verde) se dibuja además un contorno sólido verde.
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    canvas.drawShadow(path, const Color(0x661565C0), 10, false);
    canvas.drawRRect(rrect, Paint()..color = background);

    if (color != Ev.gray300) {
      canvas.drawRRect(
        rrect.deflate(0.75),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.color != color || old.background != background || old.radius != radius;
}

/// Contenedor con el borde/radio de `.panel`, `.stage` y `.extra-box`.
class EvBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;

  const EvBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color = Colors.white,
    this.borderColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Ev.radius),
        border: Border.all(color: borderColor),
        boxShadow: borderColor == Colors.transparent
            ? [
                BoxShadow(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.20),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}
