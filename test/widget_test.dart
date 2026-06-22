// Profile.fromMap 단위 테스트 — Firestore 스키마 변형(비문자열 필드)에도
// 크래시 없이 안전하게 파싱되는지 검증(Tier 0 하드닝 회귀 방지).
// (기존 스톡 카운터 위젯 테스트는 이 앱과 무관하고 Firebase 초기화로 실패하여 교체.)
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/models/profile.dart';

void main() {
  group('Profile.fromMap', () {
    test('비문자열 필드여도 throw 없이 폴백', () {
      final p = Profile.fromMap({
        'full_nickname': 123, // 숫자(스키마 변형)
        'nickname': true,
        'color': {'x': 1},
      });
      expect(p.fullNickname, '');
      expect(p.color, '#FFF9C4'); // 기본 색 폴백
    });

    test('정상 문자열 필드 파싱', () {
      final p = Profile.fromMap({
        'full_nickname': '백미밥-a3z',
        'nickname': '백미밥',
        'color': '#FFF9C4',
      });
      expect(p.fullNickname, '백미밥-a3z');
      expect(p.nickname, '백미밥');
    });
  });
}
