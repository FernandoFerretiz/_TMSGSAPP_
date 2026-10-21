import 'package:flutter/material.dart';

/// Paleta de estado compartida entre la lista de viajes y el timeline —
/// colores sólidos tipo SaaS (indigo/teal/ámbar/slate) en vez de los
/// verdes/ámbar "semáforo" usados originalmente.
Color statusColor(String code) {
  switch (code) {
    case 'accepted':
      return const Color(0xFF7C3AED); // violet
    case 'reported_to_client':
      return const Color(0xFFEA580C); // orange
    case 'ramp_assigned':
      return const Color(0xFF0891B2); // cyan
    case 'loading_unloading':
      return const Color(0xFFCA8A04); // amber
    case 'started':
      return const Color(0xFF0D9488); // teal
    case 'arrived':
      return const Color(0xFF4F46E5); // indigo
    case 'finished':
      return const Color(0xFF64748B); // slate
    case 'assigned':
    default:
      return const Color(0xFF2563EB); // blue
  }
}

class StatusBadge extends StatelessWidget {
  final String code;
  final String label;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.code,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(code);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
