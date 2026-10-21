import 'trip_evidence_file.dart';

enum TripEventType { status, incident, stop }

/// A single answered checklist question for a status-change event (e.g. the
/// "Inicio de viaje" pre-trip checklist), with its own photos if any.
class TripEventChecklistAnswer {
  final String prompt;
  final String answer;
  final String? detail;
  final List<TripEvidenceFile> photos;

  const TripEventChecklistAnswer({
    required this.prompt,
    required this.answer,
    this.detail,
    this.photos = const [],
  });

  factory TripEventChecklistAnswer.fromJson(Map<String, dynamic> json) =>
      TripEventChecklistAnswer(
        prompt: (json['prompt'] ?? '').toString(),
        answer: (json['answer'] ?? '').toString(),
        detail: json['detail']?.toString(),
        photos: (json['files'] as List? ?? [])
            .map((e) => TripEvidenceFile.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Minimal trip identification attached to each item of the cross-trip
/// "Últimos eventos" feed (GET /mobile/events) — null for events read from a
/// single trip's timeline (GET /mobile/trips/{trip}/history), which already
/// has the trip in scope.
class TripEventTripContext {
  final int id;
  final String? truckboxNum;
  final String? unitNumber;
  final String? line;

  const TripEventTripContext({
    required this.id,
    this.truckboxNum,
    this.unitNumber,
    this.line,
  });

  factory TripEventTripContext.fromJson(Map<String, dynamic> json) =>
      TripEventTripContext(
        id: json['id'] as int,
        truckboxNum: json['truckbox_num']?.toString(),
        unitNumber: json['unit_number']?.toString(),
        line: json['line']?.toString(),
      );
}

/// A dynamic field captured on an incident (from IncidentType.extra_fields),
/// already resolved to a human-readable label by the backend.
class TripEventExtraField {
  final String label;
  final String value;

  const TripEventExtraField({required this.label, required this.value});

  factory TripEventExtraField.fromJson(Map<String, dynamic> json) =>
      TripEventExtraField(
        label: (json['label'] ?? '').toString(),
        value: (json['value'] ?? '').toString(),
      );
}

class TripEvent {
  final TripEventType type;
  final String title;
  final String? subtitle;
  final String? actorName;
  final DateTime? timestamp;
  final List<TripEvidenceFile> files;
  // Only set for type == status: assigned|started|arrived|finished.
  final String? statusCode;
  // Security seal code, parsed by the backend from the status-change
  // comments — only present on the "started"/"finished" events that
  // captured it.
  final String? sealCode;
  final List<TripEventChecklistAnswer> checklist;
  // Only meaningful for type == incident.
  final bool? canContinueTrip;
  final List<TripEventExtraField> extraFields;
  // Todos los eventos "críticos" (hoy solo detenciones) comparten el mismo
  // tratamiento visual (borde rojo, tarjeta más ancha) y de comportamiento
  // (se reordenan al tope del feed en cada recordatorio) — ver
  // MobileTripHistoryController::CRITICAL_EVENT_TYPES en el backend.
  final bool eventoCritico;
  // Solo viene poblado en el feed de "Últimos eventos" (varios viajes a la
  // vez); null cuando el evento viene del timeline de un solo viaje.
  final TripEventTripContext? trip;

  const TripEvent({
    required this.type,
    required this.title,
    this.subtitle,
    this.actorName,
    this.timestamp,
    this.files = const [],
    this.statusCode,
    this.sealCode,
    this.checklist = const [],
    this.canContinueTrip,
    this.extraFields = const [],
    this.eventoCritico = false,
    this.trip,
  });

  factory TripEvent.fromJson(Map<String, dynamic> json) => TripEvent(
        type: switch (json['type']) {
          'incident' => TripEventType.incident,
          'stop' => TripEventType.stop,
          _ => TripEventType.status,
        },
        title: (json['title'] ?? '').toString(),
        subtitle: json['subtitle']?.toString(),
        actorName: json['actor_name']?.toString(),
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'].toString())
            : null,
        files: (json['files'] as List? ?? [])
            .map((e) => TripEvidenceFile.fromJson(e as Map<String, dynamic>))
            .toList(),
        statusCode: json['status_code']?.toString(),
        sealCode: json['seal_code']?.toString(),
        checklist: (json['checklist'] as List? ?? [])
            .map((e) =>
                TripEventChecklistAnswer.fromJson(e as Map<String, dynamic>))
            .toList(),
        canContinueTrip: json['can_continue_trip'] as bool?,
        extraFields: (json['extra_data'] as List? ?? [])
            .map((e) => TripEventExtraField.fromJson(e as Map<String, dynamic>))
            .toList(),
        eventoCritico: json['evento_critico'] as bool? ?? false,
        trip: json['trip'] != null
            ? TripEventTripContext.fromJson(json['trip'] as Map<String, dynamic>)
            : null,
      );
}
