// verification_service.dart — 인증 신청(사진 업로드 → verification_requests). 웹 verification.js 포팅.
// Storage 룰: verification_photos/{uid}/{name} (jpeg/png/webp/gif, <5MB). 기존 onVerificationCreated가 카톡 알림.
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'sanitize.dart';

class VerificationService {
  /// 갤러리에서 사진 선택 → 업로드 → 인증 요청 문서 생성.
  /// 반환: null=성공, 'cancelled'=사용자 취소, 그 외=오류 메시지.
  Future<String?> submit(
      {required String clubId, required String clubName}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '로그인이 필요해요';

    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return 'cancelled';

    try {
      final safe = Sanitize.filename(file.name);
      final fileName = '${clubId}_${DateTime.now().millisecondsSinceEpoch}_$safe';
      final ref =
          FirebaseStorage.instance.ref('verification_photos/$uid/$fileName');
      await ref.putFile(
          File(file.path), SettableMetadata(contentType: _contentType(file.name)));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('verification_requests').add({
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
