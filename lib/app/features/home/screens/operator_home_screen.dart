import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../../trips/controllers/trip_controller.dart';
import '../widgets/active_trip_card.dart';
import '../widgets/home_action_card.dart';

class OperatorHomeScreen extends StatelessWidget {
  const OperatorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<TripController>();

    return RefreshIndicator(
      color: AppColors.royalBlue,
      onRefresh: tc.loadActiveTrip,
      child: Obx(() {
        if (tc.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.royalBlue),
          );
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: tc.hasActiveTrip
              ? _ActiveTripView(tc: tc)
              : const _NoTripView(),
        );
      }),
    );
  }
}

// ── Active trip view ─────────────────────────────────────────────────────────

class _ActiveTripView extends StatelessWidget {
  final TripController tc;
  const _ActiveTripView({required this.tc});

  @override
  Widget build(BuildContext context) {
    final trip = tc.activeTrip!;
    final resp = tc.activeTripResponse!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Viaje Activo',
          style: TextStyle(
            color: AppColors.navyBlue,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),

        ActiveTripCard(trip: trip),
        const SizedBox(height: 20),

        // Error from last action
        Obx(() {
          final err = tc.errorMessage.value;
          if (err.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ErrorBanner(err),
          );
        }),

        // Actions depending on trip status
        if (trip.isAssigned) ...[
          const Text(
            'Acciones disponibles',
            style: TextStyle(
                color: AppColors.navyBlue,
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          // if (authController.hasPermission('trip.update'))
          HomeActionCard(
            icon: Icons.play_circle_rounded,
            title: 'Iniciar viaje',
            subtitle: 'Confirmar salida y comenzar seguimiento',
            highlight: true,
            iconColor: Colors.white,
            onTap: tc.goToStartTrip,
          ),
        ],

        if (trip.isStarted) ...[
          const Text(
            'Acciones disponibles',
            style: TextStyle(
                color: AppColors.navyBlue,
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              if (resp.canReportIncident)
                HomeActionCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Reportar incidencia',
                  iconColor: const Color(0xFFFFB74D),
                  onTap: () => tc.reportIncident(notes: ''),
                ),
              if (resp.canSendEvidence)
                HomeActionCard(
                  icon: Icons.attach_file_rounded,
                  title: 'Enviar evidencia',
                  onTap: () {/* TODO: open evidence picker */},
                ),
              if (resp.canFinishTrip)
                // if (authController.hasPermission('trip.update'))
                HomeActionCard(
                  icon: Icons.flag_rounded,
                  title: 'Finalizar viaje',
                  iconColor: const Color(0xFF81C784),
                  onTap: tc.goToChangeStatus,
                ),
            ],
          ),
        ],

        if (trip.isFinished)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'El viaje ha finalizado.',
                style: TextStyle(
                    color: AppColors.textMedium,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
      ],
    );
  }
}

// ── No active trip ────────────────────────────────────────────────────────────

class _NoTripView extends StatelessWidget {
  const _NoTripView();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: AppColors.royalBlue,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sin viaje activo',
              style: TextStyle(
                  color: AppColors.navyBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuando te asignen un viaje\naparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMedium, fontSize: 14),
            ),
            const SizedBox(height: 32),
            const Text(
              'Desliza hacia abajo para actualizar.',
              style:
                  TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.errorRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
