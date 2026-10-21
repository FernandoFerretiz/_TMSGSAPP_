import 'package:get/get.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../location/controllers/location_controller.dart';
import '../../location/data/operator_tracking_api.dart';
import '../../location/services/location_service.dart';
import '../../location/services/tracking_service.dart';
import '../../trips/controllers/trip_controller.dart';
import '../../trips/data/trip_service.dart';
import '../../chatbot/controllers/chatbot_controller.dart';
import '../../chatbot/data/chatbot_service.dart';
import '../../../core/network/api_client.dart';
import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LocationService());
    Get.lazyPut(() => TrackingService(Get.find<LocationService>()));
    Get.lazyPut(() => LocationController(
        Get.find<TrackingService>(), OperatorTrackingApi(Get.find<ApiClient>())));
    Get.lazyPut(() => TripService(Get.find<ApiClient>()));
    Get.lazyPut(
        () => TripController(Get.find<TripService>(), Get.find<TrackingService>()));
    Get.lazyPut(
      () => HomeController(Get.find<AuthController>()),
    );
    Get.lazyPut(() => ChatBotService(Get.find<ApiClient>()));
    Get.lazyPut(() => ChatBotController(Get.find<ChatBotService>()));
  }
}
