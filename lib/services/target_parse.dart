// target_parse.dart — 저장된 모집 대상 문자열을 칩 + 기타 메모로 되돌린다.
// 웹 registration.js parseTargetValue 와 같은 규칙.
//
// 저장은 `성인, 대학생 (구력 1년 이상)` 처럼 칩 목록과 메모를 합친 한 문자열이다.
// 예전엔 복원할 때 칩만 고르고 메모칸은 비운 채 뒀는데, 수정하러 들어온 사람이
// 기타란을 다시 쳐야 했고 — 더 나쁘게는 **그대로 저장하면 괄호 안이 소리 없이
// 사라졌다.**
//
// 괄호가 없어도 칩으로 설명되지 않는 글자가 남으면(칩 도입 전 자유입력분,
// 예: `성인 남녀`) 그걸 메모로 살린다. 버리는 것보다 낫다.
typedef TargetParts = ({List<String> chips, String note});

TargetParts parseTargetValue(String? targetStr, List<String> knownValues) {
  final s = (targetStr ?? '').trim();
  var base = s;
  var note = '';

  final m = RegExp(r'^([\s\S]*?)\s*\(([^()]*)\)\s*$').firstMatch(s);
  if (m != null) {
    base = m.group(1)!;
    note = m.group(2)!.trim();
  }

  final chips = knownValues.where(base.contains).toList();

  if (m == null) {
    // 괄호가 있으면 메모는 이미 그 안에 있다. 없을 때만 잔여를 살핀다.
    var leftover = base;
    for (final v in chips) {
      leftover = leftover.replaceAll(v, ' ');
    }
    leftover = leftover.replaceAll(RegExp(r'[,·/]+'), ' ').trim();
    if (leftover.isNotEmpty) note = leftover;
  }
  return (chips: chips, note: note);
}
