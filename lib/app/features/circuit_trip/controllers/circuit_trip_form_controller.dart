import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../data/circuit_trip_service.dart';
import '../models/circuit_trip_models.dart';

/// Movimiento intermedio de una ruta (alta con todos los movimientos): sale de
/// donde llegó el anterior; tipo y caja se definen por movimiento.
class RouteStop {
  // null = sale del destino del movimiento anterior; si se elige otro, la caja
  // viaja sin registrar el tramo intermedio (p. ej. baterías → frenos).
  final origin = Rxn<AddressOption>();
  final destination = Rxn<AddressOption>();
  final typeTrip = Rxn<String>(); // 'cargado' | 'vacio'
  // true (por defecto) = misma caja del movimiento anterior; false = otra (drop and hook).
  final sameTruckbox = Rxn<bool>(true);
  final truckboxIsPt = false.obs;
  final truckboxNumber = ''.obs;
  final truckboxOwner = Rxn<String>();
  // Información interna de este viaje (solo la ve el equipo).
  final internalLink = ''.obs;
  final internalNotes = ''.obs;
}

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

    final args = Get.arguments;
    final tripId = args is int ? args : null;
    if (tripId != null) {
      loadForEdit(tripId);
    } else if (args is Map && args['operator_id'] != null) {
      preselectRound(args);
    } else {
      loadClients();
    }
  }

  /// Se abrió desde una ronda abierta (historial): cliente, circuito y operador
  /// ya vienen elegidos para registrar solo el siguiente movimiento.
  bool openedFromRound = false;

  Future<void> preselectRound(Map args) async {
    openedFromRound = true;
    await loadClients();

    final client = _pick(clients, (args['client_id'] as num).toInt());
    if (client == null) return;
    await selectClient(client);

    final circuit = _pick(circuits, (args['client_circuit_id'] as num).toInt());
    if (circuit == null) return;
    if (selectedCircuit.value?.id != circuit.id) await selectCircuit(circuit);

    final operator = _pick(operators, (args['operator_id'] as num).toInt());
    if (operator != null) await selectOperator(operator);
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
      editCanRemove.value = data.canRemove;
      editCanAddMovements.value = data.canAddMovements;
      if (data.canAddMovements) {
        // Todos los lugares del circuito: origen y destino de los trayectos nuevos.
        try {
          allAddressOptions.value = await _service.getDestinationOptions(
            clientCircuitId: data.clientCircuitId,
            originId: 0,
          );
        } catch (_) {
          editCanAddMovements.value = false;
        }
      }

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

  /// El viaje en edición es un movimiento intermedio o fin que aún no inicia.
  final editCanRemove = false.obs;

  /// Se pueden agregar trayectos después de este viaje (es el último de una vuelta abierta).
  final editCanAddMovements = false.obs;

  /// En edición los trayectos nuevos salen del destino de este viaje.
  AddressOption? get editChainStart =>
      isOutbound ? selectedDestination.value : legResolution.value?.destination;

  /// Trayectos nuevos solo si ya hay con qué encadenarlos.
  bool get canAddEditStops => isEditing && editCanAddMovements.value && editChainStart != null;

  /// Elimina un movimiento ya registrado. Devuelve true si se eliminó; en el
  /// alta de una vuelta abierta vuelve a cargar el historial.
  Future<bool> removeMovement(int tripId) async {
    errorMessage.value = '';
    try {
      await _service.removeMovement(tripId);
    } catch (e) {
      errorMessage.value = _dioMessage(e, 'No se pudo eliminar el movimiento.');
      return false;
    }
    if (!isEditing && selectedOperator.value != null) {
      await selectOperator(selectedOperator.value);
    }
    return true;
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
    stops.clear();
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
          : await _service.getDestinationOptions(clientCircuitId: circuit.id, originId: initial.id);

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
      } else if (resolution.nextOrigin != null) {
        // Vuelta abierta: el siguiente movimiento sale de donde terminó el último.
        await selectReturnOrigin(resolution.nextOrigin);
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
      // Todos los lugares del circuito (con el punto inicial) para los movimientos adicionales.
      allAddressOptions.value = await _service.getDestinationOptions(
        clientCircuitId: selectedCircuit.value!.id,
        originId: 0,
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
    // Si el destino de la ida cambia, lo que dependía de él se vuelve a elegir.
    _revalidateRoute();
  }

  void selectDestinationPending() {
    selectedDestination.value = null;
    destinationPending.value = true;
    // Sin destino definido solo se puede crear la ida.
    _resetAutoReturn();
    autoReturn.value = false;
  }

  /// Quita de la ruta lo que ya no es válido tras cambiar un punto: un
  /// movimiento no puede terminar donde empieza, y el fin depende del último punto.
  void _revalidateRoute() {
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      if (stop.destination.value?.id == stopOrigin(i)?.id) stop.destination.value = null;
    }
  }

  // ── Paso 4b (regreso): origen ────────────────────────────────────────
  final selectedReturnOrigin = Rxn<AddressOption>();
  final returnOriginRouteTypeId = Rxn<int>();
  final isLoadingReturnRouteType = false.obs;

  Future<void> selectReturnOrigin(AddressOption? address) async {
    selectedReturnOrigin.value = address;
    returnOriginRouteTypeId.value = null;
    movementDestination.value = null;
    movementDestinationOptions.clear();
    if (address == null) return;

    isLoadingReturnRouteType.value = true;
    try {
      returnOriginRouteTypeId.value = await _service.getReturnOriginRouteType(
        clientId: selectedClient.value!.id,
        clientCircuitId: selectedCircuit.value!.id,
        originId: address.id,
      );
    } catch (e) {
      // Un origen intermedio puede no tener tipo de ruta definido: el alta no lo exige.
      if (isEditing) {
        errorMessage.value = _dioMessage(e, 'No se pudo resolver el tipo de ruta.');
      }
    } finally {
      isLoadingReturnRouteType.value = false;
    }

    if (!isEditing) await _loadMovementDestinations(address.id);
  }

  // ── Vuelta abierta: siguiente movimiento (intermedio o fin) ───────────
  final isFinalMovement = Rxn<bool>();
  // Fin de la ruta: "¿El destino y el origen son el mismo?" (Sí = llega al
  // punto inicial del circuito; No = se elige otro destino).
  final openFinSamePlace = Rxn<bool>();
  final movementTypeTrip = Rxn<String>();
  final movementDestination = Rxn<AddressOption>();
  final movementDestinationOptions = <AddressOption>[].obs;
  final isLoadingMovementDestinations = false.obs;

  /// Punto inicial del circuito (p. ej. Patio THR): si el movimiento llega ahí,
  /// la ronda se cierra; con cualquier otro destino sigue abierta.
  AddressOption? get circuitStartPlace => legResolution.value?.destination;

  Future<void> _loadMovementDestinations(int originId) async {
    isLoadingMovementDestinations.value = true;
    // Por defecto el movimiento regresa al inicio del circuito (fin de la ruta).
    _selectCircuitStart();
    try {
      final start = circuitStartPlace;
      final options = await _service.getDestinationOptions(
        clientCircuitId: selectedCircuit.value!.id,
        originId: originId,
      );
      // El inicio del circuito va primero y es la opción por defecto.
      movementDestinationOptions.value = [
        if (start != null) start,
        ...options.where((o) => o.id != start?.id),
      ];
    } catch (_) {
      errorMessage.value = 'No se pudieron cargar los destinos del movimiento.';
    } finally {
      isLoadingMovementDestinations.value = false;
    }
  }

  void _selectCircuitStart() {
    isFinalMovement.value = true;
    openFinSamePlace.value = true;
    movementDestination.value = null;
  }

  /// Destino mostrado en el selector (por defecto, el inicio del circuito).
  AddressOption? get movementDestinationShown =>
      (isFinalMovement.value == true && openFinSamePlace.value == true)
          ? circuitStartPlace
          : movementDestination.value;

  /// Sin pregunta de "¿es el fin?": llegar al inicio del circuito cierra la
  /// ronda; cualquier otro destino deja la ronda abierta (movimiento intermedio).
  void pickMovementDestination(AddressOption? a) {
    if (a == null) return;
    if (a.id == circuitStartPlace?.id) {
      _selectCircuitStart();
    } else {
      isFinalMovement.value = false;
      openFinSamePlace.value = null;
      movementDestination.value = a;
    }
  }

  void setFinalMovement(bool value) {
    isFinalMovement.value = value;
    openFinSamePlace.value = null;
    movementDestination.value = null;
  }

  void setOpenFinSamePlace(bool value) {
    openFinSamePlace.value = value;
    movementDestination.value = null;
  }

  /// El destino se elige de la lista (intermedio, o fin a otro lugar).
  bool get movementNeedsDestination =>
      isFinalMovement.value == false ||
      (isFinalMovement.value == true && openFinSamePlace.value == false);

  void selectMovementDestination(AddressOption? a) => movementDestination.value = a;
  void selectMovementType(String v) => movementTypeTrip.value = v;

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
  }

  // ── Movimientos adicionales (alta) ───────────────────────────────────
  // La ida es el primer movimiento; cada uno que se agrega sale del destino del
  // anterior y, por defecto, llega al inicio del circuito. El último es el fin.
  // Con "No" solo se crea la ida y los demás se agregan después.
  final autoReturn = Rxn<bool>(true);
  final stops = <RouteStop>[].obs;
  // Todos los lugares del circuito (incluido el punto inicial).
  final allAddressOptions = <AddressOption>[].obs;

  /// En el alta de una ida la ruta se arma en una sola tarjeta (línea de tiempo).
  bool get isRouteMode => isOutbound && !isEditing;

  /// Movimientos de la ruta armada y cuántos se crearán ahora.
  int get routeMovementCount => destinationPending.value ? 1 : stops.length + 1;
  int get tripsToCreate =>
      (destinationPending.value || autoReturn.value != true) ? 1 : routeMovementCount;

  /// "A → B → C" con los lugares ya elegidos ('¿?' los que faltan).
  String get routeSummary {
    final names = <String>[
      legResolution.value?.origin?.name ?? '¿?',
      destinationPending.value ? 'Pendiente' : (selectedDestination.value?.name ?? '¿?'),
    ];
    if (!destinationPending.value) {
      for (final s in stops) {
        names.add(s.destination.value?.name ?? '¿?');
      }
    }
    return names.join(' → ');
  }

  void setAutoReturn(bool value) {
    autoReturn.value = value;
  }

  /// Origen del movimiento adicional [index]: el destino del anterior.
  AddressOption? stopOrigin(int index) => stops[index].origin.value ?? _chainedOrigin(index);

  AddressOption? _chainedOrigin(int index) =>
      index == 0
          ? (isEditing ? editChainStart : selectedDestination.value)
          : stops[index - 1].destination.value;

  /// Orígenes posibles de un movimiento adicional: todo el circuito menos su destino.
  List<AddressOption> stopOriginOptions(int index) {
    final destId = stops[index].destination.value?.id;
    return allAddressOptions.where((o) => o.id != destId).toList();
  }

  void selectStopOrigin(int index, AddressOption? address) {
    final stop = stops[index];
    // Si coincide con el destino anterior vuelve a seguirlo automáticamente.
    stop.origin.value = address?.id == _chainedOrigin(index)?.id ? null : address;
    if (stop.destination.value?.id == stopOrigin(index)?.id) stop.destination.value = null;
    _revalidateRoute();
  }

  void addStop() {
    final stop = RouteStop();
    // Abre con el inicio del circuito como destino, salvo que ahí mismo termine el anterior.
    final initial = legResolution.value?.origin;
    final origin = stops.isEmpty
        ? (isEditing ? editChainStart : selectedDestination.value)
        : stops.last.destination.value;
    if (initial != null && origin?.id != initial.id) stop.destination.value = initial;
    stops.add(stop);
  }

  void removeStop(int index) {
    stops.removeAt(index);
    _revalidateRoute();
  }

  void moveStop(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= stops.length) return;
    final stop = stops.removeAt(index);
    stops.insert(target, stop);
    _revalidateRoute();
  }

  /// Destinos posibles de un movimiento adicional: todo el circuito menos su origen.
  List<AddressOption> stopOptions(int index) {
    final originId = stopOrigin(index)?.id;
    return allAddressOptions.where((o) => o.id != originId).toList();
  }

  void selectStopDestination(RouteStop stop, AddressOption? address) {
    stop.destination.value = address;
    _revalidateRoute();
  }

  void _resetAutoReturn() {
    autoReturn.value = true;
    stops.clear();
  }

  bool get _autoReturnReady {
    if (isEditing) return stops.every(_stopReady);
    if (!isRouteMode) return true;
    if (destinationPending.value || autoReturn.value != true) return true;
    return stops.every(_stopReady);
  }

  bool _stopReady(RouteStop s) {
    if (s.destination.value == null || s.typeTrip.value == null) return false;
    if (s.sameTruckbox.value == null) return false;
    if (s.sameTruckbox.value == true) return true;
    return _truckboxChoiceReady(
        s.truckboxIsPt.value, s.truckboxNumber.value, s.truckboxOwner.value);
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

  void setSameAsOutboundTruckbox(bool value) {
    sameAsOutboundTruckbox.value = value;
    if (value) {
      truckboxIsPt.value = false;
      truckboxNumber.value = '';
      truckboxOwner.value = null;
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
      selectedAdditionalMaterials.removeWhere((s) => s.additionalMaterialId == option.id);
    }
  }

  bool get otherMaterialSelected => selectedAdditionalMaterials.any((s) => s.isOther);

  void toggleOtherMaterial(bool selected) {
    if (selected) {
      selectedAdditionalMaterials.add(AdditionalMaterialSelection());
    } else {
      selectedAdditionalMaterials.removeWhere((s) => s.isOther);
    }
  }

  bool get _additionalMaterialsReady =>
      !selectedAdditionalMaterials.any((s) => s.isOther && s.customName.trim().isEmpty);

  // ── Validación / envío ───────────────────────────────────────────────
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  bool get isOutbound => legResolution.value?.leg == CircuitLeg.outbound;
  bool get isReturn => legResolution.value?.leg == CircuitLeg.returnLeg;
  bool get usesOwnTruckboxes => legResolution.value?.usesOwnTruckboxes ?? false;

  bool get originDestinationReady => isOutbound
      ? (selectedDestination.value != null || destinationPending.value)
      : selectedReturnOrigin.value != null && (!isEditing || returnOriginRouteTypeId.value != null);

  bool get _movementReady {
    if (isFinalMovement.value == null || movementTypeTrip.value == null) return false;
    if (isFinalMovement.value == true && openFinSamePlace.value == null) return false;
    return !movementNeedsDestination || movementDestination.value != null;
  }

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

  /// Lo que falta para poder registrar (se muestra bajo el botón apagado).
  List<String> get missingItems {
    if (legResolution.value == null) return const [];
    final m = <String>[];
    if (isOutbound && selectedDestination.value == null && !destinationPending.value) {
      m.add('el destino de la ida');
    }
    if (isReturn && selectedReturnOrigin.value == null) m.add('el origen del movimiento');
    if (!_typeTripReady) m.add('el tipo de viaje de la ida (cargado o vacío)');
    if (!_appointmentReady) m.add('la fecha y hora de la cita');
    if (isReturn && !isEditing) {
      if (isFinalMovement.value == null) m.add('si este movimiento es el fin de la ruta');
      if (isFinalMovement.value == true && openFinSamePlace.value == null) {
        m.add('si el destino y el origen son el mismo');
      }
      if (isFinalMovement.value != null && movementNeedsDestination && movementDestination.value == null) {
        m.add('el destino del movimiento');
      }
      if (movementTypeTrip.value == null) m.add('el tipo de viaje del movimiento');
    }
    if (!_mainTruckboxReady) {
      m.add(isReturn && sameAsOutboundTruckbox.value == null
          ? 'si es la misma caja'
          : 'la caja${usesOwnTruckboxes && !truckboxIsPt.value && truckboxNumber.value.trim().isNotEmpty ? ' (de quién es)' : ''}');
    }
    for (var i = 0; i < stops.length; i++) {
      final s = stops[i];
      final n = isEditing ? 'Trayecto ${i + 1}' : 'Movimiento ${i + 2}';
      if (s.destination.value == null) m.add('$n: el destino');
      if (s.typeTrip.value == null) m.add('$n: el tipo de viaje (cargado o vacío)');
      if (s.sameTruckbox.value == null ||
          (s.sameTruckbox.value == false &&
              !_truckboxChoiceReady(
                  s.truckboxIsPt.value, s.truckboxNumber.value, s.truckboxOwner.value))) {
        m.add('$n: la caja');
      }
    }
    if (!_additionalMaterialsReady) m.add('el nombre del material adicional "Otro"');
    return m;
  }

  /// Link http(s) válido, o null si está vacío o no es un link.
  static String? validLink(String raw) {
    final v = raw.trim();
    final uri = Uri.tryParse(v);
    final ok = uri != null && uri.hasAuthority && (uri.scheme == 'http' || uri.scheme == 'https');
    return ok ? v : null;
  }

  /// Si el viaje (o alguno de sus trayectos) no trae un link de evidencias válido.
  bool get hasMissingEvidenceLink =>
      validLink(internalLink.value) == null ||
      stops.any((s) => validLink(s.internalLink.value) == null);

  bool get canSubmit =>
      legResolution.value != null &&
      originDestinationReady &&
      _appointmentReady &&
      _typeTripReady &&
      (!isReturn || isEditing || _movementReady) &&
      _autoReturnReady &&
      _mainTruckboxReady &&
      _additionalMaterialsReady &&
      !isSubmitting.value;

  TruckBoxChoice _buildTruckboxChoice(bool isPt, String number, String? owner) {
    if (isPt) return const TruckBoxChoice.pt();
    return TruckBoxChoice.number(number.trim(), owner: owner);
  }

  /// Trayectos armados en pantalla, en el formato que espera el servidor.
  List<Map<String, dynamic>> _movementsPayload() => [
        for (final s in stops)
          {
            if (s.origin.value != null) 'origin_id': s.origin.value!.id,
            'destination_id': s.destination.value!.id,
            'type_trip': s.typeTrip.value,
            'internal_link':
                validLink(s.internalLink.value),
            'internal_notes':
                s.internalNotes.value.trim().isEmpty ? null : s.internalNotes.value.trim(),
            'truckbox': s.sameTruckbox.value == true
                ? {'reuse_previous': true}
                : _buildTruckboxChoice(
                    s.truckboxIsPt.value,
                    s.truckboxNumber.value,
                    s.truckboxOwner.value,
                  ).toJson(),
          },
      ];

  // ── Cajas no registradas ─────────────────────────────────────────────
  int get clientIdForTruckboxes => selectedClient.value!.id;
  int get transporterIdForTruckboxes => legResolution.value!.transporterId;

  /// Cajas escritas a mano (no PT, no reutilizadas) como [número, dueño].
  List<({String number, String? owner})> _typedTruckboxes() {
    final list = <({String number, String? owner})>[];
    final reuse = isReturn && sameAsOutboundTruckbox.value == true;
    if (!reuse && !truckboxIsPt.value && truckboxNumber.value.trim().isNotEmpty) {
      list.add((number: truckboxNumber.value.trim(), owner: truckboxOwner.value));
    }
    for (final s in stops) {
      if (s.sameTruckbox.value == true || s.truckboxIsPt.value) continue;
      if (s.truckboxNumber.value.trim().isEmpty) continue;
      list.add((number: s.truckboxNumber.value.trim(), owner: s.truckboxOwner.value));
    }
    return list;
  }

  /// Cajas del formulario que el sistema no tiene registradas. Si la consulta
  /// falla devuelve vacío: el envío sigue y el servidor valida.
  Future<List<MissingTruckbox>> findMissingTruckboxes() async {
    final typed = _typedTruckboxes();
    if (typed.isEmpty || legResolution.value == null || selectedClient.value == null) return const [];

    try {
      return await _service.checkTruckboxes(
        clientId: clientIdForTruckboxes,
        transporterId: transporterIdForTruckboxes,
        items: [
          for (final t in typed)
            {'number': t.number, if (usesOwnTruckboxes && t.owner != null) 'owner': t.owner},
        ],
      );
    } catch (_) {
      return const [];
    }
  }

  /// Registra la caja; devuelve null si todo salió bien o el mensaje de error.
  Future<String?> registerTruckbox({
    required String number,
    required String owner,
    required String plates,
    required String serialNumber,
    required String year,
    required String brand,
  }) async {
    try {
      await _service.registerTruckbox({
        'client_id': clientIdForTruckboxes,
        'transporter_id': transporterIdForTruckboxes,
        'owner': owner,
        'number': number,
        'plates': plates.trim(),
        'serial_number': serialNumber.trim(),
        'year': int.tryParse(year.trim()),
        'brand': brand.trim(),
      });
    } catch (e) {
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['errors'] is Map) {
          final first = (data['errors'] as Map).values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
      }
      return _dioMessage(e, 'No se pudo registrar la caja.');
    }

    // Con cajas propias, el viaje debe apuntar al dueño con el que se registró.
    if (usesOwnTruckboxes) {
      if (truckboxNumber.value.trim() == number) truckboxOwner.value = owner;
      for (final s in stops) {
        if (s.truckboxNumber.value.trim() == number) s.truckboxOwner.value = owner;
      }
    }
    return null;
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
          'internal_link': validLink(internalLink.value),
          'internal_notes': internalNotes.value.trim().isEmpty ? null : internalNotes.value.trim(),
          'truckbox': _buildTruckboxChoice(
            truckboxIsPt.value,
            truckboxNumber.value,
            truckboxOwner.value,
          ).toJson(),
          'additional_materials': selectedAdditionalMaterials.map((s) => s.toJson()).toList(),
          'confirm_without_tracking': true,
          if (stops.isNotEmpty) 'movements': _movementsPayload(),
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
        'circuit_leg':
            isReturn ? (isFinalMovement.value == false ? 'intermediate' : 'return') : 'outbound',
        'confirm_without_tracking': true,
        'comments': comments.value.trim().isEmpty ? null : comments.value.trim(),
        'internal_link': validLink(internalLink.value),
        'internal_notes': internalNotes.value.trim().isEmpty ? null : internalNotes.value.trim(),
        'loading_appointment_datetime': appointmentDateTime.value?.toIso8601String(),
        'additional_materials': selectedAdditionalMaterials.map((s) => s.toJson()).toList(),
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

        if (autoReturn.value == true && stops.isNotEmpty) {
          // Todos los movimientos de una vez; el último es el fin de la ruta.
          payload['movements'] = _movementsPayload();
        }
      } else {
        payload['origin_id'] = selectedReturnOrigin.value!.id;
        payload['destination_id'] =
            movementNeedsDestination ? movementDestination.value!.id : leg.destination!.id;
        payload['type_trip'] = movementTypeTrip.value;
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
      errorMessage.value = _dioMessage(
          e,
          isEditing
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
    isFinalMovement.value = null;
    openFinSamePlace.value = null;
    movementTypeTrip.value = null;
    movementDestination.value = null;
    movementDestinationOptions.clear();
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
    _resetAutoReturn();
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
