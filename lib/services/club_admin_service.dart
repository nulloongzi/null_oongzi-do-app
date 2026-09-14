// club_admin_service.dart — 팀 관리자 신청/탈퇴. 웹 verification.js 의
// submitAdminRequest · leaveClubAdmin 포팅.
//
// Storage 룰: admin_request_photos/{uid}/{name} (jpeg/png/webp/gif, <5MB).
// 필드 집합은 firestore.rules 의 club_admin_requests 화이트리스트와 정확히
// 같아야 한다 — 하나만 달라져도 쓰기가 통째로 거부된다.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/club.dart';
import 'club_admin.dart';
import 'i18n.dart';
import 'sanitize.dart';

class ClubAdminService {
  ClubAdminService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// 이 계정이 이 팀에 낸 최신 관리자 신청 상태. null=이력 없음 또는 조회 실패.
  ///
  /// club_id + requested_by 두 필드를 함께 거르면 복합 색인이 필요해서,
  /// requested_by 한 필드로만 뽑고 club_id 는 앱에서 고른다(웹과 동일).
  Future<({String status, String? reason})?> latestRequest(
    String clubId,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      final snap = await _db
          .collection('club_admin_requests')
          .where('requested_by', isEqualTo: uid)
          .limit(20)
          .get();
      DocumentSnapshot<Map<String, dynamic>>? latest;
      DateTime? latestAt;
      for (final doc in snap.docs) {
        if (doc.data()['club_id'] != clubId) continue;
        final ts = doc.data()['requested_at'];
        final at = ts is Timestamp ? ts.toDate() : null;
        if (latest == null ||
            (at != null && (latestAt == null || at.isAfter(latestAt)))) {
          latest = doc;
          latestAt = at;
        }
      }
      if (latest == null) return null;
      final d = latest.data()!;
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

  /// 갤러리에서 증빙 사진 선택 → 업로드 → 관리자 신청 문서 생성.
  /// 반환: null=성공, 'cancelled'=사용자 취소, 그 외=사용자에게 보일 오류 메시지.
  Future<String?> submit(Club club) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return t('ad_login_required');

    // 정원이 찼으면 사진부터 올리게 두지 않는다 — 올려봐야 거절될 뿐이고,
    // 남의 이름이 찍힌 캡처가 괜히 저장소에 남는다.
    if (club.admins.length >= kMaxClubAdmins) return t('ad_full');

    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return 'cancelled';

    try {
      final safe = Sanitize.filename(file.name);
      final fileName =
          '${club.id}_${DateTime.now().millisecondsSinceEpoch}_$safe';
      final ref = FirebaseStorage.instance.ref(
        'admin_request_photos/${user.uid}/$fileName',
      );
      await ref.putFile(
        File(file.path),
        SettableMetadata(contentType: _contentType(file.name)),
      );
      final url = await ref.getDownloadURL();

      await _db.collection('club_admin_requests').add({
        'club_id': club.id,
        'club_name': club.name.length > 120
            ? club.name.substring(0, 120)
            : club.name,
        'photo_url': url,
        'requested_by': user.uid,
        'requested_at': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      // 운영자 카톡 알림은 onClubAdminRequestCreated 트리거가 보낸다.
      return null;
    } catch (e) {
      return '${t('ad_error')}$e';
    }
  }

  /// 스스로 관리자에서 빠진다. 마지막 한 명이어도 나갈 수 있다.
  /// 규칙상 admins 는 클라이언트가 못 고치므로 서버 callable 을 거친다.
  /// 반환: null=성공, 그 외=사용자에게 보일 오류 메시지.
  Future<String?> leave(String clubId) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('leaveClubAdmin').call({
        'clubId': clubId,
      });
      return null;
    } catch (_) {
      return t('ad_leave_error');
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
