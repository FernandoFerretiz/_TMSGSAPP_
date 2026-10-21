import 'package:get/get.dart';
import '../../../core/network/api_client.dart';
import '../controllers/circuit_trip_form_controller.dart';
import '../data/circuit_trip_service.dart';

class CircuitTripBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CircuitTripService(Get.find<ApiClient>()));
    Get.lazyPut(() => CircuitTripFormController(Get.find<CircuitTripService>()));
  }
}
