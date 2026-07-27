// social_auth_service.dart — 카카오/네이버 소셜 로그인. 웹 social-auth.js 포팅.
//
// 웹은 authorization-code 리다이렉트지만 앱은 네이티브 SDK로 access token을 직접 받아
// Cloud Function(kakao/naverCustomToken)에 { accessToken }으로 넘긴다 (functions/social-auth.js
// 의 앱 경로). CF가 제공자 API로 검증 후 커스텀 토큰을 발급하면 signInWithCustomToken.
// uid 규칙: 'kakao:{id}' / 'naver:{id}' — 제공자별 독립 계정 (웹과 동일 계정으로 이어짐).
//
// 네이버는 네이티브 SDK 정책상 client secret이 앱 설정에 필요하다
// (android/app/src/main/res/values/strings.xml + ios/Runner/Info.plist).
// secret 미설정 상태에서는 kNaverLoginConfigured=false로 두어 로그인 버튼을 숨긴다.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:shared_preferences/shared_preferences.dart';

// 네이버 로그인 활성화 스위치. strings.xml/Info.plist에 client secret을 채운 뒤 true로.
// (웹 social-auth.js의 hideUnconfigured 대응 — 미설정 제공자 버튼 숨김)
const bool kNaverLoginConfigured = false;

/// 사용자가 제공자 화면에서 취소한 경우 — 에러 문구 없이 조용히 복귀한다.
class SocialAuthCancelled implements Exception {}

class SocialAuthService {
  static const _lastProviderKey = 'nulloong_last_login_provider';

  /// 지난 로그인 수단 기억(웹 rememberLoginProvider 대응).
  /// 로그인 UI에서 "지난번에 사용" 칩으로 수단 갈아탐 → 계정 분리를 최소화.
  static Future<void> rememberProvider(String provider) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_lastProviderKey, provider);
    } catch (_) {}
  }

  static Future<String> lastProvider() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getString(_lastProviderKey) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 로그인 수단 판별 — 네임카드 스탬프용 (웹 detectLoginProvider 포팅).
  /// 카카오/네이버는 커스텀 토큰 uid 규칙, 구글/이메일은 providerData로 구분.
  /// 판별 불가(익명 등)면 '' 반환. 순수 함수라 단위 테스트 가능.
  static String detectProvider({
    required String uid,
    required List<String> providerIds,
  }) {
    if (uid.startsWith('kakao:')) return 'kakao';
    if (uid.startsWith('naver:')) return 'naver';
    if (providerIds.contains('google.com')) return 'google';
    if (providerIds.contains('password')) return 'rice';
    return '';
  }

  static String detectProviderOf(User? user) {
    if (user == null) return '';
    return detectProvider(
      uid: user.uid,
      providerIds: user.providerData
          .map((p) => p.providerId)
          .toList(growable: false),
    );
  }

  /// 카카오 로그인: 톡 앱 설치 시 톡으로, 아니면 계정(웹뷰)으로. 취소는 SocialAuthCancelled.
  Future<void> loginWithKakao() async {
    kakao.OAuthToken token;
    if (await kakao.isKakaoTalkInstalled()) {
      try {
        token = await kakao.UserApi.instance.loginWithKakaoTalk();
      } catch (e) {
        if (_isCancel(e)) throw SocialAuthCancelled();
        // 톡 로그인 실패(톡 계정 미연결 등) → 계정 로그인 폴백
        token = await _kakaoAccountLogin();
      }
    } else {
      token = await _kakaoAccountLogin();
    }
    await _signInWithCustomToken('kakaoCustomToken', token.accessToken);
    await rememberProvider('kakao');
  }

  Future<kakao.OAuthToken> _kakaoAccountLogin() async {
    try {
      return await kakao.UserApi.instance.loginWithKakaoAccount();
    } catch (e) {
      if (_isCancel(e)) throw SocialAuthCancelled();
      rethrow;
    }
  }

  /// 네이버 로그인. 취소/실패 status는 SocialAuthCancelled 또는 예외로 구분.
  Future<void> loginWithNaver() async {
    final NaverLoginResult res = await FlutterNaverLogin.logIn();
    if (res.status == NaverLoginStatus.cancelledByUser) {
      throw SocialAuthCancelled();
    }
    if (res.status != NaverLoginStatus.loggedIn) {
      throw Exception(res.errorMessage);
    }
    final token = await FlutterNaverLogin.getCurrentAccessToken();
    await _signInWithCustomToken('naverCustomToken', token.accessToken);
    await rememberProvider('naver');
  }

  /// CF(kakao/naverCustomToken)로 access token 검증 → 커스텀 토큰 → Firebase 로그인.
  Future<void> _signInWithCustomToken(String fn, String accessToken) async {
    final res = await FirebaseFunctions.instance.httpsCallable(fn).call({
      'accessToken': accessToken,
    });
    final data = res.data;
    final custom = (data is Map) ? data['token'] as String? : null;
    if (custom == null || custom.isEmpty) {
      throw Exception('custom token 발급 실패');
    }
    await FirebaseAuth.instance.signInWithCustomToken(custom);
  }

  /// 로그아웃 시 제공자 세션도 best-effort로 정리 (다음 로그인 때 계정 선택 가능하게).
  static Future<void> signOutProviders() async {
    try {
      await kakao.UserApi.instance.logout();
    } catch (_) {}
    try {
      await FlutterNaverLogin.logOut();
    } catch (_) {}
  }

  static bool _isCancel(Object e) {
    return e is PlatformException &&
        (e.code == 'CANCELED' || e.code == 'CANCELLED');
  }
}
