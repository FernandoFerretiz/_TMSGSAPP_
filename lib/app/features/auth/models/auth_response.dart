import 'operator_model.dart';
import 'user_model.dart';

class AuthResponse {
  final String token;
  final String tokenType;
  final String expiresAt;
  final String userType;
  final UserModel user;
  final OperatorModel? operator;
  final List<String> roles;
  final List<String> permissions;

  const AuthResponse({
    required this.token,
    required this.tokenType,
    required this.expiresAt,
    required this.userType,
    required this.user,
    required this.operator,
    required this.roles,
    required this.permissions,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'Bearer',
      expiresAt: json['expires_at']?.toString() ?? '',
      userType: json['user_type']?.toString() ?? 'user',
      user: UserModel.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
      ),
      operator: json['operator'] == null
          ? null
          : OperatorModel.fromJson(
              Map<String, dynamic>.from(json['operator'] as Map),
            ),
      roles: _toStringList(json['roles']),
      permissions: _toStringList(json['permissions']),
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'token_type': tokenType,
        'expires_at': expiresAt,
        'user_type': userType,
        'user': user.toJson(),
        'operator': operator?.toJson(),
        'roles': roles,
        'permissions': permissions,
      };

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }

    return [];
  }
}