class LoginRequest {
  /// Correo o username: el backend acepta cualquiera de los dos en el mismo
  /// campo (los operadores sin correo se identifican por username).
  final String identifier;
  final String password;
  final bool rememberMe;

  const LoginRequest({
    required this.identifier,
    required this.password,
    this.rememberMe = false,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'password': password,
        'remember_me': rememberMe,
      };
}
