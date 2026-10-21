import 'package:flutter/material.dart';

class AppConfig {
  static const String appName = 'SultanX TMS';

  // Update this URL to match your Laravel API base URL.
  // Android emulator → http://10.0.2.2:8000
 // iOS simulator    → http://localhost:8000
  // Physical device  → http://<tu-IP-local>:puerto (misma WiFi que el servidor)
  // Production       → https://your-tms-domain.com
  
  static const String baseUrl = 'https://tms.sultanx.com.mx/';
  //static const String baseUrl = 'https://staging-tms.sultanx.com.mx/'; // Staging: descomenta para generar APK contra staging
  //static const String baseUrl = 'http://10.0.2.2:82/'; // Local (emulador Android) contra gs_erp

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
}

class AppColors {
  static const Color navyBlue = Color(0xFF0A1628);
  static const Color darkNavy = Color(0xFF0D2137);
  static const Color royalBlue = Color(0xFF1565C0);
  static const Color electricBlue = Color(0xFF2979FF);
  static const Color skyBlue = Color(0xFF64B5F6);
  static const Color lightBlue = Color(0xFFBBDEFB);
  static const Color white = Colors.white;
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color textDark = Color(0xFF1A1F3A);
  static const Color textMedium = Color(0xFF5A6482);
  static const Color textLight = Color(0xFF9095A8);
  static const Color fieldFill = Color(0xFFF4F7FF);
  static const Color fieldBorder = Color(0xFFE1E8F5);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navyBlue, darkNavy, royalBlue, electricBlue],
    stops: [0.0, 0.28, 0.62, 1.0],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [royalBlue, electricBlue],
  );
}
