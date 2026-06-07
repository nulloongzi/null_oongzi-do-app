// data_repository.dart — Firestore 읽기/쓰기 (clubs, pickup_games).
// 룰(firestore.rules): 둘 다 공개 읽기. 클럽 create=로그인+registered_by 본인+is_verified false.
// 픽업 create=owner_uid 본인(무로그인=익명). update는 merge라 보존필드 자동 유지.
import 'dart:math';
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

  /// 현재 로그인 uid (없으면 null). 클럽 등록/권한 판정용.
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// 로그인돼 있으면 그 uid, 아니면 익명 로그인. (픽업 무로그인 등록 허용)
  Future<String> ensureUid() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) return u.uid;
    final cred = await FirebaseAuth.instance.signInAnonymously();
    return cred.user!.uid;
  }

  // ── 픽업 (pickup_games) ──

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

  /// 픽업 수정(소유자). update는 merge → owner_uid 보존되어 룰 통과.
  Future<void> updatePickup(String id, Map<String, dynamic> fields) async {
    await _db.collection('pickup_games').doc(id).update({
      ...fields,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// 픽업 삭제(소유자/관리자).
  Future<void> deletePickup(String id) async {
    await _db.collection('pickup_games').doc(id).delete();
  }

  // ── 동호회 (clubs) ──

  /// 동호회 등록. 웹과 동일: 12자 난수 id를 문서 id로 set().
  /// 룰: 로그인 필수, registered_by==uid, is_verified==false, name 필수, clubFieldsValid.
  /// data엔 name/target/address/coordinates/schedule/schedule_raw/price/contact/insta_reel.
  Future<String> createClub(Map<String, dynamic> data) async {
    final uid = currentUid;
    if (uid == null) throw Exception('로그인이 필요해요');
    final id = _generateId();
    final now = FieldValue.serverTimestamp();
    final payload = <String, dynamic>{
      ...data,
      'id': id,
      'is_verified': false,
      'registered_by': uid,
      'is_urgent': false,
      'urgent_msg': '',
      'metadata': {
        'created_at': now,
        'updated_at': now,
        'status': 'approved',
        'submitted_by': uid,
      },
    };
    await _db.collection('clubs').doc(id).set(payload);
    return id;
  }

  /// 동호회 수정(소유자). update merge → is_verified/registered_by/metadata.created_at 보존.
  Future<void> updateClub(String id, Map<String, dynamic> fields) async {
    await _db.collection('clubs').doc(id).update({
      ...fields,
      'metadata.updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// 동호회 삭제(소유자/관리자).
  Future<void> deleteClub(String id) async {
    await _db.collection('clubs').doc(id).delete();
  }

  // 암호학적 난수 기반 12자 id (웹 registration.js generateId 포팅)
  static String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(12, (_) => chars[rnd.nextInt(36)]).join();
  }
}
