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

  /// 포지션 → 티어('main'|'sub'|'want'). 키가 없으면 그 포지션 불가.
  Map<String, String> tier;

  /// 참석 여부.
  bool here;

  /// 퇴장 시각 'HH:MM'. null이면 끝까지.
  String? leave;

  AnchigiPlayer({
    required this.id,
    required this.name,
    Map<String, String>? tier,
    this.here = true,
    this.leave,
  }) : tier = tier ?? <String, String>{};

  /// 가능 포지션 목록(kPos 순서). 원본은 p.pos 필드를 캐시했으나
  /// Dart에서는 tier가 단일 소스가 되도록 파생 getter로 둔다.
  List<String> get pos => kPos.where((p) => tier[p] != null).toList();

  String? tierOf(String p) => tier[p];

  int fitOf(String p) => kFit[tier[p]] ?? 0;

  int get mainCount => tier.values.where((v) => v == 'main').length;

  /// 원본 normalizePlayer(): 포지션이 하나도 없으면 S를 주 포지션으로 강제.
  void normalize() {
    tier.removeWhere((k, v) => !kPos.contains(k) || !kTiers.contains(v));
    if (tier.isEmpty) tier['S'] = 'main';
  }

  AnchigiPlayer copy() => AnchigiPlayer(
    id: id,
    name: name,
    tier: Map<String, String>.from(tier),
    here: here,
    leave: leave,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tier': tier,
    'here': here,
    'leave': leave,
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
    final p = AnchigiPlayer(
      id: (j['id'] as String?) ?? genPlayerId(),
      name: (j['name'] as String?) ?? '',
      tier: tier,
      here: j['here'] as bool? ?? true,
      leave: j['leave'] as String?,
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
    : pos = pos ?? {for (final p in kPos) p: 0};

  Map<String, dynamic> toJson() => {'play': play, 'bench': bench, 'pos': pos};

  factory AnchigiStat.fromJson(Map<String, dynamic> j) {
    final pos = {for (final p in kPos) p: 0};
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
