import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationPermissionService {
  /// Check-only, no side effects (no system dialogs, no Settings screens) —
  /// safe to call from a widget's build/init to decide whether to show the
  /// "debes activar la ubicación" gate before letting the operator start a
  /// trip. Mirrors the core requirement of [ensureTrackingPermission]
  /// (service on + "always" location) without the notification/battery
  /// extras, which aren't blocking for that screen.
  static Future<bool> hasTrackingPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    final backgroundStatus = await Permission.locationAlways.status;
    return backgroundStatus.isGranted;
  }

  static Future<bool> ensureTrackingPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    final notificationStatus = await Permission.notification.request();

    if (notificationStatus.isDenied || notificationStatus.isPermanentlyDenied) {
      return false;
    }

    final backgroundStatus = await Permission.locationAlways.request();

    if (!backgroundStatus.isGranted) {
      await openAppSettings();
      return false;
    }

    // Best-effort: some OEMs (Xiaomi, Huawei, Samsung, etc.) throttle or kill
    // the foreground service under aggressive battery-saving policies even
    // though it's a proper foreground service. Exemption isn't required for
    // tracking to work, so a denial here doesn't block the permission chain.
    await Permission.ignoreBatteryOptimizations.request();

    return true;
  }
}