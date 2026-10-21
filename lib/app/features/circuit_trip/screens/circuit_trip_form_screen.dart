import '../../../core/design/sx_design.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../../auth/widgets/gradient_button.dart';
import '../controllers/circuit_trip_form_controller.dart';
import '../models/circuit_trip_models.dart';

/// Formulario de alta de viajes de circuito — reemplazo (no conversacional)
/// del flujo equivalente del chatbot: mismos pasos, mismas reglas, resueltos
/// en el backend (ver CircuitTripFormController + CircuitTripFormService).
class CircuitTripFormScreen extends StatelessWidget {
  const CircuitTripFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CircuitTripFormController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: SxAppBar(title: Obx(() => Text(
              c.isEditing ? 'Editar viaje #${c.editingTripId.value}' : 'Nuevo viaje de circuito',
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
                    child: _OriginDestinationStep(c: c),
                  )),
            Obx(() => (c.legResolution.value == null || !c.originDestinationReady)
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AppointmentStep(c: c),
                        if (c.isOutbound) ...[
                          const SizedBox(height: 14),
                          _TypeTripStep(c: c),
                        ],
                        const SizedBox(height: 14),
                        _CommentsStep(c: c),
                        const SizedBox(height: 14),
                        _InternalInfoStep(c: c),
                        const SizedBox(height: 14),
                        _TruckboxStep(c: c),
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
                              label: c.isEditing ? 'Guardar cambios' : 'Registrar asignación',
                              isLoading: c.isSubmitting.value,
                              onPressed: c.canSubmit
                                  ? () => _handleSubmit(context, c)
                                  : null,
                            )),
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
    c.resetAll();
  }
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
              itemLabel: (o) => '${o.name}${o.transporterName != null ? ' (${o.transporterName})' : ''}',
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
          title: 'Origen del regreso',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoChip('Destino fijo: ${leg.destination?.name ?? '—'}'),
              const SizedBox(height: 10),
              _Dropdown<AddressOption>(
                value: c.selectedReturnOrigin.value,
                hint: 'Selecciona el origen',
                items: leg.returnOriginOptions,
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
                hint: c.destinationPending.value
                    ? 'Pendiente por asignar'
                    : 'Selecciona el destino',
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

    c.appointmentDateTime.value =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
            style: TextStyle(color: AppColors.textDark, fontSize: 12.5, fontWeight: FontWeight.w600),
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
            style: TextStyle(color: AppColors.textDark, fontSize: 12.5, fontWeight: FontWeight.w600),
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
                      label: '¿Misma caja de la ida? (${leg.outboundTruckboxNum ?? 'PT'})',
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
            if (c.typeTrip.value == 'vacio') ...[
              const SizedBox(height: 16),
              const Text('¿El regreso es con la misma caja?',
                  style: TextStyle(
                      color: AppColors.navyBlue, fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ChoiceChip(
                      label: 'Sí',
                      selected: c.autoReturnSameTruckbox.value == true,
                      onTap: () => c.setAutoReturnSameTruckbox(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ChoiceChip(
                      label: 'No (drop and hook)',
                      selected: c.autoReturnSameTruckbox.value == false,
                      onTap: () => c.setAutoReturnSameTruckbox(false),
                    ),
                  ),
                ],
              ),
              if (c.autoReturnSameTruckbox.value == false) ...[
                const SizedBox(height: 12),
                _TruckboxFields(
                  isPt: c.returnTruckboxIsPt,
                  number: c.returnTruckboxNumber,
                  owner: c.returnTruckboxOwner,
                  usesOwnTruckboxes: c.usesOwnTruckboxes,
                ),
              ],
            ],
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
                                        child: Text(option.name,
                                            style: const TextStyle(fontSize: 13)),
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
                                child: Text('Otro, especificar',
                                    style: TextStyle(fontSize: 13)),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
          searchMatchFn: (item, searchValue) => itemLabel(item.value as T)
              .toLowerCase()
              .contains(searchValue.toLowerCase()),
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.royalBlue.withValues(alpha: 0.12) : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.royalBlue : AppColors.fieldBorder),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppColors.royalBlue : AppColors.textMedium,
            fontSize: 13,
            fontWeight: FontWeight.w600,
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
          style: const TextStyle(color: AppColors.royalBlue, fontSize: 12.5, fontWeight: FontWeight.w600)),
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
