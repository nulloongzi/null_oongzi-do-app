// anchigi_round.dart — 뽑기 결과 모델. 원본 anchigi.html의 game/current/pastRounds 포팅.
// 원본은 배열에 .T/.bud 같은 속성을 얹었으나, Dart에서는 명시적 필드로 둔다.

/// 코트에 배치된 한 명.
class SlotAssign {
  final String id;
  final String name;
  final String pos;

  const SlotAssign({required this.id, required this.name, required this.pos});

  Map<String, dynamic> toJson() => {'id': id, 'n': name, 'p': pos};

  factory SlotAssign.fromJson(Map<String, dynamic> j) => SlotAssign(
    id: j['id'] as String? ?? '',
    name: j['n'] as String? ?? '',
    pos: j['p'] as String? ?? '',
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

  const GameResult({
    required this.teams,
    required this.names,
    required this.bench,
    required this.cost,
    required this.fitGap,
    required this.nonMain,
    this.left = const [],
    this.cores,
  });

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
      );

  Map<String, dynamic> toJson() => {
    'teams': teams.map((t) => t.map((a) => a.toJson()).toList()).toList(),
    'names': names,
    'bench': bench.map((b) => b.toJson()).toList(),
    'cost': cost,
    'fitGap': fitGap,
    'nonMain': nonMain,
    'left': left.map((l) => l.toJson()).toList(),
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
  final String feel;

  /// 실제로 사용된 비주 예산(feel 기본값보다 크면 완화된 것).
  final int budget;

  /// ABC 모드에서 선택된 팀 크기.
  final int? teamSize;

  const RoundResult({
    required this.round,
    required this.games,
    required this.mode,
    required this.feel,
    required this.budget,
    this.teamSize,
  });

  double get totalCost => games.fold(0.0, (s, g) => s + g.cost);
}

/// 확정된 라운드 기록.
class PastRound {
  final int round;
  final List<GameResult> games;
  final String mode;

  const PastRound({
    required this.round,
    required this.games,
    required this.mode,
  });

  Map<String, dynamic> toJson() => {
    'round': round,
    'games': games.map((g) => g.toJson()).toList(),
    'mode': mode,
  };

  factory PastRound.fromJson(Map<String, dynamic> j) => PastRound(
    round: (j['round'] as num?)?.toInt() ?? 1,
    games: (j['games'] as List? ?? [])
        .map((g) => GameResult.fromJson(Map<String, dynamic>.from(g as Map)))
        .toList(),
    mode: j['mode'] as String? ?? 'abc',
  );
}
