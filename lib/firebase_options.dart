// ⚠️  ESTE ARCHIVO ES UN PLACEHOLDER.
//
// Debes reemplazarlo ejecutando:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// El comando generará este archivo con los valores reales de tu proyecto
// Firebase y también colocará:
//   • android/app/google-services.json
//   • ios/Runner/GoogleService-Info.plist
//
// Una vez generado, borra este placeholder — el real lo sobreescribirá.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web no está configurado. Ejecuta flutterfire configure.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _android;
      case TargetPlatform.iOS:
        return _ios;
      default:
        throw UnsupportedError(
          'Plataforma no soportada. Ejecuta flutterfire configure.',
        );
    }
  }

  // ── Reemplaza estos valores con los de tu proyecto Firebase ──────────────
  // Los obtienes ejecutando: flutterfire configure

  static const FirebaseOptions _android = FirebaseOptions(
    apiKey: 'REEMPLAZA_CON_TU_API_KEY',
    appId: 'REEMPLAZA_CON_TU_APP_ID',
    messagingSenderId: 'REEMPLAZA_CON_TU_SENDER_ID',
    projectId: 'REEMPLAZA_CON_TU_PROJECT_ID',
    storageBucket: 'REEMPLAZA_CON_TU_STORAGE_BUCKET',
  );

  static const FirebaseOptions _ios = FirebaseOptions(
    apiKey: 'REEMPLAZA_CON_TU_API_KEY_IOS',
    appId: 'REEMPLAZA_CON_TU_APP_ID_IOS',
    messagingSenderId: 'REEMPLAZA_CON_TU_SENDER_ID',
    projectId: 'REEMPLAZA_CON_TU_PROJECT_ID',
    storageBucket: 'REEMPLAZA_CON_TU_STORAGE_BUCKET',
    iosBundleId: 'REEMPLAZA_CON_TU_BUNDLE_ID',
  );
}
