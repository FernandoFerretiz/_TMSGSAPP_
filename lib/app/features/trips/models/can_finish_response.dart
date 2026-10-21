class CanFinishResponse {
  final bool canFinish;
  final String? reason;
  final String status;
  final String statusLabel;

  const CanFinishResponse({
    required this.canFinish,
    this.reason,
    required this.status,
    required this.statusLabel,
  });

  factory CanFinishResponse.fromJson(Map<String, dynamic> json) =>
      CanFinishResponse(
        canFinish: json['can_finish'] == true,
        reason: json['reason'] as String?,
        status: json['status']?.toString() ?? '',
        statusLabel: json['status_label']?.toString() ?? '',
      );
}
