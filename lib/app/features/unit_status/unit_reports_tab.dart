import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../core/design/sx_design.dart';
import '../../core/network/api_client.dart';
import '../../shared_components/sultan_share_dialog.dart';
import 'unit_card.dart';
import 'unit_status_models.dart';

/// Pestaña "Reportes anteriores": una tarjeta por reporte generado, con quién
/// lo creó y cuándo, y los botones Ver (solo lectura) y Compartir (enlace único).
class UnitReportsTab extends StatefulWidget {
  /// Se incrementa al generar un reporte para que la lista se actualice.
  final ValueNotifier<int> refreshSignal;
  const UnitReportsTab({super.key, required this.refreshSignal});

  @override
  State<UnitReportsTab> createState() => _UnitReportsTabState();
}

class _UnitReportsTabState extends State<UnitReportsTab>
    with AutomaticKeepAliveClientMixin {
  final List<UnitReportSummary> _reports = [];
  int _page = 0;
  int _lastPage = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal.addListener(_reload);
    _load(reset: true);
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load(reset: true, silent: true);

  Future<void> _load({bool reset = false, bool silent = false}) async {
    if (reset) {
      _page = 0;
      if (!silent) setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final next = reset ? 1 : _page + 1;
      final res = await Get.find<ApiClient>()
          .dio
          .get('/api/mobile/unit-reports', queryParameters: {'page': next});
      final items = (res.data['data'] as List? ?? [])
          .map((e) => UnitReportSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = (res.data['meta'] as Map<String, dynamic>?) ?? const {};

      if (reset) _reports.clear();
      _reports.addAll(items);
      _page = (meta['current_page'] as num?)?.toInt() ?? next;
      _lastPage = (meta['last_page'] as num?)?.toInt() ?? _page;
      _error = null;
    } catch (_) {
      _error = 'No se pudieron cargar los reportes.';
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.royalBlue));
    }

    return RefreshIndicator(
      color: AppColors.royalBlue,
      onRefresh: () => _load(reset: true, silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (_error != null)
            _Empty(icon: Icons.error_outline_rounded, text: _error!)
          else if (_reports.isEmpty)
            const _Empty(
              icon: Icons.history_rounded,
              text: 'Aún no hay reportes generados.',
            )
          else ...[
            for (final r in _reports) _ReportCard(report: r),
            if (_page < _lastPage)
              Center(
                child: TextButton(
                  onPressed: _loadingMore ? null : () => _load(),
                  child: _loadingMore
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Ver más'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final UnitReportSummary report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final when = report.generatedAt == null
        ? '—'
        : DateFormat("d MMM y, HH:mm", 'es').format(report.generatedAt!);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(report.clientName,
              style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _Line(
              icon: Icons.person_outline_rounded,
              text: 'Creado por ${report.createdByName ?? '—'}'),
          const SizedBox(height: 4),
          _Line(icon: Icons.access_time_rounded, text: when),
          const SizedBox(height: 4),
          _Line(
            icon: Icons.local_shipping_outlined,
            text:
                '${report.unitsCount} ${report.unitsCount == 1 ? 'unidad' : 'unidades'}',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Get.to(() => UnitReportDetailScreen(report: report)),
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('Ver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  // Se comparte solo el enlace único del reporte.
                  onPressed: () => SultanShareDialog.showTextOnly(context,
                      text: report.shareUrl),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Compartir'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.royalBlue,
                    side: const BorderSide(color: AppColors.royalBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Line({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textLight),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: AppColors.textMedium,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.royalBlue),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textMedium, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}

/// Un reporte guardado, en solo lectura: las mismas tarjetas de cuando se
/// registró, sin poder editarlas.
class UnitReportDetailScreen extends StatefulWidget {
  final UnitReportSummary report;
  const UnitReportDetailScreen({super.key, required this.report});

  @override
  State<UnitReportDetailScreen> createState() => _UnitReportDetailScreenState();
}

class _UnitReportDetailScreenState extends State<UnitReportDetailScreen> {
  List<UnitStatusItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Get.find<ApiClient>()
          .dio
          .get('/api/mobile/unit-reports/${widget.report.id}');
      _items = (res.data['items'] as List? ?? [])
          .map((e) => UnitStatusItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _error = 'No se pudo cargar el reporte.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final when = r.generatedAt == null
        ? '—'
        : DateFormat("d MMM y, HH:mm", 'es').format(r.generatedAt!);

    return Scaffold(
      backgroundColor: Sx.pageBg,
      appBar: SxAppBar(
        title: Text(r.clientName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'Compartir',
            icon: const Icon(Icons.share_rounded),
            onPressed: () =>
                SultanShareDialog.showTextOnly(context, text: r.shareUrl),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.royalBlue))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 12),
                  child: Text(
                    'Generado el $when por ${r.createdByName ?? '—'} · '
                    '${r.unitsCount} ${r.unitsCount == 1 ? 'unidad' : 'unidades'}',
                    style: const TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                if (_error != null)
                  _Empty(icon: Icons.error_outline_rounded, text: _error!)
                else
                  for (final item in _items)
                    UnitStatusCard(item: item, showElapsed: false),
              ],
            ),
    );
  }
}
