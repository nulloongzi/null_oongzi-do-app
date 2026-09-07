// 픽업 목록 시트의 상세 모드 — 상세는 별도 패널이 아니라 같은 시트의 모드여야 한다.
// (목록 42% 시트 위로 상세 패널이 따로 떠서 크기·모서리가 어긋나 보이던 회귀 방지)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/theme.dart';
import 'package:nulloongzido/widgets/pickup_list_sheet.dart';

Widget host({Widget? detail, String? detailId, VoidCallback? onBack}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: PickupListSheet(
                spots: const [],
                onTap: (_) {},
                detail: detail,
                detailId: detailId,
                onBack: onBack,
              ),
            ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('목록 모드: 빈 목록 안내가 보이고 뒤로가기는 없다', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text(t('pk_empty')), findsOneWidget);
    expect(find.text(t('pk_back_to_list')), findsNothing);
  });

  testWidgets('상세 모드: 같은 시트 안에 뒤로가기 + 상세 본문, 목록은 숨김', (tester) async {
    var backCalls = 0;
    await tester.pumpWidget(
      host(
        detail: const Text('상세 본문'),
        detailId: 's1',
        onBack: () => backCalls++,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('상세 본문'), findsOneWidget);
    expect(find.text(t('pk_back_to_list')), findsOneWidget);
    expect(find.text(t('pk_empty')), findsNothing);
    // 시트는 하나뿐 — 상세용 패널이 따로 생기지 않는다
    expect(find.byType(PickupListSheet), findsOneWidget);

    await tester.tap(find.text(t('pk_back_to_list')));
    await tester.pump();
    expect(backCalls, 1);
  });

  testWidgets('상세 → 목록: detail을 비우면 목록으로 돌아온다', (tester) async {
    await tester.pumpWidget(host(detail: const Text('상세 본문'), detailId: 's1'));
    await tester.pumpAndSettle();
    expect(find.text('상세 본문'), findsOneWidget);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('상세 본문'), findsNothing);
    expect(find.text(t('pk_empty')), findsOneWidget);
  });
}
