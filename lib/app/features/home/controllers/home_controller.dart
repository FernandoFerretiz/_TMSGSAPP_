import 'package:get/get.dart';
import '../../auth/controllers/auth_controller.dart';

/// Controls sidebar open/close state and exposes convenience helpers
/// for the home shell. Heavy logic lives in TripController.
class HomeController extends GetxController {
  final AuthController _auth;

  HomeController(this._auth);

  final isSidebarOpen = false.obs;

  bool get isAdmin => _auth.hasRole('admin');
  bool get isMonitorista => _auth.hasRole('monitorista');
  bool get isOperador => _auth.hasRole('operador');

  String get welcomeName => _auth.currentUser?.name ?? 'Operador';
  String get roleLabel => _auth.primaryRoleLabel;
}
