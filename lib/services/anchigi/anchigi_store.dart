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
  String feel = 'real';
  List<String> allowed = ['mb2', 'mb1li', 'mb2li'];
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

  /// 허용된 템플릿(비면 첫 템플릿으로 폴백).
  List<AnchigiTemplate> get templates {
    final r = kTemplates.where((t) => allowed.contains(t.id)).toList();
    return r.isEmpty ? [kTemplates[0]] : r;
  }

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
    feel: feel,
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
    feel = read('feel', 'real', (v) => v as String);
    allowed = read('tpl', ['mb2', 'mb1li', 'mb2li'], (v) {
      final l = (v as List).map((e) => e as String).toList();
      return l.isEmpty ? ['mb2', 'mb1li', 'mb2li'] : l;
    });
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

    if (!kFeels.contains(feel)) feel = 'real';
    if (mode != 'abc' && mode != 'free') mode = 'abc';
    if (nGames < 1 || nGames > 6) nGames = 3;

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
    await sp.setString(_key('feel'), jsonEncode(feel));
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

  void setFeel(String v) {
    if (feel == v) return;
    feel = v;
    _invalidate();
    _commitChange();
  }

  void setNGames(int v) {
    if (nGames == v) return;
    nGames = v;
    _invalidate();
    _commitChange();
  }

  /// 템플릿 토글. 마지막 하나는 끌 수 없다.
  void toggleTemplate(String id) {
    if (allowed.contains(id)) {
      if (allowed.length <= 1) return;
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
    )..normalize();
    players.add(p);
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
    final t = p.tier[pos];

    if (t == null) {
      p.tier[pos] = p.mainCount > 0 ? 'sub' : 'main';
    } else if (t == 'main') {
      if (p.pos.length == 1) return; // 마지막 포지션은 유지
      p.tier.remove(pos);
      final rest = p.pos;
      if (rest.isNotEmpty && p.mainCount == 0) p.tier[rest.first] = 'main';
    } else if (t == 'sub') {
      p.tier[pos] = 'want';
    } else {
      if (p.pos.length == 1) return;
      p.tier.remove(pos);
    }

    p.normalize();
    _invalidate();
    _commitChange();
  }

  /// ☆ — 이 포지션을 주 포지션으로. 기존 주는 가능으로 내린다.
  void promoteTier(String id, String pos) {
    final p = players.firstWhere((q) => q.id == id);
    if (p.tier[pos] == null || p.tier[pos] == 'main') return;
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

    final pre = _solver().diagnose();
    if (pre.isNotEmpty) {
      current = null;
      failure = pre;
      drawing = false;
      notifyListeners();
      return;
    }

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
          final s = statOf(a.id);
          s.play++;
          s.pos[a.pos] = (s.pos[a.pos] ?? 0) + 1;
        }
      }
      for (final b in g.bench) {
        statOf(b.id).bench++;
      }
    }
    pastRounds.add(PastRound(round: c.round, games: c.games, mode: c.mode));
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
}
