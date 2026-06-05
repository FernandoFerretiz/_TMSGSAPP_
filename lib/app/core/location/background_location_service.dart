import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

class BackgroundLocationService {
  static const String notificationChannelId = 'trip_tracking_channel';
  static const int notificationId = 888;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Rastreo de viaje',
      description: 'Canal usado para compartir ubicación durante viajes activos.',
      importance: Importance.low,
    );

    final notifications = FlutterLocalNotificationsPlugin();

    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Rastreo activo',
        initialNotificationContent: 'Compartiendo ubicación del viaje',
        foregroundServiceNotificationId: notificationId,
        autoStartOnBoot: false,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );
  }

  static Future<void> startTracking({
    required int tripId,
    required String token,
    required String baseUrl,
  }) async {
    final service = FlutterBackgroundService();

    final isRunning = await service.isRunning();

    if (!isRunning) {
      await service.startService();
      await Future.delayed(const Duration(seconds: 1));
    }

    service.invoke('startTracking', {
      'trip_id': tripId,
      'token': token,
      'base_url': baseUrl,
    });
  }

  static Future<void> stopTracking() async {
    final service = FlutterBackgroundService();

    service.invoke('stopTracking');
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  Timer? locationTimer;
  int? activeTripId;
  String? token;
  String? baseUrl;

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();

    service.setForegroundNotificationInfo(
      title: 'Rastreo activo',
      content: 'Compartiendo ubicación del viaje',
    );
  }

  service.on('startTracking').listen((event) {
    activeTripId = event?['trip_id'] as int?;
    token = event?['token']?.toString();
    baseUrl = event?['base_url']?.toString();

    locationTimer?.cancel();

    locationTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (activeTripId == null || token == null || baseUrl == null) {
        return;
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final dio = Dio(
          BaseOptions(
            baseUrl: baseUrl!,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ),
        );

        final response = await dio.post(
          '/api/mobile/trips/$activeTripId/locations',
          data: {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'speed': position.speed,
            'heading': position.heading,
            'recorded_at': DateTime.now().toIso8601String(),
          },
        );

        final data = response.data;

        if (data is Map && data['should_stop_tracking'] == true) {
          locationTimer?.cancel();
          locationTimer = null;

          if (service is AndroidServiceInstance) {
            await service.stopSelf();
          } else {
            service.stopSelf();
          }
        }
      } catch (_) {
        // Keep service alive even if one location request fails.
      }
    });
  });

  service.on('stopTracking').listen((event) async {
    locationTimer?.cancel();
    locationTimer = null;

    if (service is AndroidServiceInstance) {
      await service.stopSelf();
    } else {
      service.stopSelf();
    }
  });
}
