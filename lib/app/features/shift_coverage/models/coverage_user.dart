class CoverageUser {
  final int id;
  final String name;

  const CoverageUser({required this.id, required this.name});

  factory CoverageUser.fromJson(Map<String, dynamic> json) {
    final firstName = (json['first_name'] ?? '').toString();
    final lastName = (json['last_name'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();

    return CoverageUser(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ??
          (fullName.isNotEmpty ? fullName : (json['email']?.toString() ?? '')),
    );
  }
}
