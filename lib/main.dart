// main.dart — 네이티브 재작성 진입점 (P1: 인증)
// webview 셸은 main 브랜치에 보존. 여기부터 풀 네이티브.
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';

// ⚠️ 네이버 클라우드 '지도(Mobile Dynamic Map)' Client ID — console.ncloud.com 발급 후 교체.
// placeholder면 지도가 인증 실패로 안 뜸(카운트·상세 등 나머지는 정상 동작).
const String kNaverMapClientId = 't4mzao93mh';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FlutterNaverMap().init(
    clientId: kNaverMapClientId,
    onAuthFailed: (ex) => debugPrint('네이버지도 인증 실패: $ex'),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '누룽지도',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

// 로그인 상태에 따라 로그인 화면 / 홈 전환
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) return const MapScreen();
        return const LoginScreen();
      },
    );
  }
}
