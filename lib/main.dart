import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';

import 'app/config/routes/app_pages.dart';
import 'app/config/themes/app_theme.dart';
import 'app/core/bindings/global_binding.dart';
import 'app/features/location/services/location_service.dart';

@pragma('vm:entry-point')
void locationEntry() => locationServiceCallback();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Required by flutter_foreground_task to set up communication
  // between the foreground service isolate and the main isolate.
  FlutterForegroundTask.initCommunicationPort();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'TMS GS',
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