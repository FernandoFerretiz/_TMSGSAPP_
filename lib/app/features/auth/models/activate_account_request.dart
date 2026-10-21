class ActivateAccountRequest {
  final String identifier;
  final String pin;
  final String password;

  const ActivateAccountRequest({
    required this.identifier,
    required this.pin,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'pin': pin,
        'password': password,
        'password_confirmation': password,
      };
}
