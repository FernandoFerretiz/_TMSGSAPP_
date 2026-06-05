import 'package:get/get.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/bindings/home_binding.dart';
import '../../features/trips/screens/start_trip_screen.dart';
// DashboardBinding is declared as `part of dashboard` inside dashboard_screen.dart
import '../../features/dashboard/views/screens/dashboard_screen.dart';
import 'route_names.dart';

part 'app_routes.dart';

class AppPages {
  static const initial = RouteNames.splash;

  static final routes = [
    GetPage(
      name: _Paths.splash,
      page: () => const SplashScreen(),
    ),
    GetPage(
      name: _Paths.login,
      page: () => const LoginScreen(),
    ),
    GetPage(
      name: _Paths.home,
      page: () => const HomeScreen(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.startTrip,
      page: () => const StartTripScreen(),
    ),
    GetPage(
      name: _Paths.changeStatus,
      page: () => const ChangeStatusScreen(),
    ),
    GetPage(
      name: _Paths.dashboard,
      page: () => const DashboardScreen(),
      binding: DashboardBinding(),
    ),
  ];
}
