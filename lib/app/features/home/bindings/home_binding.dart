import 'package:get/get.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../location/controllers/location_controller.dart';
import '../../location/services/location_service.dart';
import '../../trips/controllers/trip_controller.dart';
import '../../trips/data/trip_service.dart';
import '../../../core/network/api_client.dart';
import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LocationService());
    Get.lazyPut(() => LocationController(Get.find<LocationService>()));
    Get.lazyPut(() => TripService(Get.find<ApiClient>()));
    Get.lazyPut(() => TripController(Get.find<TripService>()));
    Get.lazyPut(
      () => HomeController(Get.find<AuthController>()),
    );
  }
}
