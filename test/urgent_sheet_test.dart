// 급구 올리기 시트 위젯 테스트 — 팀 일정에서 회차 칩이 나오고,
// 문구가 틀리면 칸 아래에 무엇이 틀렸는지 보이며 서버를 부르지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/services/schedule_parse.dart';
import 'package:nulloongzido/widgets/app_sheet.dart';
import 'package:nulloongzido/widgets/urgent_sheet.dart';

// 2026-10-09 금요일 20:00
DateTime _now() => DateTime(2026, 10, 9, 20);

class _Call {
  final DateTime until;
  final String msg;
  _Call(this.until, this.msg);
}

Future<List<Object?>> _open(
  WidgetTester tester, {
  List<SchedEvent> events = const [],
  String? serverError,
  List<_Call>? calls,
  String? initialMsg,
  DateTime? initialUntil,
  bool editing = false,
}) async {
  final results = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              results.add(
                await showAppSheet<bool>(
                  context,
                  child: UrgentSheet(
                    events: events,
                    clock: _now,
                    editing: editing,
                    initialMsg: initialMsg,
                    initialUntil: initialUntil,
                    onSubmit: (until, msg) async {
                      calls?.add(_Call(until, msg));
                      return serverError;
                    },
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  setUp(() => appLang.value = 'ko');

  testWidgets('일정에서 회차 칩 + 다른 날, 첫 회차가 골라져 있다', (tester) async {
    await _open(
      tester,
      events: const [SchedEvent('토', 10, 12), SchedEvent('월', 19, 22)],
    );
    expect(find.text(t('ug_when')), findsOneWidget);
    expect(find.text('토 10/10 10:00~12:00'), findsOneWidget);
    expect(find.text('월 10/12 19:00~22:00'), findsOneWidget);
    expect(find.text(t('ug_other_day')), findsOneWidget);
    expect(find.text(t('ug_auto_off')), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('ug_session_0')),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('일정이 없으면 다른 날만, 고르기 전엔 올리기 못 누름', (tester) async {
    await _open(tester);
    expect(find.byType(ChoiceChip), findsOneWidget);
    expect(find.text(t('ug_other_day')), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('ug_submit')),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('전화번호·링크가 든 문구는 바로 오류, 올리기를 눌러도 서버를 안 부른다', (tester) async {
    final calls = <_Call>[];
    await _open(tester, events: const [SchedEvent('토', 10, 12)], calls: calls);
    await tester.enterText(
      find.byKey(const ValueKey('ug_msg')),
      '연락 010-1234-5678',
    );
    await tester.pump();
    expect(find.text(t('ug_err_msg_phone')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ug_submit')));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('ug_msg')),
      'open.kakao.com/o/xx',
    );
    await tester.pump();
    expect(find.text(t('ug_err_msg_link')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ug_submit')));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  });

  testWidgets('빈 문구는 올리기를 누른 뒤에 안내', (tester) async {
    final calls = <_Call>[];
    await _open(tester, events: const [SchedEvent('토', 10, 12)], calls: calls);
    expect(find.text(t('ug_err_msg_empty')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ug_submit')));
    await tester.pumpAndSettle();
    expect(find.text(t('ug_err_msg_empty')), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('맞는 문구면 고른 회차의 끝나는 시각으로 올리고 닫힌다', (tester) async {
    final calls = <_Call>[];
    final results = await _open(
      tester,
      events: const [SchedEvent('토', 10, 12), SchedEvent('월', 19, 22)],
      calls: calls,
    );
    await tester.tap(find.text('월 10/12 19:00~22:00'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('ug_msg')),
      '  센터 1명 19시  ',
    );
    await tester.pump();
    expect(find.text(t('ug_err_msg_phone')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ug_submit')));
    await tester.pumpAndSettle();
    expect(calls.single.until, DateTime(2026, 10, 12, 22));
    expect(calls.single.msg, '센터 1명 19시');
    expect(results, [true]);
    expect(find.byType(UrgentSheet), findsNothing);
  });

  testWidgets('서버가 거절하면 그 문구를 보이고 시트는 열린 채', (tester) async {
    final results = await _open(
      tester,
      events: const [SchedEvent('토', 10, 12)],
      serverError: t('ug_err_blocked'),
    );
    await tester.enterText(find.byKey(const ValueKey('ug_msg')), '세터 1명');
    await tester.tap(find.byKey(const ValueKey('ug_submit')));
    await tester.pumpAndSettle();
    expect(find.text(t('ug_err_blocked')), findsOneWidget);
    expect(find.byType(UrgentSheet), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('수정 — 제목·문구·회차가 채워져 있다', (tester) async {
    await _open(
      tester,
      events: const [SchedEvent('토', 10, 12), SchedEvent('월', 19, 22)],
      editing: true,
      initialMsg: '리베로 1명',
      initialUntil: DateTime(2026, 10, 12, 22),
    );
    expect(find.text(t('ug_edit')), findsOneWidget);
    expect(find.text('리베로 1명'), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('ug_session_1')),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('수정 — 일정에 없는 마감은 다른 날 칩에 날짜·시각으로', (tester) async {
    await _open(
      tester,
      events: const [SchedEvent('토', 10, 12)],
      editing: true,
      initialMsg: '세터',
      initialUntil: DateTime(2026, 10, 11, 21),
    );
    expect(find.text('${t('ug_other_day')} · 일 10/11 21:00'), findsOneWidget);
  });
}
