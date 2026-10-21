import '../../../core/design/sx_design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../controllers/trip_history_controller.dart';
import '../models/trip_event.dart';

const _kSurfaceBg = Color(0xFFF3F6FC);
const _kCriticalColor = Color(0xFFDC2626);

/// "Últimos eventos": feed de cambios de estado, incidencias y detenciones
/// across todos los viajes visibles para el usuario — se abre desde la
/// tarjeta del home o al tocar la notificación de detención. A diferencia
/// del historial de un viaje puntual, los eventos aparecen aquí aunque no
/// haya llegado el push (p.ej. si el usuario no estaba en turno).
class LastEventsScreen extends StatefulWidget {
  const LastEventsScreen({super.key});

  @override
  State<LastEventsScreen> createState() => _LastEventsScreenState();
}

class _LastEventsScreenState extends State<LastEventsScreen> {
  late final TripHistoryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<TripHistoryController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadRecentEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurfaceBg,
      appBar: SxAppBar(title: const Text(
          'Últimos eventos',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        )),
      body: Obx(() {
        if (_controller.isLoadingRecentEvents.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.royalBlue),
          );
        }

        if (_controller.recentEventsErrorMessage.value.isNotEmpty) {
          return _ErrorState(
            message: _controller.recentEventsErrorMessage.value,
            onRetry: _controller.loadRecentEvents,
          );
        }

        if (_controller.recentEvents.isEmpty) {
          return const _EmptyState();
        }

        return RefreshIndicator(
          color: AppColors.royalBlue,
          onRefresh: _controller.loadRecentEvents,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: _controller.recentEvents.length,
            itemBuilder: (context, index) =>
                _EventCard(event: _controller.recentEvents[index]),
          ),
        );
      }),
    );
  }
}

class _EventCard extends StatelessWidget {
  final TripEvent event;
  const _EventCard({required this.event});

  Color get _color => switch (event.type) {
        TripEventType.incident => const Color(0xFFDC2626),
        TripEventType.stop => _kCriticalColor,
        TripEventType.status => const Color(0xFF2563EB),
      };

  IconData get _icon => switch (event.type) {
        TripEventType.incident => Icons.warning_amber_rounded,
        TripEventType.stop => Icons.pause_circle_outline_rounded,
        TripEventType.status => Icons.swap_horiz_rounded,
      };

  String? get _timeLabel {
    final ts = event.timestamp;
    if (ts == null) return null;
    return DateFormat("d MMM, HH:mm", 'es_ES').format(ts);
  }

  @override
  Widget build(BuildContext context) {
    final critical = event.eventoCritico;
    final trip = event.trip;

    // Los eventos críticos (hoy: detenciones) llaman la atención con un
    // borde rojo grueso y una tarjeta ligeramente más ancha (margen
    // horizontal reducido) — mismo tratamiento para cualquier tipo futuro
    // marcado como evento_critico por el backend.
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: critical ? 0 : 4,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: critical
            ? Border.all(color: _kCriticalColor, width: 2.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: critical ? 0.12 : 0.06),
            blurRadius: critical ? 22 : 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 18, color: _color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_timeLabel != null)
                      Text(
                        _timeLabel!,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
                if (trip != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (trip.unitNumber?.isNotEmpty ?? false)
                        'Unidad: ${trip.unitNumber}',
                      if (trip.truckboxNum?.isNotEmpty ?? false)
                        'Caja: ${trip.truckboxNum}',
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (event.subtitle != null && event.subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.subtitle!,
                    style: TextStyle(
                      color: critical ? _kCriticalColor : AppColors.textMedium,
                      fontSize: 13,
                      fontWeight: critical ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_note_outlined,
                size: 56, color: AppColors.royalBlue),
            const SizedBox(height: 14),
            const Text(
              'Sin eventos recientes',
              style: TextStyle(
                color: AppColors.navyBlue,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cambios de estado, incidencias y detenciones aparecerán aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMedium, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.errorRed),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMedium, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.royalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
