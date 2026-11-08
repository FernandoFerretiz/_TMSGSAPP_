import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';

/// A tappable card used across all role home screens for primary actions.
class HomeActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool highlight;
  // Estilo deshabilitado (gris); el onTap sigue activo para poder explicar por qué.
  final bool disabled;

  const HomeActionCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.highlight = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: disabled
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.20),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: highlight && !disabled
                        ? AppColors.buttonGradient
                        : null,
                    color: disabled
                        ? const Color(0xFFE0E3EA)
                        : (highlight ? null : _pastel(iconColor)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: disabled
                        ? AppColors.textMedium
                        : highlight
                            ? Colors.white
                            : (iconColor ?? AppColors.royalBlue),
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMedium,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textLight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Fondo pastel del círculo del ícono, derivado del color del ícono.
  static Color _pastel(Color? c) {
    final base = c ?? AppColors.royalBlue;
    return Color.alphaBlend(base.withValues(alpha: 0.13), Colors.white);
  }
}
