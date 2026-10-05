// VerificationService Tier 2 테스트 — fake Firestore/Auth 주입(DI 시임).
// latestRequest: 최신 요청 선택·거절사유 매핑·이력 없음 폴백 회귀 고정.
//
// 규칙상 verification_requests 는 신청자 본인만 읽는다. 그래서 쿼리는
// requested_by == 내 uid 로만 뽑고, club_id·최신 순서는 앱이 고른다.
// (fake Firestore 는 규칙을 모르므로 '남의 문서는 안 섞인다'로 그 경계를 본다.)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/verification_service.dart';

MockFirebaseAuth signedInAs(String uid) =>
    MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid));

void main() {
  group('latestRequest', () {
    test('이력 없음 → null (신청 버튼 폴백)', () async {
      final svc = VerificationService(
        db: FakeFirebaseFirestore(),
        auth: signedInAs('u1'),
      );
      expect(await svc.latestRequest('club-1'), isNull);
    });

    test('비로그인 → 쿼리 없이 null', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('verification_requests').add({
        'club_id': 'club-1',
        'requested_by': 'u1',
        'status': 'pending',
      });
      final svc = VerificationService(db: db, auth: MockFirebaseAuth());
      expect(await svc.latestRequest('club-1'), isNull);
    });

    test('내 요청 중 이 팀의 가장 최근 것의 status/reject_reason 반환', () async {
      final db = FakeFirebaseFirestore();
      final col = db.collection('verification_requests');
      await col.add({
        'club_id': 'club-1',
        'requested_by': 'u1',
        'status': 'rejected',
        'reject_reason': '사진 불분명',
        'requested_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      await col.add({
        'club_id': 'club-1',
        'requested_by': 'u1',
        'status': 'pending',
        'requested_at': Timestamp.fromDate(DateTime(2026, 6, 1)),
      });
      // 다른 팀
      await col.add({
        'club_id': 'other-club',
        'requested_by': 'u1',
        'status': 'approved',
        'requested_at': Timestamp.fromDate(DateTime(2026, 7, 1)),
      });

      final r = await VerificationService(
        db: db,
        auth: signedInAs('u1'),
      ).latestRequest('club-1');
      expect(r, isNotNull);
      expect(r!.status, 'pending'); // 최신(6월)이 이겨야 함
      expect(r.reason, isNull);
    });

    test('같은 팀이라도 남이 낸 요청은 보지 않는다', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('verification_requests').add({
        'club_id': 'club-1',
        'requested_by': 'someone-else',
        'status': 'rejected',
        'reject_reason': '남의 사유',
        'requested_at': Timestamp.fromDate(DateTime(2026, 8, 1)),
      });
      final r = await VerificationService(
        db: db,
        auth: signedInAs('u1'),
      ).latestRequest('club-1');
      expect(r, isNull);
    });

    test('거절 요청이면 사유 매핑', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('verification_requests').add({
        'club_id': 'club-1',
        'requested_by': 'u1',
        'status': 'rejected',
        'reject_reason': '중복 신청',
        'requested_at': Timestamp.fromDate(DateTime(2026, 5, 1)),
      });
      final r = await VerificationService(
        db: db,
        auth: signedInAs('u1'),
      ).latestRequest('club-1');
      expect(r!.status, 'rejected');
      expect(r.reason, '중복 신청');
    });

    test('타임스탬프가 아직 없는(방금 쓴) 요청도 잡힌다', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('verification_requests').add({
        'club_id': 'club-1',
        'requested_by': 'u1',
        'status': 'pending',
        'requested_at': null,
      });
      final r = await VerificationService(
        db: db,
        auth: signedInAs('u1'),
      ).latestRequest('club-1');
      expect(r?.status, 'pending');
    });
  });
}
