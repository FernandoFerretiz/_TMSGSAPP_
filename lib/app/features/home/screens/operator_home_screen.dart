import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/routes/route_names.dart';
import '../../../core/config/app_config.dart';
import '../../location/controllers/location_controller.dart';
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrackingCard(tc: tc),
              const SizedBox(height: 20),
              // La ida de un circuito ya finalizada sigue llegando como "activa"
              // (el rastreo continúa hasta cerrar la vuelta), pero no es un
              // viaje que el operador tenga que atender: no se muestra.
              tc.hasActiveTrip && !(tc.activeTrip?.isFinished ?? false)
                  ? _ActiveTripView(tc: tc)
                  : const _NoTripView(),
              const SizedBox(height: 20),
              HomeActionCard(
                icon: Icons.history_rounded,
                title: 'Mis viajes',
                subtitle: 'Historial de viajes que has realizado',
                onTap: () => Get.toNamed(RouteNames.tripHistoryList),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Tracking (Iniciar / Detener rastreo) ─────────────────────────────────────

class _TrackingCard extends StatefulWidget {
  final TripController tc;
  const _TrackingCard({required this.tc});

  @override
  State<_TrackingCard> createState() => _TrackingCardState();
}

class _TrackingCardState extends State<_TrackingCard> {
  final lc = Get.find<LocationController>();

  @override
  void initState() {
    super.initState();
    lc.syncWithServer();
  }

  Future<void> _confirmStart(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFFE3EEFF),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.my_location_rounded,
              color: AppColors.royalBlue, size: 28),
        ),
        title: const Text('Iniciar rastreo',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: const Text(
          'Una vez que inicies el rastreo estarás disponible para recibir '
          'viajes, y no podrás desactivarlo mientras tengas un viaje activo. '
          'Cuando el viaje se finalice, ya podrás detener el seguimiento.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMedium, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.royalBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Iniciar rastreo',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok == true) lc.startManual();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tracking = lc.isTracking.value;
      final busy = lc.isToggling.value;
      // Same rule the server enforces: no stopping with an open trip.
      final locked = tracking && widget.tc.hasActiveTrip;
      final error = lc.errorMessage.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrackingBanner(
            tracking: tracking,
            busy: busy,
            locked: locked,
            onPressed: busy || locked
                ? null
                : tracking
                    ? lc.stopManual
                    : () => _confirmStart(context),
          ),
          if (error.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ErrorBanner(error),
          ],
        ],
      );
    });
  }
}

/// Banner principal del inicio: estado del rastreo con acción de pastilla.
class _TrackingBanner extends StatelessWidget {
  final bool tracking;
  final bool busy;
  final bool locked;
  final VoidCallback? onPressed;

  const _TrackingBanner({
    required this.tracking,
    required this.busy,
    required this.locked,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final title = tracking ? 'Rastreo activo' : 'Rastreo apagado';
    final subtitle = busy
        ? 'Procesando...'
        : locked
            ? 'No se puede detener con un viaje asignado o en curso'
            : tracking
                ? 'Tu ubicación se está compartiendo'
                : 'Actívalo para que te puedan asignar viajes';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: tracking
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.royalBlue, AppColors.electricBlue],
              )
            : null,
        color: tracking ? null : Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0)
                .withValues(alpha: tracking ? 0.45 : 0.20),
            blurRadius: 28,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: tracking
                  ? Colors.white.withValues(alpha: 0.2)
                  : const Color(0xFFE3EEFF),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.my_location_rounded,
                color: tracking ? Colors.white : AppColors.royalBlue,
                size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: tracking ? Colors.white : AppColors.navyBlue,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        color: tracking
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppColors.textMedium,
                        fontSize: 12,
                        height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: tracking ? Colors.white : AppColors.royalBlue,
              foregroundColor: tracking ? AppColors.errorRed : Colors.white,
              disabledBackgroundColor: tracking
                  ? Colors.white.withValues(alpha: 0.35)
                  : const Color(0xFFCFD8E8),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            child: Text(tracking ? 'Detener' : 'Iniciar'),
          ),
        ],
      ),
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

        ActiveTripCard(
          trip: trip,
          onTap: trip.isAssigned
              ? tc.goToStartTrip
              // "En tránsito" es 100% automático (GPS) — no hay nada que el
              // operador pueda cambiar manualmente aquí, solo consultar.
              : trip.isStarted
                  ? () => Get.toNamed(RouteNames.tripEventHistory,
                      arguments: trip.id)
                  : trip.isFinished
                      ? null
                      // Ventana pre-tránsito (accepted o uno de los 3
                      // opcionales antes de arribar) vs. post-arribo
                      // (arrived o uno de los 3 opcionales ya arribado): en
                      // ambos casos se abre la pantalla de progreso, pero
                      // solo la segunda necesita el chequeo de canFinishTrip
                      // que ya hace goToChangeStatus.
                      : trip.isPreTransitWindow
                          ? tc.goToTripProgress
                          : tc.goToChangeStatus,
        ),
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
        // Ventana pre-tránsito sin acción manual posible: el viaje avanza
        // solo (GPS), el operador puede tocar la tarjeta para registrar
        // avances opcionales (reportado con cliente / rampa / cargando).
        if (trip.isAccepted || trip.isPreTransitOptional)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Esperando que el viaje inicie movimiento.\n'
                'Toca el viaje para registrar avances (reporte con cliente, '
                'rampa, carga).',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textMedium,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),

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
            childAspectRatio: 0.95,
            children: [
              if (resp.canReportIncident)
                HomeActionCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Reportar un problema',
                  iconColor: const Color(0xFFFFB74D),
                  onTap: () => Get.toNamed(RouteNames.reportIncident),
                ),
            ],
          ),
        ],

        if (trip.isArrived || trip.isPostArrivalOptional) ...[
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
            childAspectRatio: 0.95,
            children: [
              if (resp.canReportIncident)
                HomeActionCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Reportar un problema',
                  iconColor: const Color(0xFFFFB74D),
                  onTap: () => Get.toNamed(RouteNames.reportIncident),
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
      height: MediaQuery.of(context).size.height * 0.36,
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
