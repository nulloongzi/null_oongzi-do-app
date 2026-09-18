// anchigi_store.dart — 안치기 전체 상태. 원본 anchigi.html의 전역 변수 + persist() 포팅.
// 상태 조각이 서로 얽혀 있어(설정 변경 → 뽑기 결과 폐기 등) 하나의 ChangeNotifier로 묶는다.
// 저장은 SharedPreferences + JSON, 키는 웹과 동일한 'anchigi.{name}.v1' 체계.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/anchigi/anchigi_constants.dart';
import '../../models/anchigi/anchigi_player.dart';
import '../../models/anchigi/anchigi_round.dart';
import '../../models/anchigi/anchigi_schedule.dart';
import 'anchigi_solver.dart';

String _key(String n) => 'anchigi.$n.v1';

class AnchigiStore extends ChangeNotifier {
  List<AnchigiPlayer> players = [];
  Map<String, AnchigiStat> stat = {};
  int round = 1;
  List<PastRound> pastRounds = [];
  int nGames = 3;
  String mode = 'abc';

  /// 배치 우선순위: 'custom'(맞춘 자리 우선) | 'variety'(다양성 우선).
  String prio = 'custom';

  /// 팀당 실험 자리 수. null이면 우선순위의 기본값.
  int? flexSlots;

  /// 종목: 'v6' | 'v9'.
  String sport = 'v6';

  /// 6인제 전술: '5-1'(세터 1) | '6-2'(세터 2, 전위 세터는 라이트).
  String tactic = '5-1';

  /// 보관해 둔 지난 모임.
  List<AnchigiMeet> meets = [];

  /// 결과를 코트 대신 목록으로 볼지.
  bool compact = false;

  List<String> allowed = [for (final t in kTemplates) t.id];
  AnchigiSchedule schedule = AnchigiSchedule();

  /// 아직 확정하지 않은 뽑기 결과. 설정을 건드리면 폐기된다.
  RoundResult? current;

  /// 뽑기 진행 중(버튼 비활성화용).
  bool drawing = false;

  /// 마지막 뽑기 실패 사유. 성공하면 비워진다.
  List<InfeasibleReason> failure = [];

  /// 이름 강조용으로 선택된 선수.
  String? picked;

  bool loaded = false;

  SharedPreferences? _prefs;

  // ── 파생 ──────────────────────────────────────────────────────────────────

  List<AnchigiPlayer> get present => players.where((p) => p.here).toList();

  AnchigiStat statOf(String id) => stat[id] ??= AnchigiStat();

  /// 이 종목 · 전술에서 허용된 구성(비면 첫 구성으로 폴백).
  List<AnchigiTemplate> get templates {
    final mine = templatesOfSport(sport, tactic);
    final r = mine.where((t) => allowed.contains(t.id)).toList();
    return r.isEmpty ? [mine.first] : r;
  }

  /// 이 종목의 자리 목록.
  List<String> get seats => posOfSport(sport);

  /// 인원·자리가 모자라 빈자리가 생길 상황인지(뽑기를 막지는 않는다).
  bool get shortHanded => _solver().shortHanded();

  List<int> get teamSizes {
    final s = templates.map((t) => t.size).toSet().toList()..sort();
    return s;
  }

  int get maxRounds => schedule.maxRounds(nGames);

  /// 뽑기 전 사전 진단(불가능하면 이유 목록).
  List<InfeasibleReason> get diagnosis => _solver().diagnose();

  AnchigiSolver _solver() => AnchigiSolver(_request());

  SolveRequest _request() => SolveRequest(
    present: present.map((p) => p.copy()).toList(),
    stat: {
      for (final e in stat.entries)
        e.key: AnchigiStat(
          play: e.value.play,
          bench: e.value.bench,
          pos: Map<String, int>.from(e.value.pos),
        ),
    },
    round: round,
    nGames: nGames,
    mode: mode,
    prio: prio,
    sport: sport,
    tactic: tactic,
    flexSlots: flexSlots,
    allowed: List<String>.from(allowed),
    schedule: schedule.copy(),
  );

  /// 이번 라운드에서 대기하게 될 인원 범위(표시용).
  (int, int) get benchRange {
    final n = present.length;
    final sz = teamSizes;
    var lo = n - sz.last * 2;
    var hi = n - sz.first * 2;
    if (lo < 0) lo = 0;
    if (hi < 0) hi = 0;
    return (lo, hi);
  }

  // ── 저장 ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    final sp = _prefs = await SharedPreferences.getInstance();

    T read<T>(String name, T fallback, T Function(dynamic) parse) {
      final raw = sp.getString(_key(name));
      if (raw == null || raw.isEmpty) return fallback;
      try {
        return parse(jsonDecode(raw));
      } catch (_) {
        return fallback;
      }
    }

    players = read('players', <AnchigiPlayer>[], (v) {
      return (v as List)
          .map(
            (e) => AnchigiPlayer.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    });
    stat = read('stat', <String, AnchigiStat>{}, (v) {
      final m = <String, AnchigiStat>{};
      (v as Map).forEach((k, e) {
        if (k is String) {
          m[k] = AnchigiStat.fromJson(Map<String, dynamic>.from(e as Map));
        }
      });
      return m;
    });
    round = read('round', 1, (v) => (v as num).toInt());
    nGames = read('ngames', 3, (v) => (v as num).toInt());
    mode = read('mode', 'abc', (v) => v as String);
    sport = read('sport', 'v6', (v) => v as String);
    if (!kSports.contains(sport)) sport = 'v6';
    tactic = read('tactic', '5-1', (v) => v as String);
    if (!kTactics.contains(tactic)) tactic = '5-1';
    compact = read('compact', false, (v) => v as bool);
    meets = read('meets', <AnchigiMeet>[], (v) {
      return (v as List)
          .map((e) => AnchigiMeet.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    });

    // 배치 우선순위 2단계 + 실험 자리. 예전 게임 성격 4단계를 여기로 접는다.
    final rawPrio = read<String?>('prio', null, (v) => v as String?);
    flexSlots = read<int?>('flex', null, (v) => (v as num?)?.toInt());
    if (rawPrio == null) {
      final oldFeel = read<String?>('feel', null, (v) => v as String?);
      final moved = kFeelToPrio[oldFeel];
      prio = moved?.$1 ?? 'custom';
      flexSlots ??= moved?.$2;
    } else {
      prio = rawPrio;
    }

    final allIds = [for (final t in kTemplates) t.id];
    allowed = read('tpl', allIds, (v) {
      final l = (v as List).map((e) => e as String).toList();
      return l.isEmpty ? allIds : l;
    });
    // 예전 저장본에는 새 구성(6-2 · 9인제 포메이션)이 없다 — 켜 둔 채로 시작한다.
    const legacy = ['mb2', 'mb1li', 'mb2li'];
    for (final id in allIds) {
      if (!allowed.contains(id) && !legacy.contains(id)) allowed.add(id);
    }
    schedule = read(
      'schedule',
      AnchigiSchedule(),
      (v) => AnchigiSchedule.fromJson(Map<String, dynamic>.from(v as Map)),
    );
    pastRounds = read('past', <PastRound>[], (v) {
      return (v as List)
          .map((e) => PastRound.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    });

    if (!kPrios.contains(prio)) prio = 'custom';
    if (mode != 'abc' && mode != 'free') mode = 'abc';
    if (nGames < 1 || nGames > 6) nGames = 3;
    _syncSport();

    loaded = true;
    notifyListeners();
  }

  Future<void> persist() async {
    final sp = _prefs ??= await SharedPreferences.getInstance();
    await sp.setString(
      _key('players'),
      jsonEncode(players.map((p) => p.toJson()).toList()),
    );
    await sp.setString(
      _key('stat'),
      jsonEncode({for (final e in stat.entries) e.key: e.value.toJson()}),
    );
    await sp.setString(_key('round'), jsonEncode(round));
    await sp.setString(_key('ngames'), jsonEncode(nGames));
    await sp.setString(_key('mode'), jsonEncode(mode));
    await sp.setString(_key('prio'), jsonEncode(prio));
    await sp.setString(_key('flex'), jsonEncode(flexSlots));
    await sp.setString(_key('sport'), jsonEncode(sport));
    await sp.setString(_key('tactic'), jsonEncode(tactic));
    await sp.setString(_key('compact'), jsonEncode(compact));
    await sp.setString(
      _key('meets'),
      jsonEncode(meets.map((m) => m.toJson()).toList()),
    );
    await sp.setString(_key('tpl'), jsonEncode(allowed));
    await sp.setString(_key('schedule'), jsonEncode(schedule.toJson()));
    await sp.setString(
      _key('past'),
      jsonEncode(pastRounds.map((r) => r.toJson()).toList()),
    );
  }

  /// 설정을 바꾸면 이미 뽑아둔 결과는 무효가 된다(원본과 동일).
  void _invalidate() {
    current = null;
    failure = [];
  }

  void _commitChange() {
    notifyListeners();
    persist();
  }

  // ── 설정 ──────────────────────────────────────────────────────────────────

  void setMode(String v) {
    if (mode == v) return;
    mode = v;
    _invalidate();
    _commitChange();
  }

  void setPrio(String v) {
    if (prio == v) return;
    prio = v;
    // 실험 자리는 우선순위마다 기본값이 달라 되돌린다.
    flexSlots = null;
    _invalidate();
    _commitChange();
  }

  void setFlexSlots(int v) {
    if (flexSlots == v) return;
    flexSlots = v;
    _invalidate();
    _commitChange();
  }

  /// 종목 전환. 가능 자리가 종목별로 갈리므로 명단을 다시 맞춘다.
  void setSport(String v) {
    if (sport == v || !kSports.contains(v)) return;
    sport = v;
    flexSlots = null;
    _syncSport();
    _invalidate();
    _commitChange();
  }

  /// 6인제 전술 전환(5-1 ↔ 6-2).
  void setTactic(String v) {
    if (tactic == v || !kTactics.contains(v)) return;
    tactic = v;
    _invalidate();
    _commitChange();
  }

  void setCompact(bool v) {
    if (compact == v) return;
    compact = v;
    notifyListeners();
    persist();
  }

  /// 명단의 자리 판정이 현재 종목을 따르게 한다.
  void _syncSport() {
    for (final p in players) {
      p.sport = sport;
    }
  }

  /// 팀당 실험 자리 수(설정 안 했으면 우선순위 기본값).
  int get flexSlotsEffective {
    final v = flexSlots ?? prioOf(prio).flex;
    return v < 0 ? 0 : (v > kMaxBudget ? kMaxBudget : v);
  }

  void setNGames(int v) {
    if (nGames == v) return;
    nGames = v;
    _invalidate();
    _commitChange();
  }

  /// 구성 토글. 이 종목 · 전술에서 마지막 하나 남은 구성은 끌 수 없다.
  void toggleTemplate(String id) {
    if (allowed.contains(id)) {
      final onNow = templatesOfSport(
        sport,
        tactic,
      ).where((t) => allowed.contains(t.id)).length;
      if (onNow <= 1) return;
      allowed = allowed.where((t) => t != id).toList();
    } else {
      // kTemplates 순서를 유지해야 표시가 흔들리지 않는다.
      allowed = kTemplates
          .map((t) => t.id)
          .where((t) => t == id || allowed.contains(t))
          .toList();
    }
    _invalidate();
    _commitChange();
  }

  void setSchedule({
    String? start,
    String? warmup,
    String? end,
    int? perGame,
    int? rest,
  }) {
    schedule.start = start ?? schedule.start;
    schedule.warmup = warmup ?? schedule.warmup;
    schedule.end = end ?? schedule.end;
    schedule.perGame = perGame ?? schedule.perGame;
    schedule.rest = rest ?? schedule.rest;
    _invalidate();
    _commitChange();
  }

  // ── 명단 ──────────────────────────────────────────────────────────────────

  void addPlayer(String name, Map<String, String> tier) {
    final p = AnchigiPlayer(
      id: genPlayerId(),
      name: name.trim(),
      tier: Map<String, String>.from(tier),
      sport: sport,
    )..normalize();
    players.add(p);
    _invalidate();
    _commitChange();
  }

  /// 여러 명 한 번에 — 줄바꿈 · 쉼표 · 가운뎃점으로 끊어 넣는다.
  /// 자리는 안 고른 채('어디든') 들어가므로 이름만 붙여넣고 바로 뽑을 수 있다.
  int addPlayers(String raw) {
    final names = raw
        .split(RegExp(r'[\n,·]+'))
        .map((x) => x.trim())
        .where((x) => x.isNotEmpty)
        .toList();
    if (names.isEmpty) return 0;
    for (final n in names) {
      players.add(
        AnchigiPlayer(id: genPlayerId(), name: n, sport: sport)..normalize(),
      );
    }
    _invalidate();
    _commitChange();
    return names.length;
  }

  /// 📌 — 주 자리에 고정. '어디든'인 사람은 고정할 자리가 없어 무시한다.
  void togglePin(String id) {
    final p = players.firstWhere((q) => q.id == id);
    if (p.pin[sport] != null) {
      p.pin.remove(sport);
    } else {
      if (p.isFlex) return;
      final m = p.mainPos;
      if (m == null) return;
      p.pin[sport] = m;
    }
    _invalidate();
    _commitChange();
  }

  void setPinTeam(String id, int? team) {
    final p = players.firstWhere((q) => q.id == id);
    p.pinTeam = team;
    _invalidate();
    _commitChange();
  }

  bool hasName(String name) => players.any((p) => p.name.trim() == name.trim());

  void removePlayer(String id) {
    players.removeWhere((p) => p.id == id);
    stat.remove(id);
    if (picked == id) picked = null;
    _invalidate();
    _commitChange();
  }

  void renamePlayer(String id, String name) {
    final p = players.firstWhere((q) => q.id == id);
    p.name = name.trim();
    _commitChange();
  }

  void setHere(String id, bool v) {
    players.firstWhere((q) => q.id == id).here = v;
    _invalidate();
    _commitChange();
  }

  void setAllHere(bool v) {
    for (final p in players) {
      p.here = v;
    }
    _invalidate();
    _commitChange();
  }

  void setLeave(String id, String? leave) {
    players.firstWhere((q) => q.id == id).leave = leave;
    _invalidate();
    _commitChange();
  }

  void clearRoster() {
    players = [];
    stat = {};
    picked = null;
    _invalidate();
    _commitChange();
  }

  /// 포지션 칩 순환: 없음 → (주가 있으면 가능, 없으면 주) → 도전 → 없음.
  /// 주를 지우면 남은 포지션 중 첫 번째가 자동 승격되고,
  /// 포지션이 하나뿐이면 지울 수 없다.
  void cycleTier(String id, String pos) {
    final p = players.firstWhere((q) => q.id == id);
    // 저장된 티어를 본다 — '어디든'을 주 자리로 보정하면 첫 클릭이 먹지 않는다.
    final t = p.rawTier(pos);

    if (t == null) {
      p.tier[pos] = p.mainCount > 0 ? 'sub' : 'main';
    } else if (t == 'main') {
      // 마지막 한 자리까지 뺄 수 있다 — 다 빼면 '어디든'으로 돌아간다.
      p.tier.remove(pos);
      final rest = seats.where((q) => p.tier[q] != null).toList();
      if (rest.isNotEmpty && p.mainCount == 0) p.tier[rest.first] = 'main';
    } else if (t == 'sub') {
      p.tier[pos] = 'want';
    } else {
      p.tier.remove(pos);
    }

    // 고정해 둔 자리를 스스로 지웠으면 고정도 같이 풀린다.
    final pinnedSeat = p.pin[sport];
    if (pinnedSeat != null && p.tier[pinnedSeat] == null) p.pin.remove(sport);

    p.normalize();
    _invalidate();
    _commitChange();
  }

  /// ☆ — 이 포지션을 주 포지션으로. 기존 주는 가능으로 내린다.
  void promoteTier(String id, String pos) {
    final p = players.firstWhere((q) => q.id == id);
    if (p.rawTier(pos) == null || p.rawTier(pos) == 'main') return;
    p.tier.updateAll((k, v) => v == 'main' ? 'sub' : v);
    p.tier[pos] = 'main';
    _invalidate();
    _commitChange();
  }

  void pick(String? id) {
    picked = (picked == id) ? null : id;
    notifyListeners();
  }

  // ── 뽑기 / 확정 ───────────────────────────────────────────────────────────

  /// 라운드 배치를 뽑는다. 솔버가 무거워 Isolate에서 돌린다.
  Future<void> draw() async {
    if (drawing) return;
    drawing = true;
    failure = [];
    notifyListeners();

    RoundResult? r;
    try {
      r = await compute(solveRoundIsolate, _request());
    } catch (_) {
      r = null;
    }

    current = r;
    // 사전 진단은 통과했는데 못 뽑은 경우 — 조합 자체가 안 나온 것.
    failure = r == null ? const [InfeasibleReason('generic')] : [];
    drawing = false;
    notifyListeners();
  }

  /// 뽑은 결과를 확정. 이때만 누적 기록이 쌓인다.
  void commit() {
    final c = current;
    if (c == null) return;
    for (final g in c.games) {
      for (final team in g.teams) {
        for (final a in team) {
          if (a.empty) continue;
          final s = statOf(a.id);
          s.play++;
          s.pos[a.pos] = (s.pos[a.pos] ?? 0) + 1;
        }
      }
      for (final b in g.bench) {
        statOf(b.id).bench++;
      }
    }
    pastRounds.add(
      PastRound(
        round: c.round,
        games: c.games,
        mode: c.mode,
        sport: c.sport,
      ),
    );
    round++;
    current = null;
    _commitChange();
  }

  /// 기록만 초기화. 명단은 남긴다(원본과 동일).
  void resetStats() {
    stat = {};
    round = 1;
    pastRounds = [];
    _invalidate();
    _commitChange();
  }

  // ── 모임 보관 / 백업 ──────────────────────────────────────────────────────

  static String todayStr() {
    final d = DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }

  /// 이번 모임을 보관하고 누적 기록만 새로 시작한다. 명단은 그대로 둔다.
  bool archiveMeet() {
    if (round <= 1 && pastRounds.isEmpty) return false;
    meets.insert(
      0,
      AnchigiMeet(
        date: todayStr(),
        rounds: round - 1 < 0 ? 0 : round - 1,
        sport: sport,
        stat: {for (final e in stat.entries) e.key: e.value.toJson()},
        past: List<PastRound>.from(pastRounds),
      ),
    );
    stat = {};
    round = 1;
    pastRounds = [];
    _invalidate();
    _commitChange();
    return true;
  }

  void deleteMeet(int index) {
    if (index < 0 || index >= meets.length) return;
    meets.removeAt(index);
    _commitChange();
  }

  /// 백업 JSON. 기기를 바꾸거나 앱을 지워도 명단·기록이 남게.
  String exportJson() => jsonEncode({
    'app': 'anchigi',
    'v': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'players': players.map((p) => p.toJson()).toList(),
    'stat': {for (final e in stat.entries) e.key: e.value.toJson()},
    'round': round,
    'past': pastRounds.map((r) => r.toJson()).toList(),
    'meets': meets.map((m) => m.toJson()).toList(),
    'settings': {
      'sport': sport,
      'tactic': tactic,
      'mode': mode,
      'prio': prio,
      'flex': flexSlots,
      'tpl': allowed,
      'ngames': nGames,
      'schedule': schedule.toJson(),
    },
  });

  /// 백업 JSON 을 그대로 덮어쓴다. 읽을 수 없으면 false.
  bool importJson(String raw) {
    Map<String, dynamic> d;
    try {
      final v = jsonDecode(raw);
      if (v is! Map) return false;
      d = Map<String, dynamic>.from(v);
    } catch (_) {
      return false;
    }
    if (d['players'] is! List) return false;

    final sg = d['settings'] is Map
        ? Map<String, dynamic>.from(d['settings'] as Map)
        : <String, dynamic>{};
    if (kSports.contains(sg['sport'])) sport = sg['sport'] as String;
    if (kTactics.contains(sg['tactic'])) tactic = sg['tactic'] as String;

    players = (d['players'] as List)
        .map((e) => AnchigiPlayer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    stat = {};
    if (d['stat'] is Map) {
      (d['stat'] as Map).forEach((k, v) {
        if (k is String && v is Map) {
          stat[k] = AnchigiStat.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }
    round = (d['round'] as num?)?.toInt() ?? 1;
    pastRounds = (d['past'] as List? ?? [])
        .map((e) => PastRound.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    meets = (d['meets'] as List? ?? [])
        .map((e) => AnchigiMeet.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final m = sg['mode'];
    if (m == 'abc' || m == 'free') mode = m as String;
    if (kPrios.contains(sg['prio'])) prio = sg['prio'] as String;
    flexSlots = (sg['flex'] as num?)?.toInt();
    final tpl = sg['tpl'];
    if (tpl is List && tpl.isNotEmpty) {
      allowed = tpl.map((e) => e.toString()).toList();
      for (final t in kTemplates) {
        if (!allowed.contains(t.id) && t.sport == 'v9') allowed.add(t.id);
      }
    }
    final ng = (sg['ngames'] as num?)?.toInt();
    if (ng != null && ng >= 1 && ng <= 6) nGames = ng;
    if (sg['schedule'] is Map) {
      schedule = AnchigiSchedule.fromJson(
        Map<String, dynamic>.from(sg['schedule'] as Map),
      );
    }
    _syncSport();
    _invalidate();
    _commitChange();
    return true;
  }
}
