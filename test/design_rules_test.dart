// 디자인 규칙 회귀 테스트 — 웹 docs/design-system.md 중 코드로 잴 수 있는 것.
// 숫자 일치는 .github/workflows/design-tokens.yml, 사람 눈이 필요한 것은 웹 docs/visual-parity.md(반기 검수).
// 웹 쪽 같은 검사: 웹 저장소 tests/design-rules.test.js.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dartSources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

List<String> _hits(RegExp re) {
  final hits = <String>[];
  for (final f in _dartSources()) {
    final src = f.readAsStringSync();
    for (final m in re.allMatches(src)) {
      final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
      hits.add('${f.path}:$line');
    }
  }
  return hits;
}

void main() {
  test('그림자는 갈색만 — 검정 그림자 금지 (§3)', () {
    final black = RegExp(
      r'(BoxShadow\(\s*color:\s*(const\s+)?|shadowColor:\s*(const\s+)?)'
      r'(Color\(0x[0-9A-Fa-f]{2}000000\)|Colors\.black)',
    );
    expect(
      _hits(black),
      isEmpty,
      reason: '검정 그림자 → NurungjiShadows.* 또는 Color(0x..5D4037)',
    );
  });

  test('모달 딤은 갈색 — 검정 딤 금지 (§3)', () {
    final black = RegExp(
      r'[bB]arrierColor:\s*(const\s+)?(Color\(0x[0-9A-Fa-f]{2}000000\)|Colors\.black)',
    );
    expect(_hits(black), isEmpty, reason: '딤 → NurungjiColors.dim');
  });

  test('알림에 오류 원문(\$e)을 붙이지 않는다 (voice-and-tone)', () {
    // 웹과 같은 규칙: 사용자에겐 "…하지 못했어요. 잠시 후 다시 해 주세요." 한 문장, 원문은 debugPrint 로.
    final raw = RegExp(
      r"(Text|_snack|_toast|_err)\(\s*'(?:\$\{[^}]*\}|[^'\n])*\$\{?(e|err|error)\b",
    );
    expect(
      _hits(raw),
      isEmpty,
      reason: 'strings.dart 의 한 문장 + debugPrint(\'…: \$e\')',
    );
  });

  test('토큰 클래스는 생성 파일에만 있다 (§0)', () {
    final defs = RegExp(r'class Nurungji(Colors|Shadows|Radius)\b');
    expect(_hits(defs).map((h) => h.split(':').first).toSet(), {
      'lib/design_tokens.g.dart',
    }, reason: '토큰은 웹 tokens/design-tokens.json 에서 고치고 다시 만든다');
  });
}
