// 데이터 신뢰도 줄 + 신고 다이얼로그.
// guidelines.html 이 '6개월 점검'과 '영업일 7일 내 확인'을 약속했는데 화면에 표시도
// 창구도 없으면 문서만 있는 약속이 된다. 그 둘이 실제로 뜨는지 고정한다.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/data_repository.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/theme.dart';
import 'package:nulloongzido/widgets/data_trust_row.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  group('isStaleData', () {
    final now = DateTime(2026, 9, 6);

    test('6개월 넘으면 오래된 것', () {
      expect(isStaleData(DateTime(2026, 1, 1), null, now: now), isTrue);
    });

    test('6개월 안이면 아니다', () {
      expect(isStaleData(DateTime(2026, 8, 1), null, now: now), isFalse);
    });

    test('확인일을 모르면 낙인찍지 않는다', () {
      expect(isStaleData(null, null, now: now), isFalse);
    });

    test('data_status 가 명시되면 날짜보다 우선한다', () {
      expect(isStaleData(now, 'needs_check', now: now), isTrue);
      expect(isStaleData(now, 'dormant', now: now), isTrue);
      expect(isStaleData(now, 'active', now: now), isFalse);
    });
  });

  testWidgets('오래된 항목은 ⚠️ 와 확인 필요가 함께 뜬다', (tester) async {
    await tester.pumpWidget(
      host(
        DataTrustRow(
          kind: 'club',
          targetId: 'c1',
          targetName: '강남배구',
          lastVerified: DateTime.now().subtract(const Duration(days: 730)),
        ),
      ),
    );
    expect(find.textContaining('⚠️'), findsOneWidget);
    expect(find.textContaining(t('dt_needs_check')), findsOneWidget);
  });

  testWidgets('최근 확인된 항목은 경고 없이 날짜만', (tester) async {
    await tester.pumpWidget(
      host(
        DataTrustRow(
          kind: 'pickup',
          targetId: 'p1',
          targetName: '잠실 크루',
          lastVerified: DateTime.now(),
        ),
      ),
    );
    expect(find.textContaining('⚠️'), findsNothing);
    expect(find.textContaining(t('dt_last_verified')), findsOneWidget);
  });

  testWidgets('신고: 사유 없이 보내면 막히고, 고르면 접수된다', (tester) async {
    final db = FakeFirebaseFirestore();
    final repo = DataRepository(db: db, auth: MockFirebaseAuth());

    await tester.pumpWidget(
      host(
        DataTrustRow(
          kind: 'club',
          targetId: 'c1',
          targetName: '강남배구',
          lastVerified: DateTime.now(),
          repo: repo,
        ),
      ),
    );

    await tester.tap(find.text(t('dt_report')));
    await tester.pumpAndSettle();
    // 대상 이름이 프리필돼야 신고자가 "어느 팀인지" 적을 필요가 없다
    expect(find.text('강남배구'), findsOneWidget);

    await tester.tap(find.text(t('rp_submit')));
    await tester.pumpAndSettle();
    expect(find.text(t('rp_need_reason')), findsOneWidget);
    expect((await db.collection('reports').get()).docs, isEmpty);

    await tester.tap(find.text(t('rp_wrong_info')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('rp_submit')));
    await tester.pumpAndSettle();

    final docs = (await db.collection('reports').get()).docs;
    expect(docs.length, 1);
    expect(docs.first.data()['reason'], 'wrong_info');
    expect(docs.first.data()['target_id'], 'c1');
  });
}
