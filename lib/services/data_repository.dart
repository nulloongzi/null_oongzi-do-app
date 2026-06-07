// data_repository.dart — Firestore 읽기 (clubs, pickup_games). 룰: 둘 다 공개 읽기.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';

class DataRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Club>> loadClubs() async {
    final snap = await _db.collection('clubs').get();
    return snap.docs.map((d) => Club.fromDoc(d)).toList();
  }

  Future<List<PickupSpot>> loadPickups() async {
    final snap = await _db.collection('pickup_games').get();
    return snap.docs.map((d) => PickupSpot.fromDoc(d)).toList();
  }

  /// 로그인돼 있으면 그 uid, 아니면 익명 로그인. (픽업 무로그인 등록 허용)
  Future<String> ensureUid() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) return u.uid;
    final cred = await FirebaseAuth.instance.signInAnonymously();
    return cred.user!.uid;
  }

  /// 픽업 스팟 등록. data엔 owner_uid/타임스탬프 제외 필드만 담아 전달.
  /// 룰: owner_uid==auth.uid, title 필수, pickupFieldsValid.
  Future<void> createPickup(Map<String, dynamic> data) async {
    final uid = await ensureUid();
    final payload = <String, dynamic>{
      ...data,
      'owner_uid': uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
    await _db.collection('pickup_games').add(payload);
  }
}
