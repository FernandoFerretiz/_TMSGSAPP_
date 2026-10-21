import 'package:get/get.dart';
import '../../../core/network/api_client.dart';
import '../controllers/shift_coverage_controller.dart';
import '../data/shift_coverage_service.dart';

class ShiftCoverageBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ShiftCoverageService(Get.find<ApiClient>()));
    Get.lazyPut(() => ShiftCoverageController(Get.find<ShiftCoverageService>()));
  }
}
