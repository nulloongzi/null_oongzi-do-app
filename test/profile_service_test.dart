// ProfileService Tier 2 테스트 — fake Firestore + 고정 시드 Random 주입(DI 시임).
// 밥이름 생성 결정성·프로필 보장(생성/재사용)·중복검사·개명 회귀 고정.
import 'dart:math';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/profile_service.dart';

void main() {
  group('generate (고정 시드)', () {
    test('같은 시드 → 같은 밥이름, 포맷 base-xxx', () {
      final a = ProfileService(
        db: FakeFirebaseFirestore(),
        rnd: Random(42),
      ).generate();
      final b = ProfileService(
        db: FakeFirebaseFirestore(),
        rnd: Random(42),
      ).generate();
      expect(a.full, b.full);
      expect(a.full, '${a.base}-${a.code}');
      expect(a.code.length, 3);
      expect(a.color, startsWith('#'));
    });
  });

  group('ensureProfile', () {
    test('신규 uid → 프로필 생성(룰 화이트리스트 필드)', () async {
      final db = FakeFirebaseFirestore();
      final svc = ProfileService(db: db, rnd: Random(1));
      final p = await svc.ensureProfile('u1');
      expect(p.fullNickname, isNotEmpty);

      final d = (await db.collection('users').doc('u1').get()).data()!;
      expect(d.keys.toSet(), {
        'nickname',
        'suffix',
        'full_nickname',
        'color',
        'created_at',
      });
      expect(d['full_nickname'], p.fullNickname);
    });

    test('기존 프로필 있으면 재생성 없이 반환', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('u1').set({
        'nickname': '백미밥',
        'full_nickname': '백미밥-abc',
        'color': '#FFF59D',
      });
      final p = await ProfileService(
        db: db,
        rnd: Random(9),
      ).ensureProfile('u1');
      expect(p.fullNickname, '백미밥-abc'); // 기존 유지 (덮어쓰기 없음)
    });
  });

  group('isDuplicate / rename', () {
    test('full_nickname 중복 검사', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('other').set({
        'full_nickname': '콩밥-zzz',
      });
      final svc = ProfileService(db: db);
      expect(await svc.isDuplicate('콩밥-zzz'), true);
      expect(await svc.isDuplicate('없는이름-xxx'), false);
    });

    test('rename은 full_nickname만 변경(다른 필드 보존)', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('u1').set({
        'full_nickname': '백미밥-abc',
        'color': '#FFF59D',
      });
      await ProfileService(db: db).rename('u1', '볶음밥-qqq');
      final d = (await db.collection('users').doc('u1').get()).data()!;
      expect(d['full_nickname'], '볶음밥-qqq');
      expect(d['color'], '#FFF59D');
    });
  });
}
