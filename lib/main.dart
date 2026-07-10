// main.dart — 네이티브 재작성 진입점.
// 게스트 모드(웹 패리티 A1): 열람은 무로그인, 등록/찜/프로필 등 액션 시점에 로그인 유도.
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'services/i18n.dart';
import 'screens/map_screen.dart';

// ⚠️ 네이버 클라우드 '지도(Mobile Dynamic Map)' Client ID — console.ncloud.com 발급 후 교체.
// placeholder면 지도가 인증 실패로 안 뜸(카운트·상세 등 나머지는 정상 동작).
const String kNaverMapClientId = 't4mzao93mh';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 카카오톡 리치카드 공유 — 네이티브 앱 키(콘솔에 패키지명+키해시 등록 필요)
  KakaoSdk.init(nativeAppKey: '24e0161dd5945250b37e5ec7fbdf8363');
  await initLang();
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
    // appLang 변경 시 앱 전체 리빌드 → t()가 새 언어로 재평가됨.
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (_, __, ___) => MaterialApp(
        title: '누룽지도',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const MapScreen(), // 게스트도 바로 지도(웹과 동일)
      ),
    );
  }
}
