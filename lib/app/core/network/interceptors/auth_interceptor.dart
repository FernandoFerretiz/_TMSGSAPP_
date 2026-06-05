import 'package:dio/dio.dart';
import '../token_manager.dart';

/// Injects `Authorization: Bearer <token>` on every outgoing request
/// when a token is present in memory.
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = TokenManager.token;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }
}
