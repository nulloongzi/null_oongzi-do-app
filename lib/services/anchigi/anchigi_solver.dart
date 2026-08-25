// anchigi_solver.dart — 라운드 배치 솔버. 원본 anchigi.html의 CSP 백트래킹 이식.
// 순수 Dart(Flutter import 금지) — compute()로 Isolate에서 돌리기 위함.
//
// 원본과 의도적으로 다른 점(결과에 영향 있음):
//  1) 후보 정렬 jitter: 원본은 comparator 안에서 매번 Math.random()을 호출해
//     비추이적 비교를 만든다. Dart의 sort는 그런 comparator에 취약하므로
//     후보별로 (비용 + 난수*1.6) 키를 한 번 계산해 정렬한다.
//  2) 코어 배정을 Player 객체 변이(p.core) 대신 Map<String,int>로 관리한다.
import 'dart:math';

import '../../models/anchigi/anchigi_constants.dart';
import '../../models/anchigi/anchigi_player.dart';
import '../../models/anchigi/anchigi_round.dart';
import '../../models/anchigi/anchigi_schedule.dart';

/// 배치가 불가능한 이유. 문자열 조립은 UI(i18n) 쪽에서 한다.
class InfeasibleReason {
  /// 'short' | 'only' | 'few' | 'abc' | 'generic'
  final String kind;
  final Map<String, String> params;

  const InfeasibleReason(this.kind, [this.params = const {}]);
}

/// 솔버 입력 묶음. compute()로 Isolate에 넘길 수 있도록 평범한 객체만 담는다.
class SolveRequest {
  final List<AnchigiPlayer> present;
  final Map<String, AnchigiStat> stat;
  final int round;
  final int nGames;
  final String mode;
  final String feel;
  final List<String> allowed;
  final AnchigiSchedule schedule;

  const SolveRequest({
    required this.present,
    required this.stat,
    required this.round,
    required this.nGames,
    required this.mode,
    required this.feel,
    required this.allowed,
    required this.schedule,
  });
}

/// compute() 진입점. 배치에 실패하면 null.
RoundResult? solveRoundIsolate(SolveRequest req) =>
    AnchigiSolver(req).solveRound();

/// 스냅샷 한 명분(원본 sc[id]).
class _Snap {
  int play;
  int bench;
  final bool early;
  final Map<String, int> fit;
  final Map<String, int> pos;

  _Snap({
    required this.play,
    required this.bench,
    required this.early,
    required this.fit,
    required this.pos,
  });
}

/// 스냅샷 전체(원본 sc + sc.__avgPlay).
class _Sc {
  final Map<String, _Snap> byId;
  double avgPlay;

  _Sc(this.byId, this.avgPlay);
}

/// 채워야 할 자리 하나.
class _Slot {
  final int team;
  final String pos;

  /// 이 자리에 들어올 수 있는 코어 번호. null이면 제한 없음.
  final List<int>? allow;

  const _Slot(this.team, this.pos, this.allow);
}

class _Assign {
  final String id;
  final String name;
  final String pos;
  final int team;

  const _Assign(this.id, this.name, this.pos, this.team);
}

class AnchigiSolver {
  final List<AnchigiPlayer> present;
  final Map<String, AnchigiStat> stat;
  final int round;
  final int nGames;
  final String mode;
  final String feel;
  final List<String> allowed;
  final AnchigiSchedule schedule;
  final Random _rnd = Random();

  /// 이번 뽑기에서 실제로 쓴 비주 예산(완화 여부 판단용).
  int usedBudget = 0;

  /// ABC 모드 코어 배정 결과(원본의 p.core 대체).
  Map<String, int> _coreOf = {};

  AnchigiSolver(SolveRequest req)
    : present = req.present,
      stat = req.stat,
      round = req.round,
      nGames = req.nGames,
      mode = req.mode,
      feel = req.feel,
      allowed = req.allowed,
      schedule = req.schedule;

  FeelWeights get _f => feelOf(feel);

  int get _budStart => min(_f.budget, kMaxBudget);

  AnchigiStat _st(String id) => stat[id] ?? AnchigiStat();

  // ── 템플릿 ────────────────────────────────────────────────────────────────

  List<AnchigiTemplate> _tpls() {
    final r = kTemplates.where((t) => allowed.contains(t.id)).toList();
    return r.isEmpty ? [kTemplates[0]] : r;
  }

  List<int> _sizes() {
    final s = _tpls().map((t) => t.size).toSet().toList()..sort();
    return s;
  }

  List<AnchigiTemplate> _tplsOfSize(int sz) =>
      _tpls().where((t) => t.size == sz).toList();

  // ── 시간 ──────────────────────────────────────────────────────────────────

  bool _isEarly(AnchigiPlayer p) {
    final l = parseTime(p.leave), e = parseTime(schedule.end);
    return l != null && e != null && l < e;
  }

  /// 이 경기가 끝날 때까지 남아 있는 사람만.
  List<AnchigiPlayer> _availForGame(List<AnchigiPlayer> pool, int rnd, int gi) {
    final ge = schedule.gameEndMin(rnd, gi, nGames);
    return pool.where((p) {
      if (p.leave == null || p.leave!.isEmpty) return true;
      final l = parseTime(p.leave);
      return l == null || l >= ge;
    }).toList();
  }

  // ── 점수 ──────────────────────────────────────────────────────────────────

  _Sc _snapshot(List<AnchigiPlayer> pool) {
    final by = <String, _Snap>{};
    var sum = 0.0;
    for (final p in pool) {
      final s = _st(p.id);
      by[p.id] = _Snap(
        play: s.play,
        bench: s.bench,
        early: _isEarly(p),
        fit: {for (final q in kPos) q: p.fitOf(q)},
        pos: {for (final q in kPos) q: s.pos[q] ?? 0},
      );
      sum += s.play;
    }
    return _Sc(by, pool.isEmpty ? 0 : sum / pool.length);
  }

  /// 라운드 안에서 경기가 끝날 때마다 평균 출전을 다시 계산.
  void _refreshAvg(_Sc sc) {
    if (sc.byId.isEmpty) {
      sc.avgPlay = 0;
      return;
    }
    var sum = 0.0;
    for (final s in sc.byId.values) {
      sum += s.play;
    }
    sc.avgPlay = sum / sc.byId.length;
  }

  /// 이 선수를 이 자리에 앉히는 비용. 낮을수록 먼저 뽑힌다.
  double _slotCost(String id, String pos, _Sc sc, int nOpt) {
    final s = sc.byId[id]!;
    final f = _f;
    var c = s.play * f.playW;
    // 적합도: 주 자리면 0, 가능이면 fitW, 도전이면 2×fitW.
    c += (2 - (s.fit[pos] ?? 0)) * f.fitW;
    // 포지션 선택지가 적은 사람일수록 비용이 낮아 먼저 자리를 잡는다.
    c -= (kPos.length - nOpt) * 1.0;
    if (s.early) c -= kEarlySlotBonus;
    if (nOpt > 1) {
      final cnt = s.pos[pos] ?? 0;
      c += cnt * f.varietyW;
      // 센터는 반복 부담이 커서 한 번 더 가중(원본과 동일).
      if (pos == 'MB') c += (s.pos['MB'] ?? 0) * f.varietyW;
      if (cnt == 0) c -= f.newBonus;
    }
    if (pos == 'S' && nOpt == 1 && s.play >= sc.avgPlay + kSetterOveruseN) {
      // 세터 전용인데 많이 뛰었으면 다른 사람이 세터를 볼 여지를 준다.
      c += (s.play - sc.avgPlay) * 3.0;
    }
    return c;
  }

  double _benchCost(String id, _Sc sc, double avgPlay) {
    final s = sc.byId[id]!;
    return (avgPlay - s.play) * 3.5 +
        s.bench * 4.0 +
        (s.early ? kEarlyBenchPenalty : 0.0);
  }

  /// 배치 하나를 완성된 경기 결과로. 대기 비용과 팀 균형까지 합산한다.
  GameResult _finish(
    List<AnchigiPlayer> pool,
    _Sc sc,
    List<_Assign?> assign,
    List<String> teamNames,
  ) {
    final teams = <List<SlotAssign>>[[], []];
    final used = <String>{};
    final capOf = {for (final q in pool) q.id: q.pos.length};
    var cost = 0.0;

    for (final a in assign) {
      if (a == null) continue;
      teams[a.team].add(SlotAssign(id: a.id, name: a.name, pos: a.pos));
      used.add(a.id);
      cost += _slotCost(a.id, a.pos, sc, capOf[a.id] ?? 1);
    }

    final bench = pool
        .where((q) => !used.contains(q.id))
        .map((q) => PlayerRef(id: q.id, name: q.name))
        .toList();

    // 주의: 대기 비용의 평균은 이 경기의 present 기준으로 따로 구한다.
    // slotCost의 sc.avgPlay(라운드 단위)와는 다른 값이며 원본도 그렇다.
    var avg = 0.0;
    for (final q in pool) {
      avg += sc.byId[q.id]!.play;
    }
    if (pool.isNotEmpty) avg /= pool.length;
    for (final b in bench) {
      cost += _benchCost(b.id, sc, avg);
    }

    final fitSum = [0.0, 0.0];
    final nOn = [0, 0];
    final nonMain = [0, 0];
    for (final a in assign) {
      if (a == null) continue;
      final fv = sc.byId[a.id]!.fit[a.pos] ?? 0;
      fitSum[a.team] += fv;
      nOn[a.team]++;
      if (fv < 2) nonMain[a.team]++;
    }
    final gap =
        (fitSum[0] / (nOn[0] == 0 ? 1 : nOn[0]) -
                fitSum[1] / (nOn[1] == 0 ? 1 : nOn[1]))
            .abs();
    cost += gap * _f.balanceW * 6;

    return GameResult(
      teams: teams,
      names: teamNames,
      bench: bench,
      cost: cost,
      fitGap: gap,
      nonMain: nonMain,
    );
  }

  // ── 탐색 ──────────────────────────────────────────────────────────────────

  List<_Slot> _mkSlots(
    AnchigiTemplate a,
    AnchigiTemplate b, [
    List<int>? allowA,
    List<int>? allowB,
  ]) => [
    for (final p in a.slots) _Slot(0, p, allowA),
    for (final p in b.slots) _Slot(1, p, allowB),
  ];

  /// MRV 백트래킹. 해를 못 찾거나 노드 한도를 넘으면 null.
  List<_Assign?>? _search(
    List<AnchigiPlayer> pool,
    _Sc sc,
    List<_Slot> slots,
    List<Set<String>>? must,
    int nodeCap,
    int? slotBudget,
  ) {
    final n = slots.length;
    final used = <String>{};
    final assign = List<_Assign?>.filled(n, null);
    var nodes = 0;
    final left = [0, 0];
    final need = [0, 0];
    final nm = [0, 0];
    final maxNM = slotBudget ?? 99;

    for (final s in slots) {
      left[s.team]++;
    }
    if (must != null) {
      for (final p in pool) {
        if (must[0].contains(p.id)) {
          need[0]++;
        } else if (must[1].contains(p.id)) {
          need[1]++;
        }
      }
    }

    bool ok(AnchigiPlayer p, _Slot sl) {
      if (used.contains(p.id)) return false;
      if (!p.tier.containsKey(sl.pos)) return false;
      if (sl.allow != null && !sl.allow!.contains(_coreOf[p.id])) return false;
      if (must != null && must[1 - sl.team].contains(p.id)) return false;
      if (p.tierOf(sl.pos) != 'main' && nm[sl.team] >= maxNM) return false;
      return true;
    }

    bool bt(int depth) {
      // 코어 인원이 남은 자리보다 많으면 가망 없음.
      // 이 검사는 depth==N보다 먼저 와야 마지막 슬롯에서 코어가 대기로 새지 않는다.
      if (must != null && (need[0] > left[0] || need[1] > left[1])) {
        return false;
      }
      if (depth == n) return true;
      if (++nodes > nodeCap) return false;

      // MRV: 채울 수 있는 후보가 가장 적은 자리부터.
      var bi = -1;
      List<AnchigiPlayer>? bc;
      for (var k = 0; k < n; k++) {
        if (assign[k] != null) continue;
        final c = <AnchigiPlayer>[];
        for (final q in pool) {
          if (ok(q, slots[k])) c.add(q);
        }
        if (bc == null || c.length < bc.length) {
          bi = k;
          bc = c;
        }
        if (c.isEmpty) break;
      }
      if (bc == null || bc.isEmpty) return false;

      // 싼 후보부터, 다만 매번 다른 결과가 나오도록 난수를 섞는다.
      final slot = slots[bi];
      final keyed =
          bc
              .map(
                (p) => (
                  p: p,
                  key:
                      _slotCost(p.id, slot.pos, sc, p.pos.length) +
                      _rnd.nextDouble() * 1.6,
                ),
              )
              .toList()
            ..sort((x, y) => x.key.compareTo(y.key));

      final tm = slot.team;
      for (final e in keyed) {
        final p = e.p;
        final isNM = p.tierOf(slot.pos) != 'main';
        used.add(p.id);
        assign[bi] = _Assign(p.id, p.name, slot.pos, tm);
        left[tm]--;
        if (must != null && must[tm].contains(p.id)) need[tm]--;
        if (isNM) nm[tm]++;
        if (bt(depth + 1)) return true;
        left[tm]++;
        if (must != null && must[tm].contains(p.id)) need[tm]++;
        if (isNM) nm[tm]--;
        used.remove(p.id);
        assign[bi] = null;
      }
      return false;
    }

    return bt(0) ? assign : null;
  }

  // ── 코어 분할(ABC) ────────────────────────────────────────────────────────

  /// 이 인원이 템플릿을 채울 수 있는지(단순 이분매칭). 티어는 보지 않는다.
  bool _fitsTemplate(List<AnchigiPlayer> members, AnchigiTemplate tpl) {
    final ms = members.toList()
      ..sort((a, b) => a.pos.length.compareTo(b.pos.length));
    final slots = tpl.slots;
    final used = List<bool>.filled(slots.length, false);

    bool bt(int i) {
      if (i == ms.length) return true;
      for (var k = 0; k < slots.length; k++) {
        if (used[k] || !ms[i].tier.containsKey(slots[k])) continue;
        used[k] = true;
        if (bt(i + 1)) return true;
        used[k] = false;
      }
      return false;
    }

    return bt(0);
  }

  bool _coreFits(List<AnchigiPlayer> core, int t) {
    for (final o in _tplsOfSize(t)) {
      if (_fitsTemplate(core, o)) return true;
    }
    return false;
  }

  /// A·B는 정확히 T명, C는 나머지. 참석이 2T~3T가 아니면 불가.
  List<int>? _coreSizes(int n, int t) {
    if (n < 2 * t || n > 3 * t) return null;
    return [t, t, n - 2 * t];
  }

  List<List<AnchigiPlayer>>? _makeCores(
    List<AnchigiPlayer> pool,
    List<int> szs,
    int t,
  ) {
    var avgP = 0.0;
    for (final p in pool) {
      avgP += _st(p.id).play;
    }
    if (pool.isNotEmpty) avgP /= pool.length;

    bool overusedSetter(AnchigiPlayer p) {
      final ps = p.pos;
      return ps.length == 1 &&
          ps[0] == 'S' &&
          _st(p.id).play >= avgP + kSetterOveruseN;
    }

    // 유연성이 낮은 사람부터 배정해야 자리가 막히지 않는다.
    // 과다 출전 세터 전용은 뒤로 밀어 작은 C 코어로 가게 한다.
    final byFlex =
        pool
            .map(
              (p) => (
                p: p,
                over: overusedSetter(p) ? 1 : 0,
                flex: p.pos.length,
                jit: _rnd.nextDouble(),
              ),
            )
            .toList()
          ..sort((a, b) {
            if (a.over != b.over) return a.over - b.over;
            if (a.flex != b.flex) return a.flex - b.flex;
            return a.jit.compareTo(b.jit);
          });

    final cores = <List<AnchigiPlayer>>[[], [], []];
    final coreOf = <String, int>{};

    for (final e in byFlex) {
      final p = e.p;
      final order =
          [0, 1, 2]
              .where(
                (c) =>
                    cores[c].length < szs[c] && _coreFits([...cores[c], p], t),
              )
              .map(
                (c) => (
                  c: c,
                  room: szs[c] - cores[c].length,
                  jit: _rnd.nextDouble(),
                ),
              )
              .toList()
            // 남은 자리가 많은 코어부터 채운다.
            ..sort((a, b) {
              if (a.room != b.room) return b.room - a.room;
              return a.jit.compareTo(b.jit);
            });
      if (order.isEmpty) return null;
      final c = order.first.c;
      cores[c].add(p);
      coreOf[p.id] = c;
    }

    _coreOf = coreOf;
    return cores;
  }

  // ── 경기 풀이 ─────────────────────────────────────────────────────────────

  GameResult? _solveGameABC(
    List<AnchigiPlayer> pool,
    _Sc sc,
    int t,
    int gi,
    int tries,
    int bud,
  ) {
    final pr = kPairs[gi % 3];
    final x = pr[0], y = pr[1], z = pr[2];
    final must = [<String>{}, <String>{}];
    for (final p in pool) {
      final c = _coreOf[p.id];
      if (c == x) {
        must[0].add(p.id);
      } else if (c == y) {
        must[1].add(p.id);
      }
    }
    final names = [kTeamName[x], kTeamName[y]];
    final opts = _tplsOfSize(t);
    // 각 팀은 자기 코어 + 쉬는 코어(Z)에서만 차출한다.
    final allowA = [x, z], allowB = [y, z];

    GameResult? probe;
    for (var i = 0; i < opts.length && probe == null; i++) {
      for (var j = 0; j < opts.length && probe == null; j++) {
        final as = _search(
          pool,
          sc,
          _mkSlots(opts[i], opts[j], allowA, allowB),
          must,
          6000,
          bud,
        );
        if (as != null) probe = _finish(pool, sc, as, names);
      }
    }
    if (probe == null) return null;

    var best = probe;
    // 원본의 `tries || 40`: 0이 넘어오면 40회가 된다(그대로 유지).
    final n = tries == 0 ? 40 : tries;
    for (var i = 0; i < n; i++) {
      final a = opts[_rnd.nextInt(opts.length)];
      final b = opts[_rnd.nextInt(opts.length)];
      final as = _search(
        pool,
        sc,
        _mkSlots(a, b, allowA, allowB),
        must,
        3000,
        bud,
      );
      if (as == null) continue;
      final r = _finish(pool, sc, as, names);
      if (r.cost < best.cost) best = r;
    }
    return best;
  }

  GameResult? _solveGameFree(List<AnchigiPlayer> pool, _Sc sc, int tries) {
    final opts = _tpls();
    GameResult? probe;
    var bud = _budStart;
    for (; bud <= kMaxBudget && probe == null; bud++) {
      for (var i = 0; i < opts.length && probe == null; i++) {
        for (var j = 0; j < opts.length && probe == null; j++) {
          if (opts[i].size + opts[j].size > pool.length) continue;
          final as = _search(
            pool,
            sc,
            _mkSlots(opts[i], opts[j]),
            null,
            20000,
            bud,
          );
          if (as != null) {
            probe = _finish(pool, sc, as, ['A', 'B']);
            usedBudget = bud;
          }
        }
      }
    }
    if (probe == null) return null;

    bud = usedBudget;
    var best = probe;
    final n = tries == 0 ? 60 : tries;
    for (var i = 0; i < n; i++) {
      final a = opts[_rnd.nextInt(opts.length)];
      final b = opts[_rnd.nextInt(opts.length)];
      if (a.size + b.size > pool.length) continue;
      final as = _search(pool, sc, _mkSlots(a, b), null, 3000, bud);
      if (as == null) continue;
      final r = _finish(pool, sc, as, ['A', 'B']);
      if (r.cost < best.cost) best = r;
    }
    return best;
  }

  // ── 라운드 풀이 ───────────────────────────────────────────────────────────

  List<GameResult>? _runRoundABC(int t, bool quality, int bud) {
    final szs = _coreSizes(present.length, t);
    if (szs == null) return null;
    final cores = _makeCores(present, szs, t);
    if (cores == null) return null;
    for (final c in cores) {
      if (!_coreFits(c, t)) return null;
    }

    final sc = _snapshot(present);
    final games = <GameResult>[];
    final coreRefs = [
      for (var c = 0; c < 3; c++)
        present
            .where((p) => _coreOf[p.id] == c)
            .map((p) => PlayerRef(id: p.id, name: p.name))
            .toList(),
    ];

    for (var i = 0; i < nGames; i++) {
      final avail = _availForGame(present, round, i);
      final availIds = avail.map((p) => p.id).toSet();
      final g = _solveGameABC(avail, sc, t, i, quality ? 20 : 0, bud);
      if (g == null) return null;

      games.add(
        g.copyWith(
          left: present
              .where((p) => !availIds.contains(p.id))
              .map((p) => PlayerRef(id: p.id, name: p.name))
              .toList(),
          cores: coreRefs,
        ),
      );

      for (final team in g.teams) {
        for (final a in team) {
          final s = sc.byId[a.id]!;
          s.play++;
          s.pos[a.pos] = (s.pos[a.pos] ?? 0) + 1;
        }
      }
      for (final b in g.bench) {
        sc.byId[b.id]!.bench++;
      }
      _refreshAvg(sc);
    }
    return games;
  }

  RoundResult? _solveRoundABC() {
    final szList = _sizes()
        .where((t) => _coreSizes(present.length, t) != null)
        .toList();
    if (szList.isEmpty) return null;

    List<GameResult>? found;
    var bestT = 0, bestBud = 0;
    // 예산 완화는 최후의 수단 — 각 예산에서 코어를 80번 다시 짜본 뒤에야 올린다.
    for (var bud = _budStart; bud <= kMaxBudget && found == null; bud++) {
      for (var i = 0; i < 80 && found == null; i++) {
        final t = szList[_rnd.nextInt(szList.length)];
        final r = _runRoundABC(t, false, bud);
        if (r != null) {
          found = r;
          bestT = t;
          bestBud = bud;
          usedBudget = bud;
        }
      }
    }
    if (found == null) return null;

    var best = found;
    var bestCost = _totalCost(found);
    for (var k = 0; k < 6; k++) {
      final r = _runRoundABC(bestT, true, bestBud);
      if (r != null && _totalCost(r) < bestCost) {
        best = r;
        bestCost = _totalCost(r);
      }
    }
    return RoundResult(
      round: round,
      games: best,
      mode: mode,
      feel: feel,
      budget: usedBudget,
      teamSize: bestT,
    );
  }

  RoundResult? _solveRoundFree() {
    final sc = _snapshot(present);
    final games = <GameResult>[];
    var maxBud = _budStart;

    for (var i = 0; i < nGames; i++) {
      final avail = _availForGame(present, round, i);
      final availIds = avail.map((p) => p.id).toSet();
      final g = _solveGameFree(avail, sc, 0);
      if (g == null) return null;
      if (usedBudget > maxBud) maxBud = usedBudget;

      games.add(
        g.copyWith(
          left: present
              .where((p) => !availIds.contains(p.id))
              .map((p) => PlayerRef(id: p.id, name: p.name))
              .toList(),
        ),
      );

      for (final team in g.teams) {
        for (final a in team) {
          final s = sc.byId[a.id]!;
          s.play++;
          s.pos[a.pos] = (s.pos[a.pos] ?? 0) + 1;
        }
      }
      for (final b in g.bench) {
        sc.byId[b.id]!.bench++;
      }
      _refreshAvg(sc);
    }

    usedBudget = maxBud;
    return RoundResult(
      round: round,
      games: games,
      mode: mode,
      feel: feel,
      budget: maxBud,
    );
  }

  double _totalCost(List<GameResult> gs) => gs.fold(0.0, (s, g) => s + g.cost);

  RoundResult? solveRound() {
    if (quickInfeasible() != null) return null;
    return mode == 'abc' ? _solveRoundABC() : _solveRoundFree();
  }

  // ── 사전 진단 ─────────────────────────────────────────────────────────────

  int _maxSlotFor(String p) {
    var m = 0;
    for (final t in _tpls()) {
      final c = t.slots.where((s) => s == p).length * 2;
      if (c > m) m = c;
    }
    return m;
  }

  int _minSlotFor(String p) {
    int? m;
    for (final t in _tpls()) {
      final c = t.slots.where((s) => s == p).length * 2;
      if (m == null || c < m) m = c;
    }
    return m ?? 0;
  }

  int minCourt() => _sizes().first * 2;

  /// 뽑기 전에 명백히 불가능한 조건을 걸러낸다. 가능하면 null.
  InfeasibleReason? quickInfeasible() {
    final reasons = diagnose();
    return reasons.isEmpty ? null : reasons.first;
  }

  /// 불가능한 이유를 모두. 가능하면 빈 목록.
  List<InfeasibleReason> diagnose() {
    final out = <InfeasibleReason>[];
    final n = present.length;
    final mc = minCourt();

    if (n < mc) {
      return [
        InfeasibleReason('short', {'mc': '$mc', 'n': '$n'}),
      ];
    }
    final bench = n - mc;

    for (final p in kPos) {
      final onlyList = present
          .where((q) => q.pos.length == 1 && q.pos[0] == p)
          .toList();
      final maxs = _maxSlotFor(p);
      if (onlyList.length > maxs + bench) {
        out.add(
          InfeasibleReason('only', {
            'pos': p,
            'cnt': '${onlyList.length}',
            'names': onlyList.map((q) => q.name).join(', '),
            'max': '$maxs',
            'bench': '$bench',
          }),
        );
      }
    }

    for (final p in kPos) {
      final mins = _minSlotFor(p);
      if (mins == 0) continue;
      final able = present.where((q) => q.tier.containsKey(p)).length;
      if (able < mins) {
        out.add(
          InfeasibleReason('few', {'pos': p, 'able': '$able', 'min': '$mins'}),
        );
      }
    }

    if (mode == 'abc') {
      final ok = _sizes().where((t) => _coreSizes(n, t) != null).toList();
      if (ok.isEmpty) {
        out.add(
          InfeasibleReason('abc', {
            'ranges': _sizes().map((t) => '${2 * t}~${3 * t}').join(', '),
            'n': '$n',
          }),
        );
      }
    }

    return out;
  }
}
