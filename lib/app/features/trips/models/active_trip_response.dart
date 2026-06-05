import 'trip_model.dart';

class ActiveTripResponse {
  final bool hasActiveTrip;
  final bool trackingEnabled;
  final TripModel? trip;
  final List<String> availableActions;

  const ActiveTripResponse({
    required this.hasActiveTrip,
    required this.trackingEnabled,
    this.trip,
    required this.availableActions,
  });

  factory ActiveTripResponse.fromJson(Map<String, dynamic> json) =>
      ActiveTripResponse(
        hasActiveTrip: json['has_active_trip'] == true,
        trackingEnabled: json['tracking_enabled'] == true,
        trip: json['trip'] == null
            ? null
            : TripModel.fromJson(json['trip'] as Map<String, dynamic>),
        availableActions: (json['available_actions'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  bool get canStartTrip => availableActions.contains('start_trip');
  bool get canReportIncident => availableActions.contains('report_incident');
  bool get canSendEvidence => availableActions.contains('send_evidence');
  bool get canFinishTrip => availableActions.contains('finish_trip');
}
