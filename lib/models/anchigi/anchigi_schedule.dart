// anchigi_schedule.dart — 운동 시간표 계산. 원본 anchigi.html의 스케줄 수학 포팅.
// 주의: start는 표시 전용(몸풀기 라벨)이고, 모든 경기 시각은 warmup을 기준으로 계산된다.

class AnchigiSchedule {
  String start;
  String warmup;
  String end;
  int perGame;
  int rest;

  AnchigiSchedule({
    this.start = '13:00',
    this.warmup = '14:00',
    this.end = '17:00',
    this.perGame = 15,
    this.rest = 10,
  });

  AnchigiSchedule copy() => AnchigiSchedule(
    start: start,
    warmup: warmup,
    end: end,
    perGame: perGame,
    rest: rest,
  );

  Map<String, dynamic> toJson() => {
    'start': start,
    'warmup': warmup,
    'end': end,
    'perGame': perGame,
    'rest': rest,
  };

  factory AnchigiSchedule.fromJson(Map<String, dynamic> j) => AnchigiSchedule(
    start: j['start'] as String? ?? '13:00',
    warmup: j['warmup'] as String? ?? '14:00',
    end: j['end'] as String? ?? '17:00',
    perGame: (j['perGame'] as num?)?.toInt() ?? 15,
    // 레거시 데이터에 rest가 없던 경우 10으로 보정(원본과 동일).
    rest: (j['rest'] as num?)?.toInt() ?? 10,
  );

  /// 라운드 rnd(1-base), 경기 gi(0-base)의 시작 시각(분).
  int gameStartMin(int rnd, int gi, int nGames) {
    final w = parseTime(warmup) ?? 0;
    return w + ((rnd - 1) * nGames + gi) * perGame + (rnd - 1) * rest;
  }

  int gameEndMin(int rnd, int gi, int nGames) =>
      gameStartMin(rnd, gi, nGames) + perGame;

  /// 종료 시각까지 가능한 최대 라운드 수. 마지막 라운드 뒤 휴식은 빼고 계산.
  int maxRounds(int nGames) {
    final e = parseTime(end), w = parseTime(warmup);
    if (e == null || w == null) return 99;
    final total = e - w;
    final per = nGames * perGame;
    if (total <= 0 || per <= 0) return 99;
    return ((total + rest) / (per + rest)).floor();
  }
}

/// 'HH:MM' → 분. 파싱 실패 시 null.
int? parseTime(String? s) {
  if (s == null || s.isEmpty) return null;
  final parts = s.split(':');
  final h = int.tryParse(parts[0]);
  if (h == null) return null;
  final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  return h * 60 + m;
}

/// 분 → 'HH:MM'(24시간 순환).
String formatTime(int m) {
  final h = (m ~/ 60) % 24;
  final mm = m % 60;
  return '${h < 10 ? '0' : ''}$h:${mm < 10 ? '0' : ''}$mm';
}
