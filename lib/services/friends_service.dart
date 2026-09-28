// friends_service.dart — 밥친구 1단계: 초대코드 · 신청 · 수락 · 거절 · 끊기. 웹 js/friends.js 포팅.
//
// 친구 찾기는 초대코드 하나뿐이다(밥이름 검색 없음) — 밥이름은 공개라서 검색을 열면
// 아무나 신청할 수 있다. 코드를 넣어도 바로 친구가 되지 않고 상대가 수락해야 한다.
// 보안 규칙: 웹 레포 firestore.rules 의 invite_codes · friendships.
//
// 데이터 (웹과 같은 스키마)
//   invite_codes/{CODE}          { uid, created_at }       코드 → 주인
//   users/{uid}/private/profile  { invite_code }           내 현재 코드(본인만)
//   friendships/{작은uid_큰uid}  { members, requested_by, requested_to,
//                                  status: pending|accepted, code, created_at, accepted_at }
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics.dart';

// ── 순수 규칙 (웹 window.friendsPure 와 같은 값·같은 규칙) ─────────────

/// 헷갈리는 0·O·1·I 를 뺀 32자. firestore.rules 의 정규식과 같아야 한다.
const kInviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const kInviteLen = 6;
final kInviteRe = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');
const kPendingTtl = Duration(days: 7); // 신청은 7일 뒤 조용히 사라진다
const kMaxFriends = 100;

String makeInviteCode([Random? rand]) {
  final r = rand ?? Random.secure();
  final b = StringBuffer();
  for (var i = 0; i < kInviteLen; i++) {
    b.write(kInviteAlphabet[r.nextInt(kInviteAlphabet.length)]);
  }
  return b.toString();
}

/// 사람이 친 코드 → 정규형. 공백·하이픈은 버리고 대문자로. 형식이 아니면 ''.
String normalizeInviteCode(String? v) {
  final s = (v ?? '').toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  return kInviteRe.hasMatch(s) ? s : '';
}

String friendPairId(String a, String b) =>
    a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

DateTime? _ts(dynamic v) =>
    v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

/// 막 만든 신청(서버 시각이 아직 없음)은 만료가 아니다.
bool isRequestExpired(Map<String, dynamic> d, DateTime now) {
  if (d['status'] != 'pending') return false;
  final c = _ts(d['created_at']);
  return c != null && now.difference(c) > kPendingTtl;
}

class FriendLink {
  final String id; // 쌍 문서 id
  final String other; // 상대 uid
  final Map<String, dynamic> doc;
  const FriendLink(this.id, this.other, this.doc);
  DateTime? get acceptedAt => _ts(doc['accepted_at']);
}

class FriendState {
  final String? uid; // null = 로그아웃·익명
  final bool loaded;
  final List<FriendLink> friends;
  final List<FriendLink> incoming;
  final List<FriendLink> outgoing;
  final Map<String, FriendProfile> profiles;
  const FriendState({
    this.uid,
    this.loaded = false,
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.profiles = const {},
  });
  static const empty = FriendState();

  FriendProfile profileOf(String uid) =>
      profiles[uid] ?? const FriendProfile('…', '#F3E9D2');
}

class FriendProfile {
  final String name;
  final String color; // "#FFF9C4"
  const FriendProfile(this.name, this.color);
}

/// 내 관계 문서들 → 친구 / 받은 신청 / 보낸 신청. 만료된 신청은 뺀다.
({
  List<FriendLink> friends,
  List<FriendLink> incoming,
  List<FriendLink> outgoing,
})
partitionFriendships(
  Iterable<({String id, Map<String, dynamic> data})> docs,
  String me,
  DateTime now,
) {
  final friends = <FriendLink>[];
  final incoming = <FriendLink>[];
  final outgoing = <FriendLink>[];
  for (final d in docs) {
    final m = d.data['members'];
    if (m is! List) continue;
    final other = m.whereType<String>().where((u) => u != me).firstOrNull;
    if (other == null) continue;
    final link = FriendLink(d.id, other, d.data);
    final status = d.data['status'];
    if (status == 'accepted') {
      friends.add(link);
    } else if (status == 'pending' && !isRequestExpired(d.data, now)) {
      if (d.data['requested_to'] == me) {
        incoming.add(link);
      } else if (d.data['requested_by'] == me) {
        outgoing.add(link);
      }
    }
  }
  return (friends: friends, incoming: incoming, outgoing: outgoing);
}

/// 코드 조회 결과. status: ok | self | friend | sent | received | not_found | invalid
class InviteLookup {
  final String status;
  final String? code;
  final String? uid;
  final FriendProfile? profile;
  const InviteLookup(this.status, {this.code, this.uid, this.profile});
}

// ── Firestore ────────────────────────────────────────────────────

class FriendsService {
  FriendsService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _private(String uid) =>
      _db.collection('users').doc(uid).collection('private').doc('profile');

  /// 새 코드를 잡는다. 이미 있는 코드와 부딪히면(룰이 덮어쓰기 거부) 다시 뽑는다.
  Future<String> _claimNewCode(String uid, {Random? rand}) async {
    Object? last;
    for (var i = 0; i < 5; i++) {
      final code = makeInviteCode(rand);
      final ref = _db.collection('invite_codes').doc(code);
      try {
        // fake 환경에서도 충돌을 재현하도록 먼저 확인한다(룰에서는 set 자체가 거부된다).
        if ((await ref.get()).exists) continue;
        await ref.set({'uid': uid, 'created_at': FieldValue.serverTimestamp()});
        return code;
      } catch (e) {
        last = e;
      }
    }
    throw last ?? StateError('invite code');
  }

  Future<String> ensureMyCode(String uid) async {
    final snap = await _private(uid).get();
    final c = snap.data()?['invite_code'];
    if (c is String && c.isNotEmpty) return c;
    final code = await _claimNewCode(uid);
    await _private(uid).set({'invite_code': code}, SetOptions(merge: true));
    return code;
  }

  /// 새 코드 받기: 새 코드를 먼저 잡고, 저장하고, 옛 코드를 지운다
  /// (순서가 바뀌면 코드가 없는 순간이 생긴다). 옛 코드는 즉시 무효.
  Future<String> regenerate(String uid, String? old, {Random? rand}) async {
    final code = await _claimNewCode(uid, rand: rand);
    await _private(uid).set({'invite_code': code}, SetOptions(merge: true));
    if (old != null) {
      try {
        await _db.collection('invite_codes').doc(old).delete();
      } catch (_) {}
    }
    return code;
  }

  Future<FriendProfile> loadProfile(String uid) async {
    try {
      final d = (await _db.collection('users').doc(uid).get()).data() ?? {};
      final full = (d['full_nickname'] ?? d['nickname'] ?? '') as String;
      final color = d['color'] is String ? d['color'] as String : '#FFF9C4';
      return FriendProfile(full.isEmpty ? '?' : full, color);
    } catch (_) {
      return const FriendProfile('?', '#FFF9C4');
    }
  }

  Future<InviteLookup> lookup(String raw, FriendState st) async {
    final code = normalizeInviteCode(raw);
    if (code.isEmpty) return const InviteLookup('invalid');
    final snap = await _db.collection('invite_codes').doc(code).get();
    if (!snap.exists) return InviteLookup('not_found', code: code);
    final uid = snap.data()?['uid'] as String?;
    if (uid == null) return InviteLookup('not_found', code: code);
    if (uid == st.uid) return InviteLookup('self', code: code);
    final p = await loadProfile(uid);
    final id = friendPairId(st.uid ?? '', uid);
    var status = 'ok';
    if (st.friends.any((f) => f.id == id)) {
      status = 'friend';
    } else if (st.outgoing.any((f) => f.id == id)) {
      status = 'sent';
    } else if (st.incoming.any((f) => f.id == id)) {
      status = 'received';
    }
    return InviteLookup(status, code: code, uid: uid, profile: p);
  }

  /// 신청. 반환: 'sent' | 'accepted'(상대가 먼저 신청해 둠 → 곧 수락) | 'friend'
  Future<String> sendRequest(String me, String code, String toUid) async {
    final id = friendPairId(me, toUid);
    final ref = _db.collection('friendships').doc(id);
    final snap = await ref.get();
    if (snap.exists) {
      final d = snap.data()!;
      if (d['status'] == 'pending' && d['requested_to'] == me) {
        await accept(id);
        return 'accepted';
      }
      if (d['status'] == 'accepted') return 'friend';
      if (!isRequestExpired(d, DateTime.now())) return 'sent';
      await ref.delete(); // 만료된 내 신청 → 새로
    }
    final members = [me, toUid]..sort();
    await ref.set({
      'members': members,
      'requested_by': me,
      'requested_to': toUid,
      'status': 'pending',
      'code': code,
      'created_at': FieldValue.serverTimestamp(),
    });
    Track.event('friend_request_send');
    return 'sent';
  }

  Future<void> accept(String id) async {
    await _db.collection('friendships').doc(id).update({
      'status': 'accepted',
      'accepted_at': FieldValue.serverTimestamp(),
    });
    Track.event('friend_accept');
  }

  /// 거절·취소·끊기 — 모두 조용히 지운다(상대에게 알리지 않는다).
  Future<void> remove(String id, String why) async {
    await _db.collection('friendships').doc(id).delete();
    Track.event('friend_remove', {'why': why});
  }

  Stream<List<({String id, Map<String, dynamic> data})>> watch(String uid) =>
      _db
          .collection('friendships')
          .where('members', arrayContains: uid)
          .snapshots()
          .map((s) => [for (final d in s.docs) (id: d.id, data: d.data())]);
}

// ── 앱 전체 상태 ────────────────────────────────────────────────
// 🍚 버블 배지와 팝업 둘째 장이 같은 상태를 본다. 로그인(익명 제외)하면 구독, 나가면 끊는다.

class FriendsHub {
  FriendsHub._();
  static final FriendsHub instance = FriendsHub._();

  final state = ValueNotifier<FriendState>(FriendState.empty);

  /// 받은 신청 중 아직 둘째 장에서 못 본 게 있나 — 둘째 도트를 키우고 빛낸다.
  final hasUnseen = ValueNotifier<bool>(false);

  // 늦게 만든다 — Firebase 초기화 전(테스트 포함)에 허브를 건드려도 죽지 않게.
  FriendsService? _svc;
  FriendsService get svc => _svc ??= FriendsService();
  set svc(FriendsService v) => _svc = v;
  StreamSubscription? _authSub;
  StreamSubscription? _sub;
  final Map<String, FriendProfile> _profiles = {};
  String? myCode;
  static const _seenKey = 'seen_friend_req';

  void start() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u == null || u.isAnonymous) {
        _stop();
      } else if (state.value.uid != u.uid) {
        _listen(u.uid);
      }
    });
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _profiles.clear();
    myCode = null;
    state.value = FriendState.empty;
    hasUnseen.value = false;
  }

  void _listen(String uid) {
    _sub?.cancel();
    state.value = FriendState(uid: uid);
    _sub = svc.watch(uid).listen((docs) async {
      final p = partitionFriendships(docs, uid, DateTime.now());
      final others = {
        for (final l in [...p.friends, ...p.incoming, ...p.outgoing]) l.other,
      };
      for (final o in others) {
        _profiles[o] ??= await svc.loadProfile(o);
      }
      state.value = FriendState(
        uid: uid,
        loaded: true,
        friends: p.friends,
        incoming: p.incoming,
        outgoing: p.outgoing,
        profiles: Map.of(_profiles),
      );
      await _syncUnseen();
    }, onError: (_) {});
  }

  Future<void> _syncUnseen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList(_seenKey) ?? const [];
      hasUnseen.value = state.value.incoming.any((l) => !seen.contains(l.id));
    } catch (_) {}
  }

  /// 둘째 장을 봤다 → 지금 받은 신청을 모두 본 것으로.
  Future<void> markSeen() async {
    hasUnseen.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_seenKey, [
        for (final l in state.value.incoming) l.id,
      ]);
    } catch (_) {}
  }

  Future<String> ensureMyCode() async {
    final uid = state.value.uid;
    if (uid == null) throw StateError('login');
    return myCode ??= await svc.ensureMyCode(uid);
  }

  Future<String> regenerate() async {
    final uid = state.value.uid;
    if (uid == null) throw StateError('login');
    return myCode = await svc.regenerate(uid, myCode);
  }
}
