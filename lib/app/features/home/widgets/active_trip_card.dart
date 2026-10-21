import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../shared_components/sultan_share_dialog.dart';
import '../../trips/models/trip_model.dart';
import '../../trips/utils/fianza_share_template.dart';

/// Shows the operator's active trip summary with a gradient header.
class ActiveTripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback? onTap;

  const ActiveTripCard({super.key, required this.trip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.royalBlue.withValues(alpha: 0.38),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.royalBlue, AppColors.electricBlue],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_shipping_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Unidad ${trip.truckboxNum}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    _StatusBadge(trip.statusLabel),
                  ],
                ),
              ),
              // White body
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  children: [
                    _RouteRow(
                      origin: trip.origin,
                      destination: trip.destination,
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Asignación',
                      value: trip.assignmentDatetime ?? '—',
                    ),
                    if (trip.departureDatetime != null) ...[
                      const SizedBox(height: 6),
                      _InfoRow(
                        icon: Icons.departure_board_outlined,
                        label: 'Salida',
                        value: trip.departureDatetime!,
                      ),
                    ],
                    if (trip.comments != null && trip.comments!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.comment_rounded,
                              color: AppColors.royalBlue, size: 15),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              trip.comments!,
                              style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_hasMapsLink(trip)) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => _openInMaps(trip),
                        borderRadius: BorderRadius.circular(8),
                        child: const Row(
                          children: [
                            Icon(Icons.map_rounded,
                                color: AppColors.royalBlue, size: 15),
                            SizedBox(width: 6),
                            Text('Abrir destino en Maps',
                                style: TextStyle(
                                    color: AppColors.royalBlue,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _FianzaShareButton(
                      isComplete: trip.truckbox?.isCompleteForFianza ?? false,
                      onTap: () {
                        SultanShareDialog.showTextOnly(
                          context,
                          text: fianzaShareText(trip),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasMapsLink(TripModel trip) =>
      trip.destinationMapsUrl != null ||
      (trip.destinationLatitude != null && trip.destinationLongitude != null);

  Future<void> _openInMaps(TripModel trip) async {
    final uri = trip.destinationMapsUrl != null
        ? Uri.parse(trip.destinationMapsUrl!)
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${trip.destinationLatitude},${trip.destinationLongitude}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Comparte (o copia) los datos de la caja para tramitar la fianza —
/// económico, marca, placas, modelo y no. de serie, todos del catálogo
/// truck_boxes del backend. Mismo diálogo (WhatsApp/Telegram/copiar) que
/// "Compartir resumen" en el historial de eventos del viaje.
class _FianzaShareButton extends StatelessWidget {
  final bool isComplete;
  final VoidCallback onTap;
  const _FianzaShareButton({required this.isComplete, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.badge_outlined,
                  color: isComplete
                      ? AppColors.royalBlue
                      : const Color(0xFFEF6C00),
                  size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    isComplete
                        ? 'Datos para Fianza'
                        : 'Datos incompletos para fianza',
                    style: TextStyle(
                        color: isComplete
                            ? AppColors.navyBlue
                            : const Color(0xFFEF6C00),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.share_rounded,
                  color: AppColors.royalBlue, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  const _StatusBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final String origin;
  final String destination;
  const _RouteRow({required this.origin, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Origen',
                  style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(origin,
                  style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded,
              color: AppColors.royalBlue, size: 20),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Destino',
                  style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(destination,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textLight),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: AppColors.textMedium,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
