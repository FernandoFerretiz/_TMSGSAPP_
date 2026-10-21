import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../data/circuit_trip_service.dart';
import '../models/circuit_trip_models.dart';

/// Controla el formulario de alta de circuito paso a paso — cada selección
/// dispara la consulta del siguiente catálogo, igual que el chatbot lo hace
/// conversacionalmente (ver CircuitTripFormService en el backend). Los
/// pasos posteriores a cualquier selección se limpian al cambiarla, para
/// nunca enviar una combinación a medio resolver.
class CircuitTripFormController extends GetxController {
  final CircuitTripService _service;
  CircuitTripFormController(this._service);

  @override
  void onInit() {
    super.onInit();
    loadAdditionalMaterials();

    final tripId = Get.arguments is int ? Get.arguments as int : null;
    if (tripId != null) {
      loadForEdit(tripId);
    } else {
      loadClients();
    }
  }

  // ── Modo edición (viaje de circuito ya existente) ────────────────────
  final editingTripId = Rxn<int>();
  final isLoadingForEdit = false.obs;
  final editLoadFailed = false.obs;
  bool get isEditing => editingTripId.value != null;

  /// Carga un viaje existente y precarga todos los pasos del formulario con
  /// sus valores actuales — a diferencia del alta, aquí no se "resuelve" la
  /// ida/regreso (eso ya quedó decidido cuando se creó el viaje): se toma
  /// tal cual viene del backend (ver MobileCircuitTripController::edit()).
  Future<void> loadForEdit(int tripId) async {
    // Se marca el modo edición desde el inicio: si la carga falla, la
    // pantalla debe mostrar el error y no caer al formulario de alta.
    editingTripId.value = tripId;
    editLoadFailed.value = false;
    isLoadingForEdit.value = true;
    errorMessage.value = '';
    try {
      final data = await _service.getForEdit(tripId);

      editLeg = data.leg;

      // Catálogos completos para que cliente, circuito y operador sigan
      // siendo editables, con el valor actual del viaje preseleccionado.
      clients.value = await _service.getClients();
      selectedClient.value = _pick(clients, data.client.id) ?? data.client;

      circuits.value = await _service.getCircuits(data.client.id);
      selectedCircuit.value = _pick(circuits, data.clientCircuitId) ??
          ClientCircuitOption(id: data.clientCircuitId, name: '');

      final loadedOperators = await _service.getOperators(
        clientId: data.client.id,
        clientCircuitId: data.clientCircuitId,
      );
      // El operador actual puede no venir en el catálogo (p. ej. ya tiene
      // su regreso asignado): se agrega para que quede preseleccionado.
      operators.value = loadedOperators.any((o) => o.id == data.operator.id)
          ? loadedOperators
          : [data.operator, ...loadedOperators];
      selectedOperator.value = _pick(operators, data.operator.id);

      // Las opciones de origen/destino vienen en la misma respuesta de edición
      // (no se vuelve a resolver el operador: la vuelta ya no está abierta).
      final returnOriginOptions =
          data.leg == CircuitLeg.returnLeg ? data.addressOptions : const <AddressOption>[];

      legResolution.value = OperatorLegResolution(
        leg: data.leg,
        operatorId: data.operator.id,
        transporterId: data.operator.transporterId,
        unitId: data.unitId,
        usesOwnTruckboxes: data.usesOwnTruckboxes,
        origin: data.leg == CircuitLeg.outbound ? data.origin : null,
        destination: data.leg == CircuitLeg.returnLeg ? data.destination : null,
        routeTypeId: data.routeTypeId,
        returnOriginOptions: returnOriginOptions,
      );

      if (data.leg == CircuitLeg.outbound) {
        destinationOptions.value = data.addressOptions;
        if (data.destination != null) {
          selectedDestination.value = data.destination;
        } else {
          destinationPending.value = true;
        }
        typeTrip.value = data.typeTrip;
      } else {
        selectedReturnOrigin.value = data.origin;
        returnOriginRouteTypeId.value = data.routeTypeId;
      }

      hasAppointment.value = data.loadingAppointmentDatetime != null;
      appointmentDateTime.value = data.loadingAppointmentDatetime;
      comments.value = data.comments ?? '';
      internalLink.value = data.internalLink ?? '';
      internalNotes.value = data.internalNotes ?? '';

      // El regreso ya no se "reutiliza" de la ida al editar: se muestra y
      // edita la caja tal cual quedó guardada en este viaje puntual.
      sameAsOutboundTruckbox.value = data.leg == CircuitLeg.returnLeg ? false : null;
      truckboxIsPt.value = data.truckboxNumber == null || data.truckboxNumber == 'PT';
      truckboxNumber.value = truckboxIsPt.value ? '' : (data.truckboxNumber ?? '');
      truckboxOwner.value = data.truckboxOwner;

      selectedAdditionalMaterials.value = data.additionalMaterials;
    } catch (e) {
      editLoadFailed.value = true;
      errorMessage.value = _dioMessage(e, 'No se pudo cargar el viaje para editarlo.');
    } finally {
      isLoadingForEdit.value = false;
    }
  }

  /// Tramo del viaje que se está editando: no cambia al cambiar
  /// cliente/circuito/operador (solo se re-resuelven los catálogos).
  CircuitLeg? editLeg;

  T? _pick<T>(List<T> list, int id) {
    for (final item in list) {
      final itemId = (item as dynamic).id as int;
      if (itemId == id) return item;
    }
    return null;
  }

  void _clearEditLegSelections() {
    legResolution.value = null;
    destinationOptions.clear();
    selectedDestination.value = null;
    destinationPending.value = false;
    selectedReturnOrigin.value = null;
    returnOriginRouteTypeId.value = null;
  }

  /// Al cambiar el operador (o circuito) en edición se conserva el tramo del
  /// viaje y solo se recalculan origen/destino fijos y catálogos del circuito.
  Future<void> _resolveForEdit(CircuitOperatorOption operator) async {
    isResolvingOperator.value = true;
    try {
      final client = selectedClient.value!;
      final circuit = selectedCircuit.value!;
      final resolution = await _service.resolveOperator(
        clientId: client.id,
        clientCircuitId: circuit.id,
        operatorId: operator.id,
        confirmWithoutTracking: true,
      );

      // Punto inicial del circuito: origen fijo en la ida (viene en
      // resolution.origin) o destino fijo en el regreso.
      final initial = resolution.origin ?? resolution.destination;
      final options = initial == null
          ? const <AddressOption>[]
          : await _service.getDestinationOptions(
              clientCircuitId: circuit.id, originId: initial.id);

      final isReturnLeg = editLeg == CircuitLeg.returnLeg;
      int? routeTypeId;
      if (!isReturnLeg && initial != null) {
        routeTypeId = await _service.getReturnOriginRouteType(
          clientId: client.id,
          clientCircuitId: circuit.id,
          originId: initial.id,
        );
      }

      destinationOptions.value = isReturnLeg ? const [] : options;
      legResolution.value = OperatorLegResolution(
        leg: editLeg ?? resolution.leg,
        operatorId: resolution.operatorId,
        transporterId: resolution.transporterId,
        unitId: resolution.unitId,
        usesOwnTruckboxes: resolution.usesOwnTruckboxes,
        origin: isReturnLeg ? null : initial,
        destination: isReturnLeg ? initial : null,
        routeTypeId: routeTypeId,
        returnOriginOptions: isReturnLeg ? options : const [],
      );
    } catch (e) {
      _handleResolveError(e, operator);
    } finally {
      isResolvingOperator.value = false;
    }
  }

  Future<void> _selectClientForEdit(CircuitOption? client) async {
    selectedClient.value = client;
    circuits.clear();
    selectedCircuit.value = null;
    operators.clear();
    selectedOperator.value = null;
    _clearEditLegSelections();
    if (client == null) return;

    isLoadingCircuits.value = true;
    try {
      circuits.value = await _service.getCircuits(client.id);
      if (circuits.length == 1) await _selectCircuitForEdit(circuits.first);
    } catch (_) {
      errorMessage.value = 'No se pudieron cargar los circuitos del cliente.';
    } finally {
      isLoadingCircuits.value = false;
    }
  }

  Future<void> _selectCircuitForEdit(ClientCircuitOption? circuit) async {
    selectedCircuit.value = circuit;
    operators.clear();
    selectedOperator.value = null;
    _clearEditLegSelections();
    if (circuit == null || selectedClient.value == null) return;

    isLoadingOperators.value = true;
    try {
      operators.value = await _service.getOperators(
        clientId: selectedClient.value!.id,
        clientCircuitId: circuit.id,
      );
    } catch (e) {
      errorMessage.value = _dioMessage(e, 'No se pudieron cargar los operadores.');
    } finally {
      isLoadingOperators.value = false;
    }
  }

  Future<void> _selectOperatorForEdit(CircuitOperatorOption? operator) async {
    selectedOperator.value = operator;
    _clearEditLegSelections();
    if (operator == null || selectedClient.value == null || selectedCircuit.value == null) {
      return;
    }
    await _resolveForEdit(operator);
  }

  // ── Paso 1: cliente ──────────────────────────────────────────────────
  final clients = <CircuitOption>[].obs;
  final isLoadingClients = false.obs;
  final selectedClient = Rxn<CircuitOption>();

  Future<void> loadClients() async {
    isLoadingClients.value = true;
    errorMessage.value = '';
    try {
      clients.value = await _service.getClients();
    } catch (_) {
      errorMessage.value = 'No se pudieron cargar los clientes con circuito.';
    } finally {
      isLoadingClients.value = false;
    }
  }

  Future<void> selectClient(CircuitOption? client) async {
    if (isEditing) return _selectClientForEdit(client);
    selectedClient.value = client;
    _resetFromCircuit();
    if (client == null) return;

    isLoadingCircuits.value = true;
    try {
      final result = await _service.getCircuits(client.id);
      circuits.value = result;
      // Mismo atajo que el chatbot: si el cliente solo tiene un circuito,
      // se selecciona solo — ver resolveCircuitsForClient().
      if (result.length == 1) {
        await selectCircuit(result.first);
      }
    } catch (_) {
      errorMessage.value = 'No se pudieron cargar los circuitos del cliente.';
    } finally {
      isLoadingCircuits.value = false;
    }
  }

  // ── Paso 2: circuito ─────────────────────────────────────────────────
  final circuits = <ClientCircuitOption>[].obs;
  final isLoadingCircuits = false.obs;
  final selectedCircuit = Rxn<ClientCircuitOption>();

  Future<void> selectCircuit(ClientCircuitOption? circuit) async {
    if (isEditing) return _selectCircuitForEdit(circuit);
    selectedCircuit.value = circuit;
    _resetFromOperator();
    if (circuit == null || selectedClient.value == null) return;

    isLoadingOperators.value = true;
    try {
      operators.value = await _service.getOperators(
        clientId: selectedClient.value!.id,
        clientCircuitId: circuit.id,
      );
    } catch (e) {
      errorMessage.value = _dioMessage(e, 'No se pudieron cargar los operadores.');
    } finally {
      isLoadingOperators.value = false;
    }
  }

  // ── Paso 3: operador (resuelve ida/regreso automáticamente) ─────────
  final operators = <CircuitOperatorOption>[].obs;
  final isLoadingOperators = false.obs;
  final selectedOperator = Rxn<CircuitOperatorOption>();
  final legResolution = Rxn<OperatorLegResolution>();
  final isResolvingOperator = false.obs;

  Future<void> selectOperator(CircuitOperatorOption? operator) async {
    if (isEditing) return _selectOperatorForEdit(operator);
    selectedOperator.value = operator;
    _resetFromLeg();
    if (operator == null || selectedClient.value == null || selectedCircuit.value == null) {
      return;
    }

    isResolvingOperator.value = true;
    try {
      final resolution = await _service.resolveOperator(
        clientId: selectedClient.value!.id,
        clientCircuitId: selectedCircuit.value!.id,
        operatorId: operator.id,
        confirmWithoutTracking: true,
      );
      legResolution.value = resolution;

      if (resolution.leg == CircuitLeg.outbound && resolution.origin != null) {
        await _loadDestinationOptions(resolution.origin!.id);
      }
    } catch (e) {
      _handleResolveError(e, operator);
    } finally {
      isResolvingOperator.value = false;
    }
  }

  // ── Paso 4a (ida): destino ───────────────────────────────────────────
  final destinationOptions = <AddressOption>[].obs;
  final isLoadingDestinations = false.obs;
  final selectedDestination = Rxn<AddressOption>();
  final destinationPending = false.obs;

  Future<void> _loadDestinationOptions(int originId) async {
    isLoadingDestinations.value = true;
    try {
      destinationOptions.value = await _service.getDestinationOptions(
        clientCircuitId: selectedCircuit.value!.id,
        originId: originId,
      );
    } catch (_) {
      errorMessage.value = 'No se pudieron cargar los destinos del circuito.';
    } finally {
      isLoadingDestinations.value = false;
    }
  }

  void selectDestination(AddressOption? address) {
    selectedDestination.value = address;
    destinationPending.value = false;
  }

  void selectDestinationPending() {
    selectedDestination.value = null;
    destinationPending.value = true;
  }

  // ── Paso 4b (regreso): origen ────────────────────────────────────────
  final selectedReturnOrigin = Rxn<AddressOption>();
  final returnOriginRouteTypeId = Rxn<int>();
  final isLoadingReturnRouteType = false.obs;

  Future<void> selectReturnOrigin(AddressOption? address) async {
    selectedReturnOrigin.value = address;
    returnOriginRouteTypeId.value = null;
    if (address == null) return;

    isLoadingReturnRouteType.value = true;
    try {
      returnOriginRouteTypeId.value = await _service.getReturnOriginRouteType(
        clientId: selectedClient.value!.id,
        clientCircuitId: selectedCircuit.value!.id,
        originId: address.id,
      );
    } catch (e) {
      errorMessage.value = _dioMessage(e, 'No se pudo resolver el tipo de ruta.');
    } finally {
      isLoadingReturnRouteType.value = false;
    }
  }

  // ── Paso 5: cita ─────────────────────────────────────────────────────
  final hasAppointment = false.obs;
  final appointmentDateTime = Rxn<DateTime>();

  void setHasAppointment(bool value) {
    hasAppointment.value = value;
    if (!value) appointmentDateTime.value = null;
  }

  // ── Paso 6 (solo ida): tipo de viaje ─────────────────────────────────
  final typeTrip = Rxn<String>(); // 'cargado' | 'vacio'

  void selectTypeTrip(String value) {
    typeTrip.value = value;
    // Cambiar de Vacío a Cargado invalida cualquier decisión de regreso
    // automático ya tomada.
    if (value != 'vacio') {
      autoReturnSameTruckbox.value = null;
      returnTruckboxIsPt.value = false;
      returnTruckboxNumber.value = '';
      returnTruckboxOwner.value = null;
    }
  }

  // ── Paso 7: comentarios ──────────────────────────────────────────────
  final comments = ''.obs;

  // Información interna (nunca visible para el operador ni el
  // transportista): link que nos comparte el cliente para subir ahí los
  // documentos/evidencias, y notas libres para el equipo.
  final internalLink = ''.obs;
  final internalNotes = ''.obs;

  // ── Paso 8: caja ─────────────────────────────────────────────────────
  // Regreso: "¿es la misma caja de la ida?"
  final sameAsOutboundTruckbox = Rxn<bool>();
  // Caja propia del tramo (ida siempre; regreso solo si sameAsOutbound == false)
  final truckboxIsPt = false.obs;
  final truckboxNumber = ''.obs;
  final truckboxOwner = Rxn<String>(); // 'client' | 'transporter'
  // Ida Vacío: "¿el regreso es con la misma caja?"
  final autoReturnSameTruckbox = Rxn<bool>();
  final returnTruckboxIsPt = false.obs;
  final returnTruckboxNumber = ''.obs;
  final returnTruckboxOwner = Rxn<String>();

  void setSameAsOutboundTruckbox(bool value) {
    sameAsOutboundTruckbox.value = value;
    if (value) {
      truckboxIsPt.value = false;
      truckboxNumber.value = '';
      truckboxOwner.value = null;
    }
  }

  void setAutoReturnSameTruckbox(bool value) {
    autoReturnSameTruckbox.value = value;
    if (value) {
      returnTruckboxIsPt.value = false;
      returnTruckboxNumber.value = '';
      returnTruckboxOwner.value = null;
    }
  }

  // ── Paso 9: material adicional (opcional) ────────────────────────────
  final additionalMaterialOptions = <AdditionalMaterialOption>[].obs;
  final isLoadingAdditionalMaterials = false.obs;
  final selectedAdditionalMaterials = <AdditionalMaterialSelection>[].obs;

  Future<void> loadAdditionalMaterials() async {
    isLoadingAdditionalMaterials.value = true;
    try {
      additionalMaterialOptions.value = await _service.getAdditionalMaterials();
    } catch (_) {
      // No bloquea el resto del formulario: material adicional es opcional.
    } finally {
      isLoadingAdditionalMaterials.value = false;
    }
  }

  void toggleAdditionalMaterial(AdditionalMaterialOption option, bool selected) {
    if (selected) {
      selectedAdditionalMaterials.add(
        AdditionalMaterialSelection(
          additionalMaterialId: option.id,
          customName: option.name,
        ),
      );
    } else {
      selectedAdditionalMaterials
          .removeWhere((s) => s.additionalMaterialId == option.id);
    }
  }

  bool get otherMaterialSelected =>
      selectedAdditionalMaterials.any((s) => s.isOther);

  void toggleOtherMaterial(bool selected) {
    if (selected) {
      selectedAdditionalMaterials.add(AdditionalMaterialSelection());
    } else {
      selectedAdditionalMaterials.removeWhere((s) => s.isOther);
    }
  }

  bool get _additionalMaterialsReady => !selectedAdditionalMaterials
      .any((s) => s.isOther && s.customName.trim().isEmpty);

  // ── Validación / envío ───────────────────────────────────────────────
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  bool get isOutbound => legResolution.value?.leg == CircuitLeg.outbound;
  bool get isReturn => legResolution.value?.leg == CircuitLeg.returnLeg;
  bool get usesOwnTruckboxes => legResolution.value?.usesOwnTruckboxes ?? false;

  bool get originDestinationReady =>
      isOutbound
          ? (selectedDestination.value != null || destinationPending.value)
          : selectedReturnOrigin.value != null && returnOriginRouteTypeId.value != null;

  bool get _appointmentReady => !hasAppointment.value || appointmentDateTime.value != null;

  bool get _typeTripReady => isReturn || typeTrip.value != null;

  bool _truckboxChoiceReady(bool isPt, String number, String? owner) {
    if (isPt) return true;
    if (number.trim().isEmpty) return false;
    if (usesOwnTruckboxes && owner == null) return false;
    return true;
  }

  bool get _mainTruckboxReady {
    if (isReturn) {
      if (sameAsOutboundTruckbox.value == null) return false;
      if (sameAsOutboundTruckbox.value == true) return true;
      return _truckboxChoiceReady(truckboxIsPt.value, truckboxNumber.value, truckboxOwner.value);
    }
    return _truckboxChoiceReady(truckboxIsPt.value, truckboxNumber.value, truckboxOwner.value);
  }

  bool get _autoReturnTruckboxReady {
    if (!isOutbound || typeTrip.value != 'vacio') return true;
    if (autoReturnSameTruckbox.value == null) return false;
    if (autoReturnSameTruckbox.value == true) return true;
    return _truckboxChoiceReady(
        returnTruckboxIsPt.value, returnTruckboxNumber.value, returnTruckboxOwner.value);
  }

  bool get canSubmit =>
      legResolution.value != null &&
      originDestinationReady &&
      _appointmentReady &&
      _typeTripReady &&
      _mainTruckboxReady &&
      _autoReturnTruckboxReady &&
      _additionalMaterialsReady &&
      !isSubmitting.value;

  TruckBoxChoice _buildTruckboxChoice(bool isPt, String number, String? owner) {
    if (isPt) return const TruckBoxChoice.pt();
    return TruckBoxChoice.number(number.trim(), owner: owner);
  }

  Future<CircuitTripSubmitResult?> submit() async {
    if (!canSubmit) return null;
    final leg = legResolution.value!;

    isSubmitting.value = true;
    errorMessage.value = '';
    try {
      if (isEditing) {
        final payload = <String, dynamic>{
          'client_id': selectedClient.value!.id,
          'client_circuit_id': selectedCircuit.value!.id,
          'origin_id': isOutbound ? leg.origin!.id : selectedReturnOrigin.value!.id,
          'destination_id': isOutbound
              ? (destinationPending.value ? null : selectedDestination.value!.id)
              : leg.destination!.id,
          'route_type_id': isOutbound ? leg.routeTypeId : returnOriginRouteTypeId.value,
          'operator_id': leg.operatorId,
          'transporter_id': leg.transporterId,
          'unit_id': leg.unitId,
          'loading_appointment_datetime': appointmentDateTime.value?.toIso8601String(),
          'type_trip': isOutbound ? typeTrip.value : null,
          'comments': comments.value.trim().isEmpty ? null : comments.value.trim(),
          'internal_link': internalLink.value.trim().isEmpty ? null : internalLink.value.trim(),
          'internal_notes': internalNotes.value.trim().isEmpty ? null : internalNotes.value.trim(),
          'truckbox': _buildTruckboxChoice(
            truckboxIsPt.value,
            truckboxNumber.value,
            truckboxOwner.value,
          ).toJson(),
          'additional_materials':
              selectedAdditionalMaterials.map((s) => s.toJson()).toList(),
          'confirm_without_tracking': true,
        };

        await _service.update(editingTripId.value!, payload);
        return CircuitTripSubmitResult(
          outboundTripId: isOutbound ? editingTripId.value : null,
          returnTripId: isReturn ? editingTripId.value : null,
        );
      }

      final payload = <String, dynamic>{
        'client_id': selectedClient.value!.id,
        'client_circuit_id': selectedCircuit.value!.id,
        'operator_id': leg.operatorId,
        'transporter_id': leg.transporterId,
        'unit_id': leg.unitId,
        'circuit_leg': isReturn ? 'return' : 'outbound',
        'confirm_without_tracking': true,
        'comments': comments.value.trim().isEmpty ? null : comments.value.trim(),
        'internal_link': internalLink.value.trim().isEmpty ? null : internalLink.value.trim(),
        'internal_notes': internalNotes.value.trim().isEmpty ? null : internalNotes.value.trim(),
        'loading_appointment_datetime': appointmentDateTime.value?.toIso8601String(),
        'additional_materials':
            selectedAdditionalMaterials.map((s) => s.toJson()).toList(),
      };

      if (isOutbound) {
        payload['origin_id'] = leg.origin!.id;
        payload['destination_id'] = destinationPending.value ? null : selectedDestination.value!.id;
        payload['route_type_id'] = leg.routeTypeId;
        payload['type_trip'] = typeTrip.value;
        payload['truckbox'] = _buildTruckboxChoice(
          truckboxIsPt.value,
          truckboxNumber.value,
          truckboxOwner.value,
        ).toJson();

        if (typeTrip.value == 'vacio') {
          payload['return_truckbox'] = autoReturnSameTruckbox.value == true
              ? null
              : _buildTruckboxChoice(
                  returnTruckboxIsPt.value,
                  returnTruckboxNumber.value,
                  returnTruckboxOwner.value,
                ).toJson();
        }
      } else {
        payload['origin_id'] = selectedReturnOrigin.value!.id;
        payload['destination_id'] = leg.destination!.id;
        payload['route_type_id'] = returnOriginRouteTypeId.value;
        payload['client_circuit_round_id'] = leg.roundId;
        payload['truckbox'] = sameAsOutboundTruckbox.value == true
            ? const TruckBoxChoice.reuseOutbound().toJson()
            : _buildTruckboxChoice(
                truckboxIsPt.value,
                truckboxNumber.value,
                truckboxOwner.value,
              ).toJson();
      }

      return await _service.submit(payload);
    } catch (e) {
      errorMessage.value = _dioMessage(e, isEditing
          ? 'No se pudo actualizar el viaje.'
          : 'No se pudo registrar la asignación de circuito.');
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Regresa el formulario a su estado inicial (después de crear un viaje
  /// con éxito, para poder dar de alta otro sin salir de la pantalla).
  void resetAll() {
    selectedClient.value = null;
    _resetFromCircuit();
  }

  void _resetFromCircuit() {
    circuits.clear();
    selectedCircuit.value = null;
    _resetFromOperator();
  }

  void _resetFromOperator() {
    operators.clear();
    selectedOperator.value = null;
    _resetFromLeg();
  }

  void _resetFromLeg() {
    legResolution.value = null;
    destinationOptions.clear();
    selectedDestination.value = null;
    destinationPending.value = false;
    selectedReturnOrigin.value = null;
    returnOriginRouteTypeId.value = null;
    hasAppointment.value = false;
    appointmentDateTime.value = null;
    typeTrip.value = null;
    comments.value = '';
    internalLink.value = '';
    internalNotes.value = '';
    sameAsOutboundTruckbox.value = null;
    truckboxIsPt.value = false;
    truckboxNumber.value = '';
    truckboxOwner.value = null;
    autoReturnSameTruckbox.value = null;
    returnTruckboxIsPt.value = false;
    returnTruckboxNumber.value = '';
    returnTruckboxOwner.value = null;
    selectedAdditionalMaterials.clear();
  }

  Future<void> _handleResolveError(Object e, CircuitOperatorOption? operator) async {
    errorMessage.value = _dioMessage(e, 'No se pudo resolver el operador.');
  }

  String _dioMessage(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    }
    return fallback;
  }
}
