// 필터 탑시트 — 위에서 내려오고, 손잡이를 위로 끌거나 바깥을 누르면 닫힌다(웹 #filterSheet 와 같음).
// 값: docs/motion-spec.md §5 · NurungjiMotion.modalEnter/modalExit.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/widgets/app_sheet.dart';

Future<void> _open(WidgetTester tester, void Function(Object?) done) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => done(
                await showTopSheet<String>(
                  context,
                  child: const SizedBox(height: 300, child: Text('필터 본문')),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
}

void main() {
  testWidgets('위에서 내려와 화면 맨 위에 붙는다', (tester) async {
    await _open(tester, (_) {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = tester.getTopLeft(find.text('필터 본문')).dy;
    await tester.pumpAndSettle();
    final end = tester.getTopLeft(find.text('필터 본문')).dy;
    expect(mid, lessThan(end), reason: '내려오는 중에는 아직 위쪽에 있다');
    expect(end, lessThan(60));
  });

  testWidgets('손잡이를 조금 올리면 제자리, 50px 넘게 올리면 닫힌다', (tester) async {
    var closed = 0;
    await _open(tester, (_) => closed++);
    await tester.pumpAndSettle();
    final handle = find.bySemanticsLabel('Close');

    await tester.timedDrag(
      handle,
      const Offset(0, -30),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('필터 본문'), findsOneWidget);
    expect(closed, 0);

    await tester.timedDrag(
      handle,
      const Offset(0, -80),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('필터 본문'), findsNothing);
    expect(closed, 1);
  });

  testWidgets('바깥(딤)을 누르면 닫힌다', (tester) async {
    Object? result = 'x';
    await _open(tester, (r) => result = r);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 800));
    await tester.pumpAndSettle();
    expect(find.text('필터 본문'), findsNothing);
    expect(result, isNull);
    expect(kTopSheetCloseDrag, 50.0);
  });
}
