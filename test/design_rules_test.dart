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

  test('영어 서비스 이름은 Nulloongzi-do 하나 (웹 design-system §4)', () {
    final files = ['lib/l10n/strings.dart', 'ios/Runner/Info.plist'];
    // 대문자로 시작하는 표기만 — 소문자 내부 이름(CFBundleName nulloongzido 등)은 화면 이름이 아니다
    final bad = RegExp(r'Nurungji-?do|Nulloongzido|Nulloongzi do\b');
    final hits = <String>[];
    for (final f in files) {
      final lines = File(f).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (bad.hasMatch(lines[i])) {
          hits.add('$f:${i + 1}');
        }
      }
    }
    expect(hits, isEmpty, reason: 'Nulloongzi-do 로');
  });

  test('글자는 10 이상 (design-references U8)', () {
    // 표 칸처럼 빽빽한 곳도 10 까지 — 웹 tests/design-rules.test.js 와 같은 바닥.
    // 예외: 네임카드 스탬프(provider_stamp.dart)의 'TALK' 각인은 글자가 아니라 그림이다.
    final tiny = RegExp(r'fontSize:\s*[0-9](\.[0-9]+)?\b');
    expect(
      _hits(
        tiny,
      ).where((h) => !h.startsWith('lib/widgets/provider_stamp.dart')),
      isEmpty,
      reason: '10 미만 글자',
    );
  });

  test('토큰 클래스는 생성 파일에만 있다 (§0)', () {
    final defs = RegExp(r'class Nurungji(Colors|Shadows|Radius)\b');
    expect(_hits(defs).map((h) => h.split(':').first).toSet(), {
      'lib/design_tokens.g.dart',
    }, reason: '토큰은 웹 tokens/design-tokens.json 에서 고치고 다시 만든다');
  });
}
