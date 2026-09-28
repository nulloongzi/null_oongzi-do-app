// friend_share_service.dart — 밥친구 2단계: 친구에게 보이는 도시락(식단표) 공유.
// 웹 js/friends-share.js 포팅 — 같은 스키마·같은 규칙.
//
// 비공개 도시락(users/{uid}/private/profile)을 친구에게 여는 대신, 보이기로 켠 팀만 담은
// 사본을 users/{uid}/shared/lunchbox 에 둔다. 숨긴 팀은 처음부터 사본에 쓰지 않는다 —
// 받는 쪽 화면에서 가리는 게 아니라 데이터가 안 간다(웹 레포 firestore.rules).
//
// 설정은 하나(모든 밥친구에게 같은 도시락), private/profile 에:
//   friend_hidden   [팀id]   숨긴 팀 (도시락 편집의 눈 스위치)
//   friend_hide_all bool     식단표 전부 숨기기
//   friend_share_ok bool     첫 밥친구 때 '보일 팀' 확인을 마쳤나
// 확인 전에는 사본을 쓰지 않는다 — 기본이 전부 보이기라, 모르는 사이에 공개되는 일이 없게.
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club.dart';
import 'lunchbox_service.dart';
import 'schedule_parse.dart';

// ── 순수 규칙 (웹 friendSharePure 와 같다) ──────────────────────

class SharedLunchbox {
  final List<String> teams; // 동호회 id
  final List<({String name, String schedule})> custom; // 직접 추가한 팀
  final bool hideAll;
  const SharedLunchbox(this.teams, this.custom, this.hideAll);

  Map<String, dynamic> toMap() => {
    'teams': teams,
    'custom': [
      for (final c in custom) {'name': c.name, 'schedule': c.schedule},
    ],
    'hide_all': hideAll,
  };

  static SharedLunchbox? fromMap(Map<String, dynamic>? d) {
    if (d == null) return null;
    final teams = (d['teams'] is List)
        ? (d['teams'] as List).whereType<String>().toList()
        : <String>[];
    final custom = <({String name, String schedule})>[];
    if (d['custom'] is List) {
      for (final c in d['custom'] as List) {
        if (c is Map) {
          custom.add((
            name: '${c['name'] ?? ''}',
            schedule: '${c['schedule'] ?? ''}',
          ));
        }
      }
    }
    return SharedLunchbox(teams, custom, d['hide_all'] == true);
  }

  /// 같은 내용이면 다시 쓰지 않는다 — updated_at 이 곧 '도시락 바뀜' 신호라서.
  bool sameAs(SharedLunchbox? o) =>
      o != null && jsonEncode(toMap()) == jsonEncode(o.toMap());
}

String _cut(Object? v, int n) {
  final s = '${v ?? ''}';
  return s.length > n ? s.substring(0, n) : s;
}

/// 저장된 도시락 → 친구용 사본. 칸 순서를 지키고 빈칸·숨긴 팀은 뺀다.
/// 직접 추가한 팀은 id 가 친구에게 의미가 없으니 이름·일정만 담는다.
SharedLunchbox buildSharedLunchbox(
  List<String?> bookmarks,
  Map<String, dynamic> customTeams,
  List<String> hidden,
  bool hideAll,
) {
  if (hideAll) return const SharedLunchbox([], [], true);
  final teams = <String>[];
  final custom = <({String name, String schedule})>[];
  for (final id in bookmarks.take(5)) {
    if (id == null || hidden.contains(id)) continue;
    final c = customTeams[id];
    if (c is Map) {
      custom.add((
        name: _cut(c['name'], 80),
        schedule: _cut(c['schedule'], 600),
      ));
    } else {
      teams.add(id);
    }
  }
  return SharedLunchbox(teams, custom, false);
}

class FriendShareSettings {
  final List<String> hidden;
  final bool hideAll;
  final bool shareOk;
  const FriendShareSettings({
    this.hidden = const [],
    this.hideAll = false,
    this.shareOk = false,
  });
  static const empty = FriendShareSettings();

  static FriendShareSettings fromMap(Map<String, dynamic>? d) =>
      FriendShareSettings(
        hidden: d?['friend_hidden'] is List
            ? (d!['friend_hidden'] as List).whereType<String>().toList()
            : const [],
        hideAll: d?['friend_hide_all'] == true,
        shareOk: d?['friend_share_ok'] == true,
      );
}

/// 친구 도시락의 팀 하나(식단표용). [id] 는 동호회 팀만 — 직접 추가한 팀은 null.
class FriendTeam {
  final String name;
  final bool isCustom;
  final int slot;
  final List<SchedEvent> events;
  final String? id;
  const FriendTeam(this.name, this.isCustom, this.slot, this.events, {this.id});
}

// ── 합석 · 익힘 (웹 friendSharePure.mealOverlaps / warmthTier 와 같다) ──

class MealOverlap {
  final String id;
  final String day;
  final double start;
  final double end;
  const MealOverlap(this.id, this.day, this.start, this.end);
}

const _mealMinHours = 0.5;

/// 합석: 같은 동호회(id) · 같은 요일 · 30분 이상 겹치는 시간. 직접 추가한 팀은 같은 팀인지
/// 알 수 없어서 넣지 않는다. 양쪽 모두 친구에게 공개한 팀이어야 한다 — 숨긴 팀까지 세면
/// 두 사람의 숫자가 달라져 숨긴 팀이 드러난다.
List<MealOverlap> mealOverlaps(List<FriendTeam> mine, List<FriendTeam> theirs) {
  final out = <MealOverlap>[];
  final seen = <String>{};
  for (final m in mine) {
    for (final o in theirs) {
      final id = m.id;
      if (id == null || id.isEmpty || id != o.id) continue;
      for (final a in m.events) {
        for (final b in o.events) {
          if (a.day != b.day) continue;
          final s = a.start > b.start ? a.start : b.start;
          final e = a.end < b.end ? a.end : b.end;
          if (e - s < _mealMinHours) continue;
          if (!seen.add('$id|${a.day}|$s|$e')) continue;
          out.add(MealOverlap(id, a.day, s, e));
        }
      }
    }
  }
  return out;
}

/// 익힘 단계: 한 주 합석 횟수 → 0 생쌀 · 1 뜸 · 2 노릇 · 3 누룽지(3회 이상)
int warmthTier(int n) => n >= 3 ? 3 : (n >= 2 ? 2 : (n >= 1 ? 1 : 0));

class FriendMeal {
  final List<MealOverlap> overlaps;
  const FriendMeal(this.overlaps);
  static const none = FriendMeal([]);
  int get n => overlaps.length;
  int get tier => warmthTier(n);
}

/// 합석 목록 정렬: 요일 → 시작 시각 (웹 friendSharePure.sortOverlaps).
List<MealOverlap> sortOverlaps(List<MealOverlap> list) =>
    [...list]..sort((a, b) {
      final d = scheduleDays.indexOf(a.day) - scheduleDays.indexOf(b.day);
      return d != 0 ? d : a.start.compareTo(b.start);
    });

/// 시각 표기 "19–22" / "19:30–22" (웹 fmtRange 와 같다).
String fmtHourRange(double a, double b) => '${_fmtHour(a)}–${_fmtHour(b)}';
String _fmtHour(double v) {
  final h = v.floor(), m = ((v - h) * 60).round();
  return m == 0 ? '$h' : '$h:${m < 10 ? '0' : ''}$m';
}

/// 포장하기 카드 후보 한 명(선별용). 나가는 건 이름·색·익힘 단계뿐.
class CardFriendEntry {
  final String name;
  final String color;
  final int tier;
  final int n;
  final bool hidden; // '식단표 전부 숨기기'를 켠 친구 — 카드에 넣지 않는다
  const CardFriendEntry({
    required this.name,
    required this.color,
    required this.tier,
    required this.n,
    this.hidden = false,
  });
}

/// 카드에 넣을 밥친구: 합석 있는 친구만, 전부 숨긴 친구는 빼고, 합석 많은 순(같으면 이름순) 최대 [max].
/// 웹 friendSharePure.pickCardFriends 와 같은 규칙.
List<CardFriendEntry> pickCardFriends(
  List<CardFriendEntry> entries, {
  int max = 4,
}) {
  final out = entries.where((f) => f.n > 0 && !f.hidden).toList()
    ..sort((a, b) => b.n != a.n ? b.n - a.n : a.name.compareTo(b.name));
  return out.length > max ? out.sublist(0, max) : out;
}

class FriendLunchbox {
  final String status; // ok | none(아직 공개 안 함) | hidden(전부 숨김)
  final List<FriendTeam> teams;
  final DateTime? updatedAt;
  const FriendLunchbox(this.status, this.teams, this.updatedAt);
}

List<SchedEvent> clubEvents(Club c) =>
    (c.scheduleRaw != null && c.scheduleRaw!.isNotEmpty)
    ? eventsFromRaw(c.scheduleRaw)
    : eventsFromText(c.schedule);

// ── Firestore ────────────────────────────────────────────────────

class FriendShareService {
  FriendShareService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _private(String uid) =>
      _db.collection('users').doc(uid).collection('private').doc('profile');
  DocumentReference<Map<String, dynamic>> _shared(String uid) =>
      _db.collection('users').doc(uid).collection('shared').doc('lunchbox');

  SharedLunchbox? _last;
  String? _lastFor;

  void reset() {
    _last = null;
    _lastFor = null;
  }

  Future<FriendShareSettings> loadSettings(String uid) async =>
      FriendShareSettings.fromMap((await _private(uid).get()).data());

  Future<void> saveSettings(String uid, Map<String, dynamic> fields) =>
      _private(uid).set(fields, SetOptions(merge: true));

  /// 지금 도시락에 맞춰 사본을 쓴다. 확인 전이면 쓰지 않고, 내용이 같아도 쓰지 않는다.
  Future<void> sync(String uid) async {
    final s = await loadSettings(uid);
    if (!s.shareOk) return;
    final lb = await LunchboxService(db: _db).load(uid);
    final want = buildSharedLunchbox(
      lb.bookmarks,
      lb.customTeams,
      s.hidden,
      s.hideAll,
    );
    if (_lastFor != uid) {
      _last = SharedLunchbox.fromMap((await _shared(uid).get()).data());
      _lastFor = uid;
    }
    if (want.sameAs(_last)) return;
    await _shared(
      uid,
    ).set({...want.toMap(), 'updated_at': FieldValue.serverTimestamp()});
    _last = want;
  }

  Future<FriendLunchbox> loadFriend(String other) async {
    final snap = await _shared(other).get();
    final d = snap.data();
    if (d == null) return const FriendLunchbox('none', [], null);
    final at = d['updated_at'] is Timestamp
        ? (d['updated_at'] as Timestamp).toDate()
        : null;
    final sh = SharedLunchbox.fromMap(d)!;
    if (sh.hideAll) return FriendLunchbox('hidden', const [], at);
    final teams = <FriendTeam>[];
    for (final id in sh.teams) {
      try {
        final doc = await _db.collection('clubs').doc(id).get();
        if (!doc.exists) continue; // 삭제된 팀
        final c = Club.fromDoc(doc);
        teams.add(
          FriendTeam(c.name, false, teams.length, clubEvents(c), id: id),
        );
      } catch (_) {}
    }
    for (final c in sh.custom) {
      teams.add(
        FriendTeam(c.name, true, teams.length, eventsFromText(c.schedule)),
      );
    }
    return FriendLunchbox('ok', teams, at);
  }

  /// 내 도시락 팀(이름·일정). 보는 사람은 나라서 숨긴 팀도 포함한다.
  Future<List<({String id, FriendTeam team})>> myTeams(String uid) async {
    final lb = await LunchboxService(db: _db).load(uid);
    final out = <({String id, FriendTeam team})>[];
    for (var i = 0; i < 5; i++) {
      final id = lb.bookmarks[i];
      if (id == null) continue;
      final c = lb.customTeams[id];
      if (c is Map) {
        out.add((
          id: id,
          team: FriendTeam(
            '${c['name'] ?? ''}',
            true,
            i,
            eventsFromText(c['schedule'] as String?),
          ),
        ));
        continue;
      }
      try {
        final doc = await _db.collection('clubs').doc(id).get();
        if (!doc.exists) continue;
        final club = Club.fromDoc(doc);
        out.add((
          id: id,
          team: FriendTeam(club.name, false, i, clubEvents(club), id: id),
        ));
      } catch (_) {}
    }
    return out;
  }

  /// 합석을 셀 내 팀: 친구에게 실제로 보이는 동호회 팀만. 확인 전이거나 전부 숨기기면 없다.
  Future<List<FriendTeam>> myMealTeams(
    String uid,
    FriendShareSettings s,
  ) async {
    if (!s.shareOk || s.hideAll) return const [];
    return [
      for (final x in await myTeams(uid))
        if (!x.team.isCustom && !s.hidden.contains(x.id)) x.team,
    ];
  }
}
