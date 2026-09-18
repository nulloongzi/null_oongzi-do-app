// anchigi_constants.dart — 안치기 상수/템플릿/가중치 테이블.
// 원본 anchigi.html(Vanilla JS)의 POS/FIT/TEMPLATES/FEEL을 그대로 옮김.
// 값이 바뀌면 배치 결과가 달라지므로 원본과 1:1로 유지할 것.

/// 종목. v6=6인제(로테이션·대각), v9=9인제(자리 고정 3×3).
const List<String> kSports = ['v6', 'v9'];

/// 종목별 자리 코드. 순서 의미 있음(slotCost의 `자리 수 - nOpt` 계산에 쓰임).
const Map<String, List<String>> kPosBySport = {
  'v6': ['S', 'OP', 'OH', 'MB', 'Li'],
  'v9': ['FL', 'FC', 'FR', 'CL', 'CC', 'CR', 'BL', 'BC', 'BR'],
};

/// 6인제 자리. 기존 호출부 호환용 별칭.
const List<String> kPos = ['S', 'OP', 'OH', 'MB', 'Li'];

/// 두 종목 자리를 합친 목록. 기록(stat)은 이 키로 한 벌만 쌓는다.
const List<String> kAllPos = [
  'S', 'OP', 'OH', 'MB', 'Li',
  'FL', 'FC', 'FR', 'CL', 'CC', 'CR', 'BL', 'BC', 'BR',
];

List<String> posOfSport(String sport) => kPosBySport[sport] ?? kPosBySport['v6']!;

/// 티어: 주(main) / 가능(sub) / 도전(want).
const List<String> kTiers = ['main', 'sub', 'want'];

/// 적합도 점수. 키가 없으면 0(=불가/도전).
const Map<String, int> kFit = {'main': 2, 'sub': 1, 'want': 0};

/// 팀 구성 템플릿. 대각 규칙(S↔OP, OH↔OH, MB↔Li or MB)을 만족하도록 구성됨.
class AnchigiTemplate {
  final String id;

  /// 이 구성이 속한 종목('v6'|'v9').
  final String sport;

  final int size;
  final String labelKey;
  final String descKey;
  final List<String> slots;

  const AnchigiTemplate({
    required this.id,
    this.sport = 'v6',
    required this.size,
    required this.labelKey,
    required this.descKey,
    required this.slots,
  });
}

const List<AnchigiTemplate> kTemplates = [
  AnchigiTemplate(
    id: 'mb2',
    size: 6,
    labelKey: 'ag_tpl_mb2',
    descKey: 'ag_tpl_mb2_desc',
    slots: ['S', 'OP', 'OH', 'OH', 'MB', 'MB'],
  ),
  AnchigiTemplate(
    id: 'mb1li',
    size: 6,
    labelKey: 'ag_tpl_mb1li',
    descKey: 'ag_tpl_mb1li_desc',
    slots: ['S', 'OP', 'OH', 'OH', 'MB', 'Li'],
  ),
  AnchigiTemplate(
    id: 'mb2li',
    size: 7,
    labelKey: 'ag_tpl_mb2li',
    descKey: 'ag_tpl_mb2li_desc',
    slots: ['S', 'OP', 'OH', 'OH', 'MB', 'MB', 'Li'],
  ),
  // 9인제는 로테이션이 없어 코트 아홉 자리를 그대로 채운다(구성은 하나뿐).
  AnchigiTemplate(
    id: 'v9',
    sport: 'v9',
    size: 9,
    labelKey: 'ag_tpl_v9',
    descKey: 'ag_tpl_v9_desc',
    slots: ['FL', 'FC', 'FR', 'CL', 'CC', 'CR', 'BL', 'BC', 'BR'],
  ),
];

List<AnchigiTemplate> templatesOfSport(String sport) =>
    kTemplates.where((t) => t.sport == sport).toList();

AnchigiTemplate? templateById(String id) {
  for (final t in kTemplates) {
    if (t.id == id) return t;
  }
  return null;
}

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

/// 9인제 코트 — 네트에서 먼 줄부터. 위쪽 팀은 좌우가 뒤집힌다(마주 보는 코트).
const List<List<String>> kV9TopRows = [
  ['BR', 'BC', 'BL'],
  ['CR', 'CC', 'CL'],
  ['FR', 'FC', 'FL'],
];
const List<List<String>> kV9BotRows = [
  ['FL', 'FC', 'FR'],
  ['CL', 'CC', 'CR'],
  ['BL', 'BC', 'BR'],
];
