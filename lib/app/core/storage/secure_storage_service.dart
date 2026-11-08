import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Wraps flutter_secure_storage for storing the auth token.
/// Only call saveToken() when the user opts in to "Remember me".
/// Never stores the password.
class SecureStorageService {
  static const _tokenKey = 'auth_token';
  static const _installIdKey = 'install_id';

  final _storage = const FlutterSecureStorage(
    // encryptedSharedPreferences requires Android API 23+.
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  /// Anonymous per-installation id (not the hardware id): lets the server
  /// rate-limit per device instead of per shared network. Changes on reinstall.
  Future<String> getInstallId() async {
    var id = await _storage.read(key: _installIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await _storage.write(key: _installIdKey, value: id);
    }
    return id;
  }
}
