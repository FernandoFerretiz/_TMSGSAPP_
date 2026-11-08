import '../../../utils/helpers/server_time.dart';

class TripSummary {
  final int id;
  final String tripNumber;
  final String truckboxNum;
  final String origin;
  final String destination;
  final String statusCode;
  final String statusLabel;
  final String? assignmentDatetime;
  final String? completionDatetime;
  // Nombre del transportista asignado al viaje.
  final String? line;
  final String? operatorName;
  final String? unitNumber;
  final String? plates;
  // "Cargado" / "Vacío" (u otro valor de type_trip tal cual, p.ej. "drop").
  final String? cargoType;
  // Nombre del RouteType del viaje (Importación, Exportación, Local, etc.).
  final String? routeType;
  // Link público de rastreo del viaje (mismo que "Copiar enlace de cuenta
  // espejo" en el tablero de trips del ERP web).
  final String? mirrorLink;
  // Link para que el operador cargue documentos/evidencias e inicie/
  // finalice el viaje sin la app (usado por "Compartir detalle del viaje").
  final String? evidenceLink;
  final String? comments;
  // Hora de la cita de carga y texto de "Compartir detalle del viaje"
  // armado por el backend (plantilla configurable en el servidor).
  final String? appointmentDatetime;
  final String? shareText;
  // Nombres del material de sujeción agregado al viaje.
  final List<String> additionalMaterials;

  const TripSummary({
    required this.id,
    required this.tripNumber,
    required this.truckboxNum,
    required this.origin,
    required this.destination,
    required this.statusCode,
    required this.statusLabel,
    this.assignmentDatetime,
    this.completionDatetime,
    this.line,
    this.operatorName,
    this.unitNumber,
    this.plates,
    this.cargoType,
    this.routeType,
    this.mirrorLink,
    this.evidenceLink,
    this.comments,
    this.appointmentDatetime,
    this.shareText,
    this.additionalMaterials = const [],
  });

  factory TripSummary.fromJson(Map<String, dynamic> json) => TripSummary(
        id: json['id'] as int,
        tripNumber: (json['trip_number'] ?? json['id']).toString(),
        truckboxNum: (json['truckbox_num'] ?? '').toString(),
        origin: (json['origin'] ?? '').toString(),
        destination: (json['destination'] ?? '').toString(),
        statusCode: (json['status_code'] ?? '').toString(),
        statusLabel: (json['status_label'] ?? '').toString(),
        assignmentDatetime: json['assignment_datetime']?.toString(),
        completionDatetime: json['completion_datetime']?.toString(),
        line: json['line']?.toString(),
        operatorName: json['operator_name']?.toString(),
        unitNumber: json['unit_number']?.toString(),
        plates: json['plates']?.toString(),
        cargoType: json['cargo_type']?.toString(),
        routeType: json['route_type']?.toString(),
        mirrorLink: json['mirror_link']?.toString(),
        evidenceLink: json['evidence_link']?.toString(),
        comments: (json['comments'] as String?)?.trim().isNotEmpty == true
            ? json['comments'] as String
            : null,
        appointmentDatetime: json['appointment_datetime']?.toString(),
        shareText: json['share_text']?.toString(),
        additionalMaterials: (json['additional_materials'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Un movimiento (viaje) dentro de una ronda, en el orden de la ronda.
class TripRoundMovement {
  final TripSummary trip;
  final int position;
  // outbound | intermediate | return | single
  final String role;
  // Cuándo se registró el viaje (puede no ser seguido al de los demás de la ronda).
  final String? registeredAt;

  const TripRoundMovement({
    required this.trip,
    required this.position,
    required this.role,
    this.registeredAt,
  });

  factory TripRoundMovement.fromJson(Map<String, dynamic> json) => TripRoundMovement(
        trip: TripSummary.fromJson(json),
        position: (json['position'] as num?)?.toInt() ?? 1,
        role: (json['role'] ?? 'intermediate').toString(),
        registeredAt: json['registered_at']?.toString(),
      );
}

/// Una ronda de circuito con todos sus movimientos (o un viaje suelto como
/// ronda de un solo movimiento) — ver MobileTripHistoryController::rounds.
class TripRoundGroup {
  final String key;
  final int? roundId;
  // Última actividad (movimiento más reciente): ubica la tarjeta en su día.
  final DateTime? lastActivity;
  // open | closed | voided | single
  final String state;
  final String? circuit;
  final String? operatorName;
  final String route;
  // Ronda abierta: de dónde saldría el siguiente movimiento.
  final String? nextOrigin;
  final int? clientId;
  final int? clientCircuitId;
  final int? operatorId;
  final List<TripRoundMovement> movements;

  const TripRoundGroup({
    required this.key,
    this.roundId,
    this.lastActivity,
    required this.state,
    this.circuit,
    this.operatorName,
    required this.route,
    this.nextOrigin,
    this.clientId,
    this.clientCircuitId,
    this.operatorId,
    required this.movements,
  });

  bool get isOpen => state == 'open';
  bool get isSingle => state == 'single';
  int get finishedCount => movements.where((m) => m.trip.statusCode == 'finished').length;

  factory TripRoundGroup.fromJson(Map<String, dynamic> json) => TripRoundGroup(
        key: (json['key'] ?? '').toString(),
        roundId: (json['round_id'] as num?)?.toInt(),
        lastActivity: parseServerDateTime(json['last_activity']),
        state: (json['state'] ?? 'single').toString(),
        circuit: json['circuit']?.toString(),
        operatorName: json['operator_name']?.toString(),
        route: (json['route'] ?? '').toString(),
        nextOrigin: json['next_origin']?.toString(),
        clientId: (json['client_id'] as num?)?.toInt(),
        clientCircuitId: (json['client_circuit_id'] as num?)?.toInt(),
        operatorId: (json['operator_id'] as num?)?.toInt(),
        movements: (json['movements'] as List? ?? [])
            .map((e) => TripRoundMovement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
