import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../models/user_model.dart';

/// Handles all HTTP calls related to authentication.
class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _apiClient.dio.post(
      '/api/mobile/login',
      data: request.toJson(),
    );

    try {
      final data = Map<String, dynamic>.from(response.data as Map);

      if (kDebugMode) {
        debugPrint('Login response data: $data');
      }

      return AuthResponse.fromJson(data);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('---------------- AUTH RESPONSE PARSE ERROR ----------------');
        debugPrint('Error: $e');
        debugPrint('Response data: ${response.data}');
        debugPrint('StackTrace: $stackTrace');
        debugPrint('-----------------------------------------------------------');
      }

      rethrow;
    }
  }

  /// Validates the stored token and returns the authenticated user.
  Future<UserModel> me() async {
    final response = await _apiClient.dio.get('/api/mobile/me');

    try {
      final data = Map<String, dynamic>.from(response.data as Map);

      if (kDebugMode) {
        debugPrint('Me response data: $data');
      }

      final userJson = data['user'] == null
          ? data
          : Map<String, dynamic>.from(data['user'] as Map);

      return UserModel.fromJson(userJson);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('---------------- USER PARSE ERROR ----------------');
        debugPrint('Error: $e');
        debugPrint('Response data: ${response.data}');
        debugPrint('StackTrace: $stackTrace');
        debugPrint('--------------------------------------------------');
      }

      rethrow;
    }
  }

  Future<void> logout() async {
    await _apiClient.dio.post('/api/mobile/logout');
  }
}