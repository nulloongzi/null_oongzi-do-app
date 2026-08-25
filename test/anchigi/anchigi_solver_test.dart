// 솔버 정확성 검증 — 배치가 규칙(가능 포지션, 코어 제약, 예산)을 지키는지.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/models/anchigi/anchigi_constants.dart';
import 'package:nulloongzido/models/anchigi/anchigi_player.dart';
import 'package:nulloongzido/models/anchigi/anchigi_round.dart';
import 'package:nulloongzido/models/anchigi/anchigi_schedule.dart';
import 'package:nulloongzido/services/anchigi/anchigi_solver.dart';

/// 모든 포지션을 주로 보는 만능 선수(제약 검증용 기본 재료).
AnchigiPlayer p(String name, Map<String, String> tier, {String? leave}) =>
    AnchigiPlayer(
      id: 'id_$name',
      name: name,
      tier: tier,
      here: true,
      leave: leave,
    );

Map<String, String> allMain() => {for (final q in kPos) q: 'main'};

List<AnchigiPlayer> roster(int n) =>
    List.generate(n, (i) => p('P$i', allMain()));

SolveRequest req(
  List<AnchigiPlayer> present, {
  String mode = 'abc',
  String feel = 'real',
  int nGames = 3,
  List<String>? allowed,
  Map<String, AnchigiStat>? stat,
  AnchigiSchedule? schedule,
  int round = 1,
}) => SolveRequest(
  present: present,
  stat: stat ?? {},
  round: round,
  nGames: nGames,
  mode: mode,
  feel: feel,
  allowed: allowed ?? ['mb2', 'mb1li', 'mb2li'],
  schedule: schedule ?? AnchigiSchedule(),
);

/// 배치된 모든 사람이 자기가 가능한 포지션에 있는지.
void expectPositionsValid(RoundResult r, List<AnchigiPlayer> pool) {
  final byId = {for (final q in pool) q.id: q};
  for (final g in r.games) {
    for (final team in g.teams) {
      for (final a in team) {
        expect(
          byId[a.id]!.tier.containsKey(a.pos),
          isTrue,
          reason: '${a.name}은(는) ${a.pos}를 볼 수 없음',
        );
      }
    }
  }
}

/// 한 경기에 같은 사람이 두 번 나오지 않는지.
void expectNoDuplicates(RoundResult r) {
  for (final g in r.games) {
    final ids = <String>[];
    for (final team in g.teams) {
      ids.addAll(team.map((a) => a.id));
    }
    expect(ids.toSet().length, ids.length, reason: '한 경기에 중복 출전');
  }
}

/// 배치된 팀이 허용 템플릿 중 하나와 정확히 일치하는지.
void expectTeamsMatchTemplate(RoundResult r, List<String> allowed) {
  final want = kTemplates
      .where((t) => allowed.contains(t.id))
      .map((t) => (t.slots.toList()..sort()).join(','))
      .toSet();
  for (final g in r.games) {
    for (final team in g.teams) {
      final got = (team.map((a) => a.pos).toList()..sort()).join(',');
      expect(want, contains(got), reason: '팀 구성이 템플릿과 불일치: $got');
    }
  }
}

void main() {
  group('기본 배치 유효성', () {
    test('ABC 모드 12명 — 포지션·중복·템플릿 규칙을 모두 지킨다', () {
      final pool = roster(12);
      final r = AnchigiSolver(req(pool)).solveRound();
      expect(r, isNotNull);
      expect(r!.games.length, 3);
      expectPositionsValid(r!, pool);
      expectNoDuplicates(r);
      expectTeamsMatchTemplate(r, ['mb2', 'mb1li', 'mb2li']);
    });

    test('자유 모드 14명 — 규칙을 지키고 팀 이름은 항상 A/B', () {
      final pool = roster(14);
      final r = AnchigiSolver(req(pool, mode: 'free')).solveRound();
      expect(r, isNotNull);
      expectPositionsValid(r!, pool);
      expectNoDuplicates(r);
      for (final g in r.games) {
        expect(g.names, ['A', 'B']);
        expect(g.cores, isNull);
      }
    });

    test('mb2만 허용하면 모든 팀이 리베로 없는 6인 구성', () {
      final pool = roster(12);
      final r = AnchigiSolver(req(pool, allowed: ['mb2'])).solveRound();
      expect(r, isNotNull);
      expectTeamsMatchTemplate(r!, ['mb2']);
      for (final g in r.games) {
        for (final team in g.teams) {
          expect(team.length, 6);
          expect(team.where((a) => a.pos == 'Li'), isEmpty);
        }
      }
    });
  });

  group('ABC 코어 제약', () {
    test('코어 선수는 자기 팀 경기에 반드시 출전한다', () {
      final pool = roster(15);
      final r = AnchigiSolver(req(pool)).solveRound();
      expect(r, isNotNull);

      for (var gi = 0; gi < r!.games.length; gi++) {
        final g = r.games[gi];
        final cores = g.cores;
        expect(cores, isNotNull, reason: 'ABC 모드는 코어 정보를 담아야 함');

        final pair = kPairs[gi % 3];
        final onCourt = <String>{
          for (final team in g.teams) ...team.map((a) => a.id),
        };
        final leftIds = g.left.map((l) => l.id).toSet();

        // 팀1 코어(X), 팀2 코어(Y)는 퇴장자가 아니면 전원 출전.
        for (final teamIdx in [0, 1]) {
          for (final m in cores![pair[teamIdx]]) {
            if (leftIds.contains(m.id)) continue;
            expect(
              onCourt.contains(m.id),
              isTrue,
              reason: '${gi + 1}경기: 코어 ${m.name}이(가) 코트 밖',
            );
            // 자기 팀에 있어야 한다.
            expect(
              g.teams[teamIdx].any((a) => a.id == m.id),
              isTrue,
              reason: '${gi + 1}경기: 코어 ${m.name}이(가) 상대 팀에 있음',
            );
          }
        }
      }
    });

    test('참석 인원이 2T~3T 밖이면 배치 불가', () {
      // 6인 템플릿만 허용 → 12~18명. 19명은 범위 밖.
      final solver = AnchigiSolver(req(roster(19), allowed: ['mb2']));
      expect(solver.diagnose().any((d) => d.kind == 'abc'), isTrue);
      expect(solver.solveRound(), isNull);
    });
  });

  group('경계 조건', () {
    test('참석 = 2T (C코어 0명) — 배치는 되고 C코어는 비어 있다', () {
      final pool = roster(12);
      final r = AnchigiSolver(req(pool, allowed: ['mb2'])).solveRound();
      expect(r, isNotNull);
      expect(r!.games.first.cores![2], isEmpty);
      // 전원 출전이므로 대기 없음.
      for (final g in r.games) {
        expect(g.bench, isEmpty);
      }
      expectPositionsValid(r, pool);
    });

    test('참석 = 3T (대기 0명) — 모든 경기가 12명을 채운다', () {
      final pool = roster(18);
      final r = AnchigiSolver(req(pool, allowed: ['mb2'])).solveRound();
      expect(r, isNotNull);
      for (final g in r!.games) {
        expect(g.teams[0].length + g.teams[1].length, 12);
        expect(g.bench.length, 6); // 18명 중 12명 출전
      }
      expectPositionsValid(r, pool);
    });

    test('인원이 최소 코트 인원보다 적으면 진단이 short를 낸다', () {
      final solver = AnchigiSolver(req(roster(9)));
      final d = solver.diagnose();
      expect(d.first.kind, 'short');
      expect(d.first.params['n'], '9');
      expect(solver.solveRound(), isNull);
    });
  });

  group('퇴장 처리', () {
    test('경기 종료 시각 전에 가는 사람은 그 경기에서 빠진다', () {
      // 게임 시작 14:00, 경기당 15분 → 1경기 14:00~14:15, 2경기 ~14:30, 3경기 ~14:45.
      final pool = roster(13);
      pool[0] = p('일찍가', allMain(), leave: '14:20');
      final r = AnchigiSolver(req(pool)).solveRound();
      expect(r, isNotNull);

      // 1·2경기는 14:15/14:30 종료 → 14:20이면 2경기부터 제외.
      expect(r!.games[0].left.map((l) => l.name), isNot(contains('일찍가')));
      expect(r.games[1].left.map((l) => l.name), contains('일찍가'));
      expect(r.games[2].left.map((l) => l.name), contains('일찍가'));

      // 빠진 경기에는 코트에도 대기에도 없어야 한다.
      for (final gi in [1, 2]) {
        final g = r.games[gi];
        final ids = <String>{
          for (final team in g.teams) ...team.map((a) => a.id),
          ...g.bench.map((b) => b.id),
        };
        expect(ids.contains('id_일찍가'), isFalse);
      }
    });
  });

  group('예산(비주 포지션) 제약', () {
    test('comp 모드는 주 포지션만으로 채워지면 비주 0명', () {
      // 모두가 전 포지션 main이므로 comp(budget 0)로 충분.
      final r = AnchigiSolver(req(roster(12), feel: 'comp')).solveRound();
      expect(r, isNotNull);
      expect(r!.budget, 0);
      for (final g in r.games) {
        expect(g.nonMain, [0, 0]);
      }
    });

    test('주 포지션이 모자라면 comp에서도 예산이 완화된다', () {
      // 세터 주전 2명 + 나머지는 세터를 sub로만 볼 수 있는 12명 구성.
      // 팀은 2개이므로 세터 main이 2명이면 충분하지만, MB main을 없애서
      // 어느 팀이든 비주를 써야만 하도록 만든다.
      final pool = <AnchigiPlayer>[];
      for (var i = 0; i < 12; i++) {
        pool.add(
          p('Q$i', {
            'S': 'main',
            'OP': 'main',
            'OH': 'main',
            'MB': 'sub', // 센터는 아무도 주전이 아님 → 반드시 비주 사용
            'Li': 'main',
          }),
        );
      }
      final solver = AnchigiSolver(
        req(pool, feel: 'comp', allowed: ['mb2']),
      );
      final r = solver.solveRound();
      expect(r, isNotNull);
      // mb2는 팀당 MB가 2자리 → 팀당 비주 2명 필요 → 예산이 2까지 올라간다.
      expect(r!.budget, greaterThanOrEqualTo(2));
      expect(r.budget, greaterThan(kFeel['comp']!.budget));
    });
  });

  group('진단', () {
    test('리베로만 가능한 사람이 자리보다 많으면 only', () {
      final pool = <AnchigiPlayer>[];
      for (var i = 0; i < 9; i++) {
        pool.add(p('L$i', {'Li': 'main'})); // 리베로 전용 9명
      }
      for (var i = 0; i < 5; i++) {
        pool.add(p('A$i', allMain()));
      }
      // mb1li: 팀당 Li 1자리 → 최대 2자리. 대기를 감안해도 9명은 과다.
      final d = AnchigiSolver(
        req(pool, allowed: ['mb1li']),
      ).diagnose();
      expect(d.any((x) => x.kind == 'only' && x.params['pos'] == 'Li'), isTrue);
    });

    test('세터 가능자가 자리보다 적으면 few', () {
      final pool = <AnchigiPlayer>[];
      // 세터 가능 1명뿐 — 팀이 2개라 2자리가 필요.
      pool.add(p('S0', {'S': 'main', 'OH': 'main'}));
      for (var i = 0; i < 13; i++) {
        pool.add(p('N$i', {'OP': 'main', 'OH': 'main', 'MB': 'main'}));
      }
      final d = AnchigiSolver(req(pool, allowed: ['mb2'])).diagnose();
      expect(d.any((x) => x.kind == 'few' && x.params['pos'] == 'S'), isTrue);
    });

    test('충분한 명단이면 진단이 비어 있다', () {
      expect(AnchigiSolver(req(roster(14))).diagnose(), isEmpty);
    });
  });

  group('출전 기록 반영', () {
    test('자유 모드에서 많이 뛴 사람이 대기로 밀린다', () {
      // mb2만 허용 → 항상 6+6=12명 출전, 13명 중 1명 대기.
      // 자유 모드라 코어 제약이 없어 공정성 점수만으로 결정된다.
      final pool = roster(13);
      final stat = <String, AnchigiStat>{
        for (final q in pool) q.id: AnchigiStat(),
      };
      stat['id_P0'] = AnchigiStat(play: 20, bench: 0);

      for (var trial = 0; trial < 5; trial++) {
        final r = AnchigiSolver(
          req(pool, mode: 'free', stat: stat, nGames: 1, allowed: ['mb2']),
        ).solveRound();
        expect(r, isNotNull);
        expect(r!.games[0].bench.length, 1);
        expect(
          r.games[0].bench.first.id,
          'id_P0',
          reason: '20회 더 뛴 사람이 대기해야 함',
        );
      }
    });

    test('ABC 코어에 묶이면 많이 뛰었어도 출전한다', () {
      // 코어 제약은 공정성 점수보다 우선한다(원본 설계). A/B 코어면 반드시 출전.
      final pool = roster(13);
      final stat = <String, AnchigiStat>{
        for (final q in pool) q.id: AnchigiStat(),
      };
      stat['id_P0'] = AnchigiStat(play: 20, bench: 0);

      final r = AnchigiSolver(
        req(pool, stat: stat, nGames: 1, allowed: ['mb2']),
      ).solveRound();
      expect(r, isNotNull);
      final g = r!.games[0];
      final coreOfP0 = [0, 1, 2].firstWhere(
        (c) => g.cores![c].any((m) => m.id == 'id_P0'),
      );
      final onCourt = <String>{
        for (final team in g.teams) ...team.map((a) => a.id),
      };
      // 1경기는 A(0) vs B(1). C(2) 코어만 대기 가능.
      if (coreOfP0 != 2) {
        expect(onCourt.contains('id_P0'), isTrue);
      }
    });

    test('10라운드를 돌리면 출전 편차가 벌어지지 않는다', () {
      // 공정성 수렴 검증: 자유 모드 13명으로 10라운드 누적.
      final pool = roster(13);
      final stat = <String, AnchigiStat>{
        for (final q in pool) q.id: AnchigiStat(),
      };

      for (var rnd = 1; rnd <= 10; rnd++) {
        final r = AnchigiSolver(
          req(
            pool,
            mode: 'free',
            stat: stat,
            round: rnd,
            nGames: 3,
            allowed: ['mb2'],
          ),
        ).solveRound();
        expect(r, isNotNull, reason: '$rnd라운드 배치 실패');
        // 확정(commit)과 같은 방식으로 누적.
        for (final g in r!.games) {
          for (final team in g.teams) {
            for (final a in team) {
              final s = stat[a.id]!;
              s.play++;
              s.pos[a.pos] = (s.pos[a.pos] ?? 0) + 1;
            }
          }
          for (final b in g.bench) {
            stat[b.id]!.bench++;
          }
        }
      }

      final plays = pool.map((q) => stat[q.id]!.play).toList();
      final benches = pool.map((q) => stat[q.id]!.bench).toList();
      final spread =
          plays.reduce((a, b) => a > b ? a : b) -
          plays.reduce((a, b) => a < b ? a : b);
      final benchSpread =
          benches.reduce((a, b) => a > b ? a : b) -
          benches.reduce((a, b) => a < b ? a : b);

      // 30경기 × 12자리 = 360자리를 13명이 나눠 가짐(1인 평균 27.7).
      expect(plays.reduce((a, b) => a + b), 30 * 12);
      expect(spread, lessThanOrEqualTo(3), reason: '출전 편차: $plays');
      expect(benchSpread, lessThanOrEqualTo(3), reason: '대기 편차: $benches');
    });

    test('포지션 분배도 한쪽으로 몰리지 않는다', () {
      // 전 포지션 가능자만 있으면 varietyW가 같은 포지션 반복을 막아야 한다.
      final pool = roster(12);
      final stat = <String, AnchigiStat>{
        for (final q in pool) q.id: AnchigiStat(),
      };

      for (var rnd = 1; rnd <= 6; rnd++) {
        final r = AnchigiSolver(
          req(
            pool,
            mode: 'free',
            stat: stat,
            round: rnd,
            nGames: 3,
            allowed: ['mb2'],
          ),
        ).solveRound();
        expect(r, isNotNull);
        for (final g in r!.games) {
          for (final team in g.teams) {
            for (final a in team) {
              final s = stat[a.id]!;
              s.play++;
              s.pos[a.pos] = (s.pos[a.pos] ?? 0) + 1;
            }
          }
        }
      }

      // 18경기 동안 아무도 한 포지션만 계속 서지 않아야 한다.
      for (final q in pool) {
        final used = stat[q.id]!.pos.entries
            .where((e) => e.value > 0)
            .length;
        expect(used, greaterThanOrEqualTo(2), reason: '${q.name}이(가) 한 포지션만 섬');
      }
    });
  });
}
