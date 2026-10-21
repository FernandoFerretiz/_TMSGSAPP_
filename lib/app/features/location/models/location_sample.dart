/// A single GPS fix captured between server flushes.
///
/// Round-trips through the local sqflite queue (`toDbMap`/`fromDbMap`) and
/// carries a client-generated [locationUuid] used for server-side
/// idempotency when a batch is retried.
class LocationSample {
  final int? id;
  final int tripId;
  final String locationUuid;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final DateTime recordedAt;

  const LocationSample({
    this.id,
    required this.tripId,
    required this.locationUuid,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    required this.recordedAt,
  });

  Map<String, Object?> toDbMap() => {
        'trip_id': tripId,
        'location_uuid': locationUuid,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
      };

  factory LocationSample.fromDbMap(Map<String, Object?> map) {
    double? asDouble(Object? v) => v == null ? null : (v as num).toDouble();
    return LocationSample(
      id: map['id'] as int?,
      tripId: map['trip_id'] as int,
      locationUuid: map['location_uuid'] as String,
      latitude: asDouble(map['latitude'])!,
      longitude: asDouble(map['longitude'])!,
      accuracy: asDouble(map['accuracy']),
      speed: asDouble(map['speed']),
      heading: asDouble(map['heading']),
      recordedAt: DateTime.parse(map['recorded_at'] as String),
    );
  }

  /// Shape sent to `POST /api/mobile/trips/{trip}/locations` as one entry
  /// of the `locations` batch array.
  Map<String, dynamic> toApiJson() => {
        'location_uuid': locationUuid,
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (speed != null && speed! >= 0) 'speed': speed,
        if (heading != null && heading! >= 0) 'heading': heading,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
      };
}
