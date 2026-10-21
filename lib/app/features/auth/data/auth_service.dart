import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/activate_account_request.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';

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

  /// Activa una cuenta invitada (access_invites) usando el username/correo
  /// y el PIN que el admin le dio en persona al operador — pantalla exclusiva
  /// de la app, no existe equivalente web para este caso (ver
  /// AuthController::activate en el backend, Api/Mobile).
  Future<AuthResponse> activate(ActivateAccountRequest request) async {
    final response = await _apiClient.dio.post(
      '/api/mobile/access/activate',
      data: request.toJson(),
    );

    try {
      final data = Map<String, dynamic>.from(response.data as Map);

      if (kDebugMode) {
        debugPrint('Activate response data: $data');
      }

      return AuthResponse.fromJson(data);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('---------------- ACTIVATE RESPONSE PARSE ERROR ----------------');
        debugPrint('Error: $e');
        debugPrint('Response data: ${response.data}');
        debugPrint('StackTrace: $stackTrace');
        debugPrint('----------------------------------------------------------------');
      }

      rethrow;
    }
  }

  /// Validates the stored token and returns the authenticated user along
  /// with their roles/permissions (needed to restore role-based routing
  /// after a cold start, since roles aren't persisted locally).
  Future<AuthResponse> me() async {
    final response = await _apiClient.dio.get('/api/mobile/me');

    try {
      final data = Map<String, dynamic>.from(response.data as Map);

      if (kDebugMode) {
        debugPrint('Me response data: $data');
      }

      return AuthResponse.fromJson(data);
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