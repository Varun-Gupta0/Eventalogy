import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
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
    apiKey: 'AIzaSyDYW_IA2z9kx_bjZY-4VZ_H5dyD0SGUsQ0',
    appId: '1:605358096794:web:2ab2ebff2f30920db17a23',
    messagingSenderId: '605358096794',
    projectId: 'eventalogy-p1',
    authDomain: 'eventalogy-p1.firebaseapp.com',
    storageBucket: 'eventalogy-p1.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDYW_IA2z9kx_bjZY-4VZ_H5dyD0SGUsQ0',
    appId: '1:605358096794:android:2ab2ebff2f30920db17a23',
    messagingSenderId: '605358096794',
    projectId: 'eventalogy-p1',
    storageBucket: 'eventalogy-p1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDYW_IA2z9kx_bjZY-4VZ_H5dyD0SGUsQ0',
    appId: '1:605358096794:ios:2ab2ebff2f30920db17a23',
    messagingSenderId: '605358096794',
    projectId: 'eventalogy-p1',
    storageBucket: 'eventalogy-p1.firebasestorage.app',
    iosBundleId: 'com.eventology_app',
  );
}
