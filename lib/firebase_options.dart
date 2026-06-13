// File generated to match the `nulloongzi-do` Firebase project.
// Android values come from android/app/google-services.json,
// web values from the web app's firebase-init.js.
// (iOS/macOS not configured yet — see plan follow-ups.)
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform '
          '($defaultTargetPlatform). Run flutterfire configure to add it.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDPerbZbPV6FL0vvSv1uihkIs8ptRSwnHk',
    appId: '1:1024551952678:android:cd1adc5bb02fcac568a1e7',
    messagingSenderId: '1024551952678',
    projectId: 'nulloongzi-do',
    storageBucket: 'nulloongzi-do.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCnzjy0jzK6HD34Z-i7tapG3y-hkrA-XaM',
    appId: '1:1024551952678:web:91a0df59c12b68b968a1e7',
    messagingSenderId: '1024551952678',
    projectId: 'nulloongzi-do',
    authDomain: 'nulloongzi-do.firebaseapp.com',
    storageBucket: 'nulloongzi-do.firebasestorage.app',
    measurementId: 'G-L1KWREQEMW',
  );
}
