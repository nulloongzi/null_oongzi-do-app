// data_repository.dart — Firestore 읽기/쓰기 (clubs, pickup_games).
// 룰(firestore.rules): 둘 다 공개 읽기. 클럽 create=로그인+registered_by 본인+is_verified false.
// 픽업 create=owner_uid 본인(무로그인=익명). update는 merge라 보존필드 자동 유지.
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';
import 'i18n.dart';

class DataRepository {
  // DI 시임: 테스트에서 fake/mock 주입. 기본값은 프로덕션 싱글턴(동작 불변).
  DataRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Future<List<Club>> loadClubs() async {
    final snap = await _db.collection('clubs').get();
    return snap.docs.map((d) => Club.fromDoc(d)).toList();
  }

  Future<List<PickupSpot>> loadPickups() async {
    final snap = await _db.collection('pickup_games').get();
    final now = DateTime.now();
    // 유효기간(B): 만료된 스팟은 숨김 (TTL 하드삭제 전이라도). null=상시.
    return snap.docs
        .map((d) => PickupSpot.fromDoc(d))
        .where((s) => s.expireAt == null || s.expireAt!.isAfter(now))
        .toList();
  }

  /// 딥링크 단건 조회 (메모리에 없을 때 폴백).
  Future<Club?> getClub(String id) async {
    final doc = await _db.collection('clubs').doc(id).get();
    return doc.exists ? Club.fromDoc(doc) : null;
  }

  Future<PickupSpot?> getSpot(String id) async {
    final doc = await _db.collection('pickup_games').doc(id).get();
    return doc.exists ? PickupSpot.fromDoc(doc) : null;
  }

  /// 현재 로그인 uid (없으면 null). 클럽 등록/권한 판정용.
  String? get currentUid => _auth.currentUser?.uid;

  // 관리자 여부 캐시 — uid별로 보관(계정 전환 시 이전 값이 남는 버그 방지).
  static String? _adminUid;
  static bool _adminValue = false;

  /// 관리자 여부(/admins/{uid} 존재). uid별 1회 캐시. 모더레이션 권한 판정용.
  Future<bool> isAdmin() async {
    final uid = currentUid;
    if (uid == null) return false; // 비로그인/익명
    if (_adminUid == uid) return _adminValue; // 같은 계정만 캐시 사용
    try {
      final doc = await _db.collection('admins').doc(uid).get();
      _adminUid = uid;
      _adminValue = doc.exists;
      return _adminValue;
    } catch (_) {
      return false;
    }
  }

  /// 로그인돼 있으면 그 uid, 아니면 익명 로그인. (픽업 무로그인 등록 허용)
  Future<String> ensureUid() async {
    final u = _auth.currentUser;
    if (u != null) return u.uid;
    final cred = await _auth.signInAnonymously();
    final user = cred.user;
    if (user == null) throw Exception(t('err_anon_auth'));
    return user.uid;
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
    if (uid == null) throw Exception(t('login_required'));
    final id = _generateId();
    final now = FieldValue.serverTimestamp();
    final payload = <String, dynamic>{
      ...data,
      'id': id,
      'is_verified': false,
      'registered_by': uid,
      'is_urgent': false,
      'urgent_msg': '',
      // 데이터 신뢰도(guidelines.html 2-3) — 웹 registration.js 와 동일.
      'last_verified_at': now,
      'data_status': 'active',
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
      // 소유자가 폼을 저장한 것 = "이 정보가 지금도 맞다"는 확인. 웹과 동일 규칙.
      'last_verified_at': FieldValue.serverTimestamp(),
    });
  }

  /// 동호회 삭제(소유자/관리자).
  Future<void> deleteClub(String id) async {
    await _db.collection('clubs').doc(id).delete();
  }

  // ── 신고 (reports) ──

  /// 잘못된 정보 신고. 필드 집합은 firestore.rules 의 화이트리스트와 정확히 같아야 한다
  /// (하나라도 더 붙으면 hasOnly 에서 거부됨).
  ///
  /// 무로그인 신고가 요건이라 ensureUid()로 익명 uid를 확보한다 — 제3자는 신고하려고
  /// 로그인하지 않는다. 접수되면 Cloud Function(onReportCreated)이 운영자에게 알린다.
  Future<void> createReport({
    required String kind, // 'club' | 'pickup'
    required String targetId,
    required String targetName,
    required String reason,
    String detail = '',
  }) async {
    final uid = await ensureUid();
    await _db.collection('reports').add({
      'kind': kind,
      'target_id': targetId,
      'target_name': targetName.length > 120
          ? targetName.substring(0, 120)
          : targetName,
      'reason': reason,
      'detail': detail.length > 500 ? detail.substring(0, 500) : detail,
      'reporter_uid': uid,
      'status': 'open',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // 암호학적 난수 기반 12자 id (웹 registration.js generateId 포팅)
  static String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(12, (_) => chars[rnd.nextInt(36)]).join();
  }
}
