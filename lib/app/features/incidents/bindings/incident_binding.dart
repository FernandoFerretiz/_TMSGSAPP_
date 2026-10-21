import 'package:get/get.dart';
import '../../../core/network/api_client.dart';
import '../controllers/incident_controller.dart';
import '../data/incident_service.dart';

class IncidentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => IncidentService(Get.find<ApiClient>()));
    Get.lazyPut(() => IncidentController(Get.find<IncidentService>()));
  }
}
