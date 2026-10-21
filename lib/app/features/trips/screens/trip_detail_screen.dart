import '../../../core/design/sx_design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../controllers/trip_controller.dart';
import '../models/trip_model.dart';
import '../../../config/routes/route_names.dart';

/// Pantalla abierta al tocar una notificación push de tipo `trip_assigned`.
///
/// Recibe el `tripId` como argumento de navegación:
///   Get.toNamed(RouteNames.tripDetail, arguments: '123')
///
/// Carga el viaje activo (que coincide con el tripId asignado) y permite
/// al operador iniciar o ver el estado del viaje.
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late final String? tripId;
  late final TripController _tc;

  @override
  void initState() {
    super.initState();
    tripId = Get.arguments?.toString();
    _tc = Get.find<TripController>();
    // Refresh so the card reflects the just-assigned trip
    WidgetsBinding.instance.addPostFrameCallback((_) => _tc.loadActiveTrip());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fieldFill,
      appBar: SxAppBar(title: const Text(
          'Detalle del viaje',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        )),
      body: Obx(() {
        if (_tc.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.royalBlue),
          );
        }

        if (!_tc.hasActiveTrip) {
          return _EmptyState(tripId: tripId);
        }

        final trip = _tc.activeTrip!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Notification badge ────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active_rounded,
                        color: Color(0xFF388E3C), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Nuevo viaje asignado',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Trip card ─────────────────────────────────────────────
              _TripInfoCard(trip: trip, tripId: tripId),
              const SizedBox(height: 24),

              // ── Action button ─────────────────────────────────────────
              if (trip.isAssigned)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Get.back();
                      // Navigate to home so the operator sees the full flow
                      Get.offAllNamed(RouteNames.home);
                    },
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Ver en inicio'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.royalBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Trip info card ────────────────────────────────────────────────────────────

class _TripInfoCard extends StatelessWidget {
  final TripModel trip;
  final String? tripId;
  const _TripInfoCard({required this.trip, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row(
            icon: Icons.local_shipping_rounded,
            label: 'Unidad',
            value: trip.truckboxNum.isNotEmpty ? trip.truckboxNum : '—',
          ),
          const Divider(height: 20),
          _Row(
            icon: Icons.trip_origin_rounded,
            label: 'Origen',
            value: trip.origin.isNotEmpty ? trip.origin : '—',
          ),
          const Divider(height: 20),
          _Row(
            icon: Icons.flag_rounded,
            label: 'Destino',
            value: trip.destination.isNotEmpty ? trip.destination : '—',
          ),
          const Divider(height: 20),
          _Row(
            icon: Icons.tag_rounded,
            label: 'ID de viaje',
            value: tripId ?? trip.id.toString(),
          ),
          const Divider(height: 20),
          _Row(
            icon: Icons.info_outline_rounded,
            label: 'Estado',
            value: trip.statusLabel.isNotEmpty ? trip.statusLabel : trip.status,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.royalBlue, size: 20),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: const TextStyle(
            color: AppColors.textMedium,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.navyBlue,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String? tripId;
  const _EmptyState({required this.tripId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_shipping_outlined,
                size: 64, color: AppColors.royalBlue),
            const SizedBox(height: 16),
            Text(
              tripId != null
                  ? 'Viaje #$tripId'
                  : 'Viaje asignado',
              style: const TextStyle(
                color: AppColors.navyBlue,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'El viaje fue asignado. Ve al inicio para verlo y comenzar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMedium, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Get.offAllNamed(RouteNames.home),
              icon: const Icon(Icons.home_rounded),
              label: const Text('Ir al inicio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.royalBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
