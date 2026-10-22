// 시간표 모프가 시트 높이를 따라 **매 프레임 레이아웃을 다시 하지 않는지**.
// 2.13.0 은 펼침비율마다 Align.heightFactor 로 본문 높이를 바꿔 시트가 미세하게 끊겼다.
// 레이아웃은 0.5 를 넘나들 때 한 번만 바뀌고, 그 사이는 투명도만 바뀌어야 한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/models/pickup_spot.dart';
import 'package:nulloongzido/screens/detail_sheet.dart';
import 'package:nulloongzido/theme.dart';
import 'package:nulloongzido/widgets/map_detail_panel.dart';

void main() {
  testWidgets('모프: 같은 쪽 안에서는 본문 높이가 그대로, 0.5 를 넘을 때만 바뀐다', (tester) async {
    final expand = ValueNotifier<double>(0);
    final body = GlobalKey();
    final spot = PickupSpot(
      id: 'pk-1',
      title: '잠실 토요 6인제 픽업 크루',
      sport: '6s',
      level: 'any',
      venueName: '잠실학생체육관',
      region: '서울',
      schedule: '토 19:00~22:00',
      lastVerifiedAt: DateTime.now(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DetailPanelScope(
            expand: expand,
            toggle: () {},
            child: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Builder(
                  builder: (ctx) => KeyedSubtree(
                    key: body,
                    child: spotDetailBody(ctx, spot, close: () {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    double h() => tester.getSize(find.byKey(body)).height;

    final peek = h();
    expand.value = 0.3;
    await tester.pump();
    expect(h(), peek, reason: '접힘 쪽에서 끄는 동안 본문 높이가 변하면 매 프레임 재배치');

    expand.value = 0.6;
    await tester.pump();
    final open = h();
    expect(open, greaterThan(peek), reason: '0.5 를 넘으면 시간표가 자리를 잡는다');
    expand.value = 0.8;
    await tester.pump();
    expect(h(), open);
    expand.value = 1;
    await tester.pump();
    expect(h(), open, reason: '펼침 쪽에서 끄는 동안에도 높이는 그대로(투명도만)');

    final fades = tester
        .widgetList<FadeTransition>(find.byType(FadeTransition))
        .map((f) => f.opacity.value);
    expect(fades, contains(1.0));
    expect(tester.takeException(), isNull);
  });
}
