import '../../../core/design/sx_design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/routes/route_names.dart';
import '../../../core/config/app_config.dart';
import '../../../core/location/location_permission_service.dart';
import '../../../shared_components/sultan_share_dialog.dart';
import '../../auth/widgets/gradient_button.dart';
import '../controllers/trip_controller.dart';
import '../models/trip_model.dart';
import '../utils/fianza_share_template.dart';
import '../widgets/evidence_style.dart';
import '../widgets/trip_evidence_section.dart';
import '../widgets/location_permission_gate.dart';
import '../widgets/photo_source_sheet.dart';

class StartTripScreen extends StatefulWidget {
  const StartTripScreen({super.key});

  @override
  State<StartTripScreen> createState() => _StartTripScreenState();
}

class _StartTripScreenState extends State<StartTripScreen>
    with WidgetsBindingObserver {
  final _notesCtrl = TextEditingController();

  late final TripController _tc;
  // null = aún consultando; el operador no puede llegar al checklist ni al
  // botón de confirmar mientras esto no sea true — "activar ubicación
  // siempre" es requisito para poder iniciar el viaje, no algo que se pida
  // recién al arrancar el tracking (momento en el que ya se cambió el
  // estatus en el backend).
  bool? _hasLocationPermission;

  @override
  void initState() {
    super.initState();
    _tc = Get.find<TripController>();
    WidgetsBinding.instance.addObserver(this);
    // Deferred to after the current frame: resetStartTripFlow()/
    // refreshRequirements() mutate Rx state synchronously, and calling them
    // straight from initState() can hit an in-progress Obx build elsewhere
    // in the tree (e.g. when navigating here quickly) — Flutter throws
    // "setState()/markNeedsBuild() called during build" on the very first
    // line of _fetchActiveTrip(), before its try/finally, which used to
    // leave isLoading stuck at true forever (permanent loader).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tc.resetStartTripFlow();
      // Requirements/checklist come from the backend for the trip's current
      // state — the cached copy from whenever the app last polled may be
      // stale, and acting on stale requirements can skip steps that are
      // actually needed. Always get a fresh read before showing this screen.
      _tc.refreshRequirements();
      _checkLocationPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notesCtrl.dispose();
    super.dispose();
  }

  // El flujo para conceder "siempre" suele mandar al operador a Ajustes del
  // sistema (openAppSettings/openLocationSettings) — al volver a la app hay
  // que re-consultar, no queda otra señal de que ya lo activó.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final granted = await LocationPermissionService.hasTrackingPermission();
    if (mounted) setState(() => _hasLocationPermission = granted);
  }

  Future<void> _requestLocationPermission() async {
    await LocationPermissionService.ensureTrackingPermission();
    await _checkLocationPermission();
  }

  Future<void> _confirm() async {
    final success = await _tc.startTripWithEvidence(
      notes: _notesCtrl.text.trim(),
    );
    if (success && mounted) Get.back();
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
    final trip = _tc.activeTrip;

    return Scaffold(
      backgroundColor: Ev.pageBg,
      appBar: SxAppBar(
        title: const Text('Iniciar viaje'),
        actions: [
          Obx(() {
            final link = _tc.activeTrip?.evidenceLink;
            if (link == null || link.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.open_in_browser_rounded),
              tooltip: 'Abrir link de evidencias',
              onPressed: () => _openEvidenceLink(link),
            );
          }),
        ]),
      body: Obx(() {
        if (_tc.isLoading.value || _hasLocationPermission == null) {
          return const Center(
            child: CircularProgressIndicator(color: Ev.orangeDark),
          );
        }

        if (_hasLocationPermission == false) {
          return LocationPermissionGate(onEnable: _requestLocationPermission);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (trip != null) _EvHero(trip: trip),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (trip != null) ...[
                      _TripInfoPanel(trip: trip),
                      const SizedBox(height: 16),
                    ],
                    _EvStage(
                      number: '1',
                      title: 'Inicio del viaje',
                      description:
                          'Evidencias al enganchar / iniciar el movimiento',
                      counter: Obx(() => Text(
                            _filesCounterLabel(
                                _tc.evidence.value?.startCount ?? 0),
                            style: const TextStyle(
                                color: Ev.gray700,
                                fontSize: 12,
                                fontWeight: FontWeight.w800),
                          )),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TripEvidenceSection(tc: _tc),
                          Obx(() {
                            if (!_tc.needsAdditionalMaterialsStep) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _MaterialsCard(tc: _tc),
                            );
                          }),
                          _NotesBox(controller: _notesCtrl),
                          const SizedBox(height: 14),
                          Obx(() {
                            final err = _tc.errorMessage.value;
                            if (err.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ErrorRow(err),
                            );
                          }),
                          Obx(() {
                            final ready = _tc.evidenceStartReady;
                            return _EvActionBox(
                              title: '¿Ya vas a salir?',
                              subtitle: ready
                                  ? 'Asegúrate de cargar los documentos y las '
                                      'evidencias del viaje. Al iniciar se '
                                      'comenzará a compartir tu ubicación en '
                                      'tiempo real.'
                                  : (_tc.evidence.value?.gap ??
                                      'Asegúrate de cargar los documentos y '
                                          'las evidencias del viaje.'),
                              label: 'Iniciar viaje',
                              color: Ev.orangeDark,
                              background: Ev.orangeSoft,
                              borderColor: const Color(0xFFD6E4FF),
                              loading: _tc.isChangingStatus.value,
                              onPressed: (!ready || _tc.isChangingStatus.value)
                                  ? null
                                  : _confirm,
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'La información y evidencias se asociarán '
                      'automáticamente al viaje en SultánX TMS.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Ev.gray500, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Change-Status screen ─────────────────────────────────────────────────────

class ChangeStatusScreen extends StatefulWidget {
  const ChangeStatusScreen({super.key});

  @override
  State<ChangeStatusScreen> createState() => _ChangeStatusScreenState();
}

class _ChangeStatusScreenState extends State<ChangeStatusScreen> {
  final _notesCtrl = TextEditingController();

  late final TripController _tc;

  @override
  void initState() {
    super.initState();
    _tc = Get.find<TripController>();
    // See StartTripScreen.initState for why this is deferred — calling
    // Rx-mutating methods straight from initState() can throw "setState()/
    // markNeedsBuild() called during build" when navigating here quickly,
    // which left isLoading permanently stuck (loader that never goes away).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Same shared pre-flow state (documents + checklist) as StartTripScreen —
      // reset it so a previous start/finish attempt doesn't leak in.
      _tc.resetStartTripFlow();
      // Get the trip's current requirements fresh — see StartTripScreen for why.
      _tc.refreshRequirements();
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmFinish() async {
    final confirmed = await _showConfirmDialog();
    if (confirmed != true) return;

    final success = await _tc.finishTripWithEvidence(
      notes: _notesCtrl.text.trim(),
    );
    if (success && mounted) Get.back();
  }

  Future<bool?> _showConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Finalizar viaje',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          '¿Confirmas que el viaje ha concluido? Se detendrá el '
          'seguimiento de ubicación.',
          style: TextStyle(color: AppColors.textMedium),
        ),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Finalizar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = _tc.activeTrip;

    return Obx(() {
      final resp = _tc.activeTripResponse;
      final canFinish = resp?.canFinishTrip ?? false;
      final hasOptionalActions = resp != null &&
          (resp.canReportToClient ||
              resp.canMarkRampAssigned ||
              resp.canMarkLoadingUnloading);

      final evidence = _tc.evidence.value;
      final requiresEnd = evidence?.requiresEndEvidence ?? true;

      return Scaffold(
        backgroundColor: Ev.pageBg,
        appBar: _evAppBar(
          actions: [
            Builder(builder: (_) {
              final link = _tc.activeTrip?.evidenceLink;
              if (link == null || link.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.open_in_browser_rounded),
                tooltip: 'Abrir link de evidencias',
                onPressed: () async {
                  final uri = Uri.tryParse(link);
                  final opened = uri != null &&
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!opened) {
                    Get.snackbar('No se pudo abrir',
                        'El link de evidencias no es válido.');
                  }
                },
              );
            }),
          ],
        ),
        body: _tc.isLoading.value
            ? const Center(
                child: CircularProgressIndicator(color: Ev.orangeDark),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (trip != null) _EvHero(trip: trip),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (trip != null) ...[
                            _TripInfoPanel(trip: trip),
                            const SizedBox(height: 16),
                          ],

                          // Los 3 estados opcionales de patio — no
                          // obligatorios, se pueden saltar; el backend decide
                          // cuáles aplican en este punto (orden fijo:
                          // reportado -> rampa -> carga). Cada botón solo abre
                          // la pantalla de foto+comentario para esa acción
                          // puntual — no se pide nada por adelantado aquí.
                          if (hasOptionalActions) ...[
                            EvBox(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Registrar avance',
                                      style: TextStyle(
                                          color: Ev.text,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  const Text(
                                      'Opcional: registra en qué punto del '
                                      'patio vas.',
                                      style: TextStyle(
                                          color: Ev.gray500, fontSize: 12)),
                                  const SizedBox(height: 12),
                                  if (resp.canReportToClient)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _EvTapCard(
                                        icon: Icons.forum_outlined,
                                        title: 'Reportado con cliente',
                                        description: 'Toca para registrar',
                                        onTap: () => Get.to(
                                            () => TripProgressActionScreen(
                                                  title: 'Reportado con cliente',
                                                  action: _tc.reportToClient,
                                                )),
                                      ),
                                    ),
                                  if (resp.canMarkRampAssigned)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _EvTapCard(
                                        icon: Icons.warehouse_outlined,
                                        title: 'Rampa asignada',
                                        description: 'Toca para registrar',
                                        onTap: () => Get.to(
                                            () => TripProgressActionScreen(
                                                  title: 'Rampa asignada',
                                                  action: _tc.markRampAssigned,
                                                )),
                                      ),
                                    ),
                                  if (resp.canMarkLoadingUnloading)
                                    _EvTapCard(
                                      icon: Icons.inventory_2_outlined,
                                      title: 'Cargando/Descargando',
                                      description: 'Toca para registrar',
                                      onTap: () => Get.to(
                                          () => TripProgressActionScreen(
                                                title: 'Cargando/Descargando',
                                                action:
                                                    _tc.markLoadingUnloading,
                                              )),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (canFinish)
                            _EvStage(
                              number: '2',
                              title: 'Final del viaje',
                              description: requiresEnd
                                  ? 'Evidencias de descarga / entrega'
                                  : 'No hay nada que evidenciar',
                              counter: requiresEnd
                                  ? Text(
                                      _filesCounterLabel(
                                          evidence?.endCount ?? 0),
                                      style: const TextStyle(
                                          color: Ev.gray700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800))
                                  : const SizedBox.shrink(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TripEvidenceSection(tc: _tc),
                                  _NotesBox(
                                    controller: _notesCtrl,
                                    title: 'Notas de llegada (opcional)',
                                    hint: 'Observaciones al cierre del viaje...',
                                  ),
                                  const SizedBox(height: 14),
                                  Obx(() {
                                    final err = _tc.errorMessage.value;
                                    if (err.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _ErrorRow(err),
                                    );
                                  }),
                                  Obx(() {
                                    final ready = _tc.evidenceFinishReady;
                                    final ev = _tc.evidence.value;
                                    final needsEvidence =
                                        ev?.requiresEndEvidence ?? true;
                                    final subtitle = !needsEvidence
                                        ? 'No se requiere evidencia para '
                                            'finalizar este viaje.'
                                        : (ev?.podRequired ?? false)
                                            ? 'Carga las evidencias y el POD '
                                                '(obligatorio) para finalizar '
                                                'el viaje.'
                                            : 'Carga al menos una evidencia de '
                                                'finalización y finaliza el '
                                                'viaje.';
                                    return _EvActionBox(
                                      title: needsEvidence
                                          ? '¿Ya entregaste la carga?'
                                          : '¿Ya llegaste a destino?',
                                      subtitle: ready
                                          ? '$subtitle Al finalizar se dejará '
                                              'de compartir tu ubicación.'
                                          : (ev?.gap ?? subtitle),
                                      label: 'Finalizar viaje',
                                      color: Ev.green,
                                      background: Ev.greenSoft,
                                      borderColor: const Color(0xFFBBF7D0),
                                      loading: _tc.isChangingStatus.value,
                                      onPressed:
                                          (!ready || _tc.isChangingStatus.value)
                                              ? null
                                              : _confirmFinish,
                                    );
                                  }),
                                ],
                              ),
                            ),
                          const SizedBox(height: 18),
                          const Text(
                            'La información y evidencias se asociarán '
                            'automáticamente al viaje en SultánX TMS.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Ev.gray500, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      );
    });
  }
}

// ── Trip progress action screen ──────────────────────────────────────────────
//
// Pantalla genérica para registrar cualquiera de los 3 estados opcionales de
// patio (reportado con cliente / rampa asignada / cargando-descargando): se
// abre solo al tocar el botón de esa acción específica en ChangeStatusScreen
// — no pide foto/comentario por adelantado en la lista, solo aquí. Al
// guardar, manda directo al home.

class TripProgressActionScreen extends StatefulWidget {
  final String title;
  final Future<bool> Function({String? notes, List<String> evidenceFilePaths})
      action;

  const TripProgressActionScreen({
    super.key,
    required this.title,
    required this.action,
  });

  @override
  State<TripProgressActionScreen> createState() =>
      _TripProgressActionScreenState();
}

class _TripProgressActionScreenState extends State<TripProgressActionScreen> {
  final _notesCtrl = TextEditingController();
  XFile? _photo;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await showPhotoSourceSheet(context);
    if (picked.isNotEmpty && mounted) {
      setState(() => _photo = picked.first);
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final notes = _notesCtrl.text.trim();
    final success = await widget.action(
      notes: notes.isEmpty ? null : notes,
      evidenceFilePaths: _photo == null ? const [] : [_photo!.path],
    );

    if (!mounted) return;

    if (success) {
      // A propósito manda al home (no Get.back()) — el registro ya quedó
      // guardado, no hay nada más que hacer en el flujo de cambio de estado.
      Get.offAllNamed(RouteNames.home);
      return;
    }

    setState(() {
      _isSaving = false;
      _error = 'No se pudo guardar. Intenta de nuevo.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FC),
      appBar: SxAppBar(title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        )),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Foto (opcional)',
              style: TextStyle(
                  color: AppColors.navyBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _PreStartCard(
              icon: Icons.camera_alt_outlined,
              title: 'Adjuntar foto',
              statusLabel:
                  _photo == null ? 'Sin foto seleccionada' : '1 foto seleccionada',
              isComplete: _photo != null,
              onTap: _pickPhoto,
            ),
            const SizedBox(height: 22),

            const Text(
              'Comentario (opcional)',
              style: TextStyle(
                  color: AppColors.navyBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textDark, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ej. "Ya me reporté, me dan acceso en 1 hora"...',
                hintStyle:
                    const TextStyle(color: AppColors.textLight, fontSize: 13),
                filled: true,
                fillColor: AppColors.fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.fieldBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.fieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.royalBlue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 30),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ErrorRow(_error!),
              ),

            GradientButton(
              label: 'Guardar',
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancelar',
                    style: TextStyle(color: AppColors.textMedium)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreStartCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String statusLabel;
  final bool isComplete;
  final VoidCallback onTap;
  final String? description;
  final String? actionLabel;

  const _PreStartCard({
    required this.icon,
    required this.title,
    required this.statusLabel,
    required this.isComplete,
    required this.onTap,
    this.description,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.fieldBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.navyBlue.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isComplete
                      ? AppColors.buttonGradient
                      : const LinearGradient(
                          colors: [Color(0xFFE8EEFF), Color(0xFFD6E4FF)],
                        ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: isComplete ? Colors.white : AppColors.royalBlue,
                    size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    if (description != null) ...[
                      const SizedBox(height: 3),
                      Text(description!,
                          style: const TextStyle(
                              color: AppColors.textMedium,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (isComplete)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.check_circle_rounded,
                                color: Color(0xFF2E7D32), size: 13),
                          ),
                        Flexible(
                          child: Text(statusLabel,
                              style: TextStyle(
                                  color: isComplete
                                      ? const Color(0xFF2E7D32)
                                      : AppColors.textLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (actionLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFE8EEFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(actionLabel!,
                      style: TextStyle(
                          color: isComplete
                              ? const Color(0xFF2E7D32)
                              : AppColors.royalBlue,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                )
              else
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }
}

String _filesCounterLabel(int count) =>
    count == 1 ? '1 archivo' : '$count archivos';

/// "Información del viaje": mismo panel de la página de evidencias —
/// trayecto, estado de la caja, caja/remolque y comentarios — con el aviso
/// de material de sujeción y el acceso a los datos para fianza.
class _TripInfoPanel extends StatelessWidget {
  final TripModel trip;
  const _TripInfoPanel({required this.trip});

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final box = trip.truckbox;
    final boxLines = <String>[
      if (box != null && _has(box.plates)) 'Placas: ${box.plates}',
      if (box != null && _has(box.serialNumber)) 'Serie: ${box.serialNumber}',
      if (box != null && _has(box.brand)) 'Marca: ${box.brand!.toUpperCase()}',
      if (box != null && _has(box.model)) 'Modelo: ${box.model}',
      if (box != null && _has(box.year)) 'Año: ${box.year}',
      if (box != null && _has(box.color)) 'Color: ${box.color}',
    ];

    final rows = <Widget>[
      if (_has(trip.routeType)) _row('Trayecto', Text(trip.routeType!, style: _value)),
      if (_has(trip.boxState)) _row('Estado de la caja', Text(trip.boxState!, style: _value)),
      if (box != null && _has(box.number))
        _row(
          'Caja / Remolque',
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: Ev.gray50,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(box.number!,
                    style: const TextStyle(
                        color: Ev.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                for (final line in boxLines)
                  Text(line,
                      style: const TextStyle(
                          color: Ev.gray700,
                          fontSize: 14,
                          height: 1.55,
                          fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      if (_has(trip.comments))
        _row('Comentarios',
            Text(trip.comments!, style: _value.copyWith(color: Ev.gray700, fontWeight: FontWeight.w500))),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Ev.radius),
        boxShadow: Sx.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Ev.gray200)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Información del viaje',
                    style: TextStyle(
                        color: Ev.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('Verifica estos datos antes de cargar evidencias.',
                    style: TextStyle(color: Ev.gray500, fontSize: 13)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i < rows.length - 1)
                    const Divider(height: 1, color: Ev.gray100),
                ],
                const SizedBox(height: 12),
                _FianzaShareButton(
                  isComplete: box?.isCompleteForFianza ?? false,
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
          if (trip.additionalMaterials.isNotEmpty)
            _MaterialAlert(materials: trip.additionalMaterials),
        ],
      ),
    );
  }

  static const _value =
      TextStyle(color: Ev.text, fontSize: 14, fontWeight: FontWeight.w700);

  Widget _row(String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    color: Ev.gray500,
                    fontSize: 11,
                    letterSpacing: 0.66,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            value,
          ],
        ),
      );
}

/// Aviso destacado de material de sujeción (`.material-alert` de la web).
class _MaterialAlert extends StatelessWidget {
  final List<AdditionalMaterialItem> materials;
  const _MaterialAlert({required this.materials});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Ev.orangeSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFBD38D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Ev.orange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('IMPORTANTE · MATERIAL DE SUJECIÓN',
                    style: TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                for (final m in materials)
                  Text(
                    [
                      if (m.quantity != null && m.quantity!.isNotEmpty)
                        m.quantity!,
                      m.name,
                      if (m.deliveryLocation != null &&
                          m.deliveryLocation!.isNotEmpty)
                        'en ${m.deliveryLocation}',
                    ].join(' '),
                    style: const TextStyle(
                        color: Color(0xFF78350F),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w700),
                  ),
                const Text('No olvides recogerlo antes de salir.',
                    style: TextStyle(
                        color: Color(0xFF78350F),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _monthsEs = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
  'septiembre', 'octubre', 'noviembre', 'diciembre',
];

String? _tripDateLabel(TripModel trip) {
  final raw = trip.departureDatetime ?? trip.assignmentDatetime;
  final date = raw == null ? null : DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (date == null) return null;
  return '${date.day} ${_monthsEs[date.month - 1]} ${date.year}';
}

/// Encabezado oscuro de la página de evidencias (`.hero`).
class _EvHero extends StatelessWidget {
  final TripModel trip;
  const _EvHero({required this.trip});

  String? get _destUrl {
    if (trip.destinationMapsUrl != null && trip.destinationMapsUrl!.isNotEmpty) {
      return trip.destinationMapsUrl;
    }
    if (trip.destinationLatitude != null && trip.destinationLongitude != null) {
      return 'https://www.google.com/maps?q='
          '${trip.destinationLatitude},${trip.destinationLongitude}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final date = _tripDateLabel(trip);
    final destUrl = _destUrl;

    Widget eyebrow(String text) => Text(text.toUpperCase(),
        style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w800));

    Widget tag(String text, {bool orange = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: orange ? 0.28 : 0.16),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(text.toUpperCase(),
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: Sx.headerGradient,
        borderRadius: BorderRadius.all(Radius.circular(26)),
      ),
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          eyebrow('Viaje${date != null ? ' · $date' : ''}'),
          const SizedBox(height: 6),
          Text('CAJA ${trip.truckboxNum.isEmpty ? '—' : trip.truckboxNum}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  height: 1,
                  letterSpacing: -1.9,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                  color: Color(0xFFE2E8F0), fontSize: 15, height: 1.4),
              children: [
                TextSpan(
                    text: trip.origin.isEmpty ? '—' : trip.origin,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                const TextSpan(text: ' → '),
                TextSpan(
                    text: trip.destination.isEmpty ? '—' : trip.destination,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (destUrl != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(destUrl),
                  mode: LaunchMode.externalApplication),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text('📍 Ver destino en el mapa',
                    style: TextStyle(
                        color: Ev.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ],
          const SizedBox(height: 17),
          eyebrow('Transportista'),
          const SizedBox(height: 6),
          Text(
              (trip.transporter != null && trip.transporter!.isNotEmpty)
                  ? trip.transporter!
                  : '—',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          if (trip.operatorName != null && trip.operatorName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text.rich(TextSpan(
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
              children: [
                const TextSpan(text: 'Operador: '),
                TextSpan(
                    text: trip.operatorName,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ],
            )),
          ],
          if ((trip.routeType?.isNotEmpty ?? false) ||
              (trip.boxState?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (trip.routeType?.isNotEmpty ?? false)
                  tag(trip.routeType!, orange: true),
                if (trip.boxState?.isNotEmpty ?? false)
                  tag('Caja ${trip.boxState}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Etapa numerada (`.stage`): cabecera gris con número, título y contador.
class _EvStage extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final Widget counter;
  final Widget child;

  const _EvStage({
    required this.number,
    required this.title,
    required this.description,
    required this.counter,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Ev.radius),
        boxShadow: Sx.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Ev.gray50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Ev.navy, shape: BoxShape.circle),
                  child: Text(number,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Ev.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(description,
                          style: const TextStyle(
                              color: Ev.gray500, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Ev.gray200),
                  ),
                  child: counter,
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(10), child: child),
        ],
      ),
    );
  }
}

/// Caja de acción final (`.action-box` / `.finish-box`).
class _EvActionBox extends StatelessWidget {
  final String title;
  final String subtitle;
  final String label;
  final Color color;
  final Color background;
  final Color borderColor;
  final bool loading;
  final VoidCallback? onPressed;

  const _EvActionBox({
    required this.title,
    required this.subtitle,
    required this.label,
    required this.color,
    required this.background,
    required this.borderColor,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Ev.radius),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Ev.text, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Ev.gray500, fontSize: 12)),
          const SizedBox(height: 12),
          Opacity(
            opacity: onPressed == null ? 0.5 : 1,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                disabledBackgroundColor: color,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta del material de sujeción, con el mismo aspecto que las tarjetas
/// de carga; abre su pantalla de fotos por material.
class _MaterialsCard extends StatelessWidget {
  final TripController tc;
  const _MaterialsCard({required this.tc});

  @override
  Widget build(BuildContext context) {
    final complete = tc.additionalMaterialsCompleted;
    return GestureDetector(
      onTap: () => Get.toNamed(RouteNames.tripAdditionalMaterials),
      child: DashedRRectBorder(
        color: complete ? const Color(0xFFBBF7D0) : Ev.gray300,
        background: complete ? Ev.greenSoft : Colors.white,
        child: Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: complete
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFE3EEFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.inventory_2_rounded,
                    size: 24, color: complete ? Ev.green : Ev.orangeDark),
              ),
              const Text('Material de sujeción',
                  style: TextStyle(
                      color: Ev.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                  '${tc.additionalMaterialsDoneCount} de '
                  '${tc.additionalMaterials.length} con evidencia. '
                  'Una fotografía por cada material.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Ev.gray500, fontSize: 12, height: 1.35)),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: complete ? Ev.green : Ev.navy,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(complete ? 'Revisar' : 'Tomar fotos',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra superior de las pantallas de evidencia (estilo nuevo).
PreferredSizeWidget _evAppBar({List<Widget> actions = const []}) =>
    SxAppBar(title: const Text('Finalizar viaje'), actions: actions);

/// Tarjeta tocable con el aspecto de las tarjetas de carga.
class _EvTapCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  const _EvTapCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DashedRRectBorder(
        color: Ev.gray300,
        background: Colors.white,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3EEFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: Ev.orangeDark),
              ),
              Text(title,
                  style: const TextStyle(
                      color: Ev.text, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(description,
                  style: const TextStyle(color: Ev.gray500, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Notas (opcional) con el aspecto de `.extra-box`.
class _NotesBox extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final String hint;
  const _NotesBox({
    required this.controller,
    this.title = 'Notas de salida (opcional)',
    this.hint = 'Condiciones del vehículo, observaciones...',
  });

  @override
  Widget build(BuildContext context) {
    return EvBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Ev.text, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(hint, style: const TextStyle(color: Ev.gray500, fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(color: Ev.text, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Ev.gray300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Ev.gray300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Ev.navy, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

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

class _ErrorRow extends StatelessWidget {
  final String message;
  const _ErrorRow(this.message);

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
