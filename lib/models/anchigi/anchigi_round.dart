// anchigi_round.dart — 뽑기 결과 모델. 원본 anchigi.html의 game/current/pastRounds 포팅.
// 원본은 배열에 .T/.bud 같은 속성을 얹었으나, Dart에서는 명시적 필드로 둔다.

/// 코트의 자리 하나. 사람이 없어 비워 둔 자리면 [empty] 가 true 이고
/// 화면에는 '(필요)' 로 나온다 — 어떤 자리를 더 구해야 하는지 보이라고.
class SlotAssign {
  final String id;
  final String name;

  /// 역할 키(S · OH · QK · CH …).
  final String pos;

  /// 6인제 존(1~6). 9인제는 0.
  final int zone;

  /// 자리 고유 이름의 i18n 키(9인제, 6-2 전위 세터). 없으면 빈 문자열.
  final String label;

  /// 코트 밖에서 교대하는 자리(6인제 리베로).
  final bool off;

  final bool empty;

  const SlotAssign({
    required this.id,
    required this.name,
    required this.pos,
    this.zone = 0,
    this.label = '',
    this.off = false,
    this.empty = false,
  });

  const SlotAssign.needed(
    this.pos, {
    this.zone = 0,
    this.label = '',
    this.off = false,
  }) : id = '',
       name = '',
       empty = true;

  Map<String, dynamic> toJson() => {
    'id': id,
    'n': name,
    'p': pos,
    if (zone != 0) 'z': zone,
    if (label.isNotEmpty) 'l': label,
    if (off) 'o': true,
    if (empty) 'e': true,
  };

  factory SlotAssign.fromJson(Map<String, dynamic> j) => SlotAssign(
    id: j['id'] as String? ?? '',
    name: j['n'] as String? ?? '',
    pos: j['p'] as String? ?? '',
    zone: (j['z'] as num?)?.toInt() ?? 0,
    label: j['l'] as String? ?? '',
    off: j['o'] as bool? ?? false,
    empty: j['e'] as bool? ?? false,
  );
}

/// 이름만 필요한 자리(대기/퇴장/코어 명단).
class PlayerRef {
  final String id;
  final String name;

  const PlayerRef({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'n': name};

  factory PlayerRef.fromJson(Map<String, dynamic> j) =>
      PlayerRef(id: j['id'] as String? ?? '', name: j['n'] as String? ?? '');
}

/// 한 경기의 결과.
class GameResult {
  /// [팀0, 팀1] 각각의 배치.
  final List<List<SlotAssign>> teams;

  /// 팀 이름(ABC 모드는 'A'/'B'/'C', 자유 모드는 항상 'A'/'B').
  final List<String> names;

  final List<PlayerRef> bench;
  final double cost;

  /// 두 팀의 평균 적합도 차이(균형 지표).
  final double fitGap;

  /// 팀별 비주 포지션 인원 수.
  final List<int> nonMain;

  /// 이 경기 시각에 이미 퇴장한 사람.
  final List<PlayerRef> left;

  /// ABC 모드의 코어 명단 [A, B, C]. 자유 모드는 null.
  final List<List<PlayerRef>>? cores;

  /// 팀별로 사람이 없어 비워 둔 자리 목록.
  final List<List<String>> need;

  /// 팀별로 어떤 구성으로 짰는지(코트를 그리려면 필요하다).
  final List<String>? tpls;

  const GameResult({
    required this.teams,
    required this.names,
    required this.bench,
    required this.cost,
    required this.fitGap,
    required this.nonMain,
    this.left = const [],
    this.cores,
    this.need = const [[], []],
    this.tpls,
  });

  /// 이 경기에 비는 자리가 있는지.
  bool get hasNeed => need.any((n) => n.isNotEmpty);

  GameResult copyWith({List<PlayerRef>? left, List<List<PlayerRef>>? cores}) =>
      GameResult(
        teams: teams,
        names: names,
        bench: bench,
        cost: cost,
        fitGap: fitGap,
        nonMain: nonMain,
        left: left ?? this.left,
        cores: cores ?? this.cores,
        need: need,
        tpls: tpls,
      );

  Map<String, dynamic> toJson() => {
    'teams': teams.map((t) => t.map((a) => a.toJson()).toList()).toList(),
    'names': names,
    'bench': bench.map((b) => b.toJson()).toList(),
    'cost': cost,
    'fitGap': fitGap,
    'nonMain': nonMain,
    'left': left.map((l) => l.toJson()).toList(),
    if (hasNeed) 'need': need,
    if (tpls != null) 'tpls': tpls,
    if (cores != null)
      'cores': cores!.map((c) => c.map((p) => p.toJson()).toList()).toList(),
  };

  factory GameResult.fromJson(Map<String, dynamic> j) {
    List<PlayerRef> refs(dynamic v) => (v as List? ?? [])
        .map((e) => PlayerRef.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return GameResult(
      teams: (j['teams'] as List? ?? [])
          .map(
            (t) => (t as List)
                .map(
                  (a) =>
                      SlotAssign.fromJson(Map<String, dynamic>.from(a as Map)),
                )
                .toList(),
          )
          .toList(),
      names: (j['names'] as List? ?? []).map((e) => e as String).toList(),
      bench: refs(j['bench']),
      cost: (j['cost'] as num?)?.toDouble() ?? 0,
      fitGap: (j['fitGap'] as num?)?.toDouble() ?? 0,
      nonMain: (j['nonMain'] as List? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      left: refs(j['left']),
      tpls: j['tpls'] == null
          ? null
          : (j['tpls'] as List).map((e) => e as String).toList(),
      need: j['need'] == null
          ? const [[], []]
          : (j['need'] as List)
                .map((n) => (n as List).map((e) => e as String).toList())
                .toList(),
      cores: j['cores'] == null
          ? null
          : (j['cores'] as List).map((c) => refs(c)).toList(),
    );
  }
}

/// 아직 확정되지 않은 뽑기 결과.
class RoundResult {
  final int round;
  final List<GameResult> games;
  final String mode;
  final String prio;
  final String sport;

  /// 6인제 전술('5-1'|'6-2'). 9인제는 빈 문자열.
  final String tactic;

  /// 실제로 사용된 비주 예산(요청한 실험 자리보다 크면 완화된 것).
  final int budget;

  /// 뽑을 때 요청했던 실험 자리 수.
  final int flexAsked;

  /// ABC 모드에서 선택된 팀 크기.
  final int? teamSize;

  /// 고정(📌)을 다 지킬 수 없어 풀고 뽑았는지.
  final bool pinsRelaxed;

  /// A · B · C 인원이 안 돼 자유 편성으로 내려갔는지.
  final bool abcFellBack;

  const RoundResult({
    required this.round,
    required this.games,
    required this.mode,
    required this.prio,
    this.sport = 'v6',
    this.tactic = '5-1',
    required this.budget,
    this.flexAsked = 0,
    this.teamSize,
    this.pinsRelaxed = false,
    this.abcFellBack = false,
  });

  double get totalCost => games.fold(0.0, (s, g) => s + g.cost);

  /// 비는 자리가 하나라도 있는지.
  bool get hasNeed => games.any((g) => g.hasNeed);

  RoundResult copyWith({bool? pinsRelaxed, bool? abcFellBack, String? mode}) =>
      RoundResult(
        round: round,
        games: games,
        mode: mode ?? this.mode,
        prio: prio,
        sport: sport,
        tactic: tactic,
        budget: budget,
        flexAsked: flexAsked,
        teamSize: teamSize,
        pinsRelaxed: pinsRelaxed ?? this.pinsRelaxed,
        abcFellBack: abcFellBack ?? this.abcFellBack,
      );
}

/// 확정된 라운드 기록.
class PastRound {
  final int round;
  final List<GameResult> games;
  final String mode;

  /// 이 라운드를 뽑았을 때의 종목. 코트를 그리려면 필요하다.
  final String sport;

  const PastRound({
    required this.round,
    required this.games,
    required this.mode,
    this.sport = 'v6',
  });

  Map<String, dynamic> toJson() => {
    'round': round,
    'games': games.map((g) => g.toJson()).toList(),
    'mode': mode,
    'sport': sport,
  };

  factory PastRound.fromJson(Map<String, dynamic> j) => PastRound(
    round: (j['round'] as num?)?.toInt() ?? 1,
    games: (j['games'] as List? ?? [])
        .map((g) => GameResult.fromJson(Map<String, dynamic>.from(g as Map)))
        .toList(),
    mode: j['mode'] as String? ?? 'abc',
    sport: j['sport'] as String? ?? 'v6',
  );
}

/// 보관한 지난 모임. 기록이 한 모임에 영영 묶이지 않게 끊어 둔다.
class AnchigiMeet {
  final String date;
  final int rounds;
  final String sport;
  final Map<String, dynamic> stat;
  final List<PastRound> past;

  const AnchigiMeet({
    required this.date,
    required this.rounds,
    required this.sport,
    required this.stat,
    this.past = const [],
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'rounds': rounds,
    'sport': sport,
    'stat': stat,
    'past': past.map((r) => r.toJson()).toList(),
  };

  factory AnchigiMeet.fromJson(Map<String, dynamic> j) => AnchigiMeet(
    date: j['date'] as String? ?? '',
    rounds: (j['rounds'] as num?)?.toInt() ?? 0,
    sport: j['sport'] as String? ?? 'v6',
    stat: j['stat'] is Map
        ? Map<String, dynamic>.from(j['stat'] as Map)
        : <String, dynamic>{},
    past: (j['past'] as List? ?? [])
        .map((e) => PastRound.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}
