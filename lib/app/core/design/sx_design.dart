import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_config.dart';

/// Tokens y piezas del estilo nuevo de la app (encabezado azul redondeado,
/// tarjetas blancas con sombra suave, íconos en círculos pastel, botones de
/// pastilla). Mantiene el azul de SultanX.
class Sx {
  static const pageBg = Color(0xFFF3F6FC);
  static const cardRadius = 22.0;
  static const blue = AppColors.royalBlue;
  static const blueLight = AppColors.electricBlue;

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D47A1), AppColors.royalBlue, AppColors.electricBlue],
    stops: [0.0, 0.55, 1.0],
  );

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: AppColors.royalBlue.withValues(alpha: 0.20),
          blurRadius: 26,
          offset: const Offset(0, 10),
        ),
      ];

  /// Fondo pastel para el círculo de un ícono, derivado de su color.
  static Color pastel(Color base) =>
      Color.alphaBlend(base.withValues(alpha: 0.13), Colors.white);
}

/// Barra superior de las pantallas internas: azul con esquinas inferiores
/// redondeadas, flecha de regreso y título en blanco.
class SxAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget> actions;

  const SxAppBar({super.key, this.title, this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Container(
      decoration: const BoxDecoration(
        gradient: Sx.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Color(0x551565C0),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 66,
          child: IconTheme(
            data: const IconThemeData(color: Colors.white),
            child: Row(
              children: [
                if (canPop)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Get.back(),
                  )
                else
                  const SizedBox(width: 16),
                Expanded(
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                    ),
                    overflow: TextOverflow.ellipsis,
                    child: title ?? const SizedBox.shrink(),
                  ),
                ),
                ...actions,
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
