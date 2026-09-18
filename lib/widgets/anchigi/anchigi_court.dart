// anchigi_court.dart — 한 경기의 코트 시각화. 원본 anchigi.html의 toZones/sideHTML 포팅.
// 두 팀이 네트를 사이에 두고 마주 보도록 아래 팀은 자리 배열을 뒤집는다.
// 6인제는 로테이션이 있어 존(1~6)으로 서고, 9인제는 로테이션이 없어
// 속공 수에 따른 포메이션의 줄 인원(2-4-3 · 3-4-2 · 4-3-2)대로 선다.
import 'package:flutter/material.dart';

import '../../models/anchigi/anchigi_constants.dart';
import '../../models/anchigi/anchigi_round.dart';
import '../../services/i18n.dart';
import '../../theme.dart';

/// 위 팀: 후위 1·6·5 / 전위 2·3·4. 아래 팀은 마주 보도록 좌우·앞뒤가 뒤집힌다.
const List<List<int>> _topRows = [
  [1, 6, 5],
  [2, 3, 4],
];
const List<List<int>> _botRows = [
  [4, 3, 2],
  [5, 6, 1],
];

/// 역할별 색(웹 .pos.S 등과 같은 역할).
const Map<String, Color> _posColor = {
  'S': Color(0xFF6A5ACD),
  'OP': Color(0xFFE07A5F),
  'OH': Color(0xFF3D9970),
  'MB': Color(0xFF2C7BE5),
  'Li': Color(0xFFD4A017),
  'S9': Color(0xFF6A5ACD),
  'QK': Color(0xFF2C7BE5),
  'L9': Color(0xFF3D9970),
  'R9': Color(0xFFE07A5F),
  'CH': Color(0xFF5C6BC0),
  'BK': Color(0xFFD4A017),
};

/// 코트 한 칸. 비어 있으면 [pl] 이 null, 사람이 없어 비운 자리면 pl.empty.
typedef _Cell = ({String label, SlotAssign? pl});

/// 존 번호 → 배치된 사람. 존을 안 싣던 시절의 기록용 폴백.
Map<int, SlotAssign> _legacyZones(List<SlotAssign> lineup) {
  final z = <int, SlotAssign>{};
  final ohs = [2, 5], mbs = [3, 6];
  for (final p in lineup) {
    switch (p.pos) {
      case 'S':
        z[1] = p;
      case 'OP':
        z[4] = p;
      case 'OH':
        if (ohs.isNotEmpty) z[ohs.removeAt(0)] = p;
      case 'MB':
        if (mbs.isNotEmpty) z[mbs.removeAt(0)] = p;
      case 'Li':
        z[6] = p;
    }
  }
  return z;
}

class AnchigiCourt extends StatelessWidget {
  final GameResult game;

  /// 이 경기의 두 팀 코어 명단(차출 표시용). 자유 편성이면 null.
  final List<List<PlayerRef>>? teamCores;

  final String? picked;
  final ValueChanged<String>? onPick;

  /// 이 경기를 뽑았을 때의 종목.
  final String sport;

  const AnchigiCourt({
    super.key,
    required this.game,
    this.teamCores,
    this.picked,
    this.onPick,
    this.sport = 'v6',
  });

  /// 이 팀을 어떤 구성으로 짰는지.
  AnchigiTemplate? _tplOf(int teamIdx) {
    final ids = game.tpls;
    if (ids == null || teamIdx >= ids.length) return null;
    return templateById(ids[teamIdx]);
  }

  bool _isBorrowed(int teamIdx, String id) {
    final cores = teamCores;
    if (cores == null) return false;
    return !cores[teamIdx].any((x) => x.id == id);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _side(0, true),
      // 네트.
      Container(
        height: 3,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: NurungjiColors.brown.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      _side(1, false),
    ],
  );

  /// 코트 칸 머리에 붙는 작은 글씨 — 자리 이름이 있으면 그걸, 없으면 존 번호.
  String _seatLabel(SlotAssign x) {
    if (x.label.isNotEmpty && x.zone != 0) {
      return '${t('ag_court_zone_short')}${x.zone} · ${t(x.label)}';
    }
    if (x.label.isNotEmpty) return t(x.label);
    if (x.zone != 0) return '${t('ag_court_zone_short')}${x.zone}';
    return t('ag_posx_${x.pos}');
  }

  /// 이 팀의 코트 칸을 줄 단위로 만든다.
  /// 6인제는 존(1~6)으로 두 줄, 9인제는 포메이션의 줄 인원대로 세 줄.
  ({List<List<_Cell>> rows, List<SlotAssign> off}) _layout(
    List<SlotAssign> lineup,
    bool top,
    int teamIdx,
  ) {
    final off = lineup.where((x) => x.off).toList();
    final on = lineup.where((x) => !x.off).toList();

    if (sport == 'v9') {
      final tpl = _tplOf(teamIdx);
      final lens = (tpl?.rows != null && tpl!.slots.length == lineup.length)
          ? tpl.rows!
          : [for (var i = 0; i < on.length; i += 3) 3];
      var rows = <List<_Cell>>[];
      var i = 0;
      for (final n in lens) {
        final take = on.skip(i).take(n).toList();
        if (take.isEmpty) break;
        rows.add([for (final x in take) (label: _seatLabel(x), pl: x)]);
        i += n;
      }
      // 위쪽 팀은 네트가 아래라 뒷줄부터 그리고, 좌우도 뒤집힌다.
      if (top) {
        rows = rows.reversed.map((r) => r.reversed.toList()).toList();
      }
      return (rows: rows, off: off);
    }

    var byZone = <int, SlotAssign>{for (final x in on) if (x.zone != 0) x.zone: x};
    if (byZone.isEmpty) byZone = _legacyZones(on);
    final order = top ? _topRows : _botRows;
    return (
      rows: [
        for (final row in order)
          [
            for (final zn in row)
              (
                label: byZone[zn] == null
                    ? '${t('ag_court_zone_short')}$zn'
                    : _seatLabel(byZone[zn]!),
                pl: byZone[zn],
              ),
          ],
      ],
      off: off,
    );
  }

  Widget _side(int teamIdx, bool top) {
    final lineup = game.teams[teamIdx];
    final l = _layout(lineup, top, teamIdx);
    final name = teamIdx < game.names.length ? game.names[teamIdx] : '?';
    // 비운 자리는 인원으로 세지 않는다.
    final filled = lineup.where((x) => !x.empty).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${t('ag_team_word')} $name',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                  color: NurungjiColors.dark,
                ),
              ),
              Text(
                '$filled${t('ag_people')}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: NurungjiColors.brown,
                ),
              ),
            ],
          ),
        ),
        for (final row in l.rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  Expanded(child: _cell(teamIdx, row[i].label, row[i].pl)),
                  if (i != row.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        // 코트 밖에서 교대하는 자리(6인제 리베로).
        for (final o in l.off)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Flexible(child: _cell(teamIdx, _seatLabel(o), o)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t('ag_team_swap'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: NurungjiColors.brown,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(int teamIdx, String label, SlotAssign? pl) {
    if (pl == null) {
      return Container(
        height: 58,
        decoration: BoxDecoration(
          color: NurungjiColors.chipBg.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }
    final color = _posColor[pl.pos] ?? NurungjiColors.brown;

    // 사람이 없어 비운 자리 — 어떤 자리를 구해야 하는지 여기서 읽힌다.
    if (pl.empty) {
      return Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: NurungjiColors.urgent.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: NurungjiColors.urgent.withValues(alpha: .55),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: NurungjiColors.brown,
              ),
            ),
            Text(
              '(${t('ag_need_label')})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: NurungjiColors.urgent,
              ),
            ),
            _posBadge(pl.pos, color),
          ],
        ),
      );
    }

    final hl = picked != null && picked == pl.id;
    final borrowed = _isBorrowed(teamIdx, pl.id);

    return GestureDetector(
      onTap: onPick == null ? null : () => onPick!(pl.id),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: hl
              ? NurungjiColors.yellow.withValues(alpha: .55)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hl ? NurungjiColors.yellow : const Color(0x22000000),
            width: hl ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: NurungjiColors.brown,
              ),
            ),
            Text(
              pl.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: NurungjiColors.dark,
              ),
            ),
            Row(
              children: [
                _posBadge(pl.pos, color),
                if (borrowed) ...[
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      t('ag_borrowed'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: NurungjiColors.urgent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _posBadge(String pos, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      t('ag_posx_$pos'),
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
  );
}

/// 간단히 보기 — 코트 그림 대신 '자리 · 사람' 한 줄.
class AnchigiLineupList extends StatelessWidget {
  final GameResult game;
  final List<List<PlayerRef>>? teamCores;
  final String? picked;
  final ValueChanged<String>? onPick;

  const AnchigiLineupList({
    super.key,
    required this.game,
    this.teamCores,
    this.picked,
    this.onPick,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var ti = 0; ti < game.teams.length; ti++)
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x22000000)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: NurungjiColors.dark,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '${t('ag_team_word')} ${ti < game.names.length ? game.names[ti] : '?'}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                for (final pl in game.teams[ti]) _slot(ti, pl),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _slot(int ti, SlotAssign pl) {
    final label = pl.label.isNotEmpty ? t(pl.label) : t('ag_posx_${pl.pos}');
    if (pl.empty) {
      return Text(
        '$label (${t('ag_need_label')})',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: NurungjiColors.urgent,
        ),
      );
    }
    final borrowed =
        teamCores != null && !teamCores![ti].any((x) => x.id == pl.id);
    final hl = picked != null && picked == pl.id;
    return GestureDetector(
      onTap: onPick == null ? null : () => onPick!(pl.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: hl ? NurungjiColors.yellow : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          '$label · ${pl.name}${borrowed ? ' (${t('ag_borrowed')})' : ''}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: NurungjiColors.dark,
          ),
        ),
      ),
    );
  }
}
