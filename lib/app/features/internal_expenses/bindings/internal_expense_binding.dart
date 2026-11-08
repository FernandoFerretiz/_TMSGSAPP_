import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../controllers/internal_expense_controller.dart';
import '../data/internal_expense_service.dart';

class InternalExpenseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => InternalExpenseService(Get.find<ApiClient>()));
    Get.lazyPut(() => InternalExpenseController(Get.find<InternalExpenseService>()));
  }
}
