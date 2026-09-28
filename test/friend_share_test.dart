// 밥친구 2단계 — 식단표 공유 사본(웹 tests/friends-share.test.js 와 같은 규칙).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/friend_share_service.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/services/schedule_parse.dart';
import 'package:nulloongzido/widgets/friends_page.dart';
import 'package:nulloongzido/widgets/warm_avatar.dart';

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

  group('합석 (3단계)', () {
    FriendTeam team(String? id, List<SchedEvent> ev) =>
        FriendTeam(id ?? '직접', id == null, 0, ev, id: id);

    test('같은 팀 · 같은 요일 · 30분 이상 겹치면 합석', () {
      final ov = mealOverlaps(
        [
          team('a', const [SchedEvent('월', 19, 22), SchedEvent('수', 20, 22)]),
        ],
        [
          team('a', const [
            SchedEvent('월', 19, 22),
            SchedEvent('수', 21.75, 23),
          ]),
        ],
      );
      expect(ov.length, 1); // 수요일은 15분만 겹쳐 빠진다
      expect(
        (ov.single.day, ov.single.start, ov.single.end),
        ('월', 19.0, 22.0),
      );
    });

    test('다른 팀 · 직접 추가한 팀은 세지 않는다', () {
      const ev = [SchedEvent('월', 19, 22)];
      expect(mealOverlaps([team('a', ev)], [team('b', ev)]), isEmpty);
      expect(mealOverlaps([team(null, ev)], [team(null, ev)]), isEmpty);
    });

    test('겹치는 시간만 잘라 한 번씩 센다', () {
      final ov = mealOverlaps(
        [
          team('a', const [SchedEvent('토', 14, 17)]),
          team('a', const [SchedEvent('토', 14, 17)]),
        ],
        [
          team('a', const [SchedEvent('토', 15, 18)]),
        ],
      );
      expect(ov.length, 1);
      expect((ov.single.start, ov.single.end), (15.0, 17.0));
    });

    test('합석 단계는 같이 다니는 팀 수: 1 한 숟갈 · 2 한 그릇 · 3팀 이상 한솥밥', () {
      expect([0, 1, 2, 3, 4, 9].map(warmthTier), [0, 1, 2, 3, 3, 3]);
    });

    test('myMealTeams: 공개한 동호회 팀만, 확인 전·전부 숨기기면 없음', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('clubs').doc('a').set({
        'name': 'A',
        'schedule': '월 19:00~22:00',
      });
      await db.collection('clubs').doc('b').set({
        'name': 'B',
        'schedule': '수 20:00~22:00',
      });
      await db
          .collection('users')
          .doc('me')
          .collection('private')
          .doc('profile')
          .set({
            'bookmarks': ['a', 'b', 'custom_1', null, null],
            'customTeams': {
              'custom_1': {'name': '동네', 'schedule': '토 14:00~17:00'},
            },
          });
      final svc = FriendShareService(db: db);
      expect(await svc.myMealTeams('me', FriendShareSettings.empty), isEmpty);
      expect(
        await svc.myMealTeams(
          'me',
          const FriendShareSettings(shareOk: true, hideAll: true),
        ),
        isEmpty,
      );
      final mine = await svc.myMealTeams(
        'me',
        const FriendShareSettings(shareOk: true, hidden: ['b']),
      );
      expect(mine.map((t) => t.id), ['a']);
    });
  });

  testWidgets('FriendTimetable: 합석 칸과 범례', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: FriendTimetable(
              mine: [
                FriendTeam('A', false, 0, [SchedEvent('월', 19, 22)], id: 'a'),
              ],
              theirs: [
                FriendTeam('A', false, 0, [SchedEvent('월', 19, 22)], id: 'a'),
              ],
              meals: [MealOverlap('a', '월', 19, 22)],
            ),
          ),
        ),
      ),
    );
    expect(find.text(t('fr_tt_meal')), findsWidgets);
    expect(find.text(t('fr_tt_meal_legend')), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('WarmAvatar: 효과 없이 단계 색 테두리만', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            WarmAvatar(
              size: 48,
              tier: 3,
              big: true,
              child: SizedBox.square(dimension: 48),
            ),
            WarmAvatar(
              size: 38,
              tier: 2,
              child: SizedBox.square(dimension: 38),
            ),
            WarmAvatar(
              size: 38,
              tier: 0,
              child: SizedBox.square(dimension: 38),
            ),
          ],
        ),
      ),
    );
    expect(tester.hasRunningAnimations, isFalse);
    final boxes = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((b) => b.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.shape == BoxShape.circle)
        .toList();
    expect(boxes, hasLength(2)); // 0 단계는 테두리 없음
    expect((boxes[0].border! as Border).top.color, warmRing[3]);
    expect((boxes[0].border! as Border).top.width, 3);
    expect((boxes[1].border! as Border).top.color, warmRing[2]);
    expect(
      boxes.every((d) => d.boxShadow == null && d.gradient == null),
      isTrue,
    );
  });

  group('포장하기 밥친구 · 합석 목록 (4단계)', () {
    test('pickCardFriends: 합석 있는 친구만, 전부 숨긴 친구 제외, 합석 많은 순 최대 4', () {
      CardFriendEntry e(String name, int n, {bool hidden = false}) =>
          CardFriendEntry(
            name: name,
            color: '#fff',
            tier: warmthTier(n),
            n: n,
            hidden: hidden,
          );
      final out = pickCardFriends([
        e('가', 1),
        e('나', 0),
        e('다', 3),
        e('라', 2, hidden: true),
        e('마', 2),
        e('바', 1),
        e('사', 1),
      ]);
      expect(out.map((f) => f.name), ['다', '마', '가', '바']);
      expect(pickCardFriends(const []), isEmpty);
    });

    test('sortOverlaps: 요일 → 시작 시각', () {
      final out = sortOverlaps(const [
        MealOverlap('a', '토', 19, 22),
        MealOverlap('a', '월', 20, 22),
        MealOverlap('a', '월', 19, 21),
      ]);
      expect(out.map((o) => '${o.day}${o.start.toInt()}'), [
        '월19',
        '월20',
        '토19',
      ]);
    });

    test('fmtHourRange: 정시는 시만, 아니면 분까지', () {
      expect(fmtHourRange(19, 22), '19–22');
      expect(fmtHourRange(19.5, 22), '19:30–22');
      expect(fmtHourRange(9.25, 10.75), '9:15–10:45');
    });
  });

  testWidgets('FriendTimetable: 23시 이후 일정도 그려진다 (clamp 회귀)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: FriendTimetable(
              mine: [
                FriendTeam('나', false, 0, [SchedEvent('금', 23, 24)], id: 'a'),
              ],
              theirs: [
                FriendTeam('밤', false, 0, [SchedEvent('금', 23.5, 24)], id: 'a'),
              ],
              meals: [MealOverlap('a', '금', 23.5, 24)],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('밤'), findsOneWidget);
  });

  group('합석 단계는 팀 수로 센다', () {
    test('주 3회 하는 팀 하나는 팀 하나 — 한 숟갈', () {
      const m = FriendMeal([
        MealOverlap('a', '월', 19, 22),
        MealOverlap('a', '수', 19, 22),
        MealOverlap('a', '금', 19, 22),
      ]);
      expect(m.n, 3);
      expect(m.teams, 1);
      expect(m.tier, 1);
    });
    test('팀 두 개는 한 그릇, 세 개면 한솥밥', () {
      expect(
        const FriendMeal([
          MealOverlap('a', '월', 19, 21),
          MealOverlap('b', '수', 19, 21),
        ]).tier,
        2,
      );
      expect(
        const FriendMeal([
          MealOverlap('a', '월', 19, 21),
          MealOverlap('b', '수', 19, 21),
          MealOverlap('c', '금', 19, 21),
        ]).tier,
        3,
      );
    });
  });
}
