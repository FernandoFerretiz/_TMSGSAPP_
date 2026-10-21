import 'package:flutter/material.dart';
import 'app/features/auth/screens/splash_screen.dart';

/// Preview-only entry point to iterate on SplashScreen without booting
/// the full app (GetX bindings, auth, Firebase, etc).
/// Run with: flutter run -t lib/main_splash_preview.dart
void main() {
  runApp(const MaterialApp(home: SplashScreen(), debugShowCheckedModeBanner: false));
}
