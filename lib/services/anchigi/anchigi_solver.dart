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
  final String prio;
  final String sport;

  /// 6인제 전술('5-1'|'6-2').
  final String tactic;

  /// 팀당 실험 자리 수. null이면 우선순위의 기본값.
  final int? flexSlots;
  final List<String> allowed;
  final AnchigiSchedule schedule;

  const SolveRequest({
    required this.present,
    required this.stat,
    required this.round,
    required this.nGames,
    required this.mode,
    required this.prio,
    this.sport = 'v6',
    this.tactic = '5-1',
    this.flexSlots,
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

  /// 이번 라운드 안에서 연달아 대기한 횟수. 뛰면 0으로 돌아간다.
  int bstreak;
  final bool early;
  final Map<String, int> fit;
  final Map<String, int> pos;

  /// 고정(📌)한 자리. 없으면 null.
  final String? pin;

  _Snap({
    required this.play,
    required this.bench,
    required this.early,
    required this.fit,
    required this.pos,
    this.pin,
  }) : bstreak = 0;
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

  /// 이 자리에 필요한 역할.
  final String pos;

  /// 이 자리에 들어올 수 있는 코어 번호. null이면 제한 없음.
  final List<int>? allow;

  /// 코트에서 이 자리가 어디인지(존 · 이름 · 코트 밖).
  final SeatSlot def;

  const _Slot(this.team, this.pos, this.allow, this.def);
}

class _Assign {
  final String id;
  final String name;
  final String pos;
  final int team;
  final SeatSlot def;

  /// 사람이 없어 비워 둔 자리.
  final bool empty;

  const _Assign(
    this.id,
    this.name,
    this.pos,
    this.team,
    this.def, {
    this.empty = false,
  });
}

class AnchigiSolver {
  final List<AnchigiPlayer> present;
  final Map<String, AnchigiStat> stat;
  final int round;
  final int nGames;
  final String mode;
  final String prio;
  final String sport;
  final String tactic;
  final int? flexSlots;
  final List<String> allowed;
  final AnchigiSchedule schedule;
  final Random _rnd = Random();

  /// 이번 뽑기에서 실제로 쓴 비주 예산(완화 여부 판단용).
  int usedBudget = 0;

  /// 고정(📌)을 지키는 중인지. 다 지킬 수 없을 때만 false 가 된다.
  bool _pinsOn = true;

  /// 이번 뽑기에서 고정을 풀었는지 / A · B · C 를 포기했는지.
  bool pinsRelaxed = false;
  bool abcFellBack = false;

  /// ABC 모드 코어 배정 결과(원본의 p.core 대체).
  Map<String, int> _coreOf = {};

  AnchigiSolver(SolveRequest req)
    : present = req.present,
      stat = req.stat,
      round = req.round,
      nGames = req.nGames,
      mode = req.mode,
      prio = req.prio,
      sport = req.sport,
      tactic = req.tactic,
      flexSlots = req.flexSlots,
      allowed = req.allowed,
      schedule = req.schedule {
    // 자리 판정이 종목을 따라가도록 맞춰 둔다(스토어가 이미 맞췄어도 안전하게).
    for (final p in present) {
      p.sport = sport;
    }
  }

  PrioWeights get _f => prioOf(prio);

  List<String> get _seats => posOfSport(sport);

  int get _budStart {
    final v = flexSlots ?? _f.flex;
    return max(0, min(v, kMaxBudget));
  }

  AnchigiStat _st(String id) => stat[id] ?? AnchigiStat();

  // ── 템플릿 ────────────────────────────────────────────────────────────────

  List<AnchigiTemplate> _tpls() {
    final mine = templatesOfSport(sport, tactic);
    final r = mine.where((t) => allowed.contains(t.id)).toList();
    return r.isEmpty ? [mine.first] : r;
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
        fit: {for (final q in _seats) q: p.fitOf(q)},
        pos: {for (final q in _seats) q: s.pos[q] ?? 0},
        pin: _pinsOn ? p.pinned : null,
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
    c -= (_seats.length - nOpt) * 1.0;
    if (s.early) c -= kEarlySlotBonus;
    // 고정한 자리면 크게 깎아, 그 사람이 실제로 그 자리에 들어가게 한다.
    if (s.pin != null && s.pin == pos) c -= kPinSlotBonus;
    if (nOpt > 1) {
      final cnt = s.pos[pos] ?? 0;
      c += cnt * f.varietyW;
      // 6인제 센터는 한 팀에 두 자리라 같은 사람이 연달아 걸리기 쉽다.
      if (pos == 'MB' && sport == 'v6') c += (s.pos['MB'] ?? 0) * f.varietyW;
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
        s.bstreak * kBenchStreakPenalty +
        (s.early ? kEarlyBenchPenalty : 0.0) +
        (s.pin != null ? kPinSlotBonus : 0.0);
  }

  /// 배치 하나를 완성된 경기 결과로. 대기 비용과 팀 균형까지 합산한다.
  GameResult _finish(
    List<AnchigiPlayer> pool,
    _Sc sc,
    List<_Assign?> assign,
    List<String> teamNames, [
    List<String>? tplIds,
  ]) {
    final teams = <List<SlotAssign>>[[], []];
    final need = <List<String>>[[], []];
    final used = <String>{};
    final capOf = {for (final q in pool) q.id: q.pos.length};
    var cost = 0.0;

    for (final a in assign) {
      if (a == null) continue;
      if (a.empty) {
        // 사람이 없어 비운 자리 — 코트에 '(필요)' 로 남는다.
        teams[a.team].add(
          SlotAssign.needed(
            a.pos,
            zone: a.def.zone,
            label: a.def.label,
            off: a.def.off,
          ),
        );
        need[a.team].add(a.pos);
        cost += kEmptySlotCost;
        continue;
      }
      teams[a.team].add(
        SlotAssign(
          id: a.id,
          name: a.name,
          pos: a.pos,
          zone: a.def.zone,
          label: a.def.label,
          off: a.def.off,
        ),
      );
      used.add(a.id);
      cost += _slotCost(a.id, a.pos, sc, capOf[a.id] ?? 1);
    }
    // 빈자리는 두 팀에 고르게 — 한쪽만 텅 빈 코트를 막는다.
    cost += (need[0].length - need[1].length).abs() * kEmptySlotCost * 0.5;

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
      if (a == null || a.empty) continue;
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
      need: need,
      tpls: tplIds,
    );
  }

  /// 비워 둘 수 있는 자리 수.
  /// (1) 사람이 자리 수보다 모자란 만큼 (2) 아무도 설 수 없는 자리 수.
  int _emptyAllowance(List<AnchigiPlayer> pool, List<_Slot> slots) {
    final deficit = max(0, slots.length - pool.length);
    var impossible = 0;
    for (final sl in slots) {
      if (!pool.any((p) => p.pos.contains(sl.pos))) impossible++;
    }
    return deficit + impossible;
  }

  // ── 탐색 ──────────────────────────────────────────────────────────────────

  List<_Slot> _mkSlots(
    AnchigiTemplate a,
    AnchigiTemplate b, [
    List<int>? allowA,
    List<int>? allowB,
  ]) => [
    for (final d in a.slots) _Slot(0, d.role, allowA, d),
    for (final d in b.slots) _Slot(1, d.role, allowB, d),
  ];

  /// MRV 백트래킹. 해를 못 찾거나 노드 한도를 넘으면 null.
  List<_Assign?>? _search(
    List<AnchigiPlayer> pool,
    _Sc sc,
    List<_Slot> slots,
    List<Set<String>>? must,
    int nodeCap,
    int? slotBudget, [
    int maxEmpty = 0,
  ]) {
    final n = slots.length;
    final used = <String>{};
    final assign = List<_Assign?>.filled(n, null);
    var nodes = 0;
    final left = [0, 0];
    final need = [0, 0];
    final nm = [0, 0];
    final maxNM = slotBudget ?? 99;
    var emptyLeft = maxEmpty;

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
      if (!p.pos.contains(sl.pos)) return false;
      if (sl.allow != null && !sl.allow!.contains(_coreOf[p.id])) return false;
      if (must != null && must[1 - sl.team].contains(p.id)) return false;
      // 고정(📌)한 사람은 고정한 자리에만 선다.
      final pn = sc.byId[p.id]?.pin;
      if (pn != null && pn != sl.pos) return false;
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
      var ties = 0;
      for (var k = 0; k < n; k++) {
        if (assign[k] != null) continue;
        final c = <AnchigiPlayer>[];
        for (final q in pool) {
          if (ok(q, slots[k])) c.add(q);
        }
        // 후보 수가 같은 자리끼리는 고르게 무작위로 고른다(저수지 표집).
        // 앞에서부터 차례로 고르면 팀 A 자리가 먼저 차서, 인원이 모자랄 때
        // 빈자리가 한쪽 팀에만 몰린다.
        if (bc == null || c.length < bc.length) {
          bi = k;
          bc = c;
          ties = 1;
        } else if (c.length == bc.length) {
          ties++;
          if (_rnd.nextDouble() * ties < 1) {
            bi = k;
            bc = c;
          }
        }
        if (c.isEmpty) break;
      }
      if (bc == null) return false;
      if (bc.isEmpty) {
        // 이 자리를 볼 사람이 없다 — 비워 둘 여유가 있으면 '(필요)' 로 남긴다.
        if (emptyLeft <= 0) return false;
        final etm = slots[bi].team;
        emptyLeft--;
        left[etm]--;
        assign[bi] = _Assign('', '', slots[bi].pos, etm, slots[bi].def, empty: true);
        if (bt(depth + 1)) return true;
        emptyLeft++;
        left[etm]++;
        assign[bi] = null;
        return false;
      }

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
        assign[bi] = _Assign(p.id, p.name, slot.pos, tm, slot.def);
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
        if (used[k] || !ms[i].pos.contains(slots[k].role)) continue;
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

  int? _pinTeamOf(AnchigiPlayer p) => _pinsOn ? p.pinTeam : null;

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
            // 팀을 지정(📌)해 둔 사람부터 — 뒤로 밀리면 자리가 없어 실패한다.
            final ap = _pinTeamOf(a.p) == null ? 1 : 0;
            final bp = _pinTeamOf(b.p) == null ? 1 : 0;
            if (ap != bp) return ap - bp;
            if (a.over != b.over) return a.over - b.over;
            if (a.flex != b.flex) return a.flex - b.flex;
            return a.jit.compareTo(b.jit);
          });

    final cores = <List<AnchigiPlayer>>[[], [], []];
    final coreOf = <String, int>{};

    for (final e in byFlex) {
      final p = e.p;
      final want = _pinTeamOf(p);
      final order =
          [0, 1, 2]
              .where(
                (c) =>
                    (want == null || c == want) &&
                    cores[c].length < szs[c] &&
                    _coreFits([...cores[c], p], t),
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
    bool allowEmpty,
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

    int allowOf(List<_Slot> sl) => allowEmpty ? _emptyAllowance(pool, sl) : 0;

    GameResult? probe;
    for (var i = 0; i < opts.length && probe == null; i++) {
      for (var j = 0; j < opts.length && probe == null; j++) {
        final sl = _mkSlots(opts[i], opts[j], allowA, allowB);
        final as = _search(pool, sc, sl, must, 6000, bud, allowOf(sl));
        if (as != null) {
          probe = _finish(pool, sc, as, names, [opts[i].id, opts[j].id]);
        }
      }
    }
    if (probe == null) return null;

    var best = probe;
    // 원본의 `tries || 40`: 0이 넘어오면 40회가 된다(그대로 유지).
    final n = tries == 0 ? 40 : tries;
    for (var i = 0; i < n; i++) {
      final a = opts[_rnd.nextInt(opts.length)];
      final b = opts[_rnd.nextInt(opts.length)];
      final sl = _mkSlots(a, b, allowA, allowB);
      final as = _search(pool, sc, sl, must, 3000, bud, allowOf(sl));
      if (as == null) continue;
      final r = _finish(pool, sc, as, names, [a.id, b.id]);
      if (r.cost < best.cost) best = r;
    }
    return best;
  }

  GameResult? _solveGameFree(List<AnchigiPlayer> pool, _Sc sc, int tries) {
    final opts = _tpls();
    GameResult? probe;
    var bud = _budStart;
    var allow = 0;
    // 1차는 자리를 다 채우는 배치만 본다. 그래도 안 되면(인원 부족 등)
    // 2차에서 모자란 자리를 비워 둔 배치를 허용한다.
    for (var pass = 0; pass < 2 && probe == null; pass++) {
      for (bud = _budStart; bud <= kMaxBudget && probe == null; bud++) {
        for (var i = 0; i < opts.length && probe == null; i++) {
          for (var j = 0; j < opts.length && probe == null; j++) {
            if (pass == 0 && opts[i].size + opts[j].size > pool.length) {
              continue;
            }
            final sl = _mkSlots(opts[i], opts[j]);
            allow = pass == 0 ? 0 : _emptyAllowance(pool, sl);
            final as = _search(pool, sc, sl, null, 20000, bud, allow);
            if (as != null) {
              probe = _finish(pool, sc, as, ['A', 'B'], [opts[i].id, opts[j].id]);
              usedBudget = bud;
            }
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
      final sl = _mkSlots(a, b);
      if (allow == 0 && a.size + b.size > pool.length) continue;
      final as = _search(
        pool,
        sc,
        sl,
        null,
        3000,
        bud,
        allow == 0 ? 0 : _emptyAllowance(pool, sl),
      );
      if (as == null) continue;
      final r = _finish(pool, sc, as, ['A', 'B'], [a.id, b.id]);
      if (r.cost < best.cost) best = r;
    }
    return best;
  }

  /// 한 경기를 마친 뒤 라운드 안의 누적치를 갱신한다.
  /// 연속 대기(bstreak)는 여기서만 오르내린다 — 뛰면 0으로 돌아간다.
  void _applyGame(_Sc sc, GameResult g) {
    for (final team in g.teams) {
      for (final a in team) {
        if (a.empty) continue;
        final snap = sc.byId[a.id]!;
        snap.play++;
        snap.pos[a.pos] = (snap.pos[a.pos] ?? 0) + 1;
        snap.bstreak = 0;
      }
    }
    for (final b in g.bench) {
      final snap = sc.byId[b.id]!;
      snap.bench++;
      snap.bstreak++;
    }
    _refreshAvg(sc);
  }

  // ── 라운드 풀이 ───────────────────────────────────────────────────────────

  List<GameResult>? _runRoundABC(
    int t,
    bool quality,
    int bud,
    bool allowEmpty,
  ) {
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
      final g = _solveGameABC(avail, sc, t, i, quality ? 20 : 0, bud, allowEmpty);
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

      _applyGame(sc, g);
    }
    return games;
  }

  RoundResult? _solveRoundABC() {
    final szList = _sizes()
        .where((t) => _coreSizes(present.length, t) != null)
        .toList();
    if (szList.isEmpty) return null;

    List<GameResult>? found;
    var bestT = 0, bestBud = 0, bestPass = 0;
    // 예산 완화는 최후의 수단 — 각 예산에서 코어를 80번 다시 짜본 뒤에야 올린다.
    for (var pass = 0; pass < 2 && found == null; pass++) {
      for (var bud = _budStart; bud <= kMaxBudget && found == null; bud++) {
        for (var i = 0; i < 80 && found == null; i++) {
          final t = szList[_rnd.nextInt(szList.length)];
          final r = _runRoundABC(t, false, bud, pass == 1);
          if (r != null) {
            found = r;
            bestT = t;
            bestBud = bud;
            bestPass = pass;
            usedBudget = bud;
          }
        }
      }
    }
    if (found == null) return null;

    var best = found;
    var bestCost = _totalCost(found);
    for (var k = 0; k < 6; k++) {
      final r = _runRoundABC(bestT, true, bestBud, bestPass == 1);
      if (r != null && _totalCost(r) < bestCost) {
        best = r;
        bestCost = _totalCost(r);
      }
    }
    return RoundResult(
      round: round,
      games: best,
      mode: mode,
      prio: prio,
      sport: sport,
      tactic: tactic,
      budget: usedBudget,
      flexAsked: _budStart,
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

      _applyGame(sc, g);
    }

    usedBudget = maxBud;
    return RoundResult(
      round: round,
      games: games,
      mode: mode,
      prio: prio,
      sport: sport,
      tactic: tactic,
      budget: maxBud,
      flexAsked: _budStart,
    );
  }

  double _totalCost(List<GameResult> gs) => gs.fold(0.0, (s, g) => s + g.cost);

  RoundResult? solveRound() {
    if (present.isEmpty) return null;
    pinsRelaxed = false;
    abcFellBack = false;

    var r = _solveOnce();
    if (r == null) {
      // 고정(📌)을 다 지키면 답이 없을 수 있다. 마지막에 고정을 풀고 한 번 더.
      final anyPin = present.any((p) => p.pinned != null || p.pinTeam != null);
      if (!anyPin) return null;
      _pinsOn = false;
      r = _solveOnce();
      _pinsOn = true;
      if (r == null) return null;
      pinsRelaxed = true;
    }
    return r.copyWith(
      pinsRelaxed: pinsRelaxed,
      abcFellBack: abcFellBack,
      mode: abcFellBack ? 'free' : mode,
    );
  }

  RoundResult? _solveOnce() {
    if (mode != 'abc') return _solveRoundFree();
    final r = _solveRoundABC();
    if (r != null) return r;
    // A · B · C 는 팀 인원의 2~3배가 필요하다. 인원이 그에 못 미치면
    // 못 뽑는다고 막는 대신 자유 편성으로 돌려 빈자리를 보여준다.
    final f = _solveRoundFree();
    if (f != null) abcFellBack = true;
    return f;
  }

  /// 자리가 빌 것 같은 상황인지 — 막는 판단이 아니라 미리 알려주는 판단이다.
  bool shortHanded() {
    if (present.isEmpty) return false;
    if (present.length < minCourt()) return true;
    return _tpls().every(
      (t) => t.slots.any((sl) => !present.any((q) => q.pos.contains(sl.role))),
    );
  }

  // ── 사전 진단 ─────────────────────────────────────────────────────────────

  int _maxSlotFor(String p) {
    var m = 0;
    for (final t in _tpls()) {
      final c = t.slots.where((s) => s.role == p).length * 2;
      if (c > m) m = c;
    }
    return m;
  }

  int _minSlotFor(String p) {
    int? m;
    for (final t in _tpls()) {
      final c = t.slots.where((s) => s.role == p).length * 2;
      if (m == null || c < m) m = c;
    }
    return m ?? 0;
  }

  int minCourt() => _sizes().first * 2;

  /// 인원·자리가 모자란 이유를 모두. 넉넉하면 빈 목록.
  /// 이제 뽑기를 막지 않고 '이런 자리가 빈다'는 안내로만 쓴다.
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

    for (final p in _seats) {
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

    for (final p in _seats) {
      final mins = _minSlotFor(p);
      if (mins == 0) continue;
      final able = present.where((q) => q.pos.contains(p)).length;
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
