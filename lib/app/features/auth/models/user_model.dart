class UserModel {
  final int id;
  final String name;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String phone;
  final int status;
  final String avatarUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.phone,
    required this.status,
    required this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final fullName = _toString(json['full_name']);
    final firstName = _toString(json['first_name']);
    final lastName = _toString(json['last_name']);
    final email = _toString(json['email']);

    return UserModel(
      id: _toInt(json['id']),
      name: fullName.isNotEmpty
          ? fullName
          : '${firstName} $lastName'.trim().isNotEmpty
              ? '${firstName} $lastName'.trim()
              : email,
      email: email,
      firstName: firstName,
      lastName: lastName,
      fullName: fullName,
      phone: _toString(json['phone']),
      status: _toInt(json['status']),
      avatarUrl: _toString(json['avatar_url']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'full_name': fullName,
        'phone': phone,
        'status': status,
        'avatar_url': avatarUrl,
      };

  static String _toString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString()) ?? 0;
  }
}