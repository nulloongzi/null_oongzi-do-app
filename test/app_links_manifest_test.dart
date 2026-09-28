// App Link 범위 회귀 테스트 — AndroidManifest 의 https 인텐트 필터.
// 경로를 빼먹으면 도메인 전체를 가져가서, 웹 카카오·네이버 로그인 복귀 주소(/auth/callback/)와
// 약관 같은 웹 전용 페이지까지 앱이 연다(2026-09 실제로 웹 로그인이 끊겼다).
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('do.nulloongzi.com App Link 는 루트(/)만 연다', () {
    final xml = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final filters = RegExp(
      r'<intent-filter android:autoVerify="true">(.*?)</intent-filter>',
      dotAll: true,
    ).allMatches(xml).map((m) => m.group(1)!).toList();
    final web = filters.where((f) => f.contains('do.nulloongzi.com')).toList();
    expect(web, hasLength(1));
    final data = RegExp(r'<data[^>]*/>', dotAll: true).allMatches(web.single);
    expect(data, hasLength(1), reason: 'data 가 여러 개면 조합돼 범위가 넓어진다');
    final d = data.single.group(0)!;
    expect(d, contains('android:scheme="https"'));
    expect(d, contains('android:path="/"'));
    expect(d, isNot(contains('pathPrefix')));
    expect(d, isNot(contains('pathPattern')));
  });
}
