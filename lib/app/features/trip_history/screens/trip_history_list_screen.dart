import '../../../core/design/sx_design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../config/routes/route_names.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/trip_history_controller.dart';
import '../models/trip_summary.dart';
import '../widgets/status_badge.dart';
import '../widgets/trip_history_filters_sheet.dart';
import '../../../utils/helpers/server_time.dart';

const _kSurfaceBg = Color(0xFFF3F6FC);

/// Lista de viajes: admin/monitorista ven todos los viajes, el operador solo
/// los suyos (el backend hace el scope). Al tocar un viaje se abre su
/// historial de eventos (RouteNames.tripEventHistory).
class TripHistoryListScreen extends StatefulWidget {
  const TripHistoryListScreen({super.key});

  @override
  State<TripHistoryListScreen> createState() => _TripHistoryListScreenState();
}

class _TripHistoryListScreenState extends State<TripHistoryListScreen> {
  late final TripHistoryController _controller;
  final _scrollController = ScrollController();
  // El operador ve solo sus propios viajes (scope forzado en el backend); el
  // catálogo de transportista/operador para filtrar es solo para
  // admin/monitorista.
  late final bool _isOperator = Get.find<AuthController>().hasRole('operador');

  @override
  void initState() {
    super.initState();
    _controller = Get.find<TripHistoryController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadTrips();
      if (!_isOperator) _controller.loadFilterOptions();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _controller.loadMoreTrips();
    }
  }

  Future<void> _openFilters() async {
    final result = await showTripHistoryFiltersSheet(
      context,
      current: _controller.filters.value,
      options: _controller.filterOptions.value,
      showOwnerFilters: !_isOperator,
    );
    if (result != null) {
      _controller.applyFilters(result);
    }
  }

  bool _sameDay(DateTime? a, DateTime? b) =>
      a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  /// Abre el formulario de circuito con la ronda ya elegida (cliente, circuito y
  /// operador) para registrar el siguiente movimiento.
  Future<void> _addMovement(TripRoundGroup round) async {
    final added = await Get.toNamed(RouteNames.circuitTripForm, arguments: {
      'client_id': round.clientId,
      'client_circuit_id': round.clientCircuitId,
      'operator_id': round.operatorId,
    });
    if (added == true) _controller.loadTrips();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurfaceBg,
      appBar: SxAppBar(
          title: const Text(
            'Historial de viajes',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          actions: [
            Obx(() {
              final count = _controller.filters.value.activeCount;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: _openFilters,
                    icon: const Icon(Icons.filter_list_rounded),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.electricBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
            const SizedBox(width: 4),
          ]),
      body: Obx(() {
        if (_controller.isLoadingTrips.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.royalBlue),
          );
        }

        if (_controller.tripsErrorMessage.value.isNotEmpty) {
          return _ErrorState(
            message: _controller.tripsErrorMessage.value,
            onRetry: _controller.loadTrips,
          );
        }

        if (_controller.trips.isEmpty) {
          return const _EmptyState();
        }

        return RefreshIndicator(
          color: AppColors.royalBlue,
          onRefresh: _controller.loadTrips,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: _controller.trips.length + 1,
            itemBuilder: (context, index) {
              if (index == _controller.trips.length) {
                return Obx(() => _controller.isLoadingMore.value
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.royalBlue,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : const SizedBox.shrink());
              }

              final round = _controller.trips[index];
              final previous = index > 0 ? _controller.trips[index - 1] : null;
              final showDay =
                  previous == null || !_sameDay(previous.lastActivity, round.lastActivity);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDay) _DayHeader(date: round.lastActivity),
                  _RoundCard(
                    round: round,
                    canAdd: !_isOperator && round.isOpen,
                    onOpenTrip: (tripId) =>
                        Get.toNamed(RouteNames.tripEventHistory, arguments: tripId),
                    onAddMovement: () => _addMovement(round),
                  ),
                ],
              );
            },
          ),
        );
      }),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime? date;
  const _DayHeader({required this.date});

  String get _label {
    final d = date;
    if (d == null) return '';
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    if (d.year == today.year && d.month == today.month && d.day == today.day) return 'Hoy';
    if (d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day) {
      return 'Ayer';
    }
    return DateFormat("d MMMM y", 'es_ES').format(d);
  }

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        _label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMedium,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Una ronda: todos sus movimientos en una sola tarjeta (con 1, 2 o más),
/// en el orden de la ronda aunque se hayan registrado en momentos distintos.
class _RoundCard extends StatelessWidget {
  final TripRoundGroup round;
  final bool canAdd;
  final ValueChanged<int> onOpenTrip;
  final VoidCallback onAddMovement;

  const _RoundCard({
    required this.round,
    required this.canAdd,
    required this.onOpenTrip,
    required this.onAddMovement,
  });

  String get _title => round.isSingle
      ? 'Viaje · ${round.operatorName ?? '—'}'
      : 'Ronda · ${round.operatorName ?? '—'}';

  (String, Color, Color) get _pill {
    if (round.isSingle) return ('Viaje suelto', AppColors.fieldFill, AppColors.textMedium);
    switch (round.state) {
      case 'open':
        return round.movements.length == 1
            ? ('Solo ida', AppColors.fieldFill, AppColors.textMedium)
            : ('Abierta', const Color(0xFFFFF3E0), const Color(0xFFED6C02));
      case 'voided':
        return ('Anulada', const Color(0xFFFDECEA), const Color(0xFFD32F2F));
      default:
        return ('Cerrada', const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
    }
  }

  String _roleLabel(TripRoundMovement m) {
    if (m.role == 'single') return 'Viaje';
    if (m.role == 'outbound') return 'Ida';
    if (m.role == 'return') return 'Fin';
    return 'Movimiento';
  }

  String? _registered(TripRoundMovement m) {
    final d = parseServerDateTime(m.registeredAt);
    return d == null ? null : DateFormat("EEE HH:mm", 'es_ES').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final pill = _pill;
    final total = round.movements.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Sx.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.royalBlue.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF4F8FF), Colors.white],
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFE1E8F5))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.navyBlue,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration:
                          BoxDecoration(color: pill.$2, borderRadius: BorderRadius.circular(20)),
                      child: Text(pill.$1,
                          style:
                              TextStyle(color: pill.$3, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                if (round.circuit != null && round.circuit!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(round.circuit!,
                      style: const TextStyle(color: AppColors.textMedium, fontSize: 12.5)),
                ],
                const SizedBox(height: 2),
                Text(round.route,
                    style: const TextStyle(
                        color: AppColors.navyBlue, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Column(
              children: [
                for (var i = 0; i < total; i++)
                  _MovementRow(
                    movement: round.movements[i],
                    label: _roleLabel(round.movements[i]),
                    registered: _registered(round.movements[i]),
                    isFirst: i == 0,
                    isLast: i == total - 1 && !round.isOpen,
                    hasLine: i < total - 1 || (round.isOpen && round.nextOrigin != null),
                    onTap: () => onOpenTrip(round.movements[i].trip.id),
                  ),
                if (round.isOpen && round.nextOrigin != null)
                  _PendingRow(position: total + 1, origin: round.nextOrigin!),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE1E8F5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    round.state == 'closed'
                        ? '${round.finishedCount} de $total terminados · ronda completa'
                        : '${round.finishedCount} de $total terminados',
                    style: const TextStyle(color: AppColors.textMedium, fontSize: 12.5),
                  ),
                ),
                if (canAdd)
                  InkWell(
                    onTap: onAddMovement,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('+ Agregar movimiento',
                          style: TextStyle(
                              color: AppColors.royalBlue,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un movimiento dentro de la tarjeta de la ronda: punto + línea de tiempo.
class _MovementRow extends StatelessWidget {
  final TripRoundMovement movement;
  final String label;
  final String? registered;
  final bool isFirst;
  final bool isLast;
  final bool hasLine;
  final VoidCallback onTap;

  const _MovementRow({
    required this.movement,
    required this.label,
    required this.registered,
    required this.isFirst,
    required this.isLast,
    required this.hasLine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trip = movement.trip;
    final filled = isFirst || isLast;
    final color = isLast ? AppColors.navyBlue : AppColors.royalBlue;
    final meta = [
      if (trip.cargoType != null && trip.cargoType!.isNotEmpty) trip.cargoType!,
      if (trip.truckboxNum.isNotEmpty) 'Caja ${trip.truckboxNum}',
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Rail(color: color, filled: filled, hasLine: hasLine),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                  text: '#${trip.tripNumber}',
                                  style: const TextStyle(color: AppColors.royalBlue)),
                              TextSpan(text: ' · $label'),
                            ]),
                            style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        StatusBadge(
                          code: trip.statusCode,
                          label: trip.statusLabel.isNotEmpty ? trip.statusLabel : 'Desconocido',
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${trip.origin.isNotEmpty ? trip.origin : '—'} → ${trip.destination.isNotEmpty ? trip.destination : '—'}',
                      style: const TextStyle(color: AppColors.textDark, fontSize: 13),
                    ),
                    if (meta.isNotEmpty || registered != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text.rich(
                          TextSpan(children: [
                            if (meta.isNotEmpty) TextSpan(text: meta),
                            if (meta.isNotEmpty && registered != null) const TextSpan(text: ' · '),
                            if (registered != null)
                              TextSpan(
                                  text: 'registrado $registered',
                                  style: const TextStyle(color: AppColors.textLight)),
                          ]),
                          style: const TextStyle(color: AppColors.textMedium, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Riel de la línea de tiempo: punto del movimiento y línea hacia el siguiente.
class _Rail extends StatelessWidget {
  final Color color;
  final bool filled;
  final bool hasLine;
  const _Rail({required this.color, required this.filled, required this.hasLine});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Column(
        children: [
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? color : Colors.white,
              border: Border.all(color: color, width: 3),
            ),
          ),
          if (hasLine) Expanded(child: Container(width: 3, color: AppColors.lightBlue)),
        ],
      ),
    );
  }
}

/// Siguiente movimiento todavía sin crear de una ronda abierta (atenuado).
class _PendingRow extends StatelessWidget {
  final int position;
  final String origin;
  const _PendingRow({required this.position, required this.origin});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.75,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Rail(color: AppColors.textLight, filled: false, hasLine: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('$position · Siguiente',
                            style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.fieldFill, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Sin crear',
                            style: TextStyle(
                                color: AppColors.textMedium,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('$origin → ¿?',
                      style: const TextStyle(color: AppColors.textDark, fontSize: 13)),
                  const Text('Se agrega cuando se necesite',
                      style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
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
            const Icon(Icons.route_outlined, size: 56, color: AppColors.royalBlue),
            const SizedBox(height: 14),
            const Text(
              'Aún no hay viajes',
              style: TextStyle(
                color: AppColors.navyBlue,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cuando se registren viajes, aparecerán aquí.',
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
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.errorRed),
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
