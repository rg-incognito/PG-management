// GENERATED PLACEHOLDER — replace this file by running `flutterfire configure`
// from the `tenant_app/` directory once registered against the same
// kaushik-pg-admin Firebase project. Do not hand-edit the keys below.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'TODO-run-flutterfire-configure',
    appId: 'TODO-run-flutterfire-configure',
    messagingSenderId: 'TODO-run-flutterfire-configure',
    projectId: 'TODO-run-flutterfire-configure',
    storageBucket: 'TODO-run-flutterfire-configure',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAxYEhXrwlsryX54mHlGrfbjJ0lI8FR9Do',
    appId: '1:1096625634070:android:eb72777e40996bc215ee37',
    messagingSenderId: '1096625634070',
    projectId: 'kaushik-pg-admin',
    storageBucket: 'kaushik-pg-admin.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAjgc2qUa3zlQx2JQdEWo0x3sB8JPpfem0',
    appId: '1:1096625634070:ios:d57b535639f1dfb615ee37',
    messagingSenderId: '1096625634070',
    projectId: 'kaushik-pg-admin',
    storageBucket: 'kaushik-pg-admin.firebasestorage.app',
    iosBundleId: 'com.kaushikpg.kaushikPgTenant',
  );
}
