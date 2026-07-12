// profile_service.dart — 밥이름 생성 + 프로필 보장/조회/변경. 웹 profile.js 포팅.
// 공개 users 문서(룰 화이트리스트 필드만). 닉네임 중복은 full_nickname 쿼리로 검사.
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/profile.dart';

typedef _Rice = ({String name, int weight, String color});

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

  // 웹 profile.js riceData 포팅 (가중치 + 색)
  static const List<_Rice> _rice = [
    (name: '현미밥', weight: 50, color: '#FFF9C4'),
    (name: '백미밥', weight: 50, color: '#FFF59D'),
    (name: '흑미밥', weight: 50, color: '#FFF176'),
    (name: '보리밥', weight: 50, color: '#FFEE58'),
    (name: '콩밥', weight: 50, color: '#FFD54F'),
    (name: '오곡밥', weight: 50, color: '#FFCA28'),
    (name: '차조밥', weight: 10, color: '#FFE082'),
    (name: '기장밥', weight: 10, color: '#FFECB3'),
    (name: '숭늉', weight: 10, color: '#FFE0B2'),
    (name: '볶음밥', weight: 10, color: '#FFCC80'),
    (name: '비빔밥', weight: 10, color: '#FFB74D'),
    (name: '김밥', weight: 10, color: '#FFF8E1'),
    (name: '주먹밥', weight: 10, color: '#FFECB3'),
    (name: '유부초밥', weight: 10, color: '#FFE082'),
    (name: '덮밥', weight: 10, color: '#FFF59D'),
    (name: '국밥', weight: 10, color: '#FFCCBC'),
    (name: '솥밥', weight: 10, color: '#D7CCC8'),
    (name: '약밥', weight: 10, color: '#CFD8DC'),
    (name: '죽', weight: 10, color: '#F5F5F5'),
    (name: '곤드레밥', weight: 10, color: '#C5E1A5'),
    (name: '영양밥', weight: 10, color: '#E6EE9C'),
    (name: '치밥', weight: 10, color: '#FFAB91'),
    (name: '햇반', weight: 10, color: '#FFFFFF'),
    (name: '고봉밥', weight: 10, color: '#BCAAA4'),
    (name: '밥아저씨', weight: 1, color: '#81D4FA'),
  ];

  RiceName generate() {
    final total = _rice.fold<int>(0, (s, r) => s + r.weight);
    var n = _rnd.nextDouble() * total;
    var sel = _rice.first;
    for (final r in _rice) {
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
    final rn = generate();
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

  /// 닉네임 변경(full_nickname만). update merge → 화이트리스트 키 유지로 룰 통과.
  Future<void> rename(String uid, String newName) async {
    await _db.collection('users').doc(uid).update({'full_nickname': newName});
  }
}
