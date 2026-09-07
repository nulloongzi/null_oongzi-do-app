// anchigi_court.dart — 한 경기의 코트 시각화. 원본 anchigi.html의 toZones/sideHTML 포팅.
// 두 팀이 네트를 사이에 두고 마주 보도록 아래 팀은 존 배열을 뒤집는다.
import 'package:flutter/material.dart';

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

/// 포지션별 색(웹 .pos.S 등과 같은 역할).
const Map<String, Color> _posColor = {
  'S': Color(0xFF6A5ACD),
  'OP': Color(0xFFE07A5F),
  'OH': Color(0xFF3D9970),
  'MB': Color(0xFF2C7BE5),
  'Li': Color(0xFFD4A017),
};

/// 존 번호 → 배치된 사람. 7인(센터2+리베로1)이면 리베로는 코트 밖.
({Map<int, SlotAssign> zones, SlotAssign? libero}) _toZones(
  List<SlotAssign> lineup,
) {
  final z = <int, SlotAssign>{};
  final ohs = [2, 5], mbs = [3, 6];
  SlotAssign? libero;
  final nMb = lineup.where((x) => x.pos == 'MB').length;
  final nLi = lineup.where((x) => x.pos == 'Li').length;
  // 센터 2 + 리베로 1이면 리베로가 후위 센터와 교대하므로 코트 밖에 표시한다.
  final split = nMb == 2 && nLi == 1;

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
        if (split) {
          libero = p;
        } else {
          z[6] = p;
        }
    }
  }
  return (zones: z, libero: libero);
}

class AnchigiCourt extends StatelessWidget {
  final GameResult game;

  /// 이 경기의 두 팀 코어 명단(차출 표시용). 자유 편성이면 null.
  final List<List<PlayerRef>>? teamCores;

  final String? picked;
  final ValueChanged<String>? onPick;

  const AnchigiCourt({
    super.key,
    required this.game,
    this.teamCores,
    this.picked,
    this.onPick,
  });

  bool _isBorrowed(int teamIdx, String id) {
    final cores = teamCores;
    if (cores == null) return false;
    return !cores[teamIdx].any((x) => x.id == id);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _side(0, _topRows),
      // 네트.
      Container(
        height: 3,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: NurungjiColors.brown.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      _side(1, _botRows),
    ],
  );

  Widget _side(int teamIdx, List<List<int>> rows) {
    final lineup = game.teams[teamIdx];
    final r = _toZones(lineup);
    final name = teamIdx < game.names.length ? game.names[teamIdx] : '?';

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
                '${lineup.length}${t('ag_people')}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: NurungjiColors.brown,
                ),
              ),
            ],
          ),
        ),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (final zn in row) ...[
                  Expanded(child: _cell(teamIdx, zn, r.zones[zn])),
                  if (zn != row.last) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        if (r.libero != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Flexible(child: _cell(teamIdx, null, r.libero)),
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

  Widget _cell(int teamIdx, int? zone, SlotAssign? pl) {
    if (pl == null) {
      return Container(
        height: 58,
        decoration: BoxDecoration(
          color: NurungjiColors.chipBg.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }
    final hl = picked != null && picked == pl.id;
    final borrowed = _isBorrowed(teamIdx, pl.id);
    final color = _posColor[pl.pos] ?? NurungjiColors.brown;

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
              zone == null ? pl.pos : '${t('ag_court_zone_short')}$zone',
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    pl.pos,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
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
}
