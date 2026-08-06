// DietGrid 골든 테스트 (Tier 3) — 픽셀 스냅샷으로 시각 회귀 방지.
// 갱신: Actions → Update Goldens 워크플로 (또는 로컬에서
//       flutter test --update-goldens test/diet_grid_golden_test.dart)
// CI에서 갱신하는 쪽을 권한다 — 검사하는 환경과 만드는 환경이 같아야 한다.
// (flutter_test 기본 Ahem 폰트 → 플랫폼 무관 결정적 렌더링)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/schedule_parse.dart';
import 'package:nulloongzido/widgets/diet_grid.dart';

Widget _wrap(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    backgroundColor: Colors.white,
    body: Padding(padding: const EdgeInsets.all(8), child: child),
  ),
);

void main() {
  testWidgets('식단표: 팀 3개(겹침 + 커스텀 포함)', (tester) async {
    // 10:00~22:30 일정 → 표시범위 15시간 × rowH 34 = 510px + 헤더/패딩.
    await tester.binding.setSurfaceSize(const Size(400, 600));
    final teams = [
      DietTeam(
        name: '강남스파이크',
        isCustom: false,
        slotIdx: 0,
        events: const [SchedEvent('월', 19, 22), SchedEvent('토', 13, 17)],
      ),
      DietTeam(
        name: '한강배구',
        isCustom: false,
        slotIdx: 1,
        events: const [
          SchedEvent('월', 20, 22.5), // 월요일 겹침 → 레인 분할(칸을 반으로)
          SchedEvent('수', 19.5, 21.5),
        ],
      ),
      DietTeam(
        name: '우리동네',
        isCustom: true,
        slotIdx: 2,
        events: const [SchedEvent('일', 10, 12)],
      ),
    ];
    await tester.pumpWidget(_wrap(DietGrid(teams: teams)));
    await expectLater(
      find.byType(DietGrid),
      matchesGoldenFile('goldens/diet_grid_populated.png'),
    );
  });

  testWidgets('식단표: 일정 없음(빈 상태)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 120));
    await tester.pumpWidget(_wrap(const DietGrid(teams: [])));
    await expectLater(
      find.byType(DietGrid),
      matchesGoldenFile('goldens/diet_grid_empty.png'),
    );
  });
}
