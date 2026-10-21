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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurfaceBg,
      appBar: SxAppBar(title: const Text(
          'Historial de viajes',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ), actions: [
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
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: _controller.trips.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
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

              final trip = _controller.trips[index];
              return _TripCard(
                trip: trip,
                onTap: () => Get.toNamed(
                  RouteNames.tripEventHistory,
                  arguments: trip.id,
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripSummary trip;
  final VoidCallback onTap;
  const _TripCard({required this.trip, required this.onTap});

  // "2026-08-21 00:00:00" → "21 Agosto, 00:00".
  String? get _completionLabel {
    final raw = trip.completionDatetime;
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat("d MMMM, HH:mm", 'es_ES').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.electricBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.route_rounded,
                    color: AppColors.royalBlue, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Viaje #${trip.tripNumber}',
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          code: trip.statusCode,
                          label: trip.statusLabel.isNotEmpty
                              ? trip.statusLabel
                              : 'Desconocido',
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (trip.truckboxNum.isNotEmpty)
                      _InfoRow(label: 'Caja', value: trip.truckboxNum),
                    if (trip.operatorName != null && trip.operatorName!.isNotEmpty)
                      _InfoRow(label: 'Operador', value: trip.operatorName!),
                    _InfoRow(
                        label: 'Origen',
                        value: trip.origin.isNotEmpty ? trip.origin : '—'),
                    _InfoRow(
                        label: 'Destino',
                        value: trip.destination.isNotEmpty
                            ? trip.destination
                            : '—'),
                    if (trip.line != null && trip.line!.isNotEmpty)
                      _InfoRow(label: 'Línea', value: trip.line!),
                    if (trip.cargoType != null)
                      _InfoRow(label: 'Tipo de carga', value: trip.cargoType!),
                    if (trip.routeType != null)
                      _InfoRow(label: 'Tipo', value: trip.routeType!),
                    if (_completionLabel != null)
                      _InfoRow(
                          label: 'Fecha de finalización',
                          value: _completionLabel!),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textLight, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textMedium,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
            const Icon(Icons.route_outlined,
                size: 56, color: AppColors.royalBlue),
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
