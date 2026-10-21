import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../config/routes/route_names.dart';
import '../core/network/api_client.dart';
import '../core/network/token_manager.dart';
import '../features/trips/controllers/trip_controller.dart';

// ─── Android notification channel ────────────────────────────────────────────

// Bumped to _v3 to drop the custom sound and fall back to the system
// default — channels are immutable once created on a device, so a new id
// is required for the change to take effect on existing installs.
const _kChannelId = 'trip_notifications_v3';
const _kChannelName = 'Viajes';
const _kChannelDescription = 'Notificaciones de asignación de viajes';

final _localNotifications = FlutterLocalNotificationsPlugin();

// ─── Background handler (must be top-level) ──────────────────────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by the time this runs (firebase_messaging
  // does it automatically), but we guard with a try/catch just in case.
  try {
    debugPrint('[FCM-BG] message received: ${message.messageId}');
  } catch (e) {
    debugPrint('[FCM-BG] error: $e');
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

class PushNotificationService extends GetxService {
  final ApiClient _apiClient;
  PushNotificationService(this._apiClient);

  // ── Lifecycle ────────────────────────────────────────────────────────────

  Future<PushNotificationService> init() async {
    await _initLocalNotifications();
    await requestPermission();
    _listenTokenRefresh();
    _setupForegroundListener();
    _setupNotificationTapHandlers();
    return this;
  }

  // ── Permissions ──────────────────────────────────────────────────────────

  Future<void> requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      debugPrint('[FCM] permission: ${settings.authorizationStatus.name}');
    } catch (e) {
      debugPrint('[FCM] requestPermission error: $e');
    }
  }

  // ── Token ────────────────────────────────────────────────────────────────

  Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  Future<void> registerTokenWithBackend() async {
    try {
      final token = await getToken();
      if (token == null) {
        debugPrint('[FCM] no token available — skipping registration');
        return;
      }

      final bearerToken = TokenManager.token;
      if (bearerToken == null || bearerToken.isEmpty) {
        debugPrint('[FCM] no bearer token — skipping registration');
        return;
      }

      final deviceName = await _getDeviceName();
      final platform = Platform.isIOS ? 'ios' : 'android';

      await _apiClient.dio.post(
        '/api/mobile/device-token',
        data: {
          'fcm_token': token,
          'platform': platform,
          'device_name': deviceName,
        },
      );
      debugPrint('[FCM] token registered: $token');
    } catch (e) {
      debugPrint('[FCM] registerTokenWithBackend error: $e');
    }
  }

  Future<void> unregisterTokenFromBackend() async {
    try {
      final token = await getToken();
      if (token == null) return;

      final bearerToken = TokenManager.token;
      if (bearerToken == null || bearerToken.isEmpty) return;

      await _apiClient.dio.delete(
        '/api/mobile/device-token',
        data: {'fcm_token': token},
      );
      debugPrint('[FCM] token unregistered');
    } catch (e) {
      // Never block logout
      debugPrint('[FCM] unregisterTokenFromBackend error: $e');
    }
  }

  // ── Token refresh listener ────────────────────────────────────────────────

  void _listenTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] token refreshed');
      await registerTokenWithBackend();
    });
  }

  // ── Foreground notifications ──────────────────────────────────────────────

  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] foreground message: ${message.messageId}');
      _showLocalNotification(message);
      _refreshActiveTripIfNeeded(message.data);
    });
  }

  // A new assignment or a status change (e.g. the ERP moves the trip to "en
  // tránsito" directly, without the operator touching the app) are the only
  // pushes that should refresh the active-trip screen without the user
  // tapping it — TripController.loadActiveTrip() is what decides whether to
  // start/stop GPS tracking (server-driven via tracking_enabled), so this is
  // what closes the gap otherwise left until the next manual pull-to-refresh
  // or app relaunch.
  static const _kRefreshOnTypes = {'trip_assigned', 'trip_status_changed'};

  void _refreshActiveTripIfNeeded(Map<String, dynamic> data) {
    if (!_kRefreshOnTypes.contains(data['type']?.toString())) return;
    if (!Get.isRegistered<TripController>()) return;
    Get.find<TripController>().loadActiveTrip();
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final title = message.notification?.title ?? 'Nuevo viaje asignado';
      final body =
          message.notification?.body ?? 'Se te asignó un nuevo viaje.';

      const androidDetails = AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: _kChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
        payload: _buildPayload(message.data),
      );
    } catch (e) {
      debugPrint('[FCM] showLocalNotification error: $e');
    }
  }

  // ── Tap handlers ─────────────────────────────────────────────────────────

  void _setupNotificationTapHandlers() {
    // App was in background and user tapped the system notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] onMessageOpenedApp: ${message.messageId}');
      _handleMessage(message.data);
    });

    // App was terminated and user tapped the notification that launched it
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('[FCM] getInitialMessage: ${message.messageId}');
        // Slight delay so the first route is built before we push on top
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleMessage(message.data);
        });
      }
    });
  }

  // ── Local notification tap ────────────────────────────────────────────────

  Future<void> _onLocalNotificationTap(
      NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final data = _parsePayload(payload);
    _handleMessage(data);
  }

  // ── Message routing ───────────────────────────────────────────────────────

  void _handleMessage(Map<String, dynamic> data) {
    try {
      final type = data['type']?.toString();
      final tripId = data['trip_id']?.toString();

      if (type == 'trip_assigned' && tripId != null && tripId.isNotEmpty) {
        Get.toNamed(RouteNames.tripDetail, arguments: tripId);
      } else if (type == 'trip_stopped' || type == 'trip_resumed') {
        Get.toNamed(RouteNames.lastEvents);
      } else if (type == 'trip_status_changed') {
        // Sin pantalla propia: solo refresca el viaje activo (y por lo
        // tanto el estado del tracking GPS) al abrir la app desde este push.
        _refreshActiveTripIfNeeded(data);
      }
    } catch (e) {
      debugPrint('[FCM] handleMessage error: $e');
    }
  }

  // ── Local notifications init ──────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create Android channel
    const channel = AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: _kChannelDescription,
      importance: Importance.high,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String> _getDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return '${android.manufacturer} ${android.model}';
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return ios.name;
      }
    } catch (_) {}
    return 'Unknown device';
  }

  /// Serialises data map to a simple key=value;... string for local notification payload.
  String _buildPayload(Map<String, dynamic> data) =>
      data.entries.map((e) => '${e.key}=${e.value}').join(';');

  Map<String, dynamic> _parsePayload(String payload) {
    final result = <String, dynamic>{};
    for (final part in payload.split(';')) {
      final idx = part.indexOf('=');
      if (idx > 0) {
        result[part.substring(0, idx)] = part.substring(idx + 1);
      }
    }
    return result;
  }
}
