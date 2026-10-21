import 'package:get/get.dart';
import '../../../core/network/api_client.dart';
import '../controllers/chatbot_controller.dart';
import '../data/chatbot_service.dart';

class ChatBotBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChatBotService(Get.find<ApiClient>()));
    Get.lazyPut(() => ChatBotController(Get.find<ChatBotService>()));
  }
}
