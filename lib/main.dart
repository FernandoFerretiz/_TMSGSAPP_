import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/config/app_flavor.dart';
import 'app/config/routes/app_pages.dart';
import 'app/config/themes/app_theme.dart';
import 'app/core/bindings/global_binding.dart';
import 'app/features/location/services/location_service.dart';
import 'app/services/push_notification_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
void locationEntry() => locationServiceCallback();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Required by flutter_foreground_task to set up communication
  // between the foreground service isolate and the main isolate.
  FlutterForegroundTask.initCommunicationPort();

  await initializeDateFormatting('es_ES');
  Intl.defaultLocale = 'es_ES';

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Must be registered before runApp so it is available when the OS wakes
  // the app in background to deliver a message.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppFlavor.current.title,
      theme: AppTheme.basic,
      initialBinding: GlobalBinding(),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      scrollBehavior: _CustomScrollBehaviour(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _CustomScrollBehaviour extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}