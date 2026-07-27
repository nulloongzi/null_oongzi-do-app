// social_auth_detect_test.dart — 로그인 수단 판별(네임카드 스탬프) 단위 테스트.
// 웹 detectLoginProvider와 동일 규칙: 커스텀 토큰 uid 접두사 → providerData.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/social_auth_service.dart';

void main() {
  group('SocialAuthService.detectProvider', () {
    test('카카오 커스텀 토큰 uid', () {
      expect(
        SocialAuthService.detectProvider(uid: 'kakao:12345', providerIds: []),
        'kakao',
      );
    });

    test('네이버 커스텀 토큰 uid', () {
      expect(
        SocialAuthService.detectProvider(uid: 'naver:abcde', providerIds: []),
        'naver',
      );
    });

    test('구글 providerData', () {
      expect(
        SocialAuthService.detectProvider(
          uid: 'FyZx1',
          providerIds: ['google.com'],
        ),
        'google',
      );
    });

    test('이메일(password) → rice 이스터에그', () {
      expect(
        SocialAuthService.detectProvider(
          uid: 'FyZx1',
          providerIds: ['password'],
        ),
        'rice',
      );
    });

    test('uid 접두사가 providerData보다 우선', () {
      expect(
        SocialAuthService.detectProvider(
          uid: 'kakao:99',
          providerIds: ['password'],
        ),
        'kakao',
      );
    });

    test('판별 불가(익명 등)는 빈 문자열 → 스탬프 미표시', () {
      expect(
        SocialAuthService.detectProvider(uid: 'anon1', providerIds: []),
        '',
      );
    });
  });
}
