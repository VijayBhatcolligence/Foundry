import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDEPoD7B5bHTfGdi09OmRyGXoztirFah8Y',
    appId: '1:819068716771:ios:0ebe264d43225e9b0e67d6',
    messagingSenderId: '819068716771',
    projectId: 'foundry-app-f71f1',
    storageBucket: 'foundry-app-f71f1.firebasestorage.app',
    iosBundleId: 'in.colligence.foundry.position',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA9VhCy16B8GuJkd6Nt9g_WNtFS4saoUs0',
    appId: '1:819068716771:android:5bec05571a510b0f0e67d6',
    messagingSenderId: '819068716771',
    projectId: 'foundry-app-f71f1',
    storageBucket: 'foundry-app-f71f1.firebasestorage.app',
  );
}
