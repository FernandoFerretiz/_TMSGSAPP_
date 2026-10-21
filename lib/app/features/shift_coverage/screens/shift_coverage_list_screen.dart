import '../../../core/design/sx_design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../../../config/routes/route_names.dart';
import '../controllers/shift_coverage_controller.dart';
import '../models/shift_coverage.dart';

const _kSurfaceBg = Color(0xFFF3F6FC);

/// Lista de coberturas de turno, con acción para finalizar las activas.
/// Misma tabla que ve el admin web (responsible_schedule_overrides).
class ShiftCoverageListScreen extends StatefulWidget {
  const ShiftCoverageListScreen({super.key});

  @override
  State<ShiftCoverageListScreen> createState() => _ShiftCoverageListScreenState();
}

class _ShiftCoverageListScreenState extends State<ShiftCoverageListScreen> {
  late final ShiftCoverageController _controller;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ShiftCoverageController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.loadCoverages());
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
      _controller.loadMoreCoverages();
    }
  }

  Future<void> _goToStart() async {
    final created = await Get.toNamed(RouteNames.shiftCoverageStart);
    if (created == true) _controller.loadCoverages();
  }

  Future<void> _confirmFinish(ShiftCoverage coverage) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Finalizar cobertura', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          '¿Confirmas que ${coverage.user.name} deja de cubrir a '
          '${coverage.coversUser?.name ?? "este usuario"} a partir de ahora?',
          style: const TextStyle(color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.royalBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Finalizar', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) _controller.finishCoverage(coverage.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurfaceBg,
      appBar: SxAppBar(title: const Text(
          'Cobertura de turno',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToStart,
        backgroundColor: AppColors.royalBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Cubrir turno', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Obx(() {
        if (_controller.isLoadingCoverages.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.royalBlue),
          );
        }

        if (_controller.coveragesErrorMessage.value.isNotEmpty) {
          return _ErrorState(
            message: _controller.coveragesErrorMessage.value,
            onRetry: _controller.loadCoverages,
          );
        }

        if (_controller.coverages.isEmpty) {
          return const _EmptyState();
        }

        return RefreshIndicator(
          color: AppColors.royalBlue,
          onRefresh: _controller.loadCoverages,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: _controller.coverages.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == _controller.coverages.length) {
                return Obx(() => _controller.isLoadingMore.value
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.royalBlue, strokeWidth: 2),
                        ),
                      )
                    : const SizedBox.shrink());
              }

              final coverage = _controller.coverages[index];
              return _CoverageCard(
                coverage: coverage,
                onFinish: () => _confirmFinish(coverage),
                isFinishing: _controller.isFinishing(coverage.id),
              );
            },
          ),
        );
      }),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  final ShiftCoverage coverage;
  final VoidCallback onFinish;
  final bool isFinishing;

  const _CoverageCard({
    required this.coverage,
    required this.onFinish,
    required this.isFinishing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${coverage.user.name} → ${coverage.coversUser?.name ?? "N/A"}',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(isActive: coverage.isActive),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${_formatDateTime(coverage.startsAt)} → '
                  '${coverage.endsAt != null ? _formatDateTime(coverage.endsAt) : "en curso"}',
                  style: const TextStyle(color: AppColors.textMedium, fontSize: 12.5, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (coverage.reason != null && coverage.reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              coverage.reason!,
              style: const TextStyle(color: AppColors.textLight, fontSize: 12.5),
            ),
          ],
          if (coverage.isActive) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isFinishing ? null : onFinish,
                icon: isFinishing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.royalBlue),
                      )
                    : const Icon(Icons.flag_rounded, size: 16, color: AppColors.royalBlue),
                label: const Text('Finalizar', style: TextStyle(color: AppColors.royalBlue, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.royalBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? d) {
    if (d == null) return '—';
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month/${d.year} $hour:$minute';
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;
  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF2E7D32) : AppColors.textLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Activa' : 'Finalizada',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
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
            const Icon(Icons.swap_horiz_rounded, size: 56, color: AppColors.royalBlue),
            const SizedBox(height: 14),
            const Text(
              'Aún no hay coberturas',
              style: TextStyle(color: AppColors.navyBlue, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cuando registres una cobertura de turno, aparecerá aquí.',
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
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMedium, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.royalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
