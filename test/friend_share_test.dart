// 밥친구 2단계 — 식단표 공유 사본(웹 tests/friends-share.test.js 와 같은 규칙).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/friend_share_service.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/services/schedule_parse.dart';
import 'package:nulloongzido/widgets/friends_page.dart';

void main() {
  group('buildSharedLunchbox', () {
    final custom = {
      'custom_1': {'name': '동네 모임', 'schedule': '토 14:00~17:00'},
    };

    test('칸 순서를 지키고 빈칸·숨긴 팀을 뺀다', () {
      final s = buildSharedLunchbox(
        ['a', null, 'b', 'custom_1', 'c'],
        custom,
        ['b'],
        false,
      );
      expect(s.teams, ['a', 'c']);
      expect(s.custom.single.name, '동네 모임');
      expect(s.custom.single.schedule, '토 14:00~17:00');
      expect(s.hideAll, isFalse);
    });

    test('직접 추가한 팀은 id 없이 이름·일정만', () {
      final m = buildSharedLunchbox(['custom_1'], custom, [], false).toMap();
      expect(m['custom'], [
        {'name': '동네 모임', 'schedule': '토 14:00~17:00'},
      ]);
      expect(m['teams'], isEmpty);
      expect(m.containsKey('updated_at'), isFalse);
    });

    test('전부 숨기기면 팀을 하나도 담지 않는다', () {
      final s = buildSharedLunchbox(['a', 'custom_1'], custom, [], true);
      expect(s.teams, isEmpty);
      expect(s.custom, isEmpty);
      expect(s.hideAll, isTrue);
    });

    test('이름·일정 길이 자르기', () {
      final s = buildSharedLunchbox(
        ['x'],
        {
          'x': {'name': 'n' * 200, 'schedule': 's' * 900},
        },
        [],
        false,
      );
      expect(s.custom.single.name.length, 80);
      expect(s.custom.single.schedule.length, 600);
    });

    test('sameAs', () {
      final a = buildSharedLunchbox(['a'], {}, [], false);
      expect(a.sameAs(buildSharedLunchbox(['a'], {}, [], false)), isTrue);
      expect(a.sameAs(buildSharedLunchbox(['b'], {}, [], false)), isFalse);
      expect(a.sameAs(null), isFalse);
    });
  });

  group('FriendShareService', () {
    const me = 'me';
    const other = 'other';

    Future<FakeFirebaseFirestore> seed({
      Map<String, dynamic> extra = const {},
    }) async {
      final db = FakeFirebaseFirestore();
      await db.collection('clubs').doc('a').set({
        'name': 'A 배구',
        'schedule': '월 19:00~22:00',
      });
      await db.collection('clubs').doc('b').set({
        'name': 'B 배구',
        'schedule': '수 20:00~22:00',
      });
      await db
          .collection('users')
          .doc(me)
          .collection('private')
          .doc('profile')
          .set({
            'bookmarks': ['a', 'b', 'custom_1', null, null],
            'customTeams': {
              'custom_1': {'name': '동네', 'schedule': '토 14:00~17:00'},
            },
            ...extra,
          });
      return db;
    }

    DocumentReference<Map<String, dynamic>> shared(
      FirebaseFirestore db,
      String uid,
    ) => db.collection('users').doc(uid).collection('shared').doc('lunchbox');

    test('확인 전에는 사본을 쓰지 않는다', () async {
      final db = await seed();
      await FriendShareService(db: db).sync(me);
      expect((await shared(db, me).get()).exists, isFalse);
    });

    test('확인 후에는 숨긴 팀을 뺀 사본을 쓴다', () async {
      final db = await seed(
        extra: {
          'friend_share_ok': true,
          'friend_hidden': ['b'],
        },
      );
      await FriendShareService(db: db).sync(me);
      final d = (await shared(db, me).get()).data()!;
      expect(d['teams'], ['a']);
      expect((d['custom'] as List).single['name'], '동네');
      expect(d['hide_all'], isFalse);
      expect(d['updated_at'], isNotNull);
    });

    test('loadFriend: 없음 / 숨김 / 팀과 일정', () async {
      final db = await seed(extra: {'friend_share_ok': true});
      final svc = FriendShareService(db: db);
      expect((await svc.loadFriend(other)).status, 'none');

      await svc.sync(me);
      final lb = await svc.loadFriend(me);
      expect(lb.status, 'ok');
      expect(lb.teams.map((t) => t.name), ['A 배구', 'B 배구', '동네']);
      expect(lb.teams.last.isCustom, isTrue);
      expect(lb.teams.first.events.single.day, '월');

      await shared(db, other).set({
        'teams': ['a'],
        'custom': [],
        'hide_all': true,
      });
      expect((await svc.loadFriend(other)).status, 'hidden');
    });

    test('loadFriend: 지워진 팀은 건너뛴다', () async {
      final db = FakeFirebaseFirestore();
      await shared(db, other).set({
        'teams': ['gone'],
        'custom': [],
        'hide_all': false,
      });
      final lb = await FriendShareService(db: db).loadFriend(other);
      expect(lb.status, 'ok');
      expect(lb.teams, isEmpty);
    });

    test('myTeams: 숨긴 팀도 포함, 칸 번호 유지', () async {
      final db = await seed(
        extra: {
          'friend_hidden': ['a'],
        },
      );
      final mine = await FriendShareService(db: db).myTeams(me);
      expect(mine.map((x) => x.id), ['a', 'b', 'custom_1']);
      expect(mine.map((x) => x.team.slot), [0, 1, 2]);
    });
  });

  testWidgets('FriendTimetable: 친구 칸 이름 · 빈 식단표 안내', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: FriendTimetable(
              mine: const [
                FriendTeam('나의 팀', false, 0, [SchedEvent('월', 19, 21)]),
              ],
              theirs: const [
                FriendTeam('친구 팀', false, 0, [SchedEvent('수', 20, 22)]),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('친구 팀'), findsOneWidget);
    // 내 칸은 테두리만 — 이름을 쓰지 않는다
    expect(find.text('나의 팀'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FriendTimetable(mine: [], theirs: []),
        ),
      ),
    );
    expect(find.text(t('fr_tt_empty')), findsOneWidget);
  });
}
