// anchigi_constants.dart — 안치기 상수/템플릿/가중치 테이블.
// 원본 anchigi.html(Vanilla JS)의 POS/FIT/TEMPLATES/FEEL을 그대로 옮김.
// 값이 바뀌면 배치 결과가 달라지므로 원본과 1:1로 유지할 것.

/// 종목. v6=6인제(로테이션·대각), v9=9인제(자리 고정 3×3).
const List<String> kSports = ['v6', 'v9'];

/// 종목별 자리 코드. 순서 의미 있음(slotCost의 `자리 수 - nOpt` 계산에 쓰임).
const Map<String, List<String>> kPosBySport = {
  'v6': ['S', 'OP', 'OH', 'MB', 'Li'],
  // 9인제는 포메이션마다 자리 이름이 달라(앞속공·빽속공·앞차·빽차…),
  // 명단에서는 역할 6종만 고르고 구체적인 자리는 코트에만 표시한다.
  'v9': ['S9', 'QK', 'L9', 'R9', 'CH', 'BK'],
};

/// 6인제 자리. 기존 호출부 호환용 별칭.
const List<String> kPos = ['S', 'OP', 'OH', 'MB', 'Li'];

/// 두 종목 자리를 합친 목록. 기록(stat)은 이 키로 한 벌만 쌓는다.
const List<String> kAllPos = [
  'S',
  'OP',
  'OH',
  'MB',
  'Li',
  'S9',
  'QK',
  'L9',
  'R9',
  'CH',
  'BK',
];

/// 6인제 전술. 5-1은 세터 한 명, 6-2는 세터 둘(전위 세터는 라이트 자리).
const List<String> kTactics = ['5-1', '6-2'];

List<String> posOfSport(String sport) =>
    kPosBySport[sport] ?? kPosBySport['v6']!;

/// 티어: 주(main) / 가능(sub) / 도전(want).
const List<String> kTiers = ['main', 'sub', 'want'];

/// 적합도 점수. 키가 없으면 0(=불가/도전).
const Map<String, int> kFit = {'main': 2, 'sub': 1, 'want': 0};

/// 코트의 자리 하나.
///  - [role]  명단에서 고르는 역량 키. 이게 맞아야 그 자리에 설 수 있다.
///  - [zone]  6인제 존(1~6). 로테이션이 있어 역할이 아니라 존으로 선다.
///  - [label] 9인제(와 6-2의 전위 세터)처럼 자리에 고유한 이름이 있을 때의 i18n 키.
///  - [off]   코트 밖에서 교대하는 자리(6인제 리베로).
class SeatSlot {
  final String role;
  final int zone;
  final String label;
  final bool off;

  const SeatSlot(this.role, {this.zone = 0, this.label = '', this.off = false});
}

/// 팀 구성. 6인제는 전술(5-1 · 6-2)로, 9인제는 속공 수로 갈린다.
class AnchigiTemplate {
  final String id;
  final String sport;

  /// 6인제 전술('5-1'|'6-2'). 9인제는 빈 문자열.
  final String tactic;

  final int size;
  final String labelKey;
  final String descKey;
  final List<SeatSlot> slots;

  /// 9인제 줄 인원(앞줄부터). 6인제는 null.
  final List<int>? rows;

  /// 포메이션에 따라붙는 수비 전환 메모의 i18n 키.
  final String noteKey;

  const AnchigiTemplate({
    required this.id,
    this.sport = 'v6',
    this.tactic = '',
    required this.size,
    required this.labelKey,
    required this.descKey,
    required this.slots,
    this.rows,
    this.noteKey = '',
  });
}

const List<AnchigiTemplate> kTemplates = [
  // 5-1 — 세터 한 명이 여섯 자리를 다 돈다.
  AnchigiTemplate(
    id: 'mb2',
    tactic: '5-1',
    size: 6,
    labelKey: 'ag_tpl_mb2',
    descKey: 'ag_tpl_mb2_desc',
    slots: [
      SeatSlot('S', zone: 1),
      SeatSlot('OP', zone: 4),
      SeatSlot('OH', zone: 2),
      SeatSlot('OH', zone: 5),
      SeatSlot('MB', zone: 3),
      SeatSlot('MB', zone: 6),
    ],
  ),
  AnchigiTemplate(
    id: 'mb1li',
    tactic: '5-1',
    size: 6,
    labelKey: 'ag_tpl_mb1li',
    descKey: 'ag_tpl_mb1li_desc',
    slots: [
      SeatSlot('S', zone: 1),
      SeatSlot('OP', zone: 4),
      SeatSlot('OH', zone: 2),
      SeatSlot('OH', zone: 5),
      SeatSlot('MB', zone: 3),
      SeatSlot('Li', zone: 6),
    ],
  ),
  AnchigiTemplate(
    id: 'mb2li',
    tactic: '5-1',
    size: 7,
    labelKey: 'ag_tpl_mb2li',
    descKey: 'ag_tpl_mb2li_desc',
    slots: [
      SeatSlot('S', zone: 1),
      SeatSlot('OP', zone: 4),
      SeatSlot('OH', zone: 2),
      SeatSlot('OH', zone: 5),
      SeatSlot('MB', zone: 3),
      SeatSlot('MB', zone: 6),
      SeatSlot('Li', off: true),
    ],
  ),
  // 6-2 — 세터 둘. 후위 세터가 토스하고, 전위 세터는 라이트 자리에서 공격한다.
  AnchigiTemplate(
    id: 'mb2x62',
    tactic: '6-2',
    size: 6,
    labelKey: 'ag_tpl_mb2',
    descKey: 'ag_tpl_mb2_desc',
    slots: [
      SeatSlot('S', zone: 1),
      SeatSlot('S', zone: 4, label: 'ag_seat_s_front'),
      SeatSlot('OH', zone: 2),
      SeatSlot('OH', zone: 5),
      SeatSlot('MB', zone: 3),
      SeatSlot('MB', zone: 6),
    ],
  ),
  AnchigiTemplate(
    id: 'mb1lix62',
    tactic: '6-2',
    size: 6,
    labelKey: 'ag_tpl_mb1li',
    descKey: 'ag_tpl_mb1li_desc',
    slots: [
      SeatSlot('S', zone: 1),
      SeatSlot('S', zone: 4, label: 'ag_seat_s_front'),
      SeatSlot('OH', zone: 2),
      SeatSlot('OH', zone: 5),
      SeatSlot('MB', zone: 3),
      SeatSlot('Li', zone: 6),
    ],
  ),
  AnchigiTemplate(
    id: 'mb2lix62',
    tactic: '6-2',
    size: 7,
    labelKey: 'ag_tpl_mb2li',
    descKey: 'ag_tpl_mb2li_desc',
    slots: [
      SeatSlot('S', zone: 1),
      SeatSlot('S', zone: 4, label: 'ag_seat_s_front'),
      SeatSlot('OH', zone: 2),
      SeatSlot('OH', zone: 5),
      SeatSlot('MB', zone: 3),
      SeatSlot('MB', zone: 6),
      SeatSlot('Li', off: true),
    ],
  ),

  // 9인제 — 로테이션이 없다. 속공을 몇 명 두느냐로 리시브 줄이 갈린다.
  // rows 는 앞줄(네트 쪽)부터의 인원이고, slots 는 그 순서대로 나열한다.
  AnchigiTemplate(
    id: 'v9q1',
    sport: 'v9',
    size: 9,
    labelKey: 'ag_tpl_q1',
    descKey: 'ag_tpl_q1_desc',
    rows: [2, 4, 3],
    slots: [
      SeatSlot('QK', label: 'ag_seat_qk'),
      SeatSlot('S9', label: 'ag_seat_s9'),
      SeatSlot('L9', label: 'ag_seat_l9'),
      SeatSlot('CH', label: 'ag_seat_fch'),
      SeatSlot('CH', label: 'ag_seat_bch'),
      SeatSlot('R9', label: 'ag_seat_r9'),
      SeatSlot('BK', label: 'ag_seat_lb'),
      SeatSlot('BK', label: 'ag_seat_cb'),
      SeatSlot('BK', label: 'ag_seat_rb'),
    ],
  ),
  AnchigiTemplate(
    id: 'v9q2',
    sport: 'v9',
    size: 9,
    labelKey: 'ag_tpl_q2',
    descKey: 'ag_tpl_q2_desc',
    rows: [3, 4, 2],
    noteKey: 'ag_note_q2',
    slots: [
      SeatSlot('QK', label: 'ag_seat_fqk'),
      SeatSlot('S9', label: 'ag_seat_s9'),
      SeatSlot('QK', label: 'ag_seat_bqk'),
      SeatSlot('L9', label: 'ag_seat_l9'),
      SeatSlot('CH', label: 'ag_seat_fch'),
      SeatSlot('CH', label: 'ag_seat_bch'),
      SeatSlot('R9', label: 'ag_seat_r9'),
      SeatSlot('BK', label: 'ag_seat_lb'),
      SeatSlot('BK', label: 'ag_seat_cb2'),
    ],
  ),
  AnchigiTemplate(
    id: 'v9q3',
    sport: 'v9',
    size: 9,
    labelKey: 'ag_tpl_q3',
    descKey: 'ag_tpl_q3_desc',
    rows: [4, 3, 2],
    noteKey: 'ag_note_q3',
    slots: [
      SeatSlot('QK', label: 'ag_seat_qb'),
      SeatSlot('QK', label: 'ag_seat_qa'),
      SeatSlot('S9', label: 'ag_seat_s9'),
      SeatSlot('QK', label: 'ag_seat_b'),
      SeatSlot('L9', label: 'ag_seat_l9'),
      SeatSlot('CH', label: 'ag_seat_ch'),
      SeatSlot('R9', label: 'ag_seat_r9'),
      SeatSlot('BK', label: 'ag_seat_lb'),
      SeatSlot('BK', label: 'ag_seat_rb'),
    ],
  ),
];

AnchigiTemplate? templateById(String id) {
  for (final t in kTemplates) {
    if (t.id == id) return t;
  }
  return null;
}

/// 이 종목(6인제는 전술까지)에 맞는 구성.
List<AnchigiTemplate> templatesOfSport(String sport, [String tactic = '5-1']) =>
    kTemplates
        .where((t) => t.sport == sport && (sport != 'v6' || t.tactic == tactic))
        .toList();

/// 배치 우선순위별 가중치. flex는 팀당 허용되는 비주(non-main) 슬롯 기본값.
class PrioWeights {
  final int flex;
  final double fitW;
  final double varietyW;
  final double newBonus;
  final double playW;
  final double balanceW;

  const PrioWeights({
    required this.flex,
    required this.fitW,
    required this.varietyW,
    required this.newBonus,
    required this.playW,
    required this.balanceW,
  });
}

const List<String> kPrios = ['custom', 'variety'];

const Map<String, PrioWeights> kPrio = {
  // 맞춘 자리 우선 — 고정(📌)과 각자 고른 주 자리를 지키는 쪽.
  'custom': PrioWeights(
    flex: 1,
    fitW: 2.4,
    varietyW: 0.7,
    newBonus: 0.5,
    playW: 1.5,
    balanceW: 6.0,
  ),
  // 다양성 우선 — 안 해본 자리를 먼저. 고정은 여기서도 그대로 지킨다.
  'variety': PrioWeights(
    flex: 3,
    fitW: 0.7,
    varietyW: 2.6,
    newBonus: 4.0,
    playW: 1.0,
    balanceW: 2.0,
  ),
};

PrioWeights prioOf(String prio) => kPrio[prio] ?? kPrio['custom']!;

/// 예전 게임 성격 4단계 → (우선순위, 실험 자리). 저장본 마이그레이션용.
const Map<String, (String, int)> kFeelToPrio = {
  'comp': ('custom', 0),
  'real': ('custom', 1),
  'mix': ('variety', 2),
  'exp': ('variety', 5),
};

/// 예산 완화 상한. 9인제 팀 인원(9)까지 열릴 수 있다.
const int kMaxBudget = 9;

/// 고정(📌)한 사람을 그 자리에 앉히는 값. 대기로 밀리지 않을 만큼 커야 한다.
const double kPinSlotBonus = 9.0;

/// 직전 경기에 대기한 사람을 또 대기시키는 벌점(연속 대기 방지).
const double kBenchStreakPenalty = 9.0;

/// 사람이 없어 비워 둔 자리 하나당 비용. 채울 수 있으면 반드시 채우게 한다.
const double kEmptySlotCost = 40.0;

/// 일찍 가는 사람은 슬롯 비용을 깎아(우선 출전) 대기 비용은 올린다(대기 회피).
const double kEarlySlotBonus = 5.0;
const double kEarlyBenchPenalty = 10.0;

/// 세터 전용 선수가 평균+N 이상 뛰었으면 세터 슬롯 비용에 가중.
const int kSetterOveruseN = 1;

/// ABC 경기 순서: [팀1 코어, 팀2 코어, 차출 풀 코어].
const List<List<int>> kPairs = [
  [0, 1, 2],
  [1, 2, 0],
  [2, 0, 1],
];

const List<String> kTeamName = ['A', 'B', 'C'];

/// 코트 존 렌더링 순서(후위 1·6·5 / 전위 2·3·4).
const List<List<int>> kTopRows = [
  [1, 6, 5],
  [2, 3, 4],
];
