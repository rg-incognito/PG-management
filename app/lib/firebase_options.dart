// GENERATED PLACEHOLDER — replace this file by running `flutterfire configure`
// from the `app/` directory once you have created a Firebase project and run
// `firebase login`. That command overwrites this file with real values for
// Android/iOS/web. Do not hand-edit the keys below — they are dummy values
// and the app cannot connect to Firebase until this file is regenerated.

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
    appId: '1:1096625634070:android:57c3409b040eb0ee15ee37',
    messagingSenderId: '1096625634070',
    projectId: 'kaushik-pg-admin',
    storageBucket: 'kaushik-pg-admin.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAjgc2qUa3zlQx2JQdEWo0x3sB8JPpfem0',
    appId: '1:1096625634070:ios:422667c70044a31e15ee37',
    messagingSenderId: '1096625634070',
    projectId: 'kaushik-pg-admin',
    storageBucket: 'kaushik-pg-admin.firebasestorage.app',
    iosBundleId: 'com.kaushikpg.kaushikPgAdmin',
  );
}
