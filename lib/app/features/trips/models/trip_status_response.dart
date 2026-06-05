import 'trip_model.dart';

class TripStatusResponse {
  final String message;
  final bool trackingEnabled;
  final bool shouldStopTracking;
  final TripModel? trip;

  const TripStatusResponse({
    required this.message,
    required this.trackingEnabled,
    required this.shouldStopTracking,
    this.trip,
  });

  factory TripStatusResponse.fromJson(Map<String, dynamic> json) =>
      TripStatusResponse(
        message: (json['message'] ?? '').toString(),
        trackingEnabled: json['tracking_enabled'] == true,
        shouldStopTracking: json['should_stop_tracking'] == true,
        trip: json['trip'] == null
            ? null
            : TripModel.fromJson(json['trip'] as Map<String, dynamic>),
      );
}
