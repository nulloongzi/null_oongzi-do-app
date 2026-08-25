// 화면 렌더링 검증 — 4탭이 뜨고, 온보딩 → 명단 추가 → 뽑기 → 확정이 이어지는지.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/screens/anchigi_screen.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/theme.dart';
import 'package:nulloongzido/widgets/anchigi/anchigi_court.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app() => MaterialApp(theme: AppTheme.light, home: const AnchigiScreen());

/// 전 포지션 가능한 선수 n명을 저장소에 미리 넣어 둔다.
/// (추가 폼으로 넣으면 포지션이 세터 하나뿐이라 배치가 안 된다)
void seedRoster(int n) {
  final players = [
    for (var i = 0; i < n; i++)
      {
        'id': 'p$i',
        'name': '선수$i',
        'tier': {
          'S': 'main',
          'OP': 'main',
          'OH': 'main',
          'MB': 'main',
          'Li': 'main',
        },
        'here': true,
        'leave': null,
      },
  ];
  SharedPreferences.setMockInitialValues({
    'anchigi.players.v1': jsonEncode(players),
  });
}

/// 뽑는 동안 진행 표시기가 계속 돌아 pumpAndSettle이 정착하지 못한다.
/// 조건이 나타날 때까지만 프레임을 굴린다.
/// 솔버는 compute()로 별도 아이솔레이트에서 도는데 tester.pump()는 가상 시간만
/// 흘리므로, runAsync로 실제 시간을 줘야 결과가 돌아온다.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxTries = 200,
}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  fail('기다린 위젯이 나타나지 않음: $finder');
}

/// 뽑기 버튼을 누르고 결과가 나올 때까지 기다린다.
Future<void> drawAndWait(WidgetTester tester) async {
  await tester.tap(find.textContaining(t('ag_draw_btn')));
  await pumpUntil(tester, find.text(t('ag_confirm_next')));
  await tester.pumpAndSettle();
}

/// 명단 탭에서 사람 한 명 추가.
Future<void> addPlayer(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextField).first, name);
  await tester.tap(find.widgetWithText(ElevatedButton, t('ag_add_btn')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appLang.value = 'ko';
  });

  // 탭 4개가 각자 ListView를 가져 스크롤 대상을 특정하기 어렵다.
  // 뷰포트를 길게 잡아 내용이 한 화면에 들어오게 한다.
  setUpAll(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1200, 4000);
    view.devicePixelRatio = 1.0;
  });

  testWidgets('4개 탭이 모두 뜬다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text(t('ag_tab_lineup')), findsOneWidget);
    expect(find.text(t('ag_tab_roster')), findsOneWidget);
    expect(find.text(t('ag_tab_record')), findsOneWidget);
    expect(find.text(t('ag_tab_help')), findsOneWidget);
  });

  testWidgets('명단이 비면 온보딩만 보인다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text(t('ag_intro_title')), findsOneWidget);
    expect(find.text(t('ag_intro_go')), findsOneWidget);
    // 설정 카드는 아직 없어야 한다.
    expect(find.text(t('ag_card_settings')), findsNothing);
  });

  testWidgets('온보딩 버튼이 명단 탭으로 보낸다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text(t('ag_intro_go')));
    await tester.pumpAndSettle();

    expect(find.text(t('ag_add_person')), findsOneWidget);
  });

  testWidgets('명단에 사람을 추가하면 목록에 나타난다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text(t('ag_tab_roster')));
    await tester.pumpAndSettle();

    await addPlayer(tester, '홍길동');
    expect(find.text('홍길동'), findsOneWidget);
    expect(find.text(t('ag_roster_empty')), findsNothing);
  });

  testWidgets('명단이 생기면 배치 탭에 설정과 뽑기 버튼이 나온다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text(t('ag_tab_roster')));
    await tester.pumpAndSettle();
    await addPlayer(tester, '홍길동');

    await tester.tap(find.text(t('ag_tab_lineup')));
    await tester.pumpAndSettle();

    expect(find.text(t('ag_card_time')), findsOneWidget);
    expect(find.text(t('ag_card_settings')), findsOneWidget);
    expect(find.textContaining(t('ag_draw_btn')), findsOneWidget);
  });

  testWidgets('인원이 부족하면 진단 메시지가 보인다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text(t('ag_tab_roster')));
    await tester.pumpAndSettle();
    await addPlayer(tester, '홍길동');

    await tester.tap(find.text(t('ag_tab_lineup')));
    await tester.pumpAndSettle();

    // 1명뿐이므로 '몇 명 부족' 안내가 떠야 한다.
    expect(find.textContaining('부족'), findsOneWidget);
  });

  testWidgets('12명이면 뽑기가 되고 결과·확정 버튼이 나온다', (tester) async {
    seedRoster(12);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // 12명이면 배치 가능 — 진단 메시지가 없어야 한다.
    expect(find.textContaining('부족'), findsNothing);
    expect(find.textContaining('전용이'), findsNothing);

    await drawAndWait(tester);

    expect(find.text(t('ag_timeline')), findsOneWidget);
    expect(find.text(t('ag_confirm_next')), findsOneWidget);
    expect(find.textContaining(t('ag_again')), findsOneWidget);
    // 3경기 코트가 그려진다.
    expect(find.byType(AnchigiCourt), findsNWidgets(3));
  });

  testWidgets('확정하면 라운드가 넘어가고 기록에 쌓인다', (tester) async {
    seedRoster(13);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.textContaining('1R'), findsOneWidget);

    await drawAndWait(tester);
    await tester.tap(find.text(t('ag_confirm_next')));
    await tester.pumpAndSettle();

    // 다음 라운드로 넘어가고 결과는 사라진다.
    expect(find.textContaining('2R'), findsOneWidget);
    expect(find.text(t('ag_confirm_next')), findsNothing);
    expect(find.text(t('ag_past_title')), findsNothing);
    expect(find.textContaining(t('ag_past_title')), findsOneWidget);

    // 기록 탭에 누적이 보인다.
    await tester.tap(find.text(t('ag_tab_record')));
    await tester.pumpAndSettle();
    expect(find.text(t('ag_stat_empty')), findsNothing);
    expect(find.text('선수0'), findsOneWidget);
  });

  testWidgets('설정을 바꾸면 뽑아둔 결과가 사라진다', (tester) async {
    seedRoster(12);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await drawAndWait(tester);
    expect(find.text(t('ag_confirm_next')), findsOneWidget);

    // 결과가 있으면 설정 카드가 접혀 있으므로 펼쳐서 바꾼다.
    await tester.tap(find.text(t('ag_card_settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('ag_feel_mix')));
    await tester.pumpAndSettle();

    expect(find.text(t('ag_confirm_next')), findsNothing);
  });

  testWidgets('기록 탭은 확정 전에는 비어 있다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text(t('ag_tab_record')));
    await tester.pumpAndSettle();

    expect(find.text(t('ag_stat_empty')), findsOneWidget);
  });

  testWidgets('설명 탭이 내용을 보여준다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text(t('ag_tab_help')));
    await tester.pumpAndSettle();

    expect(find.text(t('ag_help_h1')), findsOneWidget);
    expect(find.text(t('ag_help_h3')), findsOneWidget);
  });

  testWidgets('영어로 바꾸면 탭 이름이 번역된다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // 화면 안 EN/KO 버튼으로 전환 — 라우트가 직접 appLang을 구독해야 반영된다.
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('Lineup'), findsWidgets);
    expect(find.text('Roster'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
  });
}
