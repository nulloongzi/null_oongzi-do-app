// verification_service.dart — 인증 신청(사진 업로드 → verification_requests). 웹 verification.js 포팅.
// Storage 룰: verification_photos/{uid}/{name} (jpeg/png/webp/gif, <5MB). 기존 onVerificationCreated가 카톡 알림.
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:image_picker/image_picker.dart';
import 'capture_demo.dart';
import 'deep_link_service.dart' show kCaptureMode;
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

  /// 이 계정이 이 클럽에 낸 최신 인증 요청 상태. null=이력 없음·비로그인·조회 실패
  /// (→ 신청 버튼 폴백).
  ///
  /// 규칙상 verification_requests 는 신청자 본인만 읽을 수 있다. club_id 로 거르면
  /// 남의 문서까지 범위에 들어가 쿼리째 거부된다 — 그래서 늘 '이력 없음'으로 보여
  /// 심사 중에도 신청 버튼이 다시 떴다. requested_by 한 필드로만 뽑고 club_id 와
  /// 최신 순서는 앱에서 고른다(ClubAdminService.latestRequest 와 같은 방식,
  /// orderBy 를 붙이면 복합 색인이 필요하다).
  Future<({String status, String? reason})?> latestRequest(
    String clubId,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      final snap = await _db
          .collection('verification_requests')
          .where('requested_by', isEqualTo: uid)
          .limit(20)
          .get();
      Map<String, dynamic>? latest;
      DateTime? latestAt;
      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['club_id'] != clubId) continue;
        final ts = d['requested_at'];
        final at = ts is Timestamp ? ts.toDate() : null;
        // requested_at 이 아직 null(serverTimestamp 대기)인 문서도 후보로 잡는다.
        if (latest == null ||
            (at != null && (latestAt == null || at.isAfter(latestAt)))) {
          latest = d;
          latestAt = at;
        }
      }
      if (latest == null) return null;
      return (
        status: (latest['status'] as String?) ?? 'pending',
        reason: latest['reject_reason'] is String
            ? latest['reject_reason'] as String
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
    if (uid == null) return t('vf_login_required');

    // 캡처 시연은 시스템 사진 선택기를 조종할 수 없다(앱 밖 UI). 홍보 영상에 넣을
    // 화면도 아니라 번들 이미지를 쓴다 — 업로드와 요청 문서 생성은 실제 그대로다.
    final XFile? file = kCaptureMode
        ? await captureDemoPhoto('verify_demo.png')
        : await ImagePicker().pickImage(
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
      debugPrint('verification request: $e');
      return t('vf_error');
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
