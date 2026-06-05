class TripModel {
  final int id;
  final String truckboxNum;
  final String origin;
  final String destination;
  final String status;
  final String statusLabel;
  final String? assignmentDatetime;
  final String? departureDatetime;

  const TripModel({
    required this.id,
    required this.truckboxNum,
    required this.origin,
    required this.destination,
    required this.status,
    required this.statusLabel,
    this.assignmentDatetime,
    this.departureDatetime,
  });

  bool get isAssigned => status == 'assigned';
  bool get isStarted => status == 'started';
  bool get isFinished => status == 'finished';

  factory TripModel.fromJson(Map<String, dynamic> json) => TripModel(
        id: json['id'] as int,
        truckboxNum: (json['truckbox_num'] ?? '').toString(),
        origin: (json['origin'] ?? '').toString(),
        destination: (json['destination'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        statusLabel: (json['status_label'] ?? '').toString(),
        assignmentDatetime: json['assignment_datetime']?.toString(),
        departureDatetime: json['departure_datetime']?.toString(),
      );
}
