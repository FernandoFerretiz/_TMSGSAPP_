class TripStatusRequest {
  final String status;
  final double latitude;
  final double longitude;
  final String? notes;
  // File paths from image_picker; TripService converts them to MultipartFile.
  final List<String> evidenceFilePaths;

  const TripStatusRequest({
    required this.status,
    required this.latitude,
    required this.longitude,
    this.notes,
    this.evidenceFilePaths = const [],
  });
}
