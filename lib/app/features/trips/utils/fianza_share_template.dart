import '../models/trip_model.dart';

const _dash = '—';

/// Texto para compartir/copiar los datos de la caja usados para tramitar la
/// fianza — vienen del catálogo truck_boxes del backend (ver
/// MobileTripController::activeTrip), no de algo que capture el operador.
String fianzaShareText(TripModel trip) {
  final truckbox = trip.truckbox;

  return 'Datos para fianza\n'
      'Caja: ${trip.truckboxNum.isNotEmpty ? trip.truckboxNum : _dash}\n'
      'Económico: ${truckbox?.number ?? _dash}\n'
      'Marca: ${truckbox?.brand ?? _dash}\n'
      'Placas: ${truckbox?.plates ?? _dash}\n'
      'Año: ${truckbox?.year ?? _dash}\n'
      'No. de serie: ${truckbox?.serialNumber ?? _dash}';
}
