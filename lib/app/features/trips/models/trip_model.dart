import 'checklist_question.dart';
import 'trip_requirements.dart';

/// Datos de la caja (catálogo truck_boxes del backend) usados para compartir
/// el "resumen para fianza" desde la pantalla de documentos.
class TruckBoxInfo {
  final String? number;
  final String? brand;
  final String? plates;
  // El catálogo casi nunca trae "model" capturado, solo el año.
  final String? year;
  final String? serialNumber;
  final String? model;
  final String? color;

  const TruckBoxInfo({
    this.number,
    this.brand,
    this.plates,
    this.year,
    this.serialNumber,
    this.model,
    this.color,
  });

  factory TruckBoxInfo.fromJson(Map<String, dynamic> json) => TruckBoxInfo(
        number: json['number']?.toString(),
        brand: json['brand']?.toString(),
        plates: json['plates']?.toString(),
        year: json['year']?.toString(),
        serialNumber: json['serial_number']?.toString(),
        model: json['model']?.toString(),
        color: json['color']?.toString(),
      );

  bool get isCompleteForFianza =>
      (number?.trim().isNotEmpty ?? false) &&
      (brand?.trim().isNotEmpty ?? false) &&
      (plates?.trim().isNotEmpty ?? false) &&
      (year?.trim().isNotEmpty ?? false) &&
      (serialNumber?.trim().isNotEmpty ?? false);
}

/// Material de sujeción agregado al viaje (ver AdditionalMaterial /
/// TripAdditionalMaterial en el backend) — la app pide evidencia de cada uno
/// antes de poder iniciar el viaje.
class AdditionalMaterialItem {
  final int id;
  final String name;
  final String? quantity;
  final String? deliveryLocation;
  final bool hasEvidence;

  const AdditionalMaterialItem({
    required this.id,
    required this.name,
    this.quantity,
    this.deliveryLocation,
    this.hasEvidence = false,
  });

  factory AdditionalMaterialItem.fromJson(Map<String, dynamic> json) =>
      AdditionalMaterialItem(
        id: json['id'] as int,
        name: (json['name'] ?? '').toString(),
        quantity: json['quantity']?.toString(),
        deliveryLocation: json['delivery_location']?.toString(),
        hasEvidence: json['has_evidence'] == true,
      );
}

class TripModel {
  final int id;
  final String truckboxNum;
  final String origin;
  final String destination;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? destinationMapsUrl;
  final String? evidenceLink;
  final String? routeType;
  final String? transporter;
  final String? operatorName;
  final String? boxState;
  final String? comments;
  final String status;
  final String statusLabel;
  final String? assignmentDatetime;
  final String? appointmentDatetime;
  final String? departureDatetime;
  final String? arrivalDatetime;
  final bool isEmptyTrip;
  final TruckBoxInfo? truckbox;
  final List<ChecklistQuestion> checklistQuestions;
  final List<AdditionalMaterialItem> additionalMaterials;
  final TripRequirements requirements;

  const TripModel({
    required this.id,
    required this.truckboxNum,
    required this.origin,
    required this.destination,
    this.destinationLatitude,
    this.destinationLongitude,
    this.destinationMapsUrl,
    this.evidenceLink,
    this.routeType,
    this.transporter,
    this.operatorName,
    this.boxState,
    this.comments,
    required this.status,
    required this.statusLabel,
    this.assignmentDatetime,
    this.appointmentDatetime,
    this.departureDatetime,
    this.arrivalDatetime,
    this.isEmptyTrip = false,
    this.truckbox,
    this.checklistQuestions = const [],
    this.additionalMaterials = const [],
    this.requirements = const TripRequirements(),
  });

  bool get isAssigned => status == 'assigned';
  bool get isAccepted => status == 'accepted';
  bool get isReportedToClient => status == 'reported_to_client';
  bool get isRampAssigned => status == 'ramp_assigned';
  bool get isLoadingUnloading => status == 'loading_unloading';
  bool get isStarted => status == 'started';
  bool get isArrived => status == 'arrived';
  bool get isFinished => status == 'finished';

  /// Any of the 3 optional/reusable estados de patio, in either window
  /// (pre-tránsito o post-arribo — ver [isPreTransitWindow]).
  bool get isOptionalStatus =>
      isReportedToClient || isRampAssigned || isLoadingUnloading;

  /// True while the trip hasn't arrived yet — only meaningful together with
  /// [isOptionalStatus], since los 3 estados opcionales se reutilizan tanto
  /// antes de salir como después de arribar.
  bool get isPreTransitWindow => arrivalDatetime == null;

  bool get isPreTransitOptional => isOptionalStatus && isPreTransitWindow;
  bool get isPostArrivalOptional => isOptionalStatus && !isPreTransitWindow;

  /// True when the trip is in an active tracking state: en tránsito, o en la
  /// ventana pre-tránsito (accepted + los 3 opcionales antes de arribar) —
  /// el GPS debe seguir corriendo ahí para poder detectar el arranque.
  bool get requiresTracking =>
      isStarted || isAccepted || isPreTransitOptional || isArrived;

  factory TripModel.fromJson(Map<String, dynamic> json) => TripModel(
        id: json['id'] as int,
        truckboxNum: (json['truckbox_num'] ?? '').toString(),
        origin: (json['origin'] ?? '').toString(),
        destination: (json['destination'] ?? '').toString(),
        destinationLatitude: (json['destination_latitude'] as num?)?.toDouble(),
        destinationLongitude: (json['destination_longitude'] as num?)?.toDouble(),
        destinationMapsUrl: json['destination_maps_url']?.toString(),
        evidenceLink: json['evidence_link']?.toString(),
        routeType: json['route_type']?.toString(),
        transporter: json['transporter']?.toString(),
        operatorName: json['operator']?.toString(),
        boxState: json['box_state']?.toString(),
        comments: (json['comments'] as String?)?.trim().isNotEmpty == true
            ? json['comments'] as String
            : null,
        status: (json['status'] ?? '').toString(),
        statusLabel: (json['status_label'] ?? '').toString(),
        assignmentDatetime: json['assignment_datetime']?.toString(),
        appointmentDatetime: json['appointment_datetime']?.toString(),
        departureDatetime: json['departure_datetime']?.toString(),
        arrivalDatetime: json['arrival_datetime']?.toString(),
        isEmptyTrip: json['is_empty_trip'] == true,
        truckbox: json['truckbox'] != null
            ? TruckBoxInfo.fromJson(json['truckbox'] as Map<String, dynamic>)
            : null,
        checklistQuestions: (json['checklist_questions'] as List? ?? [])
            .map((e) => ChecklistQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
        additionalMaterials: (json['additional_materials'] as List? ?? [])
            .map((e) =>
                AdditionalMaterialItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        requirements: TripRequirements.fromJson(
            json['requirements'] as Map<String, dynamic>?),
      );
}
