// i18n 데이터 표시 변환 순수 로직 단위 테스트 (Tier 1).
// 저장은 KO, EN 모드에서 표시만 변환 — 회비/대상/지역 어휘. 웹 i18n.js 포팅.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/i18n.dart';

void main() {
  group('EN 모드 변환', () {
    setUp(() => appLang.value = 'en');
    tearDown(() => appLang.value = 'ko');

    test('i18nPrice 금액 + 어휘', () {
      expect(i18nPrice('6.5만원'), '₩65,000');
      expect(i18nPrice('8천원'), '₩8,000');
      expect(i18nPrice('회비 3만원'), 'Fee ₩30,000');
    });
    test('i18nTarget 대상 어휘', () {
      expect(i18nTarget('여성전용'), 'Women only');
      expect(i18nTarget('성인'), 'Adults');
    });
    test('i18nRegion 지역명', () {
      expect(i18nRegion('서울'), 'Seoul');
      expect(i18nRegion('경상'), 'Gyeongsang');
    });
  });

  group('KO 모드 원문 유지', () {
    test('KO 에선 변환 없음', () {
      appLang.value = 'ko';
      expect(i18nPrice('6.5만원'), '6.5만원');
      expect(i18nTarget('여성전용'), '여성전용');
      expect(i18nRegion('서울'), '서울');
    });
  });
}
