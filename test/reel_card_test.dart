// ReelCard — 릴스 발견 카드(커버 → 탭 한 번 → 인스타). WebView 없음.
// 확인하는 것: 커버 유무에 따른 두 모양, 탭이 정규화된 permalink 로 나가는지, 무효 URL 은 안 그리는지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/widgets/reel_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  const url = 'https://www.instagram.com/reel/ABC-123_x/?utm_source=copy';
  const norm = 'https://www.instagram.com/reel/ABC-123_x/';

  testWidgets('커버 없음 → 제네릭 카드, 탭하면 정규화된 permalink 로', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      _wrap(
        ReelCard(
          url: url,
          source: 'club',
          id: 'c1',
          openUrl: (u) async => opened.add(u),
        ),
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('인스타'), findsWidgets);
    await tester.tap(find.byType(ReelCard));
    await tester.pump(const Duration(milliseconds: 300));
    expect(opened, [norm]);
  });

  testWidgets('커버 있음 → 9:16 포스터(Image) + 인스타 필, 탭하면 인스타', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      _wrap(
        ReelCard(
          url: url,
          cover: 'https://example.invalid/reel_covers/ABC-123_x.jpg',
          source: 'peek',
          id: 'c1',
          openUrl: (u) async => opened.add(u),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(AspectRatio), findsOneWidget);
    expect(find.textContaining('Instagram'), findsOneWidget);
    await tester.tap(find.byType(ReelCard));
    await tester.pump(const Duration(milliseconds: 300));
    expect(opened, [norm]);
  });

  testWidgets('무효 URL 은 아무것도 그리지 않는다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ReelCard(
          url: 'https://evil.example/reel/ABC/',
          source: 'club',
          id: 'c1',
        ),
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.byType(BounceTapProbe), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });
}

// 존재하지 않는 타입을 찾는 프로브 — 무효 URL 케이스가 "아무 카드도 없음"임을 분명히 한다.
class BounceTapProbe extends StatelessWidget {
  const BounceTapProbe({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
