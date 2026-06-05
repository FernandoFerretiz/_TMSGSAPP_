import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationPermissionService {
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

    return true;
  }
}