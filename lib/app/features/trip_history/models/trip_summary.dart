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
        additionalMaterials: (json['additional_materials'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}
