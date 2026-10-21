import 'package:get/get.dart';
import '../../../core/network/api_client.dart';
import '../controllers/trip_history_controller.dart';
import '../data/trip_history_service.dart';

class TripHistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => TripHistoryService(Get.find<ApiClient>()));
    Get.lazyPut(() => TripHistoryController(Get.find<TripHistoryService>()));
  }
}
