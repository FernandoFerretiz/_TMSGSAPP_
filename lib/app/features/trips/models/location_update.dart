class LocationUpdate {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final String recordedAt;

  const LocationUpdate({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (speed != null && speed! >= 0) 'speed': speed,
        if (heading != null && heading! >= 0) 'heading': heading,
        'recorded_at': recordedAt,
      };
}
