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

/// 전 자리 가능한 선수 n명을 저장소에 미리 넣어 둔다.
/// (자리를 안 고르면 '어디든'이라 배치는 되지만, 티어별 동작을 보려면 명시가 낫다)
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
    // 코트는 한 경기씩 본다 — 경기 탭 셋에 코트는 하나.
    expect(find.byType(AnchigiCourt), findsOneWidget);
    expect(find.textContaining('1${t('ag_game_word')}'), findsWidgets);
    expect(find.textContaining('3${t('ag_game_word')}'), findsWidgets);
  });

  testWidgets('경기 탭을 누르면 그 경기 코트로 바뀐다', (tester) async {
    seedRoster(12);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await drawAndWait(tester);

    // 2경기 탭으로.
    await tester.tap(find.text('2${t('ag_game_word')}').last);
    await tester.pumpAndSettle();
    expect(find.byType(AnchigiCourt), findsOneWidget);
  });

  testWidgets('간단히 보기는 세 경기를 한눈에 둔다', (tester) async {
    seedRoster(12);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await drawAndWait(tester);

    await tester.tap(find.text(t('ag_compact_list')));
    await tester.pumpAndSettle();
    expect(find.byType(AnchigiLineupList), findsNWidgets(3));
    expect(find.byType(AnchigiCourt), findsNothing);
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
    await tester.tap(find.text(t('ag_prio_variety')));
    await tester.pumpAndSettle();

    expect(find.text(t('ag_confirm_next')), findsNothing);
  });

  testWidgets('9인제로 바꾸면 포메이션 자리로 바뀐다', (tester) async {
    seedRoster(18);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text(t('ag_sport_v9')));
    await tester.pumpAndSettle();
    // 포메이션 셋이 다 보인다(속공 1 · 2 · 3).
    expect(find.text(t('ag_tpl_q1')), findsOneWidget);
    expect(find.text(t('ag_tpl_q2')), findsOneWidget);
    expect(find.text(t('ag_tpl_q3')), findsOneWidget);

    await drawAndWait(tester);
    // 9인제 자리 이름이 코트에 보인다.
    expect(find.text(t('ag_seat_s9')), findsWidgets);
    // 빈 자리 없이 다 찼다.
    expect(find.textContaining('(${t('ag_need_label')})'), findsNothing);
  });

  testWidgets('6인제 6-2 로 바꾸면 코트에 세터가 둘', (tester) async {
    seedRoster(12);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text(t('ag_tactic_62')));
    await tester.pumpAndSettle();
    await drawAndWait(tester);

    // 전위 세터는 '존 4 · 세터 · 라이트' 로 표시된다.
    expect(find.textContaining(t('ag_seat_s_front')), findsWidgets);
  });

  testWidgets('인원이 모자라도 뽑히고 빈 자리가 (필요)로 보인다', (tester) async {
    seedRoster(9);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // 막지 않고 안내만 띄운다.
    expect(find.textContaining(t('ag_shortage_note')), findsOneWidget);

    await drawAndWait(tester);
    expect(find.textContaining('(${t('ag_need_label')})'), findsWidgets);
    expect(find.textContaining(t('ag_needs_title')), findsWidgets);
  });

  testWidgets('간단히 보기로 바꾸면 코트 대신 목록이 나온다', (tester) async {
    seedRoster(12);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await drawAndWait(tester);

    expect(find.byType(AnchigiCourt), findsWidgets);
    await tester.tap(find.text(t('ag_compact_list')));
    await tester.pumpAndSettle();
    expect(find.byType(AnchigiCourt), findsNothing);
    expect(find.byType(AnchigiLineupList), findsWidgets);
  });

  testWidgets('명단에서 자리를 고르고 고정할 수 있다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('ag_tab_roster')));
    await tester.pumpAndSettle();

    await addPlayer(tester, '누룽');
    // 자리를 안 골랐으니 '어디든'.
    expect(find.text(t('ag_flex_badge')), findsOneWidget);

    // 명단 행의 세터 칩을 눌러 주 자리로(추가 폼 칩이 아니라 첫 번째).
    await tester.tap(find.text(t('ag_posx_S')).first);
    await tester.pumpAndSettle();
    expect(find.text(t('ag_flex_badge')), findsNothing);

    // 📌 로 고정하면 자리 이름이 붙는다.
    await tester.tap(find.text('📌'));
    await tester.pumpAndSettle();
    expect(find.text('📌 ${t('ag_posx_S')}'), findsOneWidget);
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
