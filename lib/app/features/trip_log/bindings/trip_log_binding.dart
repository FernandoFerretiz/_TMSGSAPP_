import 'package:get/get.dart';
import '../../../core/network/api_client.dart';
import '../controllers/trip_log_controller.dart';
import '../data/trip_log_service.dart';

class TripLogBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => TripLogService(Get.find<ApiClient>()));
    Get.lazyPut(() => TripLogController(Get.find<TripLogService>()));
  }
}
