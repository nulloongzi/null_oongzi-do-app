// firebase_options.dart — 수동 작성(Android). google-services.json 값 기반.
// iOS/웹은 추후 `flutterfire configure`로 보강.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('웹은 아직 미설정 — flutterfire configure 필요');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          '${defaultTargetPlatform.name} 플랫폼은 아직 firebase_options 미설정 '
          '— flutterfire configure 로 추가하세요.',
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
}
