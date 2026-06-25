import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../config/routes/route_names.dart';
import '../../../core/network/token_manager.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../services/push_notification_service.dart';
import '../data/auth_service.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../models/user_model.dart';

class AuthController extends GetxController {
  final AuthService authService;
  final SecureStorageService storageService;

  AuthController({
    required this.authService,
    required this.storageService,
  });

  final isLoading = false.obs;
  final isCheckingAuth = true.obs;
  final errorMessage = ''.obs;

  final _currentUser = Rxn<UserModel>();
  final _roles = <String>[].obs;
  final _permissions = <String>[].obs;

  UserModel? get currentUser => _currentUser.value;
  List<String> get roles => List.unmodifiable(_roles);

  /// Returns the display label for the user's primary role.
  String get primaryRoleLabel {
    if (hasRole('admin')) return 'Administrador';
    if (hasRole('monitorista')) return 'Monitorista';
    if (hasRole('operador')) return 'Operador';
    return _roles.isNotEmpty ? _roles.first : 'Usuario';
  }

  // ── Role & permission helpers ──────────────────────────────────────────

  bool hasRole(String role) => _roles.contains(role);

  bool hasAnyRole(List<String> roleList) =>
      roleList.any((r) => _roles.contains(r));

  // if (authController.hasPermission('trip.index')) { ... }
  bool hasPermission(String permission) => _permissions.contains(permission);

  // if (authController.hasPermission('trip.update')) { ... }
  // if (authController.hasPermission('trip.create')) { ... }

  // ── Auth check (Splash / AuthGate) ────────────────────────────────────

  Future<void> checkAuthStatus() async {
    isCheckingAuth.value = true;
    try {
      final savedToken = await storageService.getToken();

      if (savedToken == null || savedToken.isEmpty) {
        Get.offAllNamed(RouteNames.login);
        return;
      }

      TokenManager.setToken(savedToken);
      final user = await authService.me();
      _currentUser.value = user;
      // Roles are not returned by /me — they were set at login.
      // If roles are empty here (cold-start after token restore), we rely
      // on a future /me that returns roles, or redirect to login to re-auth.
      Get.offAllNamed(RouteNames.home);
    } on DioException {
      TokenManager.clear();
      await storageService.deleteToken();
      Get.offAllNamed(RouteNames.login);
    } catch (_) {
      TokenManager.clear();
      Get.offAllNamed(RouteNames.login);
    } finally {
      isCheckingAuth.value = false;
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────

  Future<void> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await authService.login(
        LoginRequest(email: email, password: password, rememberMe: rememberMe),
      );

      _applyAuthResponse(response);

      if (rememberMe) {
        await storageService.saveToken(response.token);
      } else {
        await storageService.deleteToken();
      }

      // Register FCM token now that we have a valid Bearer token.
      // Runs in the background — never blocks the login flow.
      Get.find<PushNotificationService>()
          .registerTokenWithBackend()
          .ignore();

      Get.offAllNamed(RouteNames.home);
    } on DioException catch (e, st) {
      _printDioError(e, st);
      errorMessage.value = _getDioErrorMessage(e);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Unexpected login error: $e\n$st');
      }
      errorMessage.value = 'Error inesperado. Inténtalo de nuevo.';
    } finally {
      isLoading.value = false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────

  Future<void> logout() async {
    isLoading.value = true;
    try {
      // Unregister FCM token before clearing the Bearer token.
      await Get.find<PushNotificationService>().unregisterTokenFromBackend();
      await authService.logout();
    } catch (_) {
      // Proceed with local cleanup even if server calls fail.
    } finally {
      _clearSession();
      isLoading.value = false;
      Get.offAllNamed(RouteNames.login);
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────

  void _applyAuthResponse(AuthResponse response) {
    TokenManager.setToken(response.token);
    _currentUser.value = response.user;
    _roles.value = response.roles;
    _permissions.value = response.permissions;
  }

  void _clearSession() {
    TokenManager.clear();
    storageService.deleteToken();
    _currentUser.value = null;
    _roles.clear();
    _permissions.clear();
  }

  String _getDioErrorMessage(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    if (data is Map<String, dynamic>) {
      if (data['errors'] is Map<String, dynamic>) {
        final errors = data['errors'] as Map<String, dynamic>;
        if (errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
          return first.toString();
        }
      }
      final msg = data['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }

    switch (statusCode) {
      case 401:
        return 'No autorizado. Verifica tus credenciales.';
      case 403:
        return 'No tienes permiso para acceder a la app.';
      case 422:
        return 'Los datos enviados no son válidos.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Error interno del servidor.';
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Tiempo de conexión agotado. Verifica tu internet.';
      case DioExceptionType.connectionError:
        return 'No se pudo conectar al servidor.';
      case DioExceptionType.badCertificate:
        return 'Certificado SSL del servidor no válido.';
      default:
        return 'Error al iniciar sesión (${statusCode ?? e.type.name}).';
    }
  }

  void _printDioError(DioException e, StackTrace st) {
    if (!kDebugMode) return;
    debugPrint('── DIO ERROR ──────────────────────────────────');
    debugPrint('Type: ${e.type}  Status: ${e.response?.statusCode}');
    debugPrint('URL: ${e.requestOptions.method} ${e.requestOptions.uri}');
    debugPrint('Response: ${e.response?.data}');
    debugPrint('$st');
    debugPrint('───────────────────────────────────────────────');
  }
}
