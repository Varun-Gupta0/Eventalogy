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
    apiKey: 'AIzaSyDemoWebApiKeyForEventologyProj',
    appId: '1:100000000000:web:demo1234567890',
    messagingSenderId: '100000000000',
    projectId: 'eventology-app-demo',
    authDomain: 'eventology-app-demo.firebaseapp.com',
    storageBucket: 'eventology-app-demo.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDemoAndroidApiKeyForEventology',
    appId: '1:100000000000:android:demo1234567890',
    messagingSenderId: '100000000000',
    projectId: 'eventology-app-demo',
    storageBucket: 'eventology-app-demo.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDemoIOSApiKeyForEventologyProj',
    appId: '1:100000000000:ios:demo1234567890',
    messagingSenderId: '100000000000',
    projectId: 'eventology-app-demo',
    storageBucket: 'eventology-app-demo.appspot.com',
    iosBundleId: 'in.eventology.app',
  );
}
