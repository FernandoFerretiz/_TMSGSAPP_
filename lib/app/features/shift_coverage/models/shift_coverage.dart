import 'coverage_user.dart';

class ShiftCoverage {
  final int id;
  final CoverageUser user;
  final CoverageUser? coversUser;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? reason;
  final bool isActive;

  const ShiftCoverage({
    required this.id,
    required this.user,
    this.coversUser,
    this.startsAt,
    this.endsAt,
    this.reason,
    required this.isActive,
  });

  factory ShiftCoverage.fromJson(Map<String, dynamic> json) {
    return ShiftCoverage(
      id: int.tryParse(json['id'].toString()) ?? 0,
      user: CoverageUser.fromJson(json['user'] as Map<String, dynamic>),
      coversUser: json['covers_user'] != null
          ? CoverageUser.fromJson(json['covers_user'] as Map<String, dynamic>)
          : null,
      startsAt: json['starts_at'] != null
          ? DateTime.tryParse(json['starts_at'].toString())
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(json['ends_at'].toString())
          : null,
      reason: json['reason']?.toString(),
      isActive: json['is_active'] == true,
    );
  }
}
