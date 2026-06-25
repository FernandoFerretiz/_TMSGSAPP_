import 'package:get/get.dart';
import '../network/api_client.dart';
import '../storage/secure_storage_service.dart';
import '../../features/auth/data/auth_service.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../services/push_notification_service.dart';

/// Registers all app-wide singletons before the first route is shown.
class GlobalBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(SecureStorageService(), permanent: true);
    Get.put(ApiClient(), permanent: true);
    Get.put(AuthService(Get.find<ApiClient>()), permanent: true);
    Get.put(
      AuthController(
        authService: Get.find<AuthService>(),
        storageService: Get.find<SecureStorageService>(),
      ),
      permanent: true,
    );
    Get.putAsync<PushNotificationService>(
      () => PushNotificationService(Get.find<ApiClient>()).init(),
      permanent: true,
    );
  }
}
