// 🍚 여기 자리 있어요? 시트·입구 띠 위젯 테스트 — 종류·날짜 칩이 줄을 거르고,
// 맞는 게 없으면 빈 안내, 줄은 상세로·연락하기는 연락으로 넘긴다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/services/this_week.dart';
import 'package:nulloongzido/widgets/app_sheet.dart';
import 'package:nulloongzido/widgets/room_sheet.dart';

// 2026-10-07 수요일 18:00
DateTime _now() => DateTime(2026, 10, 7, 18);

final _items = [
  ThisWeekItem(
    kind: kTwPickup,
    start: DateTime(2026, 10, 7, 20),
    end: DateTime(2026, 10, 7, 22),
    title: '망원 픽업',
    place: '망원 체육관',
    refId: 'p1',
    refType: 'pickup',
    channel: 'instagram',
  ),
  ThisWeekItem(
    kind: kTwDropIn,
    start: DateTime(2026, 10, 8, 19),
    end: DateTime(2026, 10, 8, 21),
    title: '성미산 배구',
    place: '서울 마포구',
    msg: '초보 환영',
    refId: 'c1',
    refType: 'club',
    channel: 'link',
  ),
  ThisWeekItem(
    kind: kTwGuest,
    end: DateTime(2026, 10, 8, 22),
    title: '불꽃 배구',
    place: '서울 강서구',
    msg: '세터 1명',
    refId: 'c2',
    refType: 'club',
  ),
];

String _rowKey(ThisWeekItem e) =>
    'tw_row_${e.kind}_${e.refId}_${e.end.millisecondsSinceEpoch}';
String _contactKey(ThisWeekItem e) =>
    'tw_contact_${e.kind}_${e.refId}_${e.end.millisecondsSinceEpoch}';

Future<void> _open(
  WidgetTester tester, {
  List<ThisWeekItem>? items,
  List<ThisWeekItem>? opened,
  List<ThisWeekItem>? contacted,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppSheet<void>(
              context,
              child: RoomSheet(
                items: items ?? _items,
                clock: _now,
                onOpen: (e) => opened?.add(e),
                onContact: (e) => contacted?.add(e),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => appLang.value = 'ko');

  testWidgets('제목·종류 칩 3개(모두 켜짐)·날짜 칩 7일 + 전체, 날짜별 묶음', (tester) async {
    await _open(tester);
    expect(find.text(t('tw_title')), findsOneWidget);
    expect(find.text(t('tw_sub')), findsOneWidget);
    for (final k in kTwKinds) {
      final chip = tester.widget<FilterChip>(
        find.byKey(ValueKey('tw_kind_$k')),
      );
      expect(chip.selected, isTrue, reason: k);
    }
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('tw_day_all')))
          .selected,
      isTrue,
    );
    expect(find.byKey(const ValueKey('tw_day_6')), findsOneWidget);
    expect(find.byKey(const ValueKey('tw_day_7')), findsNothing);
    for (final e in _items) {
      expect(find.byKey(ValueKey(_rowKey(e))), findsOneWidget);
    }
    // 묶음 제목(날짜 칩과 같은 글자라 둘씩 보인다)
    expect(find.text('수 10/7'), findsNWidgets(2));
    expect(find.text('20:00~22:00'), findsOneWidget);
    expect(find.text('~22:00'), findsOneWidget); // 시작 모르는 급구
    expect(find.text('세터 1명'), findsOneWidget);
  });

  testWidgets('종류 칩을 끄면 그 줄이 빠진다', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('tw_kind_pickup')));
    await tester.pump();
    expect(find.byKey(ValueKey(_rowKey(_items[0]))), findsNothing);
    expect(find.byKey(ValueKey(_rowKey(_items[1]))), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tw_kind_guest')));
    await tester.pump();
    expect(find.byKey(ValueKey(_rowKey(_items[2]))), findsNothing);
    expect(find.byKey(ValueKey(_rowKey(_items[1]))), findsOneWidget);
  });

  testWidgets('날짜 칩 하나만 — 그날 줄만, 전체로 되돌리기', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('tw_day_1'))); // 목 10/8
    await tester.pump();
    expect(find.byKey(ValueKey(_rowKey(_items[0]))), findsNothing);
    expect(find.byKey(ValueKey(_rowKey(_items[1]))), findsOneWidget);
    expect(find.byKey(ValueKey(_rowKey(_items[2]))), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tw_day_all')));
    await tester.pump();
    expect(find.byKey(ValueKey(_rowKey(_items[0]))), findsOneWidget);
  });

  testWidgets('맞는 게 없으면 빈 안내', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('tw_day_3'))); // 토 — 항목 없음
    await tester.pump();
    expect(find.byKey(const ValueKey('tw_empty')), findsOneWidget);
    expect(find.text(t('tw_empty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tw_day_all')));
    await tester.pump();
    for (final k in kTwKinds) {
      await tester.tap(find.byKey(ValueKey('tw_kind_$k')));
    }
    await tester.pump();
    expect(find.text(t('tw_empty')), findsOneWidget);
  });

  testWidgets('항목이 아예 없어도 빈 안내', (tester) async {
    await _open(tester, items: const []);
    expect(find.text(t('tw_empty')), findsOneWidget);
  });

  testWidgets('연락하기는 연락처가 있는 줄에만, 누르면 시트는 그대로', (tester) async {
    final contacted = <ThisWeekItem>[];
    await _open(tester, contacted: contacted);
    expect(find.byKey(ValueKey(_contactKey(_items[2]))), findsNothing);
    await tester.tap(find.byKey(ValueKey(_contactKey(_items[1]))));
    await tester.pumpAndSettle();
    expect(contacted, [_items[1]]);
    expect(find.byType(RoomSheet), findsOneWidget);
  });

  testWidgets('줄을 누르면 시트가 닫히고 그 항목을 연다', (tester) async {
    final opened = <ThisWeekItem>[];
    await _open(tester, opened: opened);
    await tester.tap(find.byKey(ValueKey(_rowKey(_items[2]))));
    await tester.pumpAndSettle();
    expect(opened, [_items[2]]);
    expect(find.byType(RoomSheet), findsNothing);
  });

  testWidgets('입구 띠 — 곳 수와 다가오는 첫 줄, 누르면 열기', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomStrip(items: _items, onTap: () => taps++),
        ),
      ),
    );
    expect(find.text(tf('tw_entry', {'n': '3'})), findsOneWidget);
    expect(find.text('🍚 여기 자리 있어요? · 3곳'), findsOneWidget);
    expect(find.text('수 20:00 · 망원 픽업'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('room_strip')));
    expect(taps, 1);
    // 4초마다 다음 줄
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('목 19:00 · 성미산 배구 · 🥄 초보 환영'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // 타이머 정리
  });
}
