// profile_service.dart — 밥이름 생성 + 프로필 보장/조회/변경. 웹 profile.js 포팅.
// 공개 users 문서(룰 화이트리스트 필드만). 닉네임 중복은 full_nickname 쿼리로 검사.
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/profile.dart';
import 'rice_dex.dart' show kRiceData;

/// 예약 닉네임: 서비스 이름('누룽지'·'Nulloongzi'·'null_oongzi' …)은 공식 계정만 쓴다.
/// 공백·기호·대소문자를 걷어내고 비교한다. 웹 레포 firestore.rules isReservedNickname ·
/// js/profile.js 와 같은 목록 — 실제로 막는 건 룰이고, 앱은 저장 전에 이유를 알려줄 뿐이다.
const kReservedNicknameWords = [
  '누룽지',
  'nulloongzi',
  'nuloongzi',
  'nullongzi',
  'nurungji',
  'nurungzi',
  'nuroongzi',
];

bool isReservedNickname(String? name) {
  final n = (name ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');
  return kReservedNicknameWords.any(n.contains);
}

class RiceName {
  final String base;
  final String code;
  final String full;
  final String color;
  RiceName(this.base, this.code, this.full, this.color);
}

class ProfileService {
  // DI 시임: 테스트에서 fake db·고정 시드 Random 주입. 기본값은 프로덕션(동작 불변).
  ProfileService({FirebaseFirestore? db, Random? rnd})
    : _db = db ?? FirebaseFirestore.instance,
      _rnd = rnd ?? Random();

  final FirebaseFirestore _db;
  final Random _rnd;

  RiceName generate() {
    final total = kRiceData.fold<int>(0, (s, r) => s + r.weight);
    var n = _rnd.nextDouble() * total;
    var sel = kRiceData.first;
    for (final r in kRiceData) {
      if (n < r.weight) {
        sel = r;
        break;
      }
      n -= r.weight;
    }
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(
      3,
      (_) => chars[_rnd.nextInt(chars.length)],
    ).join();
    return RiceName(sel.name, suffix, '${sel.name}-$suffix', sel.color);
  }

  /// 프로필 보장: 없으면 밥이름 생성해 생성, 있으면 그대로 반환.
  Future<Profile> ensureProfile(String uid) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (snap.exists && snap.data() != null) {
      return Profile.fromMap(snap.data()!);
    }
    // 웹 auth.js와 동일: 중복이면 최대 10회 재생성, 그래도 겹치면 타임스탬프 뒷 4자리 부착
    var rn = generate();
    var unique = !await isDuplicate(rn.full);
    for (var i = 1; !unique && i < 10; i++) {
      rn = generate();
      unique = !await isDuplicate(rn.full);
    }
    if (!unique) {
      final ms = DateTime.now().millisecondsSinceEpoch.toString();
      rn = RiceName(
        rn.base,
        rn.code,
        '${rn.full}${ms.substring(ms.length - 4)}',
        rn.color,
      );
    }
    await ref.set({
      'nickname': rn.base,
      'suffix': rn.code,
      'full_nickname': rn.full,
      'color': rn.color,
      'created_at': FieldValue.serverTimestamp(),
    });
    return Profile(
      fullNickname: rn.full,
      nickname: rn.base,
      color: rn.color,
      createdAt: DateTime.now(),
    );
  }

  Future<bool> isDuplicate(String fullNickname) async {
    final q = await _db
        .collection('users')
        .where('full_nickname', isEqualTo: fullNickname)
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  /// 예약 닉네임을 쓸 수 있는 계정인가 — 운영자(admins) 또는 official_accounts/{uid}.
  /// 웹 레포 firestore.rules canUseReservedNickname() 과 같은 기준.
  Future<bool> canUseReservedNickname(String uid) async {
    try {
      final r = await Future.wait([
        _db.collection('admins').doc(uid).get(),
        _db.collection('official_accounts').doc(uid).get(),
      ]);
      return r.any((d) => d.exists);
    } catch (_) {
      return false;
    }
  }

  /// 닉네임 변경(full_nickname만). update merge → 화이트리스트 키 유지로 룰 통과.
  Future<void> rename(String uid, String newName) async {
    await _db.collection('users').doc(uid).update({'full_nickname': newName});
  }
}
