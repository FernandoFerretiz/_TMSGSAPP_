import '../../../core/design/sx_design.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../../auth/widgets/gradient_button.dart';
import '../controllers/circuit_trip_form_controller.dart';
import '../models/circuit_trip_models.dart';
import '../widgets/truckbox_registration_flow.dart';

/// Formulario de alta de viajes de circuito — reemplazo (no conversacional)
/// del flujo equivalente del chatbot: mismos pasos, mismas reglas, resueltos
/// en el backend (ver CircuitTripFormController + CircuitTripFormService).
class CircuitTripFormScreen extends StatelessWidget {
  const CircuitTripFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CircuitTripFormController>();

    return Scaffold(
      backgroundColor: Sx.pageBg,
      appBar: SxAppBar(
          title: Obx(() => Text(
                c.isEditing
                    ? 'Editar viaje #${c.editingTripId.value}'
                    : (c.selectedCircuit.value?.routeTypeName?.trim().isNotEmpty ?? false)
                        ? c.selectedCircuit.value!.routeTypeName!.trim()
                        : 'Nuevo viaje de circuito',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ))),
      body: Obx(() => c.isLoadingForEdit.value
          ? const Center(child: CircularProgressIndicator())
          : c.editLoadFailed.value
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ErrorBanner(c.errorMessage.value),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () => c.loadForEdit(c.editingTripId.value!),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ClientStep(c: c),
                      Obx(() => c.selectedClient.value == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: _CircuitStep(c: c),
                            )),
                      Obx(() => c.selectedCircuit.value == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: _OperatorStep(c: c),
                            )),
                      Obx(() => c.legResolution.value == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: c.isRouteMode
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _AppointmentStep(c: c),
                                        const SizedBox(height: 14),
                                        _RouteTimeline(c: c),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Vuelta del circuito: debajo del operador y arriba del origen.
                                        if (c.isReturn &&
                                            !c.isEditing &&
                                            (c.legResolution.value?.movements ?? const <RoundMovement>[])
                                                .isNotEmpty) ...[
                                          _RoundHistory(
                                              c: c, movements: c.legResolution.value!.movements),
                                          const SizedBox(height: 14),
                                        ],
                                        _OriginDestinationStep(c: c),
                                      ],
                                    ),
                            )),
                      Obx(() => (c.legResolution.value == null || !c.originDestinationReady)
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!c.isRouteMode) ...[
                                    _AppointmentStep(c: c),
                                    const SizedBox(height: 14),
                                  ],
                                  if (c.isOutbound && c.isEditing) ...[
                                    _TypeTripStep(c: c),
                                    const SizedBox(height: 14),
                                  ] else if (c.isRouteMode) ...[
                                    _CreateAllStep(c: c),
                                    const SizedBox(height: 14),
                                  ] else ...[
                                    _NextMovementStepOrNothing(c: c),
                                  ],
                                  if (c.canAddEditStops) ...[
                                    _EditExtraStops(c: c),
                                    const SizedBox(height: 14),
                                  ],
                                  _CommentsStep(c: c),
                                  if (!c.isRouteMode) ...[
                                    const SizedBox(height: 14),
                                    _InternalInfoStep(c: c),
                                    const SizedBox(height: 14),
                                    _TruckboxStep(c: c),
                                  ],
                                  const SizedBox(height: 14),
                                  _AdditionalMaterialsStep(c: c),
                                  const SizedBox(height: 22),
                                  Obx(() => c.errorMessage.value.isEmpty
                                      ? const SizedBox.shrink()
                                      : Padding(
                                          padding: const EdgeInsets.only(bottom: 14),
                                          child: _ErrorBanner(c.errorMessage.value),
                                        )),
                                  Obx(() => GradientButton(
                                        label: c.isEditing
                                            ? 'Guardar cambios'
                                            : (c.isRouteMode
                                                ? 'Registrar asignación (${c.tripsToCreate} viaje${c.tripsToCreate == 1 ? '' : 's'})'
                                                : 'Registrar asignación'),
                                        isLoading: c.isSubmitting.value,
                                        onPressed:
                                            c.canSubmit ? () => _handleSubmit(context, c) : null,
                                      )),
                                  Obx(() {
                                    final missing = c.missingItems;
                                    if (c.canSubmit || missing.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Text(
                                        'Falta: ${missing.join(', ')}.',
                                        style: const TextStyle(
                                            color: AppColors.textMedium, fontSize: 12.5),
                                      ),
                                    );
                                  }),
                                  if (c.isEditing && c.editCanRemove.value) ...[
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final removed = await _confirmRemoveMovement(
                                            context, c, c.editingTripId.value!, 0);
                                        if (removed) Get.back(result: true);
                                      },
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      label: const Text('Eliminar movimiento'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(48),
                                        foregroundColor: Colors.red.shade700,
                                        side: BorderSide(color: Colors.red.shade200),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14)),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                ],
                              ),
                            )),
                    ],
                  ),
                )),
    );
  }

  Future<void> _handleSubmit(BuildContext context, CircuitTripFormController c) async {
    // Cajas escritas que no están registradas: confirmar y registrarlas antes de crear el viaje.
    if (!await TruckboxRegistrationFlow.run(context, c)) return;

    // Sin link de evidencias válido: advertir; si continúa, el servidor lo deja como pendiente.
    if (c.hasMissingEvidenceLink) {
      if (!context.mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Link de evidencias pendiente'),
          content: const Text(
              'No se registró el link de evidencias de al menos un viaje, o no es un link válido. '
              'Si continúas, quedará pendiente y se te pedirá al finalizar el turno.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Volver')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Continuar')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final result = await c.submit();
    if (result == null) return;

    if (c.isEditing) {
      Get.snackbar(
        'Viaje actualizado',
        'Los cambios se guardaron correctamente.',
        backgroundColor: AppColors.royalBlue,
        colorText: Colors.white,
      );
      Get.back(result: true);
      return;
    }

    final parts = <String>[];
    if (result.outboundTripId != null) parts.add('Ida #${result.outboundTripId}');
    if (result.returnTripId != null) parts.add('Regreso #${result.returnTripId}');

    Get.snackbar(
      'Asignación registrada',
      parts.join(' · '),
      backgroundColor: AppColors.royalBlue,
      colorText: Colors.white,
    );
    if (c.openedFromRound) {
      Get.back(result: true);
      return;
    }
    c.resetAll();
  }
}

/// Confirma y elimina un movimiento ya registrado. El siguiente movimiento pasa
/// a salir del destino del anterior. Devuelve true si se eliminó.
Future<bool> _confirmRemoveMovement(
    BuildContext context, CircuitTripFormController c, int tripId, int position) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar movimiento'),
      content: Text(
        'Se eliminará ${position > 0 ? 'el movimiento $position' : 'este movimiento'}. El siguiente movimiento (si lo hay) pasará a salir del destino del anterior.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (ok != true) return false;

  final removed = await c.removeMovement(tripId);
  Get.snackbar(
    removed ? 'Movimiento eliminado' : 'No se pudo eliminar',
    removed ? 'La vuelta se actualizó.' : c.errorMessage.value,
    backgroundColor: removed ? AppColors.royalBlue : Colors.red.shade700,
    colorText: Colors.white,
  );
  return removed;
}

// ── Steps ─────────────────────────────────────────────────────────────────

class _ClientStep extends StatelessWidget {
  final CircuitTripFormController c;
  const _ClientStep({required this.c});

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Cliente',
      child: Obx(() {
        if (c.isLoadingClients.value) return const _InlineLoader();
        return _Dropdown<CircuitOption>(
          value: c.selectedClient.value,
          hint: 'Selecciona el cliente',
          items: c.clients,
          itemLabel: (o) => o.name,
          onChanged: c.selectClient,
        );
      }),
    );
  }
}

class _CircuitStep extends StatelessWidget {
  final CircuitTripFormController c;
  const _CircuitStep({required this.c});

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Circuito',
      child: Obx(() {
        if (c.isLoadingCircuits.value) return const _InlineLoader();
        if (c.circuits.length <= 1) {
          // Auto-seleccionado (mismo atajo que el chatbot) — no hay nada
          // que elegir, solo se confirma.
          final only = c.circuits.isEmpty ? null : c.circuits.first;
          return Text(
            only?.name ?? 'Sin circuitos disponibles',
            style: const TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 14),
          );
        }
        return _Dropdown<ClientCircuitOption>(
          value: c.selectedCircuit.value,
          hint: 'Selecciona el circuito',
          items: c.circuits,
          itemLabel: (o) => o.name,
          onChanged: c.selectCircuit,
        );
      }),
    );
  }
}

class _OperatorStep extends StatelessWidget {
  final CircuitTripFormController c;
  const _OperatorStep({required this.c});

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Operador',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            if (c.isLoadingOperators.value) return const _InlineLoader();
            return _Dropdown<CircuitOperatorOption>(
              value: c.selectedOperator.value,
              hint: 'Selecciona el operador',
              items: c.operators,
              itemLabel: (o) =>
                  '${o.name}${o.transporterName != null ? ' (${o.transporterName})' : ''}',
              onChanged: c.selectOperator,
            );
          }),
          Obx(() {
            if (!c.isResolvingOperator.value) return const SizedBox.shrink();
            return const Padding(
              padding: EdgeInsets.only(top: 10),
              child: _InlineLoader(),
            );
          }),
          Obx(() {
            final leg = c.legResolution.value;
            if (leg == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _InfoChip(
                c.isEditing
                    ? (leg.isReturn ? 'Tramo: Regreso' : 'Tramo: Ida')
                    : leg.isReturn
                        ? 'Se registrará el REGRESO de una vuelta abierta.'
                        : 'Se registrará la IDA de una nueva vuelta.',
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OriginDestinationStep extends StatelessWidget {
  final CircuitTripFormController c;
  const _OriginDestinationStep({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final leg = c.legResolution.value!;

      if (leg.isReturn) {
        return _StepCard(
          title: c.isEditing ? 'Origen del movimiento' : 'Origen del siguiente movimiento',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leg.nextOrigin == null || c.isEditing) ...[
                _InfoChip('Destino fijo: ${leg.destination?.name ?? '—'}'),
                const SizedBox(height: 10),
              ] else
                _InfoChip(
                    'Sugerido: ${leg.nextOrigin!.name} (donde terminó el movimiento anterior). '
                    'Cámbialo si la caja se cargó en otro lugar.'),
              const SizedBox(height: 10),
              _Dropdown<AddressOption>(
                  value: c.selectedReturnOrigin.value,
                  hint: 'Selecciona el origen',
                  // El último destino siempre es opción, aunque no esté en el catálogo.
                  items: [
                    ...leg.returnOriginOptions,
                    if (leg.nextOrigin != null &&
                        !leg.returnOriginOptions.contains(leg.nextOrigin))
                      leg.nextOrigin!,
                  ],
                  itemLabel: (o) => o.name,
                  onChanged: c.selectReturnOrigin,
                ),
              Obx(() => c.isLoadingReturnRouteType.value
                  ? const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: _InlineLoader(),
                    )
                  : const SizedBox.shrink()),
            ],
          ),
        );
      }

      return _StepCard(
        title: 'Destino',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoChip('Origen fijo: ${leg.origin?.name ?? '—'}'),
            const SizedBox(height: 10),
            Obx(() {
              if (c.isLoadingDestinations.value) return const _InlineLoader();
              return _Dropdown<AddressOption>(
                value: c.selectedDestination.value,
                hint:
                    c.destinationPending.value ? 'Pendiente por asignar' : 'Selecciona el destino',
                items: c.destinationOptions,
                itemLabel: (o) => o.name,
                onChanged: c.selectDestination,
              );
            }),
            const SizedBox(height: 8),
            Obx(() => CheckboxListTile(
                  value: c.destinationPending.value,
                  onChanged: (v) {
                    if (v == true) {
                      c.selectDestinationPending();
                    } else {
                      c.selectDestination(null);
                    }
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Pendiente por asignar',
                      style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
                )),
          ],
        ),
      );
    });
  }
}

class _AppointmentStep extends StatelessWidget {
  final CircuitTripFormController c;
  const _AppointmentStep({required this.c});

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: c.appointmentDateTime.value ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(c.appointmentDateTime.value ?? now),
    );
    if (time == null) return;

    c.appointmentDateTime.value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: '¿Tiene cita?',
      child: Obx(() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                value: c.hasAppointment.value,
                onChanged: c.setHasAppointment,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeThumbColor: AppColors.royalBlue,
                title: const Text('Tiene cita programada',
                    style: TextStyle(fontSize: 13.5, color: AppColors.textDark)),
              ),
              if (c.hasAppointment.value)
                InkWell(
                  onTap: () => _pick(context),
                  child: _FieldBox(
                    child: Text(
                      c.appointmentDateTime.value == null
                          ? 'Selecciona fecha y hora'
                          : c.appointmentDateTime.value.toString().substring(0, 16),
                      style: TextStyle(
                        color: c.appointmentDateTime.value == null
                            ? AppColors.textLight
                            : AppColors.textDark,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
            ],
          )),
    );
  }
}

class _TypeTripStep extends StatelessWidget {
  final CircuitTripFormController c;
  const _TypeTripStep({required this.c});

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Tipo de viaje',
      child: Obx(() => Row(
            children: [
              Expanded(
                child: _ChoiceChip(
                  label: 'Cargado',
                  selected: c.typeTrip.value == 'cargado',
                  onTap: () => c.selectTypeTrip('cargado'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceChip(
                  label: 'Vacío',
                  selected: c.typeTrip.value == 'vacio',
                  onTap: () => c.selectTypeTrip('vacio'),
                ),
              ),
            ],
          )),
    );
  }
}

/// Ruta del alta como línea de tiempo (igual que el mockup): origen fijo →
/// destino de la ida → intermedios → fin. Cada movimiento lleva su propia
/// tarjeta con tipo de viaje, caja y la información interna de ese viaje.
class _RouteTimeline extends StatelessWidget {
  final CircuitTripFormController c;
  const _RouteTimeline({required this.c});

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Ruta del circuito',
      child: Obx(() {
        final leg = c.legResolution.value!;
        final origin = leg.origin?.name ?? '—';
        final pending = c.destinationPending.value;
        final hasDestination = c.selectedDestination.value != null || pending;
        final hasStops = c.stops.isNotEmpty && !pending;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Por defecto solo hay un movimiento (la ida). Cada movimiento que agregues sale del destino del anterior y el último es el fin.',
              style: TextStyle(color: AppColors.textMedium, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            _TimelineNode(
              kind: _DotKind.start,
              title: 'Origen',
              tag: 'Fijo',
              child: _InfoChip(origin),
            ),
            _TimelineNode(
              kind: _DotKind.middle,
              title: 'Destino de la ida',
              tag: 'Ida',
              isLast: !hasDestination,
              child: _IdaDestination(c: c),
            ),
            if (hasDestination)
              _LegCard(
                position: 1,
                label: 'Ida',
                from: origin,
                to: pending ? 'Pendiente por asignar' : (c.selectedDestination.value?.name ?? '¿?'),
                isLast: !hasStops,
                typeTrip: c.typeTrip,
                truckbox: _TruckboxFields(
                  isPt: c.truckboxIsPt,
                  number: c.truckboxNumber,
                  owner: c.truckboxOwner,
                  usesOwnTruckboxes: c.usesOwnTruckboxes,
                ),
                internalLink: c.internalLink,
                internalNotes: c.internalNotes,
              ),
            if (pending)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Define el destino de la ida para poder agregar más movimientos. Por ahora solo se creará la ida.',
                  style: TextStyle(color: AppColors.textMedium, fontSize: 12.5),
                ),
              ),
            if (hasDestination && !pending) ...[
              for (var i = 0; i < c.stops.length; i++) _StopNode(c: c, index: i),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: c.addStop,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar movimiento'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: AppColors.royalBlue,
                  side: const BorderSide(color: AppColors.lightBlue, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}

enum _DotKind { start, middle, end }

/// Un punto de la línea de tiempo: círculo + línea hacia el siguiente + contenido.
class _TimelineNode extends StatelessWidget {
  final _DotKind kind;
  final String? title;
  final String? tag;
  final Widget? actions;
  final Widget child;
  final bool isLast;

  const _TimelineNode({
    super.key,
    required this.kind,
    this.title,
    this.tag,
    this.actions,
    required this.child,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final filled = kind != _DotKind.middle;
    final color = kind == _DotKind.end ? AppColors.navyBlue : AppColors.royalBlue;

    return Stack(
      children: [
        // Línea hacia el siguiente punto (detrás del contenido, sin medir alturas).
        if (!isLast && kind != _DotKind.end)
          Positioned(
            left: 11.5,
            top: 22,
            bottom: 0,
            width: 3,
            child: Container(color: AppColors.lightBlue),
          ),
        Positioned(
          left: 0,
          top: 0,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? color : Colors.white,
              border: Border.all(color: color, width: 4),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 38, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title!,
                            style: const TextStyle(
                                color: AppColors.navyBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                      ),
                      if (tag != null) _Tag(tag!),
                      if (actions != null) actions!,
                    ],
                  ),
                ),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.lightBlue.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              color: AppColors.royalBlue,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3)),
    );
  }
}

/// Destino de la ida + "Pendiente por asignar".
class _IdaDestination extends StatelessWidget {
  final CircuitTripFormController c;
  const _IdaDestination({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.isLoadingDestinations.value)
              const _InlineLoader()
            else
              _Dropdown<AddressOption>(
                value: c.selectedDestination.value,
                hint:
                    c.destinationPending.value ? 'Pendiente por asignar' : 'Selecciona el destino',
                items: c.destinationOptions,
                itemLabel: (o) => o.name,
                onChanged: c.selectDestination,
              ),
            CheckboxListTile(
              value: c.destinationPending.value,
              onChanged: (v) {
                if (v == true) {
                  c.selectDestinationPending();
                } else {
                  c.selectDestination(null);
                }
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Pendiente por asignar',
                  style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
            ),
          ],
        ));
  }
}

/// Tarjeta de un movimiento (debajo de su punto): tipo de viaje, caja e
/// información interna de ese viaje.
class _LegCard extends StatelessWidget {
  final int position;
  final String label;
  final String from;
  final String to;
  final bool isLast;
  final Rxn<String> typeTrip;
  final Widget truckbox;
  final RxString internalLink;
  final RxString internalNotes;

  const _LegCard({
    required this.position,
    required this.label,
    required this.from,
    required this.to,
    required this.isLast,
    required this.typeTrip,
    required this.truckbox,
    required this.internalLink,
    required this.internalNotes,
  });

  @override
  Widget build(BuildContext context) {
    return _TimelineNode(
      kind: _DotKind.middle,
      isLast: isLast,
      child: _DashedBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$position · $label · $from → $to',
                style: const TextStyle(
                    color: AppColors.navyBlue, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Obx(() => _TypeChips(value: typeTrip.value, onChanged: (v) => typeTrip.value = v)),
            const SizedBox(height: 10),
            const Text('Caja',
                style: TextStyle(
                    color: AppColors.navyBlue, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            truckbox,
            const SizedBox(height: 4),
            _InternalFields(link: internalLink, notes: internalNotes),
          ],
        ),
      ),
    );
  }
}

class _StopNode extends StatelessWidget {
  final CircuitTripFormController c;
  final int index;
  const _StopNode({required this.c, required this.index});

  @override
  Widget build(BuildContext context) {
    final stop = c.stops[index];

    return Obx(() {
      final isLast = index == c.stops.length - 1;

      return _TimelineNode(
        key: ObjectKey(stop),
        kind: isLast ? _DotKind.end : _DotKind.middle,
        title: 'Movimiento ${index + 2}',
        tag: isLast ? 'Fin' : null,
        actions: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniIcon(Icons.arrow_upward, index == 0 ? null : () => c.moveStop(index, -1)),
            _MiniIcon(Icons.arrow_downward, isLast ? null : () => c.moveStop(index, 1)),
            _MiniIcon(Icons.close, () => c.removeStop(index), danger: true),
          ],
        ),
        child: _DashedBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sale de',
                  style: TextStyle(
                      color: AppColors.textMedium, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              _Dropdown<AddressOption>(
                value: c.stopOrigin(index),
                hint: 'Elige el origen',
                items: c.stopOriginOptions(index),
                itemLabel: (o) => o.name,
                onChanged: (a) => c.selectStopOrigin(index, a),
              ),
              const SizedBox(height: 10),
              const Text('Llega a',
                  style: TextStyle(
                      color: AppColors.textMedium, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              _Dropdown<AddressOption>(
                value: stop.destination.value,
                hint: 'Elige el destino',
                items: c.stopOptions(index),
                itemLabel: (o) => o.name,
                onChanged: (a) => c.selectStopDestination(stop, a),
              ),
              const SizedBox(height: 12),
              _TypeChips(value: stop.typeTrip.value, onChanged: (v) => stop.typeTrip.value = v),
              const SizedBox(height: 10),
              _MovementBox(
                same: stop.sameTruckbox,
                isPt: stop.truckboxIsPt,
                number: stop.truckboxNumber,
                owner: stop.truckboxOwner,
                usesOwnTruckboxes: c.usesOwnTruckboxes,
              ),
              const SizedBox(height: 4),
              _InternalFields(link: stop.internalLink, notes: stop.internalNotes),
            ],
          ),
        ),
      );
    });
  }
}

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
  const _MiniIcon(this.icon, this.onTap, {this.danger = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 15,
            color: onTap == null
                ? AppColors.textLight.withValues(alpha: 0.5)
                : (danger ? Colors.red.shade700 : AppColors.textMedium)),
      ),
    );
  }
}

/// Tarjeta con borde punteado (como en el mockup) para cada movimiento.
class _DashedBox extends StatelessWidget {
  final Widget child;
  const _DashedBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.lightBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "¿Crear todos los movimientos ahora?" + resumen de lo que se creará.
class _CreateAllStep extends StatelessWidget {
  final CircuitTripFormController c;
  const _CreateAllStep({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final total = c.routeMovementCount;
      final created = c.tripsToCreate;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.navyBlue,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.45),
                children: [
                  const TextSpan(
                      text: 'Ruta: ',
                      style: TextStyle(color: AppColors.lightBlue, fontWeight: FontWeight.w700)),
                  TextSpan(text: '${c.routeSummary}\n'),
                  const TextSpan(
                      text: 'Movimientos: ',
                      style: TextStyle(color: AppColors.lightBlue, fontWeight: FontWeight.w700)),
                  TextSpan(text: '$total · '),
                  const TextSpan(
                      text: 'Se crearán ahora: ',
                      style: TextStyle(color: AppColors.lightBlue, fontWeight: FontWeight.w700)),
                  TextSpan(text: '$created viaje${created == 1 ? '' : 's'}'),
                  if (created < total)
                    TextSpan(text: '\nLos otros ${total - created} se agregan después.'),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// Link del cliente + notas internas de UN viaje (solo las ve el equipo).
/// Colapsado por defecto en las tarjetas de movimiento para no alargar la ruta.
class _InternalFields extends StatefulWidget {
  final RxString link;
  final RxString notes;
  const _InternalFields({required this.link, required this.notes});

  @override
  State<_InternalFields> createState() => _InternalFieldsState();
}

class _InternalFieldsState extends State<_InternalFields> {
  late bool _open = widget.link.value.isNotEmpty || widget.notes.value.isNotEmpty;

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18),
          label: const Text('Link y notas internas (opcional)'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.royalBlue,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 34),
            alignment: Alignment.centerLeft,
          ),
        ),
        if (_open) ...[
          const Text(
            'Solo la ve el equipo interno, no el operador ni el transportista.',
            style: TextStyle(color: AppColors.textLight, fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: widget.link.value,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: AppColors.textDark, fontSize: 13.5),
            onChanged: (v) => widget.link.value = v,
            decoration: _decoration('Link del cliente (https://...)'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: widget.notes.value,
            maxLines: 2,
            style: const TextStyle(color: AppColors.textDark, fontSize: 13.5),
            onChanged: (v) => widget.notes.value = v,
            decoration: _decoration('Notas internas'),
          ),
        ],
      ],
    );
  }
}

class _TypeChips extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  const _TypeChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ChoiceChip(
              label: 'Cargado', selected: value == 'cargado', onTap: () => onChanged('cargado')),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ChoiceChip(
              label: 'Vacío', selected: value == 'vacio', onTap: () => onChanged('vacio')),
        ),
      ],
    );
  }
}

/// "¿Misma caja del movimiento anterior?" + campos de la otra caja (drop and hook).
class _MovementBox extends StatelessWidget {
  final Rxn<bool> same;
  final RxBool isPt;
  final RxString number;
  final Rxn<String> owner;
  final bool usesOwnTruckboxes;

  const _MovementBox({
    required this.same,
    required this.isPt,
    required this.number,
    required this.owner,
    required this.usesOwnTruckboxes,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Caja',
                style: TextStyle(
                    color: AppColors.navyBlue, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _ChoiceChip(
                    label: 'Misma caja',
                    selected: same.value == true,
                    onTap: () {
                      same.value = true;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChoiceChip(
                    label: 'Otra (drop and hook)',
                    selected: same.value == false,
                    onTap: () {
                      same.value = false;
                    },
                  ),
                ),
              ],
            ),
            if (same.value == false) ...[
              const SizedBox(height: 10),
              _TruckboxFields(
                isPt: isPt,
                number: number,
                owner: owner,
                usesOwnTruckboxes: usesOwnTruckboxes,
              ),
            ],
          ],
        ));
  }
}

/// Edición: agrega trayectos después de este viaje (el último es el fin de la
/// vuelta). Cada uno sale del destino del anterior, pero el origen se puede cambiar.
class _EditExtraStops extends StatelessWidget {
  final CircuitTripFormController c;
  const _EditExtraStops({required this.c});

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Agregar trayectos',
      child: Obx(() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Salen de ${c.editChainStart?.name ?? '—'} (destino de este viaje). El último trayecto es el fin de la vuelta.',
                style: const TextStyle(color: AppColors.textMedium, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < c.stops.length; i++) _StopNode(c: c, index: i),
              OutlinedButton.icon(
                onPressed: c.addStop,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar trayecto'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: AppColors.royalBlue,
                  side: const BorderSide(color: AppColors.lightBlue, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          )),
    );
  }
}

class _NextMovementStepOrNothing extends StatelessWidget {
  final CircuitTripFormController c;
  const _NextMovementStepOrNothing({required this.c});

  @override
  Widget build(BuildContext context) {
    if (c.isEditing) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_NextMovementStep(c: c)],
      ),
    );
  }
}

/// Vuelta abierta: el siguiente movimiento es un intermedio o el fin de la ruta.
class _NextMovementStep extends StatelessWidget {
  final CircuitTripFormController c;
  const _NextMovementStep({required this.c});

  @override
  Widget build(BuildContext context) {
    final next = _StepCard(
      title: 'Siguiente movimiento',
      child: Obx(() {
        final finDestination = c.legResolution.value?.destination?.name ?? '—';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sale de',
                style: TextStyle(
                    color: AppColors.textMedium, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            _InfoChip(c.selectedReturnOrigin.value?.name ?? '—'),
            const SizedBox(height: 14),
            const Text('Destino del movimiento',
                style: TextStyle(
                    color: AppColors.navyBlue, fontSize: 13.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Por defecto regresa a $finDestination (inicio del circuito) y cierra la ruta. '
              'Si eliges otro destino, la ruta sigue abierta.',
              style: const TextStyle(color: AppColors.textMedium, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            c.isLoadingMovementDestinations.value
                ? const _InlineLoader()
                : _Dropdown<AddressOption>(
                    value: c.movementDestinationOptions
                        .firstWhereOrNull((o) => o.id == c.movementDestinationShown?.id),
                    hint: 'Destino del movimiento',
                    items: c.movementDestinationOptions,
                    itemLabel: (o) => o.name,
                    onChanged: c.pickMovementDestination,
                  ),
            const SizedBox(height: 14),
            const Text('Tipo de viaje',
                style: TextStyle(
                    color: AppColors.navyBlue, fontSize: 13.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _TypeChips(value: c.movementTypeTrip.value, onChanged: c.selectMovementType),
          ],
        );
      }),
    );

    return next;
  }
}

/// Movimientos ya creados de la vuelta abierta, como línea de tiempo.
class _RoundHistory extends StatelessWidget {
  final CircuitTripFormController c;
  final List<RoundMovement> movements;
  const _RoundHistory({required this.c, required this.movements});

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Vuelta del circuito',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in movements)
            _TimelineNode(
              kind: _DotKind.middle,
              title:
                  '${m.position} · ${m.role == 'outbound' ? 'Ida' : (m.role == 'return' ? 'Fin' : 'Movimiento')}',
              tag: m.statusLabel,
              actions: (m.canRemove && m.tripId != null)
                  ? _MiniIcon(
                      Icons.delete_outline,
                      () => _confirmRemoveMovement(context, c, m.tripId!, m.position),
                      danger: true,
                    )
                  : null,
              child: Text(
                '${m.origin ?? '—'} → ${m.destination ?? '—'} · ${m.typeTrip == 'vacio' ? 'Vacío' : 'Cargado'} · Caja ${m.truckboxNum ?? 'PT'}',
                style: const TextStyle(color: AppColors.textMedium, fontSize: 12.5),
              ),
            ),
          const _TimelineNode(
            kind: _DotKind.end,
            title: 'Fin del circuito',
            tag: 'Pendiente',
            child: Text('Lo define quien registra el último movimiento.',
                style: TextStyle(color: AppColors.textMedium, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

class _CommentsStep extends StatelessWidget {
  final CircuitTripFormController c;
  const _CommentsStep({required this.c});

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Comentarios adicionales (opcional)',
      child: TextFormField(
        maxLines: 2,
        style: const TextStyle(color: AppColors.textDark, fontSize: 13.5),
        onChanged: (v) => c.comments.value = v,
        decoration: InputDecoration(
          hintText: 'Sin comentarios',
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
          filled: true,
          fillColor: AppColors.fieldFill,
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.fieldBorder),
          ),
        ),
      ),
    );
  }
}

// Información interna del viaje: nunca se muestra al operador ni al
// transportista (no aparece en el link de evidencias, el portal ni el
// historial que ve el operador) — solo queda guardada para el equipo en el
// ERP.
class _InternalInfoStep extends StatelessWidget {
  final CircuitTripFormController c;
  const _InternalInfoStep({required this.c});

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Información interna (opcional)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Solo la ve el equipo interno, no el operador ni el transportista.',
            style: TextStyle(color: AppColors.textLight, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          const Text(
            'Link del cliente (documentos/evidencias)',
            style:
                TextStyle(color: AppColors.textDark, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextFormField(
            keyboardType: TextInputType.url,
            style: const TextStyle(color: AppColors.textDark, fontSize: 13.5),
            onChanged: (v) => c.internalLink.value = v,
            decoration: InputDecoration(
              hintText: 'https://...',
              hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
              filled: true,
              fillColor: AppColors.fieldFill,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.fieldBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Notas internas',
            style:
                TextStyle(color: AppColors.textDark, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextFormField(
            maxLines: 2,
            style: const TextStyle(color: AppColors.textDark, fontSize: 13.5),
            onChanged: (v) => c.internalNotes.value = v,
            decoration: InputDecoration(
              hintText: 'Sin notas',
              hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
              filled: true,
              fillColor: AppColors.fieldFill,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.fieldBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TruckboxStep extends StatelessWidget {
  final CircuitTripFormController c;
  const _TruckboxStep({required this.c});

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Caja',
      child: Obx(() {
        final leg = c.legResolution.value!;

        if (leg.isReturn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ChoiceChip(
                      label:
                          '¿Misma caja del movimiento anterior? (${leg.outboundTruckboxNum ?? 'PT'})',
                      selected: c.sameAsOutboundTruckbox.value == true,
                      onTap: () => c.setSameAsOutboundTruckbox(true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ChoiceChip(
                label: 'No, es otra caja',
                selected: c.sameAsOutboundTruckbox.value == false,
                onTap: () => c.setSameAsOutboundTruckbox(false),
              ),
              if (c.sameAsOutboundTruckbox.value == false) ...[
                const SizedBox(height: 12),
                _TruckboxFields(
                  isPt: c.truckboxIsPt,
                  number: c.truckboxNumber,
                  owner: c.truckboxOwner,
                  usesOwnTruckboxes: c.usesOwnTruckboxes,
                ),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TruckboxFields(
              isPt: c.truckboxIsPt,
              number: c.truckboxNumber,
              owner: c.truckboxOwner,
              usesOwnTruckboxes: c.usesOwnTruckboxes,
            ),
          ],
        );
      }),
    );
  }
}

/// Número de caja + PT + dueño (cuando el transportista usa cajas propias) —
/// reutilizado para la caja principal y, si aplica, la del regreso drop &
/// hook.
class _TruckboxFields extends StatelessWidget {
  final RxBool isPt;
  final RxString number;
  final Rxn<String> owner;
  final bool usesOwnTruckboxes;

  const _TruckboxFields({
    required this.isPt,
    required this.number,
    required this.owner,
    required this.usesOwnTruckboxes,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              value: isPt.value,
              onChanged: (v) {
                isPt.value = v == true;
                if (isPt.value) {
                  number.value = '';
                  owner.value = null;
                }
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Sin caja (PT)',
                  style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
            ),
            if (!isPt.value) ...[
              TextFormField(
                initialValue: number.value,
                style: const TextStyle(color: AppColors.textDark, fontSize: 13.5),
                onChanged: (v) => number.value = v,
                decoration: InputDecoration(
                  hintText: 'Número de caja',
                  hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.fieldFill,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.fieldBorder),
                  ),
                ),
              ),
              if (usesOwnTruckboxes) ...[
                const SizedBox(height: 10),
                const Text('¿De quién es la caja?',
                    style: TextStyle(
                        color: AppColors.navyBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _ChoiceChip(
                        label: 'Del cliente',
                        selected: owner.value == 'client',
                        onTap: () => owner.value = 'client',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ChoiceChip(
                        label: 'Del transportista',
                        selected: owner.value == 'transporter',
                        onTap: () => owner.value = 'transporter',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ));
  }
}

class _AdditionalMaterialsStep extends StatelessWidget {
  final CircuitTripFormController c;
  const _AdditionalMaterialsStep({required this.c});

  static const _groupLabels = {
    'sujecion': 'Material de sujeción',
    'proteccion': 'Material de protección de carga',
  };

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Material adicional (opcional)',
      child: Obx(() {
        if (c.isLoadingAdditionalMaterials.value) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final grouped = <String, List<AdditionalMaterialOption>>{};
        for (final option in c.additionalMaterialOptions) {
          grouped.putIfAbsent(option.group, () => []).add(option);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonHideUnderline(
              child: DropdownButton2<String>(
                isExpanded: true,
                value: null,
                onChanged: (_) {},
                hint: Text(
                  c.selectedAdditionalMaterials.isEmpty
                      ? 'Seleccionar material adicional'
                      : '${c.selectedAdditionalMaterials.length} seleccionado(s)',
                  style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                ),
                items: [
                  for (final group in _groupLabels.keys)
                    if ((grouped[group] ?? []).isNotEmpty) ...[
                      DropdownMenuItem<String>(
                        enabled: false,
                        child: Text(
                          _groupLabels[group]!,
                          style: const TextStyle(
                            color: AppColors.navyBlue,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ...grouped[group]!.map((option) => DropdownMenuItem<String>(
                            value: 'material_${option.id}',
                            enabled: false,
                            child: StatefulBuilder(
                              builder: (context, menuSetState) {
                                final selected = c.selectedAdditionalMaterials
                                    .any((s) => s.additionalMaterialId == option.id);

                                return InkWell(
                                  onTap: () {
                                    c.toggleAdditionalMaterial(option, !selected);
                                    menuSetState(() {});
                                  },
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: selected,
                                        onChanged: (v) {
                                          c.toggleAdditionalMaterial(option, v == true);
                                          menuSetState(() {});
                                        },
                                      ),
                                      Expanded(
                                        child:
                                            Text(option.name, style: const TextStyle(fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )),
                    ],
                  DropdownMenuItem<String>(
                    value: '__other__',
                    enabled: false,
                    child: StatefulBuilder(
                      builder: (context, menuSetState) {
                        final selected = c.otherMaterialSelected;

                        return InkWell(
                          onTap: () {
                            c.toggleOtherMaterial(!selected);
                            menuSetState(() {});
                          },
                          child: Row(
                            children: [
                              Checkbox(
                                value: selected,
                                onChanged: (v) {
                                  c.toggleOtherMaterial(v == true);
                                  menuSetState(() {});
                                },
                              ),
                              const Expanded(
                                child: Text('Otro, especificar', style: TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                buttonStyleData: ButtonStyleData(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.fieldBorder),
                  ),
                ),
                menuItemStyleData: const MenuItemStyleData(height: 44),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 320,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            if (c.selectedAdditionalMaterials.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...c.selectedAdditionalMaterials.map(
                (selection) => _AdditionalMaterialRow(selection: selection),
              ),
            ],
          ],
        );
      }),
    );
  }
}

/// Fila por cada material elegido: nombre (editable solo si es "Otro") +
/// dónde se entrega — igual que en el formulario web.
class _AdditionalMaterialRow extends StatelessWidget {
  final AdditionalMaterialSelection selection;
  const _AdditionalMaterialRow({required this.selection});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selection.isOther)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TextFormField(
                initialValue: selection.customName,
                style: const TextStyle(color: AppColors.textDark, fontSize: 13.5),
                onChanged: (v) => selection.customName = v,
                decoration: InputDecoration(
                  hintText: 'Especificar material',
                  hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.fieldFill,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.fieldBorder),
                  ),
                ),
              ),
            )
          else
            Text(selection.customName,
                style: const TextStyle(
                    color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: TextFormField(
              initialValue: selection.quantity,
              style: const TextStyle(color: AppColors.textDark, fontSize: 13.5),
              onChanged: (v) => selection.quantity = v,
              decoration: InputDecoration(
                hintText: 'Cantidad requerida (ej. 4)',
                hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
                filled: true,
                fillColor: AppColors.fieldFill,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.fieldBorder),
                ),
              ),
            ),
          ),
          TextFormField(
            initialValue: selection.deliveryLocation,
            style: const TextStyle(color: AppColors.textDark, fontSize: 13.5),
            onChanged: (v) => selection.deliveryLocation = v,
            decoration: InputDecoration(
              hintText: '¿Dónde se entrega?',
              hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
              filled: true,
              fillColor: AppColors.fieldFill,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.fieldBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ─────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _StepCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Sx.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.royalBlue.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.navyBlue, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Dropdown<T> extends StatefulWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _Dropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  State<_Dropdown<T>> createState() => _DropdownState<T>();
}

class _DropdownState<T> extends State<_Dropdown<T>> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final hint = widget.hint;
    final items = widget.items;
    final itemLabel = widget.itemLabel;
    final onChanged = widget.onChanged;

    final safeValue = items.contains(value) ? value : null;

    return DropdownButtonHideUnderline(
      child: DropdownButton2<T>(
        value: safeValue,
        isExpanded: true,
        hint: Text(hint, style: const TextStyle(color: AppColors.textLight, fontSize: 13.5)),
        iconStyleData: const IconStyleData(
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.royalBlue),
        ),
        items: items
            .map((item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textDark, fontSize: 13.5, fontWeight: FontWeight.w500)),
                ))
            .toList(),
        onChanged: items.isEmpty ? null : onChanged,
        buttonStyleData: ButtonStyleData(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.fieldBorder),
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(height: 44),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        dropdownSearchData: DropdownSearchData<T>(
          searchController: _searchController,
          searchInnerWidgetHeight: 50,
          searchInnerWidget: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: TextFormField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textDark, fontSize: 13.5),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                hintText: 'Buscar...',
                hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
                filled: true,
                fillColor: AppColors.fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.fieldBorder),
                ),
              ),
            ),
          ),
          searchMatchFn: (item, searchValue) =>
              itemLabel(item.value as T).toLowerCase().contains(searchValue.toLowerCase()),
        ),
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  final Widget child;
  const _FieldBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: child,
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.royalBlue : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: selected ? AppColors.royalBlue : AppColors.fieldBorder, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textMedium,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightBlue),
      ),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.royalBlue, fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }
}

class _InlineLoader extends StatelessWidget {
  const _InlineLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.royalBlue),
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
          const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.errorRed, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
