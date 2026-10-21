import '../models/trip_event.dart';
import '../models/trip_summary.dart';

// Plantillas de texto para compartir un evento del historial de viaje por
// WhatsApp/Telegram. Hardcodeadas a propósito por ahora — la idea es que
// más adelante esto se reemplace por una plantilla editable desde el
// backend, pero mientras tanto el formato vive aquí.

const _dash = '—';

String _headerBlock(TripSummary trip) => 'Línea: ${trip.line ?? _dash}\n'
    'Operador: ${trip.operatorName ?? _dash}\n'
    'Unidad: ${trip.unitNumber ?? _dash}\n'
    'Placas: ${trip.plates ?? _dash}\n'
    'Caja: ${trip.truckboxNum.isNotEmpty ? trip.truckboxNum : _dash}';

String _evidenceLine(TripEvent event) {
  final count = event.files.length;
  if (count == 0) return 'Evidencia: Sin evidencia adjunta';
  return 'Evidencia: $count ${count == 1 ? 'foto adjunta' : 'fotos adjuntas'}';
}

/// Formato para incidencias reportadas por el operador (ver ejemplo del
/// usuario: "Acceso negado en destino").
String incidentShareText(TripSummary trip, TripEvent event) {
  final buffer = StringBuffer(_headerBlock(trip))
    ..write('\nEvento: ${event.title}');

  if (event.subtitle != null && event.subtitle!.trim().isNotEmpty) {
    buffer.write('\nComentarios del operador:\n\n${event.subtitle!.trim()}\n');
  }

  buffer.write('\n${_evidenceLine(event)}');
  return buffer.toString();
}

/// Formato para el evento de inicio de viaje: checklist, sello, evidencia y
/// el link de cuenta espejo.
String tripStartShareText(TripSummary trip, TripEvent event) {
  final buffer = StringBuffer(_headerBlock(trip))
    ..write('\nEvento: Inicio de viaje\n');

  buffer.write('\nChecklist:');
  if (event.checklist.isEmpty) {
    buffer.write('\nSin checklist registrado');
  } else {
    for (final answer in event.checklist) {
      buffer.write('\n- ${answer.prompt}: ${answer.answer}');
      if (answer.detail != null && answer.detail!.trim().isNotEmpty) {
        buffer.write(' (${answer.detail!.trim()})');
      }
    }
  }

  buffer.write('\n\nSello: ${event.sealCode ?? 'No registrado'}');
  buffer.write('\n\n${_evidenceLine(event)}');
  buffer.write('\n\nCuenta espejo: ${trip.mirrorLink ?? 'No disponible'}');
  return buffer.toString();
}

/// Formato genérico para el resto de cambios de estado (arribo, finalizado,
/// etc.) — mismo encabezado, sin las secciones específicas de inicio.
String genericStatusShareText(TripSummary trip, TripEvent event) {
  final buffer = StringBuffer(_headerBlock(trip))
    ..write('\nEvento: ${event.title.replaceFirst('Cambio de estado: ', '')}');

  if (event.subtitle != null && event.subtitle!.trim().isNotEmpty) {
    buffer.write('\nComentarios del operador:\n\n${event.subtitle!.trim()}\n');
  }

  buffer.write('\n${_evidenceLine(event)}');
  return buffer.toString();
}

/// Detalle general del viaje (no de un evento puntual) — botón "Compartir
/// detalle del viaje" en el encabezado del historial.
String tripDetailShareText(TripSummary trip) {
  final materials = trip.additionalMaterials.isEmpty
      ? _dash
      : trip.additionalMaterials.join(', ');

  final buffer = StringBuffer()
    ..write('Comparto detalle del viaje para: ${trip.operatorName ?? _dash}\n')
    ..write('Caja: ${trip.truckboxNum.isNotEmpty ? trip.truckboxNum : _dash}\n')
    ..write('Trayecto: ${trip.routeType ?? _dash}\n')
    ..write('${trip.cargoType ?? _dash}\n')
    ..write('Origen: ${trip.origin.isNotEmpty ? trip.origin : _dash}\n')
    ..write('Destino: ${trip.destination.isNotEmpty ? trip.destination : _dash}\n')
    ..write('Material adicional: $materials\n')
    ..write('Comentarios adicionales: ${trip.comments ?? _dash}');

  if (trip.evidenceLink != null) {
    buffer.write('\n\n${trip.evidenceLink}');
  }

  return buffer.toString();
}

/// Decide qué plantilla usar según el tipo de evento.
String shareTextFor(TripSummary trip, TripEvent event) {
  if (event.type == TripEventType.incident) {
    return incidentShareText(trip, event);
  }
  // El checklist/sello/evidencia de inicio ahora se capturan en "accepted"
  // (el operador ya no los sube en "started", que pasó a ser 100%
  // automático por GPS) — este evento es el que tiene esos datos.
  if (event.statusCode == 'accepted') {
    return tripStartShareText(trip, event);
  }
  return genericStatusShareText(trip, event);
}
