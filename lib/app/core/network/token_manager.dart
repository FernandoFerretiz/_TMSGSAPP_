/// Holds the active bearer token in memory.
/// AuthController sets/clears this; AuthInterceptor reads it.
class TokenManager {
  static String? _token;

  static String? get token => _token;

  static void setToken(String token) => _token = token;

  static void clear() => _token = null;
}
