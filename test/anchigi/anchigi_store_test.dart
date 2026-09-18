// 저장소 검증 — 저장/복원 왕복, 티어 순환 규칙, 확정·초기화 흐름.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/models/anchigi/anchigi_constants.dart';
import 'package:nulloongzido/models/anchigi/anchigi_round.dart';
import 'package:nulloongzido/services/anchigi/anchigi_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AnchigiStore> freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final s = AnchigiStore();
  await s.load();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('저장·복원', () {
    test('명단·기록·설정이 왕복한다', () async {
      final s = await freshStore();
      s.addPlayer('가나', {'S': 'main', 'OH': 'sub'});
      s.addPlayer('다라', {'MB': 'main'});
      s.setMode('free');
      s.setPrio('variety');
      s.setNGames(4);
      s.setSchedule(warmup: '13:30', perGame: 20, rest: 5);
      s.statOf(s.players.first.id).play = 7;
      await s.persist();

      final back = AnchigiStore();
      await back.load();

      expect(back.players.map((p) => p.name), ['가나', '다라']);
      expect(back.players.first.tier, {'S': 'main', 'OH': 'sub'});
      expect(back.mode, 'free');
      expect(back.prio, 'variety');
      expect(back.nGames, 4);
      expect(back.schedule.warmup, '13:30');
      expect(back.schedule.perGame, 20);
      expect(back.schedule.rest, 5);
      expect(back.stat[back.players.first.id]!.play, 7);
    });

    test('저장된 값이 없으면 기본값', () async {
      final s = await freshStore();
      expect(s.players, isEmpty);
      expect(s.round, 1);
      expect(s.mode, 'abc');
      expect(s.prio, 'custom');
      expect(s.sport, 'v6');
      expect(s.tactic, '5-1');
      expect(s.allowed, [for (final t in kTemplates) t.id]);
      expect(s.nGames, 3);
      expect(s.schedule.warmup, '14:00');
    });

    test('망가진 값은 기본값으로 되돌린다', () async {
      SharedPreferences.setMockInitialValues({
        'anchigi.prio.v1': '"없는값"',
        'anchigi.mode.v1': '"엉뚱"',
        'anchigi.ngames.v1': '99',
        'anchigi.players.v1': '{잘못된 JSON',
      });
      final s = AnchigiStore();
      await s.load();
      expect(s.prio, 'custom');
      expect(s.mode, 'abc');
      expect(s.nGames, 3);
      expect(s.players, isEmpty);
    });
  });

  group('예전 저장본', () {
    test('게임 성격 4단계는 우선순위 + 실험 자리로 옮겨온다', () async {
      SharedPreferences.setMockInitialValues({'anchigi.feel.v1': '"mix"'});
      final s = AnchigiStore();
      await s.load();
      expect(s.prio, 'variety');
      expect(s.flexSlots, 2);
    });

    test('경쟁(comp)은 맞춘 자리 우선 + 실험 자리 0', () async {
      SharedPreferences.setMockInitialValues({'anchigi.feel.v1': '"comp"'});
      final s = AnchigiStore();
      await s.load();
      expect(s.prio, 'custom');
      expect(s.flexSlotsEffective, 0);
    });
  });

  group('자리 티어 순환', () {
    test('자리를 안 고르면 어디든 — 첫 클릭이 주 자리가 된다', () async {
      final s = await freshStore();
      s.addPlayer('테스트', {});
      final id = s.players.first.id;
      // 예전엔 S가 자동으로 박혔다. 지금은 '어디든'으로 들어간다.
      expect(s.players.first.tier, isEmpty);
      expect(s.players.first.isFlex, isTrue);
      expect(s.players.first.pos, kPosBySport['v6']);

      s.cycleTier(id, 'MB');
      expect(s.players.first.tier, {'MB': 'main'});
      expect(s.players.first.isFlex, isFalse);
      // 마지막 자리까지 지우면 다시 '어디든'.
      s.cycleTier(id, 'MB');
      expect(s.players.first.tier, isEmpty);
      expect(s.players.first.isFlex, isTrue);
    });

    test('주가 이미 있으면 다음 포지션은 가능부터', () async {
      final s = await freshStore();
      s.addPlayer('테스트', {'S': 'main'});
      final id = s.players.first.id;

      s.cycleTier(id, 'OH');
      expect(s.players.first.tier['OH'], 'sub');
      s.cycleTier(id, 'OH');
      expect(s.players.first.tier['OH'], 'want');
      s.cycleTier(id, 'OH');
      expect(s.players.first.tier.containsKey('OH'), isFalse);
    });

    test('주를 지우면 남은 포지션이 자동 승격', () async {
      final s = await freshStore();
      s.addPlayer('테스트', {'S': 'main', 'OH': 'sub', 'MB': 'want'});
      final id = s.players.first.id;

      s.cycleTier(id, 'S'); // 주 제거
      final t = s.players.first.tier;
      expect(t.containsKey('S'), isFalse);
      expect(t['OH'], 'main', reason: '남은 첫 포지션이 주로 승격돼야 함');
      expect(s.players.first.mainCount, 1);
    });

    test('☆는 주를 옮기고 기존 주는 가능으로 내린다', () async {
      final s = await freshStore();
      s.addPlayer('테스트', {'S': 'main', 'MB': 'want'});
      final id = s.players.first.id;

      s.promoteTier(id, 'MB');
      expect(s.players.first.tier['MB'], 'main');
      expect(s.players.first.tier['S'], 'sub');
      expect(s.players.first.mainCount, 1);
    });

    test('주는 항상 정확히 하나', () async {
      final s = await freshStore();
      s.addPlayer('테스트', {'S': 'main', 'OP': 'sub', 'OH': 'sub'});
      final id = s.players.first.id;
      for (final pos in ['OP', 'OH', 'S', 'MB', 'Li']) {
        s.cycleTier(id, pos);
        expect(s.players.first.mainCount, 1, reason: '$pos 순환 후');
      }
    });
  });

  group('설정 변경', () {
    test('설정을 바꾸면 뽑아둔 결과가 폐기된다', () async {
      final s = await freshStore();
      s.current = const RoundResult(
        round: 1,
        games: [],
        mode: 'abc',
        prio: 'real',
        budget: 0,
      );
      s.setPrio('mix');
      expect(s.current, isNull);
    });

    test('이 종목 · 전술의 마지막 구성은 끌 수 없다', () async {
      final s = await freshStore();
      s.toggleTemplate('mb2li');
      s.toggleTemplate('mb1li');
      expect(s.allowed, isNot(contains('mb1li')));
      expect(s.allowed, contains('mb2'));
      s.toggleTemplate('mb2');
      expect(s.allowed, contains('mb2'), reason: '5-1 에 하나 남으면 유지돼야 함');
    });

    test('구성을 다시 켜면 원래 순서로 들어간다', () async {
      final s = await freshStore();
      s.toggleTemplate('mb2');
      expect(s.allowed, isNot(contains('mb2')));
      s.toggleTemplate('mb2');
      expect(
        s.allowed.indexOf('mb2') < s.allowed.indexOf('mb1li'),
        isTrue,
        reason: 'kTemplates 순서를 지켜야 표시가 흔들리지 않는다',
      );
    });

    test('전술을 바꾸면 그 전술의 구성만 쓴다', () async {
      final s = await freshStore();
      expect(s.templates.every((t) => t.tactic == '5-1'), isTrue);
      s.setTactic('6-2');
      expect(s.templates.every((t) => t.tactic == '6-2'), isTrue);
      // 6-2 는 코트에 세터가 둘이다.
      expect(s.templates.first.slots.where((sl) => sl.role == 'S').length, 2);
    });

    test('종목을 바꾸면 명단의 가능 자리도 따라간다', () async {
      final s = await freshStore();
      s.addPlayer('가', {'S': 'main'});
      expect(s.players.first.pos, ['S']);
      s.setSport('v9');
      // 9인제 자리를 안 골랐으니 '어디든'.
      expect(s.players.first.isFlex, isTrue);
      expect(s.players.first.pos, kPosBySport['v9']);
      s.setSport('v6');
      expect(s.players.first.pos, ['S']);
    });

    test('고정(📌)은 주 자리에 걸리고 다시 누르면 풀린다', () async {
      final s = await freshStore();
      s.addPlayer('가', {'S': 'main', 'OH': 'sub'});
      final id = s.players.first.id;
      s.togglePin(id);
      expect(s.players.first.pinned, 'S');
      s.togglePin(id);
      expect(s.players.first.pinned, isNull);
    });

    test('여러 명 한 번에 — 줄바꿈·쉼표로 끊어 넣는다', () async {
      final s = await freshStore();
      final n = s.addPlayers('가영, 나윤\n다온 \n\n라임');
      expect(n, 4);
      expect(s.players.map((p) => p.name), ['가영', '나윤', '다온', '라임']);
      expect(s.players.every((p) => p.isFlex), isTrue);
    });
  });

  group('확정·초기화', () {
    test('확정하면 기록이 쌓이고 라운드가 넘어간다', () async {
      final s = await freshStore();
      s.addPlayer('가', {'S': 'main'});
      s.addPlayer('나', {'OH': 'main'});
      final a = s.players[0].id, b = s.players[1].id;

      s.current = RoundResult(
        round: 1,
        mode: 'abc',
        prio: 'real',
        budget: 0,
        games: [
          GameResult(
            teams: [
              [SlotAssign(id: a, name: '가', pos: 'S')],
              const [],
            ],
            names: const ['A', 'B'],
            bench: [PlayerRef(id: b, name: '나')],
            cost: 0,
            fitGap: 0,
            nonMain: const [0, 0],
          ),
        ],
      );
      s.commit();

      expect(s.stat[a]!.play, 1);
      expect(s.stat[a]!.pos['S'], 1);
      expect(s.stat[b]!.bench, 1);
      expect(s.round, 2);
      expect(s.current, isNull);
      expect(s.pastRounds.length, 1);
      expect(s.pastRounds.first.round, 1);
    });

    test('기록 초기화는 명단을 남긴다', () async {
      final s = await freshStore();
      s.addPlayer('가', {'S': 'main'});
      s.statOf(s.players.first.id).play = 5;
      s.round = 4;
      s.pastRounds = [const PastRound(round: 1, games: [], mode: 'abc')];

      s.resetStats();

      expect(s.stat, isEmpty);
      expect(s.round, 1);
      expect(s.pastRounds, isEmpty);
      expect(s.players.length, 1, reason: '명단은 유지돼야 함');
    });

    test('선수를 지우면 그 사람 기록도 사라진다', () async {
      final s = await freshStore();
      s.addPlayer('가', {'S': 'main'});
      final id = s.players.first.id;
      s.statOf(id).play = 3;

      s.removePlayer(id);
      expect(s.players, isEmpty);
      expect(s.stat.containsKey(id), isFalse);
    });
  });

  group('파생 값', () {
    test('참석자만 present에 들어간다', () async {
      final s = await freshStore();
      s.addPlayer('가', {'S': 'main'});
      s.addPlayer('나', {'OH': 'main'});
      s.setHere(s.players[1].id, false);
      expect(s.present.map((p) => p.name), ['가']);
    });

    test('대기 인원 범위', () async {
      final s = await freshStore();
      for (var i = 0; i < 14; i++) {
        s.addPlayer('P$i', {
          'S': 'main',
          'OP': 'main',
          'OH': 'main',
          'MB': 'main',
          'Li': 'main',
        });
      }
      // 6인 템플릿이면 2명 대기, 7인 템플릿이면 0명 대기.
      expect(s.benchRange, (0, 2));
    });

    test('명단이 부족하면 진단이 이유를 알려준다', () async {
      final s = await freshStore();
      s.addPlayer('가', {'S': 'main'});
      expect(s.diagnosis.first.kind, 'short');
      expect(s.shortHanded, isTrue);
    });

    test('모임을 보관하면 기록만 새로 시작한다', () async {
      final s = await freshStore();
      s.addPlayer('가', {'S': 'main'});
      s.statOf(s.players.first.id).play = 3;
      s.round = 4;

      expect(s.archiveMeet(), isTrue);
      expect(s.meets.length, 1);
      expect(s.meets.first.rounds, 3);
      expect(s.stat, isEmpty);
      expect(s.round, 1);
      expect(s.players.length, 1, reason: '명단은 유지돼야 함');
    });

    test('껐던 구성은 다시 켜지지 않는다', () async {
      // 새 구성을 아는 저장본(6-2 를 꺼 둔 상태)은 그대로 읽어야 한다.
      SharedPreferences.setMockInitialValues({
        'anchigi.tpl.v1': '["mb2","mb1li","mb2li","v9q1","v9q2","v9q3"]',
      });
      final s = AnchigiStore();
      await s.load();
      expect(s.allowed, isNot(contains('mb2x62')));
    });

    test('5-1 구성만 있던 예전 저장본에는 새 구성을 켜 준다', () async {
      SharedPreferences.setMockInitialValues({
        'anchigi.tpl.v1': '["mb2","mb1li","mb2li"]',
      });
      final s = AnchigiStore();
      await s.load();
      expect(s.allowed, contains('mb2x62'));
      expect(s.allowed, contains('v9q2'));
    });

    test('한 종목의 주 자리를 올려도 다른 종목 주 자리는 그대로', () async {
      final s = await freshStore();
      s.addPlayer('가', {'S': 'main', 'OH': 'sub', 'QK': 'main', 'CH': 'sub'});
      final id = s.players.first.id;
      s.setSport('v9');
      s.promoteTier(id, 'CH');

      expect(s.players.first.tier['CH'], 'main');
      expect(s.players.first.tier['QK'], 'sub');
      expect(s.players.first.tier['S'], 'main', reason: '6인제 주 자리는 그대로여야 한다');
    });

    test('망가진 백업은 지금 명단을 건드리지 않는다', () async {
      final s = await freshStore();
      s.addPlayer('가', {'S': 'main'});
      // players 는 배열이지만 그 안이 깨진 백업.
      final bad = '{"players":[{"id":1}],"stat":{}}';
      expect(s.importJson(bad), isFalse);
      expect(s.players.length, 1, reason: '실패하면 원래 명단이 남아야 한다');
      expect(s.players.first.name, '가');
    });

    test('백업을 내보내고 다시 불러온다', () async {
      final s = await freshStore();
      s.addPlayer('가', {'S': 'main'});
      s.setPrio('variety');
      s.statOf(s.players.first.id).play = 2;
      final dump = s.exportJson();

      final other = await freshStore();
      expect(other.importJson(dump), isTrue);
      expect(other.players.map((p) => p.name), ['가']);
      expect(other.prio, 'variety');
      expect(other.stat.values.first.play, 2);
      expect(other.importJson('{잘못된'), isFalse);
    });
  });
}
