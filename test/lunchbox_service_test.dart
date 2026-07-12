// LunchboxService Tier 2 테스트 — fake Firestore 주입(DI 시임).
// 트랜잭션 기반 read-modify-write(5칸 슬롯·커스텀 팀)의 정합성 회귀 고정.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/lunchbox_service.dart';

void main() {
  const uid = 'user-1';

  group('load 스키마 하드닝', () {
    test('문서 없음 → 빈 5칸 + 빈 커스텀', () async {
      final svc = LunchboxService(db: FakeFirebaseFirestore());
      final data = await svc.load(uid);
      expect(data.bookmarks, List<String?>.filled(5, null));
      expect(data.customTeams, isEmpty);
    });

    test('비문자열 슬롯/비맵 customTeams → 안전 폴백', () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('profile')
          .set({
            'bookmarks': ['team-a', 123, null, true, 'team-b', 'overflow-6th'],
            'customTeams': 'not-a-map',
          });
      final data = await LunchboxService(db: db).load(uid);
      expect(data.bookmarks, ['team-a', null, null, null, 'team-b']);
      expect(data.customTeams, isEmpty);
    });
  });

  group('addBookmark', () {
    test('첫 빈 슬롯에 추가', () async {
      final db = FakeFirebaseFirestore();
      final svc = LunchboxService(db: db);
      expect(await svc.addBookmark(uid, 'team-a'), isNull);
      final data = await svc.load(uid);
      expect(data.bookmarks.first, 'team-a');
    });

    test('중복 찜 → 에러 메시지, 쓰기 없음', () async {
      final db = FakeFirebaseFirestore();
      final svc = LunchboxService(db: db);
      await svc.addBookmark(uid, 'team-a');
      final err = await svc.addBookmark(uid, 'team-a');
      expect(err, isNotNull);
      final data = await svc.load(uid);
      expect(data.bookmarks.where((e) => e == 'team-a').length, 1);
    });

    test('5칸 가득 → 에러 메시지', () async {
      final db = FakeFirebaseFirestore();
      final svc = LunchboxService(db: db);
      for (var i = 0; i < 5; i++) {
        expect(await svc.addBookmark(uid, 'team-$i'), isNull);
      }
      expect(await svc.addBookmark(uid, 'team-6'), isNotNull);
    });
  });

  group('removeBookmark', () {
    test('제거 후 해당 칸 비움(순서 유지)', () async {
      final db = FakeFirebaseFirestore();
      final svc = LunchboxService(db: db);
      await svc.addBookmark(uid, 'team-a');
      await svc.addBookmark(uid, 'team-b');
      expect(await svc.removeBookmark(uid, 'team-a'), isNull);
      final data = await svc.load(uid);
      expect(data.bookmarks[0], isNull);
      expect(data.bookmarks[1], 'team-b');
    });

    test('없는 팀 제거 → 에러 없이 무시', () async {
      final svc = LunchboxService(db: FakeFirebaseFirestore());
      expect(await svc.removeBookmark(uid, 'ghost'), isNull);
    });
  });

  group('addCustomTeam', () {
    test('커스텀 팀 생성 + 슬롯 점유', () async {
      final db = FakeFirebaseFirestore();
      final svc = LunchboxService(db: db);
      expect(await svc.addCustomTeam(uid, '우리동네배구', '토 10:00~12:00'), isNull);
      final data = await svc.load(uid);
      expect(data.customTeams.length, 1);
      final id = data.customTeams.keys.first;
      expect(id, startsWith('custom_'));
      expect(data.bookmarks.first, id);
      expect((data.customTeams[id] as Map)['name'], '우리동네배구');
    });

    test('5칸 가득이면 커스텀 팀도 거부', () async {
      final db = FakeFirebaseFirestore();
      final svc = LunchboxService(db: db);
      for (var i = 0; i < 5; i++) {
        await svc.addBookmark(uid, 'team-$i');
      }
      expect(await svc.addCustomTeam(uid, '넘침', ''), isNotNull);
      expect((await svc.load(uid)).customTeams, isEmpty);
    });
  });
}
