// 🍚 식구 모집 시트 위젯 테스트 — 문구는 비워도 되고(링크·전화번호는 칸 아래 오류, 저장 안 함),
// 🥄 맛보기를 고르면 함께 저장하며, 수정할 땐 지난 값이 채워져 있다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/widgets/app_sheet.dart';
import 'package:nulloongzido/widgets/recruit_sheet.dart';

class _Call {
  final String msg;
  final bool dropIn;
  _Call(this.msg, this.dropIn);
}

Future<List<Object?>> _open(
  WidgetTester tester, {
  bool editing = false,
  String initialMsg = '',
  bool initialDropIn = false,
  String? saveError,
  List<_Call>? calls,
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
                  child: RecruitSheet(
                    editing: editing,
                    initialMsg: initialMsg,
                    initialDropIn: initialDropIn,
                    onSubmit: (msg, dropIn) async {
                      calls?.add(_Call(msg, dropIn));
                      return saveError;
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

  testWidgets('새로 켤 때 — 제목·안내·맛보기 칸, 버튼은 시작', (tester) async {
    await _open(tester);
    expect(find.text(t('rc_badge')), findsOneWidget);
    expect(find.text(t('rc_msg_label')), findsOneWidget);
    expect(find.text(t('rc_drop_in_ask')), findsOneWidget);
    expect(find.text(t('rc_auto_off')), findsOneWidget);
    expect(find.text(t('rc_on')), findsOneWidget);
    final box = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('rc_drop_in')),
    );
    expect(box.value, isFalse);
  });

  testWidgets('빈 문구로도 저장되고, 맛보기를 고르면 함께 넘긴다', (tester) async {
    final calls = <_Call>[];
    final results = await _open(tester, calls: calls);
    await tester.tap(find.text(t('rc_drop_in_ask')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rc_submit')));
    await tester.pumpAndSettle();
    expect(calls.single.msg, '');
    expect(calls.single.dropIn, isTrue);
    expect(results, [true]);
    expect(find.byType(RecruitSheet), findsNothing);
  });

  testWidgets('전화번호·링크는 칸 아래 오류, 저장을 눌러도 부르지 않는다', (tester) async {
    final calls = <_Call>[];
    await _open(tester, calls: calls);
    await tester.enterText(
      find.byKey(const ValueKey('rc_msg')),
      '문의 010-1234-5678',
    );
    await tester.pump();
    expect(find.text(t('ug_err_msg_phone')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rc_submit')));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('rc_msg')), 'www.team.kr');
    await tester.pump();
    expect(find.text(t('ug_err_msg_link')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rc_submit')));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  });

  testWidgets('문구는 앞뒤 공백을 지워 넘긴다', (tester) async {
    final calls = <_Call>[];
    await _open(tester, calls: calls);
    await tester.enterText(
      find.byKey(const ValueKey('rc_msg')),
      '  20~30대 여성 회원  ',
    );
    await tester.tap(find.byKey(const ValueKey('rc_submit')));
    await tester.pumpAndSettle();
    expect(calls.single.msg, '20~30대 여성 회원');
    expect(calls.single.dropIn, isFalse);
  });

  testWidgets('수정 — 제목·문구·맛보기가 채워져 있고 버튼은 저장하기', (tester) async {
    final calls = <_Call>[];
    await _open(
      tester,
      editing: true,
      initialMsg: '초보 환영',
      initialDropIn: true,
      calls: calls,
    );
    expect(find.text(t('rc_edit')), findsOneWidget);
    expect(find.text('초보 환영'), findsOneWidget);
    expect(find.text(t('rc_save')), findsOneWidget);
    // 맛보기 끄고 저장
    await tester.tap(find.byKey(const ValueKey('rc_drop_in')));
    await tester.tap(find.byKey(const ValueKey('rc_submit')));
    await tester.pumpAndSettle();
    expect(calls.single.msg, '초보 환영');
    expect(calls.single.dropIn, isFalse);
  });

  testWidgets('저장하지 못하면 그 문구를 보이고 시트는 열린 채', (tester) async {
    final results = await _open(tester, saveError: t('cd_update_error'));
    await tester.tap(find.byKey(const ValueKey('rc_submit')));
    await tester.pumpAndSettle();
    expect(find.text(t('cd_update_error')), findsOneWidget);
    expect(find.byType(RecruitSheet), findsOneWidget);
    expect(results, isEmpty);
  });
}
