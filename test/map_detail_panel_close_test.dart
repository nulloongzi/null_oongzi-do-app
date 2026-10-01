// 상세 패널 닫기 — 쓸어내리기(손가락) · '닫기' 버튼(화면 낭독기). 웹 #sheetHandle 과 같은 규칙.
// 닫힘 기준(접힌 높이의 60%)은 웹 club-detail.js SHEET_CLOSE_RATIO 와 같다(design-system §3-1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/semantics.dart';
import 'package:nulloongzido/widgets/map_detail_panel.dart';

Future<void> _pump(WidgetTester tester, VoidCallback onClose) async {
  // 폰 크기(390×844). 패널은 MediaQuery 높이로 접힌·펼친 높이를 정한다
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MapDetailPanel(
          onClose: onClose,
          child: const SizedBox(height: 600, child: Text('본문')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('손잡이는 화면 낭독기에 "닫기" 버튼으로 읽히고, 그 동작이 패널을 닫는다', (tester) async {
    final semantics = tester.ensureSemantics();
    var closed = 0;
    await _pump(tester, () => closed++);

    final handle = find.bySemanticsLabel('닫기');
    expect(handle, findsOneWidget);
    final node = tester.getSemantics(handle);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(closed, 1);
    semantics.dispose();
  });

  testWidgets('손가락 탭은 닫지 않는다 — 닫기는 쓸어내리기로', (tester) async {
    var closed = 0;
    await _pump(tester, () => closed++);
    await tester.tap(find.bySemanticsLabel('닫기'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(closed, 0);
  });

  testWidgets('접힌 높이의 60% 아래로 쓸어내리면 닫히고, 덜 내리면 제자리로', (tester) async {
    var closed = 0;
    await _pump(tester, () => closed++);
    final peek = 844 * 0.42;
    final handle = find.bySemanticsLabel('닫기');

    // 30% 내림(높이 70%) → 닫히지 않음
    await tester.drag(handle, Offset(0, peek * 0.3));
    await tester.pumpAndSettle();
    expect(closed, 0);

    // 50% 내림(높이 50%) → 닫힘
    await tester.drag(handle, Offset(0, peek * 0.5));
    await tester.pumpAndSettle();
    expect(closed, 1);
    expect(kSheetCloseRatio, 0.6);
  });
}
