// social_auth_service.dart — 카카오/네이버 네이티브 로그인 → Cloud Function 커스텀 토큰 → Firebase 세션.
//
// Option A(제공자별 독립 계정): uid = kakao:<id> / naver:<id>.
// 프로필 생성·소유권(registered_by==uid)·북마크·관리자는 기존 uid 중심 로직이 그대로 자동 처리.
//
// 흐름: 제공자 SDK 네이티브 로그인 → access_token → httpsCallable(kakao/naverCustomToken)
//       → { token } → signInWithCustomToken. (백엔드가 access_token을 제공자 API로 검증)
//
// 지난 로그인 수단 기억(shared_preferences) → 로그인 화면에서 우선 노출(수단 전환 최소화).
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SocialAuthService {
  static const _lastProviderKey = 'last_login_provider';

  // 네이버 모바일 SDK 자격증명(네이버 개발자센터). 모바일 SDK는 secret을 기기에서 사용.
  // TODO: 발급 후 채우기. CF의 NAVER_CLIENT_ID/SECRET과 동일 앱이어야 함.
  static const _naverClientId = '';
  static const _naverClientSecret = '';
  static const _naverClientName = '누룽지도';

  static Future<void> rememberProvider(String p) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_lastProviderKey, p);
  }

  static Future<String?> lastProvider() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_lastProviderKey);
  }

  // access_token → CF → Firebase 커스텀 토큰 로그인 (공통).
  Future<void> _signInWithCustom(String provider, String accessToken) async {
    final callable = FirebaseFunctions.instance.httpsCallable('${provider}CustomToken');
    final res = await callable.call({'accessToken': accessToken});
    final token = (res.data as Map?)?['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('$provider 커스텀 토큰 발급 실패');
    }
    await FirebaseAuth.instance.signInWithCustomToken(token);
    await rememberProvider(provider);
  }

  // 카카오: 카카오톡 앱 우선, 없으면 카카오계정 로그인 → access_token → CF.
  // KakaoSdk.init(nativeAppKey)는 main.dart에서 이미 호출됨.
  Future<void> signInWithKakao() async {
    OAuthToken token;
    if (await isKakaoTalkInstalled()) {
      try {
        token = await UserApi.instance.loginWithKakaoTalk();
      } catch (_) {
        // 카카오톡 로그인 취소/실패 시 계정 로그인으로 폴백
        token = await UserApi.instance.loginWithKakaoAccount();
      }
    } else {
      token = await UserApi.instance.loginWithKakaoAccount();
    }
    await _signInWithCustom('kakao', token.accessToken);
  }

  // 네이버 → access_token → CF.
  // NOTE: flutter_naver_login API는 버전에 따라 이름이 다를 수 있음(pub get 후 확인).
  Future<void> signInWithNaver() async {
    if (_naverClientId.isEmpty || _naverClientSecret.isEmpty) {
      throw Exception('네이버 클라이언트 미설정');
    }
    await FlutterNaverLogin.initSdk(
      clientId: _naverClientId,
      clientName: _naverClientName,
      clientSecret: _naverClientSecret,
    );
    final result = await FlutterNaverLogin.logIn();
    if (result.status != NaverLoginStatus.loggedIn) {
      throw Exception('네이버 로그인 취소/실패');
    }
    final tokenRes = await FlutterNaverLogin.currentAccessToken;
    await _signInWithCustom('naver', tokenRes.accessToken);
  }
}
