// DataRepository Tier 2 테스트 — fake Firestore/Auth 주입(DI 시임).
// 감사에서 나온 "픽업 만료 필터"와 클럽 생성 페이로드/권한 로직을 회귀 고정.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/data_repository.dart';

void main() {
  group('loadPickups 만료 필터', () {
    test('만료 스팟은 숨기고 미래/상시(null)는 유지', () async {
      final db = FakeFirebaseFirestore();
      final now = DateTime.now();
      await db.collection('pickup_games').add({
        'title': '만료됨',
        'expire_at': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
      });
      await db.collection('pickup_games').add({
        'title': '유효',
        'expire_at': Timestamp.fromDate(now.add(const Duration(days: 1))),
      });
      await db.collection('pickup_games').add({'title': '상시'});

      final repo = DataRepository(db: db, auth: MockFirebaseAuth());
      final spots = await repo.loadPickups();
      expect(spots.map((s) => s.title).toSet(), {'유효', '상시'});
    });
  });

  group('createClub', () {
    test('로그인 시 12자 id 문서 생성 + 룰 필수 필드 세팅', () async {
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-1'),
      );
      final repo = DataRepository(db: db, auth: auth);

      final id = await repo.createClub({'name': '강남배구'});
      expect(id.length, 12);

      final doc = await db.collection('clubs').doc(id).get();
      final d = doc.data()!;
      expect(d['name'], '강남배구');
      expect(d['registered_by'], 'user-1'); // 룰: 본인
      expect(d['is_verified'], false); // 룰: 미인증 시작
      expect(d['id'], id);
      expect((d['metadata'] as Map)['submitted_by'], 'user-1');
    });

    test('비로그인이면 예외', () async {
      final repo = DataRepository(
        db: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(),
      );
      expect(() => repo.createClub({'name': 'x'}), throwsException);
    });
  });

  group('ensureUid', () {
    test('로그인 상태면 그 uid', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'signed-in'),
      );
      final repo = DataRepository(db: FakeFirebaseFirestore(), auth: auth);
      expect(await repo.ensureUid(), 'signed-in');
    });

    test('비로그인이면 익명 로그인으로 uid 확보', () async {
      final auth = MockFirebaseAuth();
      final repo = DataRepository(db: FakeFirebaseFirestore(), auth: auth);
      final uid = await repo.ensureUid();
      expect(uid, isNotEmpty);
      expect(auth.currentUser, isNotNull);
    });
  });

  group('isAdmin (uid별 캐시)', () {
    test('admins 문서 존재 여부 + 계정 전환 시 캐시 무효', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('admins').doc('admin-uid-A').set({'role': 'admin'});

      final adminAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'admin-uid-A'),
      );
      expect(await DataRepository(db: db, auth: adminAuth).isAdmin(), true);

      // 계정 전환: 이전 값(true)이 남으면 안 됨 — 캐시가 uid별로 갱신돼야 함
      final plainAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'plain-uid-B'),
      );
      expect(await DataRepository(db: db, auth: plainAuth).isAdmin(), false);
    });

    test('비로그인 → false', () async {
      final repo = DataRepository(
        db: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(),
      );
      expect(await repo.isAdmin(), false);
    });
  });

  group('updateClub / updatePickup merge 보존', () {
    test('updateClub은 기존 registered_by/is_verified 유지', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('clubs').doc('c1').set({
        'name': '기존',
        'registered_by': 'owner',
        'is_verified': true,
        'metadata': {'status': 'approved'},
      });
      final repo = DataRepository(db: db, auth: MockFirebaseAuth());
      await repo.updateClub('c1', {'name': '수정됨'});

      final d = (await db.collection('clubs').doc('c1').get()).data()!;
      expect(d['name'], '수정됨');
      expect(d['registered_by'], 'owner');
      expect(d['is_verified'], true);
    });
  });

  group('createReport (제3자 신고)', () {
    test('무로그인이면 익명 uid로 접수된다 — 신고에 로그인 벽이 없어야 한다', () async {
      final db = FakeFirebaseFirestore();
      final repo = DataRepository(db: db, auth: MockFirebaseAuth());

      await repo.createReport(
        kind: 'club',
        targetId: 'club-1',
        targetName: '강남배구',
        reason: 'wrong_info',
        detail: '연습 요일이 바뀌었어요',
      );

      final docs = await db.collection('reports').get();
      expect(docs.docs.length, 1);
      final d = docs.docs.first.data();
      expect(d['status'], 'open');
      expect(d['kind'], 'club');
      expect(d['target_id'], 'club-1');
      expect((d['reporter_uid'] as String).isNotEmpty, isTrue);
    });

    test('필드 집합이 firestore.rules 화이트리스트와 정확히 같다', () async {
      final db = FakeFirebaseFirestore();
      final repo = DataRepository(db: db, auth: MockFirebaseAuth());
      await repo.createReport(
        kind: 'pickup',
        targetId: 'pk-1',
        targetName: '잠실 크루',
        reason: 'closed',
      );
      final d = (await db.collection('reports').get()).docs.first.data();
      // 하나라도 더 붙으면 규칙의 keys().hasOnly() 에서 거부된다.
      expect(d.keys.toSet(), {
        'kind',
        'target_id',
        'target_name',
        'reason',
        'detail',
        'reporter_uid',
        'status',
        'created_at',
      });
    });

    test('길이 제한을 클라이언트에서 먼저 자른다 (규칙 거부 전에)', () async {
      final db = FakeFirebaseFirestore();
      final repo = DataRepository(db: db, auth: MockFirebaseAuth());
      await repo.createReport(
        kind: 'club',
        targetId: 'club-1',
        targetName: '가' * 200,
        reason: 'other',
        detail: '나' * 900,
      );
      final d = (await db.collection('reports').get()).docs.first.data();
      expect((d['target_name'] as String).length, 120);
      expect((d['detail'] as String).length, 500);
    });
  });

  group('데이터 신뢰도 필드 (guidelines.html 2-3)', () {
    test('createClub 이 last_verified_at + data_status=active 를 남긴다', () async {
      final db = FakeFirebaseFirestore();
      final repo = DataRepository(
        db: db,
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
      );
      final id = await repo.createClub({'name': '강남배구'});
      final d = (await db.collection('clubs').doc(id).get()).data()!;
      expect(d['data_status'], 'active');
      expect(d.containsKey('last_verified_at'), isTrue);
    });

    test('updateClub 도 확인일을 갱신한다 — 소유자 저장 = 지금도 맞다는 확인', () async {
      final db = FakeFirebaseFirestore();
      final repo = DataRepository(
        db: db,
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
      );
      await db.collection('clubs').doc('c1').set({'name': '옛팀'});
      await repo.updateClub('c1', {'name': '새이름'});
      final d = (await db.collection('clubs').doc('c1').get()).data()!;
      expect(d.containsKey('last_verified_at'), isTrue);
    });
  });
}
