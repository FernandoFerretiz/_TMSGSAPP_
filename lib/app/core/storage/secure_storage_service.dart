import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps flutter_secure_storage for storing the auth token.
/// Only call saveToken() when the user opts in to "Remember me".
/// Never stores the password.
class SecureStorageService {
  static const _tokenKey = 'auth_token';

  final _storage = const FlutterSecureStorage(
    // encryptedSharedPreferences requires Android API 23+.
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);
}
