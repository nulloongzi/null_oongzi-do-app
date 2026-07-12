// VerificationService Tier 2 테스트 — fake Firestore/Auth 주입(DI 시임).
// latestRequest: 최신 요청 선택·거절사유 매핑·이력 없음 폴백 회귀 고정.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/verification_service.dart';

void main() {
  group('latestRequest', () {
    test('이력 없음 → null (신청 버튼 폴백)', () async {
      final svc = VerificationService(
        db: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(),
      );
      expect(await svc.latestRequest('club-1'), isNull);
    });

    test('가장 최근 요청의 status/reject_reason 반환', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('verification_requests').add({
        'club_id': 'club-1',
        'status': 'rejected',
        'reject_reason': '사진 불분명',
        'requested_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      await db.collection('verification_requests').add({
        'club_id': 'club-1',
        'status': 'pending',
        'requested_at': Timestamp.fromDate(DateTime(2026, 6, 1)),
      });
      await db.collection('verification_requests').add({
        'club_id': 'other-club',
        'status': 'approved',
        'requested_at': Timestamp.fromDate(DateTime(2026, 7, 1)),
      });

      final svc = VerificationService(db: db, auth: MockFirebaseAuth());
      final r = await svc.latestRequest('club-1');
      expect(r, isNotNull);
      expect(r!.status, 'pending'); // 최신(6월)이 이겨야 함
      expect(r.reason, isNull);
    });

    test('거절 요청이면 사유 매핑', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('verification_requests').add({
        'club_id': 'club-1',
        'status': 'rejected',
        'reject_reason': '중복 신청',
        'requested_at': Timestamp.fromDate(DateTime(2026, 5, 1)),
      });
      final r = await VerificationService(
        db: db,
        auth: MockFirebaseAuth(),
      ).latestRequest('club-1');
      expect(r!.status, 'rejected');
      expect(r.reason, '중복 신청');
    });
  });
}
