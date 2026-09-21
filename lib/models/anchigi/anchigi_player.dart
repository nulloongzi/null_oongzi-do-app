// anchigi_player.dart — 안치기 선수 모델. 원본 anchigi.html의 player 객체 포팅.
// tier에 키가 있으면 그 포지션 가능, 없으면 불가. pos는 tier에서 파생.
import 'dart:math';

import 'anchigi_constants.dart';

int _idSeq = 0;
final Random _idRand = Random();

/// 원본 genId(): 'p' + 순번(36진) + '-' + 난수(36진).
String genPlayerId() {
  final seq = (_idSeq++).toRadixString(36);
  final rnd = (_idRand.nextDouble() * 1679616).floor().toRadixString(36);
  return 'p$seq-$rnd';
}

class AnchigiPlayer {
  String id;
  String name;

  /// 자리 → 티어('main'|'sub'|'want'). 키가 없으면 그 자리는 안 고른 것.
  /// 두 종목 자리를 한 맵에 담는다(키가 겹치지 않는다).
  Map<String, String> tier;

  /// 참석 여부.
  bool here;

  /// 퇴장 시각 'HH:MM'. null이면 끝까지.
  String? leave;

  /// 종목별 고정(📌) 자리. {'v6': 'S'} 처럼 진행하는 사람이 지정한다.
  Map<String, String> pin;

  /// 고정할 코어(0=A,1=B,2=C). null이면 자동.
  int? pinTeam;

  /// 지금 보고 있는 종목. 가능 자리·티어가 이 값에 따라 갈린다.
  /// (웹의 전역 sport 와 같은 역할 — 스토어가 갈아 끼운다.)
  String sport;

  AnchigiPlayer({
    required this.id,
    required this.name,
    Map<String, String>? tier,
    this.here = true,
    this.leave,
    Map<String, String>? pin,
    this.pinTeam,
    this.sport = 'v6',
  }) : tier = tier ?? <String, String>{},
       pin = pin ?? <String, String>{};

  List<String> get _seats => posOfSport(sport);

  /// 이 종목 자리를 하나도 안 고른 사람 = '어디든'.
  /// 예전엔 자동으로 세터를 박아 넣어, 이름만 넣고 시작하면 전원 세터 전용이 됐다.
  bool get isFlex => !_seats.any((p) => tier[p] != null);

  /// 이 종목에서 설 수 있는 자리. 미지정이면 전 자리.
  List<String> get pos {
    final picked = _seats.where((p) => tier[p] != null).toList();
    return picked.isEmpty ? List<String>.from(_seats) : picked;
  }

  /// 솔버가 보는 티어. '어디든'인 사람은 모든 자리가 주 자리다.
  String? tierOf(String p) {
    if (!_seats.contains(p)) return null;
    if (isFlex) return 'main';
    return tier[p];
  }

  /// 저장된 티어 그대로. 명단 화면의 칩 조작은 이쪽을 봐야 첫 클릭이 주로 잡힌다.
  String? rawTier(String p) => tier[p];

  int fitOf(String p) => kFit[tierOf(p)] ?? 0;

  int get mainCount => _seats.where((p) => tier[p] == 'main').length;

  /// 이 종목의 주 자리(없으면 첫 가능 자리).
  String? get mainPos {
    for (final p in _seats) {
      if (tier[p] == 'main') return p;
    }
    return pos.isEmpty ? null : pos.first;
  }

  /// 이 종목에서 고정된 자리. 설 수 없는 자리면 고정으로 치지 않는다.
  String? get pinned {
    final v = pin[sport];
    return (v != null && pos.contains(v)) ? v : null;
  }

  void normalize() {
    tier.removeWhere((k, v) => !kAllPos.contains(k) || !kTiers.contains(v));
    pin.removeWhere((k, v) => !kSports.contains(k) || !kAllPos.contains(v));
    if (pinTeam != null && (pinTeam! < 0 || pinTeam! > 2)) pinTeam = null;
  }

  AnchigiPlayer copy() => AnchigiPlayer(
    id: id,
    name: name,
    tier: Map<String, String>.from(tier),
    here: here,
    leave: leave,
    pin: Map<String, String>.from(pin),
    pinTeam: pinTeam,
    sport: sport,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tier': tier,
    'here': here,
    'leave': leave,
    if (pin.isNotEmpty) 'pin': pin,
    if (pinTeam != null) 'pinTeam': pinTeam,
  };

  factory AnchigiPlayer.fromJson(Map<String, dynamic> j) {
    final rawTier = j['tier'];
    final tier = <String, String>{};
    if (rawTier is Map) {
      rawTier.forEach((k, v) {
        if (k is String && v is String) tier[k] = v;
      });
    } else if (j['pos'] is List) {
      // 레거시: pos 배열만 있던 시절 → 전부 main으로 승격.
      for (final p in (j['pos'] as List)) {
        if (p is String) tier[p] = 'main';
      }
    }
    final pin = <String, String>{};
    final rawPin = j['pin'];
    if (rawPin is Map) {
      rawPin.forEach((k, v) {
        if (k is String && v is String) pin[k] = v;
      });
    }
    final p = AnchigiPlayer(
      id: (j['id'] as String?) ?? genPlayerId(),
      name: (j['name'] as String?) ?? '',
      tier: tier,
      here: j['here'] as bool? ?? true,
      leave: j['leave'] as String?,
      pin: pin,
      pinTeam: (j['pinTeam'] as num?)?.toInt(),
    );
    p.normalize();
    return p;
  }
}

/// 누적 기록. 원본 stat[id] = {play, bench, pos:{...}}.
class AnchigiStat {
  int play;
  int bench;
  Map<String, int> pos;

  AnchigiStat({this.play = 0, this.bench = 0, Map<String, int>? pos})
    : pos = pos ?? {for (final p in kAllPos) p: 0} {
    // 6인제만 쓰던 시절의 기록에는 9인제 자리 칸이 없다.
    for (final p in kAllPos) {
      this.pos.putIfAbsent(p, () => 0);
    }
  }

  Map<String, dynamic> toJson() => {'play': play, 'bench': bench, 'pos': pos};

  factory AnchigiStat.fromJson(Map<String, dynamic> j) {
    final pos = {for (final p in kAllPos) p: 0};
    final raw = j['pos'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k is String && pos.containsKey(k) && v is num) {
          pos[k] = v.toInt();
        }
      });
    }
    return AnchigiStat(
      play: (j['play'] as num?)?.toInt() ?? 0,
      bench: (j['bench'] as num?)?.toInt() ?? 0,
      pos: pos,
    );
  }
}
