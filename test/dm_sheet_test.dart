// 첫 연락 문구 — 웹 i18n.js dm_template 과 같은 문구·같은 링크여야 한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/widgets/dm_sheet.dart';

void main() {
  tearDown(() => appLang.value = 'ko');

  test('팀 이름을 넣고, 누룽지도에서 왔다고 밝힌다 (KO/EN)', () {
    appLang.value = 'ko';
    final ko = dmTemplate('노원 배구');
    expect(ko, contains('누룽지도 보고 연락드려요'));
    expect(ko, contains('노원 배구 운동에'));
    appLang.value = 'en';
    final en = dmTemplate('Nowon VB');
    expect(en, contains('I found Nowon VB on Nulloongzi-do'));
  });

  test('팀 이름이 비면 대체어', () {
    appLang.value = 'ko';
    expect(dmTemplate('  '), contains('팀 운동에'));
    appLang.value = 'en';
    expect(dmTemplate(null), contains('I found your team on'));
  });

  test('DM 링크는 ig.me/m/<핸들>', () {
    expect(dmUri('smoke_crew').toString(), 'https://ig.me/m/smoke_crew');
  });
}
