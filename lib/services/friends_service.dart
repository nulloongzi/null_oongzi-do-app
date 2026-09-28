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
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics.dart';
import 'friend_share_service.dart';
import 'lunchbox_service.dart' show lunchboxChanged;

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

  /// 둘째 장에 새 소식이 있나 — 둘째 도트를 키우고 빛낸다.
  /// 못 본 받은 신청 · '보일 팀' 확인 필요 · 도시락이 바뀐 친구.
  final hasUnseen = ValueNotifier<bool>(false);

  /// 2단계: 내 공유 설정(숨긴 팀 · 전부 숨기기 · 확인 여부).
  final share = ValueNotifier<FriendShareSettings>(FriendShareSettings.empty);

  /// 2단계: 친구 도시락 사본(uid → 도시락). '도시락 바뀜' 판단에 쓴다.
  final friendLunchboxes = ValueNotifier<Map<String, FriendLunchbox>>({});
  FriendShareService? _shareSvc;
  FriendShareService get shareSvc => _shareSvc ??= FriendShareService();
  set shareSvc(FriendShareService v) => _shareSvc = v;
  Map<String, int> _lbSeen = {};
  static const _lbSeenKey = 'friend_lb_seen';

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
    lunchboxChanged.addListener(_onLunchboxChanged);
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
    share.value = FriendShareSettings.empty;
    friendLunchboxes.value = {};
    _shareSvc?.reset();
  }

  void _onLunchboxChanged() {
    final uid = state.value.uid;
    if (uid != null) shareSvc.sync(uid).catchError((_) {});
  }

  void _listen(String uid) {
    _sub?.cancel();
    state.value = FriendState(uid: uid);
    _loadShare(uid);
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
      await _loadFriendLunchboxes(p.friends);
    }, onError: (_) {});
  }

  Future<void> _loadShare(String uid) async {
    try {
      share.value = await shareSvc.loadSettings(uid);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_lbSeenKey);
      _lbSeen = raw == null
          ? {}
          : Map<String, int>.from(
              (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', v as int)),
            );
      // 다른 기기에서 도시락을 바꿨을 수 있다 → 사본을 지금 도시락에 맞춘다(같으면 쓰지 않음)
      await shareSvc.sync(uid);
    } catch (_) {}
    await _syncUnseen();
  }

  Future<void> _loadFriendLunchboxes(List<FriendLink> friends) async {
    final m = <String, FriendLunchbox>{};
    for (final f in friends) {
      try {
        m[f.other] = await shareSvc.loadFriend(f.other);
      } catch (_) {}
    }
    friendLunchboxes.value = m;
    await _syncUnseen();
  }

  Future<FriendLunchbox> reloadFriendLunchbox(String other) async {
    final lb = await shareSvc.loadFriend(other);
    friendLunchboxes.value = {...friendLunchboxes.value, other: lb};
    return lb;
  }

  /// '도시락 바뀜': 친구 사본이 마지막으로 본 뒤 바뀌었나. 처음 보는 친구는 기준만 잡는다.
  bool isLunchboxChanged(String other) {
    final at = friendLunchboxes.value[other]?.updatedAt;
    if (at == null) return false;
    final seen = _lbSeen[other];
    if (seen == null) {
      _lbSeen[other] = at.millisecondsSinceEpoch;
      _saveLbSeen();
      return false;
    }
    return at.millisecondsSinceEpoch > seen;
  }

  Future<void> markLunchboxSeen(String other) async {
    final at = friendLunchboxes.value[other]?.updatedAt;
    if (at == null) return;
    _lbSeen[other] = at.millisecondsSinceEpoch;
    await _saveLbSeen();
    await _syncUnseen();
  }

  Future<void> _saveLbSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lbSeenKey, jsonEncode(_lbSeen));
    } catch (_) {}
  }

  bool get needsShareConfirm =>
      state.value.uid != null &&
      state.value.friends.isNotEmpty &&
      !share.value.shareOk;

  Future<void> _saveShare(
    Map<String, dynamic> fields,
    FriendShareSettings next,
  ) async {
    final uid = state.value.uid;
    if (uid == null) return;
    share.value = next;
    await shareSvc.saveSettings(uid, fields);
    await shareSvc.sync(uid);
    await _syncUnseen();
  }

  Future<void> setHidden(String teamId, bool hide) {
    final list = [...share.value.hidden]..remove(teamId);
    if (hide) list.add(teamId);
    Track.event('friend_team_visibility', {'hidden': hide ? 1 : 0});
    return _saveShare(
      {'friend_hidden': list},
      FriendShareSettings(
        hidden: list,
        hideAll: share.value.hideAll,
        shareOk: share.value.shareOk,
      ),
    );
  }

  Future<void> setHideAll(bool v) {
    Track.event('friend_hide_all', {'on': v ? 1 : 0});
    return _saveShare(
      {'friend_hide_all': v},
      FriendShareSettings(
        hidden: share.value.hidden,
        hideAll: v,
        shareOk: share.value.shareOk,
      ),
    );
  }

  /// 첫 밥친구 때 '보일 팀' 확인. [hidden] 은 체크를 끈 팀.
  Future<void> confirmShare(List<String> hidden) {
    Track.event('friend_share_confirm', {'hidden': hidden.length});
    return _saveShare(
      {'friend_hidden': hidden, 'friend_share_ok': true},
      FriendShareSettings(
        hidden: hidden,
        hideAll: share.value.hideAll,
        shareOk: true,
      ),
    );
  }

  Future<void> _syncUnseen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList(_seenKey) ?? const [];
      hasUnseen.value =
          state.value.incoming.any((l) => !seen.contains(l.id)) ||
          needsShareConfirm ||
          state.value.friends.any((f) => isLunchboxChanged(f.other));
    } catch (_) {}
  }

  /// 둘째 장을 봤다 → 지금 받은 신청을 모두 본 것으로.
  Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_seenKey, [
        for (final l in state.value.incoming) l.id,
      ]);
    } catch (_) {}
    await _syncUnseen();
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
