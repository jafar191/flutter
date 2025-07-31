import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return iOS;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCtJo9pYeoPKBU5U8CWj62i0_jAD1ewkBM',
    appId: '1:410533018403:android:3017b31566718e8402ea96',
    messagingSenderId: '410533018403',
    projectId: 'jayk-delivery-app',
    storageBucket: 'jayk-delivery-app.firebasestorage.app',
  );

  static const FirebaseOptions iOS = FirebaseOptions(
    apiKey: 'AIzaSyCtJo9pYeoPKBU5U8CWj62i0_jAD1ewkBM',
    appId: '1:410533018403:ios:1ff155a3d910002d02ea96',
    messagingSenderId: '410533018403',
    projectId: 'jayk-delivery-app',
    storageBucket: 'jayk-delivery-app.firebasestorage.app',
    iosBundleId: 'com.jayk.deliveryapp',
  );
}
