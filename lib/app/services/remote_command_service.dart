import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_flavor.dart';
import '../core/config/app_config.dart';
import '../core/network/token_manager.dart';
import '../core/storage/secure_storage_service.dart';
import '../features/location/controllers/location_controller.dart';
import '../features/trips/controllers/trip_controller.dart';

/// Órdenes remotas que el TMS manda al teléfono del operador con un push
/// silencioso (solo datos, sin notificación visible):
///
/// - `diagnostic_ping`: la app reúne el estado del teléfono (permisos, GPS,
///   batería, red, servicio de rastreo), intenta obtener una posición nueva y
///   se lo reporta al servidor.
/// - `refresh_home`: recarga la pantalla principal del operador.
///
/// Todo es "mejor esfuerzo": si el servidor aún no tiene el endpoint del
/// reporte (o no hay red) la app no falla ni muestra nada.
class RemoteCommandService {
  RemoteCommandService._();

  static const typeDiagnostic = 'diagnostic_ping';
  static const typeRefreshHome = 'refresh_home';

  static bool handles(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    return type == typeDiagnostic || type == typeRefreshHome;
  }

  static const _pendingRefreshKey = 'pending_home_refresh';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// [inBackground] es true cuando lo despierta el handler de FCM (isolate
  /// aparte, sin GetX ni sesión en memoria).
  static Future<void> handle(
    Map<String, dynamic> data, {
    required bool inBackground,
  }) async {
    try {
      switch (data['type']?.toString()) {
        case typeDiagnostic:
          await _runDiagnostic(
            data['request_id']?.toString(),
            inBackground: inBackground,
          );
        case typeRefreshHome:
          await _refreshHome(inBackground: inBackground);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[REMOTE-CMD] error: $e');
    }
  }

  // ── refresh_home ─────────────────────────────────────────────────────────

  static Future<void> _refreshHome({required bool inBackground}) async {
    if (!inBackground && Get.isRegistered<TripController>()) {
      await Get.find<TripController>().loadActiveTrip();
      return;
    }
    // Sin UI viva que recargar: queda marcado y se refresca al volver a la app.
    await _storage.write(key: _pendingRefreshKey, value: '1');
  }

  /// Si llegó un `refresh_home` mientras la app estaba en segundo plano,
  /// recarga ahora. Lo invoca el observador de ciclo de vida al reanudar.
  static Future<void> applyPendingRefresh() async {
    try {
      if (await _storage.read(key: _pendingRefreshKey) != '1') return;
      await _storage.delete(key: _pendingRefreshKey);
      if (Get.isRegistered<TripController>()) {
        await Get.find<TripController>().loadActiveTrip();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[REMOTE-CMD] pending refresh error: $e');
    }
  }

  // ── diagnostic_ping ──────────────────────────────────────────────────────

  static Future<void> _runDiagnostic(
    String? requestId, {
    required bool inBackground,
  }) async {
    final errors = <String>[];

    // En primer plano, además, se reintenta reanudar el rastreo si el
    // servidor lo tiene activo pero el teléfono dejó de reportar.
    if (!inBackground && Get.isRegistered<LocationController>()) {
      await _guard(errors, 'resume_tracking',
          () => Get.find<LocationController>().syncWithServer());
    }

    final token = await _authToken();
    final trackingRunning = await _guard(
          errors,
          'tracking_service',
          () => FlutterForegroundTask.isRunningService,
        ) ??
        false;

    final position = await _fixPosition(errors);

    // Si el rastreo debía estar encendido, la posición nueva también va como
    // latido normal: así el operador reaparece en el mapa aunque el servidor
    // todavía no entienda el reporte de diagnóstico.
    final battery = await _battery(errors);
    if (position != null && trackingRunning && token != null) {
      await _guard(errors, 'ping', () => _dio(token).post(
            '/api/mobile/tracking/ping',
            data: {
              'latitude': position['latitude'],
              'longitude': position['longitude'],
              if (battery.level != null)
                'battery': {
                  'level': battery.level,
                  'charging': battery.charging,
                },
            },
          ));
    }

    if (requestId == null || requestId.isEmpty || token == null) return;

    final report = {
      'handled_in': inBackground ? 'background' : 'foreground',
      'app': await _appInfo(errors),
      'device': await _deviceInfo(errors),
      'permissions': await _permissions(errors),
      'battery': {
        'level': battery.level,
        'charging': battery.charging,
        'saver_mode': battery.saver,
      },
      'network': {'internet': await _hasInternet()},
      'tracking': {'service_running': trackingRunning},
      'position': position,
      'errors': errors,
    };

    await _guard(errors, 'report', () => _dio(token).post(
          '/api/mobile/diagnostics',
          data: {'request_id': requestId, 'report': report},
        ));
  }

  /// Corre [action] sin dejar que su error escape; lo anota en [errors].
  static Future<T?> _guard<T>(
    List<String> errors,
    String step,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } catch (e) {
      errors.add('$step: ${_short(e)}');
      return null;
    }
  }

  static String _short(Object e) {
    if (e is DioException) {
      return 'http ${e.response?.statusCode ?? e.type.name}';
    }
    final text = e.toString();
    return text.length > 120 ? text.substring(0, 120) : text;
  }

  /// Token en memoria (app abierta), el guardado con "Recordarme" o el que
  /// usa el servicio de rastreo — este último permite reportar aunque la app
  /// esté en segundo plano y sin sesión recordada.
  static Future<String?> _authToken() async {
    final memory = TokenManager.token;
    if (memory != null && memory.isNotEmpty) return memory;
    try {
      final saved = await SecureStorageService().getToken();
      if (saved != null && saved.isNotEmpty) return saved;
    } catch (_) {}
    try {
      final tracked = await FlutterForegroundTask.getData<String>(key: 'token');
      if (tracked != null && tracked.isNotEmpty) return tracked;
    } catch (_) {}
    return null;
  }

  static Dio _dio(String token) => Dio(
        BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

  static Future<Map<String, dynamic>?> _fixPosition(List<String> errors) async {
    final fresh = await _guard(
      errors,
      'gps_fix',
      () => Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      ),
    );
    if (fresh != null) return _positionJson(fresh, 'fresh');

    final last = await _guard(
        errors, 'gps_last_known', () => Geolocator.getLastKnownPosition());
    return last == null ? null : _positionJson(last, 'last_known');
  }

  static Map<String, dynamic> _positionJson(Position p, String source) => {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'accuracy': p.accuracy,
        'age_seconds': DateTime.now().difference(p.timestamp).inSeconds,
        'source': source,
      };

  static Future<({int? level, bool? charging, bool? saver})> _battery(
      List<String> errors) async {
    final battery = Battery();
    final level = await _guard(errors, 'battery_level', () => battery.batteryLevel);
    final state = await _guard(errors, 'battery_state', () => battery.batteryState);
    final saver =
        await _guard(errors, 'battery_saver', () => battery.isInBatterySaveMode);
    return (
      level: level,
      charging: state == null
          ? null
          : state == BatteryState.charging || state == BatteryState.full,
      saver: saver,
    );
  }

  static Future<Map<String, dynamic>> _permissions(List<String> errors) async {
    final serviceEnabled = await _guard(
        errors, 'gps_enabled', () => Geolocator.isLocationServiceEnabled());
    final permission = await _guard(
        errors, 'location_permission', () => Geolocator.checkPermission());
    final ignoringBatteryOptimizations = Platform.isAndroid
        ? await _guard(errors, 'battery_optimization',
            () => Permission.ignoreBatteryOptimizations.isGranted)
        : null;
    return {
      'location_service_enabled': serviceEnabled,
      // always | whileInUse | denied | deniedForever | unableToDetermine
      'location_permission': permission?.name,
      'ignoring_battery_optimizations': ignoringBatteryOptimizations,
    };
  }

  static Future<Map<String, dynamic>> _appInfo(List<String> errors) async {
    final info = await _guard(errors, 'package_info', PackageInfo.fromPlatform);
    return {
      'version': info?.version,
      'build': info?.buildNumber,
      'flavor': AppFlavor.current.name,
    };
  }

  static Future<Map<String, dynamic>> _deviceInfo(List<String> errors) async {
    if (Platform.isAndroid) {
      final info = await _guard(
          errors, 'device_info', () => DeviceInfoPlugin().androidInfo);
      return {
        'platform': 'android',
        'model': info == null ? null : '${info.manufacturer} ${info.model}',
        'os_version': info?.version.release,
        'sdk': info?.version.sdkInt,
      };
    }
    return {'platform': Platform.operatingSystem};
  }

  static Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

/// Al volver la app a primer plano aplica el `refresh_home` que llegó mientras
/// estaba en segundo plano.
class RemoteCommandLifecycleObserver with WidgetsBindingObserver {
  void attach() => WidgetsBinding.instance.addObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      RemoteCommandService.applyPendingRefresh();
    }
  }
}
