// Modelos del formulario de alta de viajes de circuito (reemplazo del
// flujo equivalente del chatbot — ver CircuitTripFormService en el
// backend). Todos son catálogos de solo lectura salvo el payload final.

class CircuitOption {
  final int id;
  final String name;

  const CircuitOption({required this.id, required this.name});

  factory CircuitOption.fromJson(Map<String, dynamic> json) => CircuitOption(
        id: json['id'] as int,
        name: (json['name'] ?? '').toString(),
      );

  @override
  bool operator ==(Object other) => other is CircuitOption && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class ClientCircuitOption {
  final int id;
  final String name;
  final String? routeTypeName;

  const ClientCircuitOption({
    required this.id,
    required this.name,
    this.routeTypeName,
  });

  factory ClientCircuitOption.fromJson(Map<String, dynamic> json) =>
      ClientCircuitOption(
        id: json['id'] as int,
        name: (json['name'] ?? '').toString(),
        routeTypeName: json['route_type_name']?.toString(),
      );

  @override
  bool operator ==(Object other) => other is ClientCircuitOption && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class CircuitOperatorOption {
  final int id;
  final String name;
  final int transporterId;
  final String? transporterName;

  const CircuitOperatorOption({
    required this.id,
    required this.name,
    required this.transporterId,
    this.transporterName,
  });

  factory CircuitOperatorOption.fromJson(Map<String, dynamic> json) =>
      CircuitOperatorOption(
        id: json['id'] as int,
        name: (json['name'] ?? '').toString(),
        transporterId: json['transporter_id'] as int,
        transporterName: json['transporter_name']?.toString(),
      );

  @override
  bool operator ==(Object other) =>
      other is CircuitOperatorOption && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class AddressOption {
  final int id;
  final String name;

  const AddressOption({required this.id, required this.name});

  factory AddressOption.fromJson(Map<String, dynamic> json) => AddressOption(
        id: json['id'] as int,
        name: (json['name'] ?? json['label'] ?? '').toString(),
      );

  @override
  bool operator ==(Object other) => other is AddressOption && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// Ítem del catálogo de material adicional (material de sujeción / de
/// protección de carga) — ver AdditionalMaterial en el backend.
class AdditionalMaterialOption {
  final int id;
  final String name;
  final String group; // 'sujecion' | 'proteccion'

  const AdditionalMaterialOption({
    required this.id,
    required this.name,
    required this.group,
  });

  factory AdditionalMaterialOption.fromJson(Map<String, dynamic> json) =>
      AdditionalMaterialOption(
        id: json['id'] as int,
        name: (json['name'] ?? '').toString(),
        group: (json['group'] ?? '').toString(),
      );

  @override
  bool operator ==(Object other) =>
      other is AdditionalMaterialOption && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// Selección de un material adicional en el formulario: puede ser un ítem
/// del catálogo (additionalMaterialId != null) o "Otro, especificar"
/// (customName libre). Cada uno lleva su propio lugar de entrega.
class AdditionalMaterialSelection {
  final int? additionalMaterialId;
  String customName;
  String quantity;
  String deliveryLocation;

  AdditionalMaterialSelection({
    this.additionalMaterialId,
    this.customName = '',
    this.quantity = '',
    this.deliveryLocation = '',
  });

  bool get isOther => additionalMaterialId == null;

  Map<String, dynamic> toJson() => {
        'additional_material_id': additionalMaterialId,
        'custom_name': customName.trim().isEmpty ? null : customName.trim(),
        'quantity': quantity.trim().isEmpty ? null : quantity.trim(),
        'delivery_location':
            deliveryLocation.trim().isEmpty ? null : deliveryLocation.trim(),
      };
}

enum CircuitLeg { outbound, returnLeg }

/// Resultado de resolver el operador elegido — el backend decide
/// automáticamente si corresponde una ida o un regreso de circuito (ver
/// CircuitTripFormService::resolveOperatorLeg).
class OperatorLegResolution {
  final CircuitLeg leg;
  final int operatorId;
  final int transporterId;
  final int? unitId;
  final bool usesOwnTruckboxes;
  // Ida: origen fijo (punto inicial del circuito). Regreso: null (se elige).
  final AddressOption? origin;
  // Regreso: destino fijo (punto inicial del circuito). Ida: null (se elige).
  final AddressOption? destination;
  final int? routeTypeId;
  final int? roundId;
  final String? outboundTruckboxNum;
  final List<AddressOption> returnOriginOptions;

  const OperatorLegResolution({
    required this.leg,
    required this.operatorId,
    required this.transporterId,
    this.unitId,
    required this.usesOwnTruckboxes,
    this.origin,
    this.destination,
    this.routeTypeId,
    this.roundId,
    this.outboundTruckboxNum,
    this.returnOriginOptions = const [],
  });

  bool get isReturn => leg == CircuitLeg.returnLeg;

  factory OperatorLegResolution.fromJson(Map<String, dynamic> json) =>
      OperatorLegResolution(
        leg: json['leg'] == 'return' ? CircuitLeg.returnLeg : CircuitLeg.outbound,
        operatorId: json['operator_id'] as int,
        transporterId: json['transporter_id'] as int,
        unitId: json['unit_id'] as int?,
        usesOwnTruckboxes: json['uses_own_truckboxes'] == true,
        origin: json['origin'] != null
            ? AddressOption.fromJson(json['origin'] as Map<String, dynamic>)
            : null,
        destination: json['destination'] != null
            ? AddressOption.fromJson(json['destination'] as Map<String, dynamic>)
            : null,
        routeTypeId: json['route_type_id'] as int?,
        roundId: json['round_id'] as int?,
        outboundTruckboxNum: json['outbound_truckbox_num']?.toString(),
        returnOriginOptions: (json['return_origin_options'] as List? ?? [])
            .map((e) => AddressOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Datos de un viaje de circuito ya existente para precargar el formulario
/// en modo edición — ver MobileCircuitTripController::edit().
// El backend a veces manda ids como texto (p. ej. unit_id "20").
int? _asInt(Object? v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

class TripEditData {
  final int id;
  final CircuitOption client;
  final int clientCircuitId;
  final CircuitLeg leg;
  final CircuitOperatorOption operator;
  final int? unitId;
  final bool usesOwnTruckboxes;
  final AddressOption? origin;
  final AddressOption? destination;
  final int? routeTypeId;
  final String? typeTrip;
  final DateTime? loadingAppointmentDatetime;
  final String? comments;
  final String? internalLink;
  final String? internalNotes;
  final String? truckboxNumber;
  final String? truckboxOwner;
  final List<AdditionalMaterialSelection> additionalMaterials;
  final List<AddressOption> addressOptions;

  const TripEditData({
    required this.id,
    required this.client,
    required this.clientCircuitId,
    required this.leg,
    required this.operator,
    this.unitId,
    required this.usesOwnTruckboxes,
    this.origin,
    this.destination,
    this.routeTypeId,
    this.typeTrip,
    this.loadingAppointmentDatetime,
    this.comments,
    this.internalLink,
    this.internalNotes,
    this.truckboxNumber,
    this.truckboxOwner,
    this.additionalMaterials = const [],
    this.addressOptions = const [],
  });

  factory TripEditData.fromJson(Map<String, dynamic> json) {
    final truckbox = json['truckbox'] as Map<String, dynamic>? ?? {};
    final materials = (json['additional_materials'] as List? ?? [])
        .map((e) => AdditionalMaterialSelection(
              additionalMaterialId: (e['additional_material_id'] as num?)?.toInt(),
              customName: (e['custom_name'] ?? '').toString(),
              quantity: (e['quantity'] ?? '').toString(),
              deliveryLocation: (e['delivery_location'] ?? '').toString(),
            ))
        .toList();

    return TripEditData(
      id: _asInt(json['id'])!,
      client: CircuitOption.fromJson(json['client'] as Map<String, dynamic>),
      clientCircuitId: _asInt(json['client_circuit_id'])!,
      leg: json['circuit_leg'] == 'return' ? CircuitLeg.returnLeg : CircuitLeg.outbound,
      operator: CircuitOperatorOption.fromJson(json['operator'] as Map<String, dynamic>),
      unitId: _asInt(json['unit_id']),
      usesOwnTruckboxes: json['uses_own_truckboxes'] == true,
      origin: json['origin'] != null ? AddressOption.fromJson(json['origin'] as Map<String, dynamic>) : null,
      destination: json['destination'] != null ? AddressOption.fromJson(json['destination'] as Map<String, dynamic>) : null,
      routeTypeId: _asInt(json['route_type_id']),
      typeTrip: json['type_trip']?.toString(),
      loadingAppointmentDatetime: json['loading_appointment_datetime'] != null
          ? DateTime.tryParse(json['loading_appointment_datetime'].toString())
          : null,
      comments: json['comments']?.toString(),
      internalLink: json['internal_link']?.toString(),
      internalNotes: json['internal_notes']?.toString(),
      truckboxNumber: truckbox['number']?.toString(),
      truckboxOwner: truckbox['owner']?.toString(),
      additionalMaterials: materials,
      addressOptions: (json['address_options'] as List? ?? [])
          .map((e) => AddressOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Elección de caja: PT (sin caja), reutilizar la de la ida (solo aplica al
/// regreso), o un número de caja (+ dueño, solo si el transportista usa
/// cajas propias).
class TruckBoxChoice {
  final bool isPt;
  final bool reuseOutbound;
  final String? number;
  final String? owner; // 'client' | 'transporter'

  const TruckBoxChoice.pt()
      : isPt = true,
        reuseOutbound = false,
        number = null,
        owner = null;

  const TruckBoxChoice.reuseOutbound()
      : isPt = false,
        reuseOutbound = true,
        number = null,
        owner = null;

  const TruckBoxChoice.number(this.number, {this.owner})
      : isPt = false,
        reuseOutbound = false;

  Map<String, dynamic> toJson() {
    if (isPt) return {'pt': true};
    if (reuseOutbound) return {'reuse_outbound': true};
    return {'number': number, if (owner != null) 'owner': owner};
  }
}
