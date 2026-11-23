// anchigi_day.dart — 날짜 하나의 안치기. 원본 anchigi.html의 days[] 포팅.
// 픽업은 날짜마다 오는 사람이 다르고 명단을 몇 주 전부터 받아 둔다(11/21 · 12/27 …).
// 그래서 명단 · 참석 · 기록 · 라운드를 날짜 하나에 묶어 따로 저장한다.
// JSON 형식은 웹과 같다: {id, date:'YYYY-MM-DD'|'', title, players, stat, round, past}.
import 'anchigi_player.dart';
import 'anchigi_round.dart';

class AnchigiDay {
  final String id;

  /// 'YYYY-MM-DD'. 비어 있으면 '날짜 미정'.
  String date;

  /// 고른 이름(예: 정기 픽업). 비어 있어도 된다.
  String title;

  List<AnchigiPlayer> players;
  Map<String, AnchigiStat> stat;
  int round;
  List<PastRound> past;

  /// 뽑았지만 아직 확정하지 않은 배치. 앱이 꺼져도 남는다.
  RoundResult? current;

  AnchigiDay({
    required this.id,
    this.date = '',
    this.title = '',
    List<AnchigiPlayer>? players,
    Map<String, AnchigiStat>? stat,
    this.round = 1,
    List<PastRound>? past,
    this.current,
  }) : players = players ?? [],
       stat = stat ?? {},
       past = past ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'title': title,
    'players': players.map((p) => p.toJson()).toList(),
    'stat': {for (final e in stat.entries) e.key: e.value.toJson()},
    'round': round,
    'past': past.map((r) => r.toJson()).toList(),
    if (current != null) 'current': current!.toJson(),
  };

  factory AnchigiDay.fromJson(Map<String, dynamic> j) {
    final stat = <String, AnchigiStat>{};
    if (j['stat'] is Map) {
      (j['stat'] as Map).forEach((k, v) {
        if (k is String && v is Map) {
          stat[k] = AnchigiStat.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }
    return AnchigiDay(
      id: j['id'] as String? ?? '',
      date: j['date'] as String? ?? '',
      title: j['title'] as String? ?? '',
      players: (j['players'] as List? ?? [])
          .map(
            (e) => AnchigiPlayer.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      stat: stat,
      round: (j['round'] as num?)?.toInt() ?? 1,
      past: (j['past'] as List? ?? [])
          .map((e) => PastRound.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      current: _current(j['current']),
    );
  }

  /// 뽑아 둔 배치는 읽다 깨져도 날짜 전체를 버리지 않는다 — 배치만 없는 셈 친다.
  static RoundResult? _current(dynamic v) {
    if (v is! Map) return null;
    try {
      final r = RoundResult.fromJson(Map<String, dynamic>.from(v));
      return r.games.isEmpty ? null : r;
    } catch (_) {
      return null;
    }
  }
}

/// 날짜순(가까운 날 먼저), 날짜 미정은 맨 뒤.
List<AnchigiDay> sortDays(Iterable<AnchigiDay> days) {
  final l = days.toList();
  l.sort((a, b) {
    if (a.date.isEmpty != b.date.isEmpty) return a.date.isEmpty ? 1 : -1;
    return a.date.compareTo(b.date);
  });
  return l;
}
