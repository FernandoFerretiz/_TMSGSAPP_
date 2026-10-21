import '../../../core/design/sx_design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/routes/route_names.dart';
import '../../../core/config/app_config.dart';
import '../../../shared_components/sultan_share_dialog.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/trip_history_controller.dart';
import '../data/trip_history_service.dart';
import '../models/trip_event.dart';
import '../models/trip_evidence_file.dart';
import '../models/trip_summary.dart';
import '../utils/trip_event_share_templates.dart';
import '../widgets/evidence_share_button.dart';
import '../widgets/status_badge.dart';
import '../widgets/trip_event_detail_sheet.dart';

const _kSurfaceBg = Color(0xFFF3F6FC);

/// Timeline de eventos (cambios de estado + incidencias) de un viaje,
/// agrupados por fecha. Recibe el tripId como Get.arguments.
class TripEventHistoryScreen extends StatefulWidget {
  const TripEventHistoryScreen({super.key});

  @override
  State<TripEventHistoryScreen> createState() =>
      _TripEventHistoryScreenState();
}

class _TripEventHistoryScreenState extends State<TripEventHistoryScreen> {
  late final TripHistoryController _controller;
  late final int _tripId;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<TripHistoryController>();
    _tripId = int.tryParse(Get.arguments?.toString() ?? '') ?? 0;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _controller.loadHistory(_tripId));
  }

  Future<void> _openOperatorSheet() async {
    final TripOperatorCatalog catalog;
    try {
      catalog = await _controller.loadOperatorOptions(_tripId);
    } catch (_) {
      Get.snackbar('Operador', 'No se pudo cargar la lista de operadores.');
      return;
    }
    if (!mounted) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _OperatorChangeSheet(
        catalog: catalog,
        onSubmit: (operatorId, confirmWithoutTracking) =>
            _controller.changeOperator(_tripId, operatorId,
                confirmWithoutTracking: confirmWithoutTracking),
      ),
    );

    if (changed == true) {
      Get.snackbar('Operador actualizado', 'El viaje se reasignó al nuevo operador.');
    }
  }

  Future<void> _openStatusSheet() async {
    final TripStatusCatalog catalog;
    try {
      catalog = await _controller.loadStatusCatalog(_tripId);
    } catch (_) {
      Get.snackbar('Estatus', 'No se pudo cargar el catálogo de estatus.');
      return;
    }
    if (!mounted) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StatusChangeSheet(
        catalog: catalog,
        onSubmit: (statusId, comments) =>
            _controller.changeStatus(_tripId, statusId, comments),
      ),
    );

    if (changed == true) {
      Get.snackbar('Estatus actualizado', 'El viaje cambió de estatus.');
    }
  }

  Future<void> _openEvidenceLink(String link) async {
    final uri = Uri.tryParse(link);
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      Get.snackbar('No se pudo abrir', 'El link de evidencias no es válido.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurfaceBg,
      appBar: SxAppBar(title: const Text(
          'Historial del viaje',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ), actions: [
          Obx(() {
            final link = _controller.tripHeader.value?.evidenceLink;
            if (link == null || link.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.open_in_browser_rounded),
              tooltip: 'Abrir link de evidencias',
              onPressed: () => _openEvidenceLink(link),
            );
          }),
          if (!Get.find<AuthController>().hasRole('operador'))
            IconButton(
              icon: const Icon(Icons.person_search_rounded),
              tooltip: 'Cambiar operador',
              onPressed: _openOperatorSheet,
            ),
          if (!Get.find<AuthController>().hasRole('operador'))
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Cambiar estatus',
              onPressed: _openStatusSheet,
            ),
          Obx(() {
            final status = _controller.tripHeader.value?.statusCode;
            final canEdit = status != null && !['finished', 'cancelled'].contains(status);
            if (!canEdit) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar viaje',
              onPressed: () async {
                final updated = await Get.toNamed(RouteNames.circuitTripForm, arguments: _tripId);
                if (updated == true) {
                  _controller.loadHistory(_tripId);
                }
              },
            );
          }),
        ]),
      body: Obx(() {
        if (_controller.isLoadingHistory.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.royalBlue),
          );
        }

        if (_controller.historyErrorMessage.value.isNotEmpty) {
          return _ErrorState(
            message: _controller.historyErrorMessage.value,
            onRetry: () => _controller.loadHistory(_tripId),
          );
        }

        final trip = _controller.tripHeader.value;
        final events = _controller.events;

        return Column(
          children: [
            if (trip != null) _TripHeaderCard(trip: trip),
            if (trip != null)
              Expanded(
                child: events.isEmpty
                    ? const _EmptyState()
                    : _Timeline(events: events, trip: trip),
              ),
          ],
        );
      }),
    );
  }
}

class _TripHeaderCard extends StatelessWidget {
  final TripSummary trip;
  const _TripHeaderCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.electricBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.route_rounded,
                    color: AppColors.royalBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${trip.origin.isNotEmpty ? trip.origin : '—'} → '
                  '${trip.destination.isNotEmpty ? trip.destination : '—'}',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              StatusBadge(
                code: trip.statusCode,
                label: trip.statusLabel.isNotEmpty
                    ? trip.statusLabel
                    : 'Desconocido',
              ),
              const SizedBox(width: 10),
              const Icon(Icons.local_shipping_outlined,
                  size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(
                trip.truckboxNum.isNotEmpty ? trip.truckboxNum : '—',
                style: const TextStyle(
                  color: AppColors.textMedium,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '#${trip.id}',
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => SultanShareDialog.showTextOnly(
                context,
                text: tripDetailShareText(trip),
              ),
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('Compartir detalle del viaje'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.royalBlue,
                side: const BorderSide(color: AppColors.fieldBorder),
                padding: const EdgeInsets.symmetric(vertical: 11),
                textStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Message pre-filled into WhatsApp/Telegram when sharing evidence for
/// [trip], optionally tagged with the specific file's [evidenceLabel].
String _shareMessageFor(TripSummary trip, {String? evidenceLabel}) {
  final route = '${trip.origin.isNotEmpty ? trip.origin : '—'} → '
      '${trip.destination.isNotEmpty ? trip.destination : '—'}';
  final buffer = StringBuffer('Viaje #${trip.id}\n$route');
  if (evidenceLabel != null && evidenceLabel.isNotEmpty) {
    buffer.write('\n$evidenceLabel');
  }
  return buffer.toString();
}


class _Timeline extends StatelessWidget {
  final List<TripEvent> events;
  final TripSummary? trip;
  const _Timeline({required this.events, required this.trip});

  Map<String, List<TripEvent>> _groupByDate() {
    final groups = <String, List<TripEvent>>{};
    for (final event in events) {
      final key = event.timestamp != null
          ? DateFormat('yyyy-MM-dd').format(event.timestamp!)
          : 'sin_fecha';
      groups.putIfAbsent(key, () => []).add(event);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate();
    final dateKeys = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: dateKeys.length,
      itemBuilder: (context, groupIndex) {
        final key = dateKeys[groupIndex];
        final groupEvents = groups[key]!;
        final label = key == 'sin_fecha'
            ? 'Sin fecha'
            : DateFormat("d 'de' MMMM").format(DateTime.parse(key));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 6, left: 2),
              child: Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFFE4E7F0),
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(groupEvents.length, (i) {
              final isLast = groupIndex == dateKeys.length - 1 &&
                  i == groupEvents.length - 1;
              return _TimelineItem(
                event: groupEvents[i],
                showLine: !isLast,
                trip: trip,
              );
            }),
          ],
        );
      },
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final TripEvent event;
  final bool showLine;
  final TripSummary? trip;
  const _TimelineItem({
    required this.event,
    required this.showLine,
    required this.trip,
  });

  Color get _color => switch (event.type) {
        TripEventType.incident => const Color(0xFFDC2626),
        TripEventType.stop => const Color(0xFFD97706),
        TripEventType.status => const Color(0xFF2563EB),
      };

  IconData get _icon => switch (event.type) {
        TripEventType.incident => Icons.warning_amber_rounded,
        TripEventType.stop => Icons.pause_circle_outline_rounded,
        TripEventType.status => Icons.swap_horiz_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 16, color: _color),
              ),
              if (showLine)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: const Color(0xFFE4E7F0),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: trip == null
                    ? null
                    : () => TripEventDetailSheet.show(
                          context,
                          trip: trip!,
                          event: event,
                        ),
                child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (event.subtitle != null &&
                        event.subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.subtitle!,
                        style: const TextStyle(
                          color: AppColors.textMedium,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (event.actorName != null &&
                            event.actorName!.trim().isNotEmpty) ...[
                          const Icon(Icons.person_outline_rounded,
                              size: 13, color: AppColors.textLight),
                          const SizedBox(width: 4),
                          Text(
                            event.actorName!,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (event.timestamp != null) ...[
                          const Icon(Icons.access_time_rounded,
                              size: 13, color: AppColors.textLight),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('HH:mm').format(event.timestamp!),
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                    ],
                ),
                ),
                ),
              ),
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
            const Icon(Icons.history_rounded,
                size: 56, color: AppColors.royalBlue),
            const SizedBox(height: 14),
            const Text(
              'Sin eventos registrados',
              style: TextStyle(
                color: AppColors.navyBlue,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Los cambios de estado y problemas de este viaje\naparecerán aquí.',
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


/// Selector de estatus (cualquiera, sin restricción de flujo) con
/// comentario opcional. Cierra con true si el cambio se guardó.
class _StatusChangeSheet extends StatefulWidget {
  final TripStatusCatalog catalog;
  final Future<String?> Function(int statusId, String? comments) onSubmit;

  const _StatusChangeSheet({required this.catalog, required this.onSubmit});

  @override
  State<_StatusChangeSheet> createState() => _StatusChangeSheetState();
}

class _StatusChangeSheetState extends State<_StatusChangeSheet> {
  int? _selectedId;
  final _commentsCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _commentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final comments = _commentsCtrl.text.trim();
    final error = await widget.onSubmit(_selectedId!, comments.isEmpty ? null : comments);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.catalog.currentStatusId;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cambiar estatus',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Puedes elegir cualquier estatus, sin seguir el flujo normal.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            for (final s in widget.catalog.statuses)
              ListTile(
                enabled: !_saving && s.id != current,
                onTap: () => setState(() => _selectedId = s.id),
                leading: Icon(
                  _selectedId == s.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _selectedId == s.id ? AppColors.royalBlue : null,
                ),
                title: Text(s.name),
                subtitle: s.id == current ? const Text('Estatus actual') : null,
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentsCtrl,
              enabled: !_saving,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedId == null || _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar estatus'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja para reasignar el viaje (y su caja) a otro operador del mismo
/// transportista. Es la misma acción que "Asignar operador" del ERP.
class _OperatorChangeSheet extends StatefulWidget {
  final TripOperatorCatalog catalog;
  final Future<String?> Function(int operatorId, bool confirmWithoutTracking)
      onSubmit;

  const _OperatorChangeSheet({required this.catalog, required this.onSubmit});

  @override
  State<_OperatorChangeSheet> createState() => _OperatorChangeSheetState();
}

class _OperatorChangeSheetState extends State<_OperatorChangeSheet> {
  int? _selectedId;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_selectedId == null) return;

    final selected =
        widget.catalog.operators.firstWhere((o) => o.id == _selectedId);
    final withoutTracking = !selected.trackingActive;

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSubmit(_selectedId!, withoutTracking);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.catalog.currentOperatorId;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cambiar operador',
                  style: TextStyle(
                      color: AppColors.navyBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                  'El viaje y su caja pasan al operador elegido. El nuevo '
                  'operador debe tener el rastreo activo; el anterior queda '
                  'libre para detener el suyo.',
                  style: TextStyle(color: AppColors.textMedium, fontSize: 12.5)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in widget.catalog.operators)
                      ListTile(
                        enabled: !_saving && o.id != current,
                        onTap: () => setState(() => _selectedId = o.id),
                        leading: Icon(
                          _selectedId == o.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: _selectedId == o.id
                              ? AppColors.royalBlue
                              : null,
                        ),
                        title: Text(o.name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          o.id == current
                              ? 'Operador actual'
                              : o.trackingActive
                                  ? 'Rastreo activo'
                                  : 'Sin rastreo activo',
                          style: TextStyle(
                              color: o.id == current || o.trackingActive
                                  ? AppColors.textMedium
                                  : AppColors.errorRed,
                              fontSize: 12),
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.errorRed,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selectedId == null || _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Cambiar operador'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
