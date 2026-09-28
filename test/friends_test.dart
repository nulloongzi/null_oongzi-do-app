// 밥친구 1단계 테스트 — 순수 규칙(웹 tests/friends.test.js 와 같은 불변식) +
// FriendsService(fake Firestore) + 딥링크 + 둘째 장 렌더.
// 보안 규칙 자체는 웹 레포 tests/firestore-rules.test.js(에뮬레이터)가 검증한다.
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nulloongzido/services/deep_link_service.dart';
import 'package:nulloongzido/services/friend_share_service.dart';
import 'package:nulloongzido/services/friends_service.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/services/schedule_parse.dart';
import 'package:nulloongzido/widgets/friends_page.dart';

/// firestore.rules invite_codes 의 정규식과 같은 식.
final ruleRe = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');

void main() {
  group('초대코드 규칙', () {
    test('알파벳 32자, 0·O·1·I 없음 — 웹과 같은 문자열', () {
      expect(kInviteAlphabet, 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789');
      for (final ch in ['0', 'O', '1', 'I']) {
        expect(kInviteAlphabet.contains(ch), isFalse, reason: ch);
      }
    });

    test('만든 코드는 항상 룰 정규식을 통과한다', () {
      final r = Random(42);
      for (var i = 0; i < 500; i++) {
        expect(ruleRe.hasMatch(makeInviteCode(r)), isTrue);
      }
    });

    test('사람이 친 코드 정규화', () {
      expect(normalizeInviteCode(' nrj-7k2 '), 'NRJ7K2');
      expect(normalizeInviteCode('NRJ 7K2'), 'NRJ7K2');
      expect(normalizeInviteCode('NRJ7K0'), ''); // 0 은 알파벳에 없다
      expect(normalizeInviteCode('NRJ7K'), '');
      expect(normalizeInviteCode(null), '');
    });

    test('쌍 id 는 순서와 상관없다', () {
      expect(friendPairId('b', 'a'), 'a_b');
      expect(friendPairId('a', 'b'), 'a_b');
    });
  });

  group('신청 만료 · 분류', () {
    final now = DateTime.utc(2026, 9, 28);
    Timestamp ago(int days) =>
        Timestamp.fromDate(now.subtract(Duration(days: days)));

    test('7일 넘은 신청만 만료, 서버 시각이 없는 막 만든 신청은 아님', () {
      expect(
        isRequestExpired({'status': 'pending', 'created_at': ago(8)}, now),
        isTrue,
      );
      expect(
        isRequestExpired({'status': 'pending', 'created_at': ago(6)}, now),
        isFalse,
      );
      expect(isRequestExpired({'status': 'pending'}, now), isFalse);
      expect(
        isRequestExpired({'status': 'accepted', 'created_at': ago(99)}, now),
        isFalse,
      );
    });

    test('친구 / 받은 신청 / 보낸 신청, 만료는 뺀다', () {
      final r = partitionFriendships(
        [
          (
            id: 'a_me',
            data: {
              'members': ['a', 'me'],
              'status': 'accepted',
            },
          ),
          (
            id: 'b_me',
            data: {
              'members': ['b', 'me'],
              'status': 'pending',
              'requested_by': 'b',
              'requested_to': 'me',
              'created_at': ago(1),
            },
          ),
          (
            id: 'c_me',
            data: {
              'members': ['c', 'me'],
              'status': 'pending',
              'requested_by': 'me',
              'requested_to': 'c',
              'created_at': ago(0),
            },
          ),
          (
            id: 'd_me',
            data: {
              'members': ['d', 'me'],
              'status': 'pending',
              'requested_by': 'd',
              'requested_to': 'me',
              'created_at': ago(30),
            },
          ),
          (id: 'bad', data: {'members': 'not-a-list'}),
        ],
        'me',
        now,
      );
      expect(r.friends.map((l) => l.other), ['a']);
      expect(r.incoming.map((l) => l.other), ['b']);
      expect(r.outgoing.map((l) => l.other), ['c']);
    });
  });

  group('FriendsService (fake Firestore)', () {
    late FakeFirebaseFirestore db;
    late FriendsService svc;
    setUp(() async {
      db = FakeFirebaseFirestore();
      svc = FriendsService(db: db);
      await db.collection('users').doc('b').set({
        'full_nickname': '보리밥-k2',
        'nickname': '보리밥',
        'color': '#FFF59D',
      });
      await db.collection('invite_codes').doc('BBBB22').set({'uid': 'b'});
    });

    test('내 코드: 처음엔 만들어 저장하고, 다음엔 같은 코드', () async {
      final c1 = await svc.ensureMyCode('me');
      expect(ruleRe.hasMatch(c1), isTrue);
      expect(
        (await db.collection('invite_codes').doc(c1).get()).data()!['uid'],
        'me',
      );
      expect(await svc.ensureMyCode('me'), c1);
    });

    test('새 코드 받기: 옛 코드는 지워져 바로 무효', () async {
      final old = await svc.ensureMyCode('me');
      final neu = await svc.regenerate('me', old);
      expect(neu, isNot(old));
      expect(
        (await db.collection('invite_codes').doc(old).get()).exists,
        isFalse,
      );
      expect(await svc.ensureMyCode('me'), neu);
    });

    test('코드 조회 결과: 형식 밖 / 없음 / 내 코드 / 신청 가능', () async {
      const st = FriendState(uid: 'me', loaded: true);
      expect((await svc.lookup('abc', st)).status, 'invalid');
      expect((await svc.lookup('ZZZZ99', st)).status, 'not_found');
      await db.collection('invite_codes').doc('MEME22').set({'uid': 'me'});
      expect((await svc.lookup('meme22', st)).status, 'self');
      final r = await svc.lookup('bbbb-22', st);
      expect(r.status, 'ok');
      expect(r.uid, 'b');
      expect(r.profile!.name, '보리밥-k2');
    });

    test('신청 → 받은 쪽 수락 → 끊기', () async {
      expect(await svc.sendRequest('me', 'BBBB22', 'b'), 'sent');
      final ref = db.collection('friendships').doc(friendPairId('me', 'b'));
      final d = (await ref.get()).data()!;
      expect(d['status'], 'pending');
      expect(d['members'], ['b', 'me']);
      expect(d['requested_to'], 'b');
      expect(d['code'], 'BBBB22');
      // 같은 사람에게 다시 신청해도 문서는 하나
      expect(await svc.sendRequest('me', 'BBBB22', 'b'), 'sent');
      await svc.accept(ref.id);
      expect((await ref.get()).data()!['status'], 'accepted');
      expect(await svc.sendRequest('me', 'BBBB22', 'b'), 'friend');
      await svc.remove(ref.id, 'unfriend');
      expect((await ref.get()).exists, isFalse);
    });

    test('상대가 먼저 신청해 뒀으면 내 신청이 곧 수락', () async {
      final id = friendPairId('me', 'b');
      await db.collection('friendships').doc(id).set({
        'members': ['b', 'me'],
        'requested_by': 'b',
        'requested_to': 'me',
        'status': 'pending',
        'code': 'MEME22',
        'created_at': Timestamp.now(),
      });
      expect(await svc.sendRequest('me', 'BBBB22', 'b'), 'accepted');
      expect(
        (await db.collection('friendships').doc(id).get()).data()!['status'],
        'accepted',
      );
    });
  });

  group('딥링크', () {
    test('?invite= 는 형식이 맞는 코드만 받는다', () {
      final d = parseDeepLink(
        Uri.parse('https://do.nulloongzi.com/?invite=nrj7k2'),
      );
      expect(d?.kind, 'invite');
      expect(d?.id, 'NRJ7K2');
      expect(
        parseDeepLink(Uri.parse('https://do.nulloongzi.com/?invite=bad')),
        isNull,
      );
    });
    test('club 이 있으면 club 이 먼저', () {
      expect(
        parseDeepLink(Uri.parse('https://x/?club=abc&invite=NRJ7K2'))?.kind,
        'club',
      );
    });
  });

  group('둘째 장 렌더', () {
    Widget wrap(Widget w) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: w)),
    );

    testWidgets('받은 신청과 친구가 보이고, 비었으면 안내', (tester) async {
      appLang.value = 'ko';
      final hub = FriendsHub.instance;
      hub.shareSvc = FriendShareService(db: FakeFirebaseFirestore());
      hub.state.value = FriendState(
        uid: 'me',
        loaded: true,
        incoming: const [
          FriendLink('b_me', 'b', {'status': 'pending'}),
        ],
        friends: const [
          FriendLink('c_me', 'c', {'status': 'accepted'}),
        ],
        profiles: const {
          'b': FriendProfile('흑미밥-z9', '#FFF176'),
          'c': FriendProfile('팥밥-q7', '#F8BBD0'),
        },
      );
      await tester.pumpWidget(wrap(const FriendsPage()));
      expect(find.text('흑미밥-z9'), findsOneWidget);
      expect(find.text('수락'), findsOneWidget);
      expect(find.text('팥밥-q7'), findsOneWidget);
      expect(find.text('밥친구 1'), findsOneWidget);
      // 첫 밥친구 — '보일 팀' 확인 카드가 먼저, 공개 스위치는 확인 뒤에도 목록 끝에
      expect(find.text(t('fr_share_title')), findsOneWidget);
      expect(find.text(t('fr_vis_title')), findsOneWidget);

      hub.share.value = const FriendShareSettings(shareOk: true);
      await tester.pump();
      expect(find.text(t('fr_share_title')), findsNothing);
      hub.share.value = FriendShareSettings.empty;

      hub.state.value = const FriendState(uid: 'me', loaded: true);
      await tester.pump();
      expect(find.text(t('fr_empty_title')), findsOneWidget);
      hub.state.value = FriendState.empty;
    });

    testWidgets('합석 줄 · 합석 많은 순 · 익힘 문구', (tester) async {
      appLang.value = 'ko';
      final hub = FriendsHub.instance;
      hub.shareSvc = FriendShareService(db: FakeFirebaseFirestore());
      hub.share.value = const FriendShareSettings(shareOk: true);
      const ev = [SchedEvent('토', 19, 22), SchedEvent('화', 20, 22)];
      hub.myMeal.value = const [FriendTeam('A', false, 0, ev, id: 'a')];
      hub.friendLunchboxes.value = {
        'c': const FriendLunchbox('ok', [
          FriendTeam('A', false, 0, ev, id: 'a'),
        ], null),
        'd': const FriendLunchbox('ok', [
          FriendTeam('B', false, 0, ev, id: 'b'),
        ], null),
      };
      hub.state.value = FriendState(
        uid: 'me',
        loaded: true,
        friends: const [
          FriendLink('a_me', 'd', {'status': 'accepted'}),
          FriendLink('c_me', 'c', {'status': 'accepted'}),
        ],
        profiles: const {
          'c': FriendProfile('팥밥-q7', '#F8BBD0'),
          'd': FriendProfile('가밥-z9', '#FFF176'),
        },
      );
      expect(hub.mealOf('c').n, 2);
      expect(hub.mealOf('d').n, 0);
      await tester.pumpWidget(wrap(const FriendsPage()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(t('fr_meal_title')), findsOneWidget);
      final tag = tf('fr_meal_tier', {'tier': t('fr_warm_2'), 'n': '2'});
      expect(find.text(tag), findsNWidgets(2)); // 합석 줄 + 목록 줄
      // 이름순이면 가밥이 먼저지만, 합석 많은 팥밥이 목록 맨 위
      final y1 = tester.getTopLeft(find.text('팥밥-q7').last).dy;
      final y2 = tester.getTopLeft(find.text('가밥-z9')).dy;
      expect(y1, lessThan(y2));

      hub.state.value = FriendState.empty;
      hub.friendLunchboxes.value = {};
      hub.myMeal.value = const [];
      hub.share.value = FriendShareSettings.empty;
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('하루 신청 상한', () {
    test('30건 — 구상안과 같은 숫자', () => expect(kMaxRequestsPerDay, 30));
    test('같은 날이면 세고, 날이 바뀌면 0 부터', () {
      final day = DateTime(2026, 9, 28, 23, 50);
      final raw = '{"d":"${requestDayKey(day)}","n":7}';
      expect(countRequestsToday(raw, day), 7);
      expect(countRequestsToday(raw, day.add(const Duration(minutes: 20))), 0);
      expect(countRequestsToday(null, day), 0);
      expect(countRequestsToday('{broken', day), 0);
    });
  });

  testWidgets('친구 상세: 겹쳐 보기 아래 합석 목록을 글로', (tester) async {
    SharedPreferences.setMockInitialValues({}); // '마지막으로 본 시각' 저장이 플러그인 없이도 끝나게
    appLang.value = 'ko';
    final hub = FriendsHub.instance;
    final db = FakeFirebaseFirestore();
    await db.collection('clubs').doc('a').set({
      'name': '잠실 배구회',
      'schedule': '토 19:00~22:00',
    });
    await db
        .collection('users')
        .doc('c')
        .collection('shared')
        .doc('lunchbox')
        .set({
          'teams': ['a'],
          'custom': [],
          'hide_all': false,
          'updated_at': Timestamp.fromDate(DateTime(2026, 9, 1)),
        });
    hub.shareSvc = FriendShareService(db: db);
    hub.share.value = const FriendShareSettings(shareOk: true);
    hub.myMeal.value = const [
      FriendTeam('잠실 배구회', false, 0, [SchedEvent('토', 19, 22)], id: 'a'),
    ];
    hub.state.value = FriendState(
      uid: 'me',
      loaded: true,
      friends: const [
        FriendLink('c_me', 'c', {'status': 'accepted'}),
      ],
      profiles: const {'c': FriendProfile('팥밥-q7', '#F8BBD0')},
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: FriendsPage())),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('팥밥-q7'));
    // 친구 도시락 로드(fake Firestore) → 합석 계산 → 목록. 익힘 애니메이션이 돌아 pumpAndSettle 은 쓰지 않는다.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('토 19–22'), findsOneWidget);
    expect(find.text(t('fr_meal_zero')), findsNothing);

    hub.state.value = FriendState.empty;
    hub.friendLunchboxes.value = {};
    hub.myMeal.value = const [];
    hub.share.value = FriendShareSettings.empty;
    await tester.pumpWidget(const SizedBox());
  });

  group('FriendsHub 초대코드', () {
    test('겹쳐 불러도 코드는 하나만 발급된다', () async {
      final db = FakeFirebaseFirestore();
      final hub = FriendsHub.instance;
      hub.svc = FriendsService(db: db);
      hub.myCode = null;
      hub.state.value = const FriendState(uid: 'me', loaded: true);
      final codes = await Future.wait([
        hub.ensureMyCode(),
        hub.ensureMyCode(),
        hub.ensureMyCode(),
      ]);
      expect(codes.toSet().length, 1);
      expect((await db.collection('invite_codes').get()).docs.length, 1);
      expect(await hub.ensureMyCode(), codes.first);
      hub.myCode = null;
      hub.state.value = FriendState.empty;
    });

    test('화면이 옛 코드를 몰라도 새 코드 받기가 서버의 옛 코드를 지운다', () async {
      final db = FakeFirebaseFirestore();
      final svc = FriendsService(db: db);
      final old = await svc.ensureMyCode('me');
      final fresh = await svc.regenerate('me', null);
      expect(fresh, isNot(old));
      expect(
        (await db.collection('invite_codes').doc(old).get()).exists,
        isFalse,
      );
      expect(
        (await db.collection('invite_codes').doc(fresh).get()).exists,
        isTrue,
      );
    });
  });

  test('합석 알림은 처음 한 번만 — 본 뒤에는 같은 친구로 다시 뜨지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    final hub = FriendsHub.instance;
    hub.shareSvc = FriendShareService(db: FakeFirebaseFirestore());
    const ev = [SchedEvent('토', 19, 22), SchedEvent('화', 20, 22)];
    hub.myMeal.value = const [FriendTeam('A', false, 0, ev, id: 'a')];
    hub.friendLunchboxes.value = {
      'c': const FriendLunchbox('ok', [
        FriendTeam('A', false, 0, ev, id: 'a'),
      ], null),
    };
    hub.state.value = FriendState(
      uid: 'me-meal',
      loaded: true,
      friends: const [
        FriendLink('c_me', 'c', {'status': 'accepted'}),
      ],
      profiles: const {'c': FriendProfile('팥밥-q7', '#F8BBD0')},
    );
    expect(hub.unseenMealTier, 2); // 처음 합석 → 알림
    await hub.markSeen(); // 밥친구 장을 봤다
    expect(hub.unseenMealTier, 0);
    expect(hub.warmth.value, 0);
    // 새 친구가 합석하게 되면 그 친구로 다시 한 번
    hub.friendLunchboxes.value = {
      'c': const FriendLunchbox('ok', [
        FriendTeam('A', false, 0, ev, id: 'a'),
      ], null),
      'd': const FriendLunchbox('ok', [
        FriendTeam('A', false, 0, ev, id: 'a'),
      ], null),
    };
    hub.state.value = FriendState(
      uid: 'me-meal',
      loaded: true,
      friends: const [
        FriendLink('c_me', 'c', {'status': 'accepted'}),
        FriendLink('d_me', 'd', {'status': 'accepted'}),
      ],
      profiles: const {},
    );
    expect(hub.unseenMealTier, 2);

    hub.state.value = FriendState.empty;
    hub.friendLunchboxes.value = {};
    hub.myMeal.value = const [];
  });
}
