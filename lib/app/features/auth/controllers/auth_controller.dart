import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../config/routes/route_names.dart';
import '../../../core/network/token_manager.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../services/push_notification_service.dart';
import '../../location/services/tracking_service.dart';
import '../data/auth_service.dart';
import '../models/activate_account_request.dart';
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
  // true cuando no se pudo validar la sesión guardada por un error que no
  // es de credenciales (sin red, timeout, 5xx): el token se conserva.
  final authCheckFailed = false.obs;
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
    authCheckFailed.value = false;
    try {
      final savedToken = await storageService.getToken();

      if (savedToken == null || savedToken.isEmpty) {
        Get.offAllNamed(RouteNames.login);
        return;
      }

      TokenManager.setToken(savedToken);
      final response = await _meWithRetry();
      _currentUser.value = response.user;
      _roles.value = response.roles;
      _permissions.value = response.permissions;
      if (kDebugMode) debugPrint('[TRACKING] Usuario autenticado (sesión restaurada)');

      // La sesión restaurada no pasa por login()/activate(), así que el
      // token FCM nunca se (re)envía al backend en este camino. Sin esto,
      // un usuario que reabre la app con sesión guardada se queda sin
      // notificaciones push hasta que vuelva a hacer login manualmente.
      Get.find<PushNotificationService>()
          .registerTokenWithBackend()
          .ignore();

      Get.offAllNamed(RouteNames.home);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Único caso en que la sesión realmente ya no es válida.
        TokenManager.clear();
        await storageService.deleteToken();
        Get.offAllNamed(RouteNames.login);
      } else {
        // Sin red / timeout / error del servidor: no se pierde la sesión,
        // se deja reintentar desde la pantalla de inicio.
        authCheckFailed.value = true;
      }
    } catch (_) {
      authCheckFailed.value = true;
    } finally {
      isCheckingAuth.value = false;
    }
  }

  // Reintenta /me ante fallos transitorios (red, timeout, 5xx); un 401 se
  // propaga de inmediato.
  Future<AuthResponse> _meWithRetry() async {
    const maxAttempts = 3;
    for (var attempt = 1;; attempt++) {
      try {
        return await authService.me();
      } on DioException catch (e) {
        if (e.response?.statusCode == 401 || attempt >= maxAttempts) rethrow;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────

  Future<void> login({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await authService.login(
        LoginRequest(
          identifier: identifier,
          password: password,
          rememberMe: rememberMe,
        ),
      );

      _applyAuthResponse(response);
      if (kDebugMode) debugPrint('[TRACKING] Usuario autenticado');

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

  // ── Activación de cuenta invitada (operador/contacto sin correo) ───────

  Future<void> activate({
    required String identifier,
    required String pin,
    required String password,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await authService.activate(
        ActivateAccountRequest(
          identifier: identifier,
          pin: pin,
          password: password,
        ),
      );

      _applyAuthResponse(response);
      if (kDebugMode) debugPrint('[TRACKING] Cuenta activada e inicio de sesión');

      // La activación siempre deja la sesión iniciada de forma persistente,
      // igual que "recordarme" en el login normal.
      await storageService.saveToken(response.token);

      Get.find<PushNotificationService>()
          .registerTokenWithBackend()
          .ignore();

      Get.offAllNamed(RouteNames.home);
    } on DioException catch (e, st) {
      _printDioError(e, st);
      errorMessage.value = _getDioErrorMessage(e);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Unexpected activate error: $e\n$st');
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
      if (kDebugMode) debugPrint('[TRACKING] Usuario cerró sesión');
      // Stop tracking before the route change disposes TrackingService, so
      // the foreground service doesn't keep running orphaned after logout.
      if (Get.isRegistered<TrackingService>()) {
        if (kDebugMode) debugPrint('[TRACKING] Tracking detenido por logout');
        await Get.find<TrackingService>().stopTracking();
      }
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
