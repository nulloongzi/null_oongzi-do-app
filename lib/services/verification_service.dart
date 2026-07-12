// verification_service.dart — 인증 신청(사진 업로드 → verification_requests). 웹 verification.js 포팅.
// Storage 룰: verification_photos/{uid}/{name} (jpeg/png/webp/gif, <5MB). 기존 onVerificationCreated가 카톡 알림.
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'i18n.dart';
import 'sanitize.dart';

class VerificationService {
  // DI 시임: 인라인 싱글턴 → 필드화 + 생성자 주입. 기본값은 프로덕션(동작 불변).
  // (Storage/ImagePicker는 submit 전용이라 현 단계에선 인라인 유지 — Phase 3.)
  VerificationService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// 이 클럽의 최신 인증 요청 상태(웹 verifyStatusArea 조회와 동일 쿼리).
  /// null=이력 없음 또는 조회 실패(→ 신청 버튼 폴백, 웹 동일).
  Future<({String status, String? reason})?> latestRequest(
    String clubId,
  ) async {
    try {
      final snap = await _db
          .collection('verification_requests')
          .where('club_id', isEqualTo: clubId)
          .orderBy('requested_at', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final d = snap.docs.first.data();
      return (
        status: (d['status'] as String?) ?? 'pending',
        reason: d['reject_reason'] is String
            ? d['reject_reason'] as String
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// 갤러리에서 사진 선택 → 업로드 → 인증 요청 문서 생성.
  /// 반환: null=성공, 'cancelled'=사용자 취소, 그 외=오류 메시지.
  Future<String?> submit({
    required String clubId,
    required String clubName,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return t('login_required');

    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return 'cancelled';

    try {
      final safe = Sanitize.filename(file.name);
      final fileName =
          '${clubId}_${DateTime.now().millisecondsSinceEpoch}_$safe';
      final ref = FirebaseStorage.instance.ref(
        'verification_photos/$uid/$fileName',
      );
      await ref.putFile(
        File(file.path),
        SettableMetadata(contentType: _contentType(file.name)),
      );
      final url = await ref.getDownloadURL();

      await _db.collection('verification_requests').add({
        'club_id': clubId,
        'club_name': clubName,
        'photo_url': url,
        'requested_by': uid,
        'requested_at': FieldValue.serverTimestamp(),
        'status': 'pending',
        'reviewed_at': null,
      });
      return null;
    } catch (e) {
      return '$e';
    }
  }

  String _contentType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
