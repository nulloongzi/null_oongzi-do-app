// 모집 대상 → 표시 태그. 괄호 안 메모를 띄어쓰기로 쪼개면 `#(구력` `#1년` `#있는분)` 같은
// 조각 칩이 나온다(실제 화면). 웹 tests 의 targetTagParts 와 같은 기대값.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/target_parse.dart';

void main() {
  test('괄호 안 메모는 한 덩어리, 나머지는 단어 칩', () {
    final p = targetTagParts('성인 대학생 여성전용 (구력 1년 이상+전국대회 출전경험 있는분)');
    expect(p.words, ['성인', '대학생', '여성전용']);
    expect(p.notes, ['구력 1년 이상+전국대회 출전경험 있는분']);
  });

  test('쉼표 구분 · 괄호 없음 · 빈 값 · 짝 없는 괄호', () {
    expect(targetTagParts('성인, 대학생').words, ['성인', '대학생']);
    expect(targetTagParts('성인, 대학생').notes, isEmpty);
    expect(targetTagParts(null).words, isEmpty);
    expect(targetTagParts('성인 ( )').notes, isEmpty);
    final odd = targetTagParts('성인 (초보 환영');
    expect(odd.words, ['성인', '초보', '환영']);
  });

  test('괄호가 가운데 있어도, 여러 개여도 각각 한 덩어리', () {
    final p = targetTagParts('(남녀 무관) 성인 (주 2회 참석)');
    expect(p.words, ['성인']);
    expect(p.notes, ['남녀 무관', '주 2회 참석']);
  });
}
