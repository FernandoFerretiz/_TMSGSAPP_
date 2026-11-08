import '../../utils/helpers/server_time.dart';

/// Cliente con al menos un viaje activo (GET /mobile/unit-statuses/clients).
class UnitStatusClient {
  final int id;
  final String name;
  const UnitStatusClient({required this.id, required this.name});

  factory UnitStatusClient.fromJson(Map<String, dynamic> json) =>
      UnitStatusClient(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
      );
}

/// Un status con su fecha y hora: el operacional (Creado, Asignado, En tránsito,
/// Arribo, Completado) o el último sub status de la bitácora (en espera de
/// rampa, etc.).
class UnitStatusEntry {
  final String label;
  final String? comment;
  // Hora de pared de Monterrey, para mostrarla.
  final DateTime? at;
  // Instante real, para calcular el tiempo transcurrido.
  final DateTime? instant;

  const UnitStatusEntry(
      {required this.label, this.comment, this.at, this.instant});

  factory UnitStatusEntry.fromJson(Map<String, dynamic> json) =>
      UnitStatusEntry(
        label: (json['label'] ?? '').toString(),
        comment: json['comment']?.toString(),
        at: parseServerDateTime(json['at']),
        instant: DateTime.tryParse((json['at'] ?? '').toString())?.toUtc(),
      );

  /// "hace 5 min", "hace 2 h 15 min", "hace 3 d".
  String? get elapsed {
    if (instant == null) return null;
    final diff = DateTime.now().toUtc().difference(instant!);
    if (diff.isNegative || diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) {
      final m = diff.inMinutes % 60;
      return m == 0
          ? 'hace ${diff.inHours} h'
          : 'hace ${diff.inHours} h $m min';
    }
    return 'hace ${diff.inDays} d';
  }
}

/// Tarjeta de un viaje activo del cliente (GET /mobile/unit-statuses).
class UnitStatusItem {
  final int tripId;
  final String? operatorName;
  final String? unitNumber;
  final String? truckboxNum;
  final String? routeType;
  final String? cargoType;
  final String? origin;
  final String? destination;
  // Hora estimada de llegada vigente (null si aún no se calcula).
  final UnitStatusEntry? eta;
  final UnitStatusEntry? status;
  final UnitStatusEntry? subStatus;
  // Solo en reportes guardados: el comentario adicional de esa unidad.
  final String? comment;

  const UnitStatusItem({
    required this.tripId,
    this.operatorName,
    this.unitNumber,
    this.truckboxNum,
    this.routeType,
    this.cargoType,
    this.origin,
    this.destination,
    this.eta,
    this.status,
    this.subStatus,
    this.comment,
  });

  factory UnitStatusItem.fromJson(Map<String, dynamic> json) => UnitStatusItem(
        tripId: (json['trip_id'] as num).toInt(),
        operatorName: json['operator_name']?.toString(),
        unitNumber: json['unit_number']?.toString(),
        truckboxNum: json['truckbox_num']?.toString(),
        routeType: json['route_type']?.toString(),
        cargoType: json['cargo_type']?.toString(),
        origin: json['origin']?.toString(),
        destination: json['destination']?.toString(),
        eta: json['eta'] is Map<String, dynamic>
            ? UnitStatusEntry.fromJson(
                {...(json['eta'] as Map<String, dynamic>), 'label': 'ETA'})
            : null,
        status: json['status'] is Map<String, dynamic>
            ? UnitStatusEntry.fromJson(json['status'] as Map<String, dynamic>)
            : null,
        subStatus: json['sub_status'] is Map<String, dynamic>
            ? UnitStatusEntry.fromJson(
                json['sub_status'] as Map<String, dynamic>)
            : null,
        comment: json['comment']?.toString(),
      );

  /// "Importación · Cargado" (lo que haya).
  String get tripKind => [routeType, cargoType]
      .where((e) => e != null && e.trim().isNotEmpty)
      .join(' · ');
}

/// Un reporte ya generado (GET /mobile/unit-reports).
class UnitReportSummary {
  final int id;
  final String clientName;
  final String? createdByName;
  // Hora de pared de Monterrey.
  final DateTime? generatedAt;
  final int unitsCount;
  final String shareUrl;

  const UnitReportSummary({
    required this.id,
    required this.clientName,
    this.createdByName,
    this.generatedAt,
    required this.unitsCount,
    required this.shareUrl,
  });

  factory UnitReportSummary.fromJson(Map<String, dynamic> json) =>
      UnitReportSummary(
        id: (json['id'] as num).toInt(),
        clientName: (json['client_name'] ?? '').toString(),
        createdByName: json['created_by_name']?.toString(),
        generatedAt: parseServerDateTime(json['generated_at']),
        unitsCount: (json['units_count'] as num?)?.toInt() ?? 0,
        shareUrl: (json['share_url'] ?? '').toString(),
      );
}
