// 저장소 검증 — 저장/복원 왕복, 티어 순환 규칙, 확정·초기화 흐름.
import 'package:flutter_test/flutter_test.dart';
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
      s.setFeel('mix');
      s.setNGames(4);
      s.setSchedule(warmup: '13:30', perGame: 20, rest: 5);
      s.statOf(s.players.first.id).play = 7;
      await s.persist();

      final back = AnchigiStore();
      await back.load();

      expect(back.players.map((p) => p.name), ['가나', '다라']);
      expect(back.players.first.tier, {'S': 'main', 'OH': 'sub'});
      expect(back.mode, 'free');
      expect(back.feel, 'mix');
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
      expect(s.feel, 'real');
      expect(s.nGames, 3);
      expect(s.allowed, ['mb2', 'mb1li', 'mb2li']);
      expect(s.schedule.warmup, '14:00');
    });

    test('망가진 값은 기본값으로 되돌린다', () async {
      SharedPreferences.setMockInitialValues({
        'anchigi.feel.v1': '"없는값"',
        'anchigi.mode.v1': '"엉뚱"',
        'anchigi.ngames.v1': '99',
        'anchigi.players.v1': '{잘못된 JSON',
      });
      final s = AnchigiStore();
      await s.load();
      expect(s.feel, 'real');
      expect(s.mode, 'abc');
      expect(s.nGames, 3);
      expect(s.players, isEmpty);
    });
  });

  group('포지션 티어 순환', () {
    test('없음 → 주(첫 포지션) → 제거 불가', () async {
      final s = await freshStore();
      s.addPlayer('테스트', {});
      final id = s.players.first.id;
      // 포지션 없이 추가하면 S가 주로 강제된다.
      expect(s.players.first.tier, {'S': 'main'});
      // 마지막 하나뿐인 포지션은 지울 수 없다.
      s.cycleTier(id, 'S');
      expect(s.players.first.tier, {'S': 'main'});
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
        feel: 'real',
        budget: 0,
      );
      s.setFeel('mix');
      expect(s.current, isNull);
    });

    test('마지막 템플릿은 끌 수 없다', () async {
      final s = await freshStore();
      s.toggleTemplate('mb2li');
      s.toggleTemplate('mb1li');
      expect(s.allowed, ['mb2']);
      s.toggleTemplate('mb2');
      expect(s.allowed, ['mb2'], reason: '하나 남으면 유지돼야 함');
    });

    test('템플릿을 다시 켜면 원래 순서로 들어간다', () async {
      final s = await freshStore();
      s.toggleTemplate('mb2');
      expect(s.allowed, ['mb1li', 'mb2li']);
      s.toggleTemplate('mb2');
      expect(s.allowed, ['mb2', 'mb1li', 'mb2li']);
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
        feel: 'real',
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
    });
  });
}
