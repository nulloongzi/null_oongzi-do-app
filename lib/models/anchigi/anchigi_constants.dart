// anchigi_constants.dart — 안치기 상수/템플릿/가중치 테이블.
// 원본 anchigi.html(Vanilla JS)의 POS/FIT/TEMPLATES/FEEL을 그대로 옮김.
// 값이 바뀌면 배치 결과가 달라지므로 원본과 1:1로 유지할 것.

/// 포지션 코드. 순서 의미 있음(slotCost의 `POS.length - nOpt` 계산에 쓰임).
const List<String> kPos = ['S', 'OP', 'OH', 'MB', 'Li'];

/// 티어: 주(main) / 가능(sub) / 도전(want).
const List<String> kTiers = ['main', 'sub', 'want'];

/// 적합도 점수. 키가 없으면 0(=불가/도전).
const Map<String, int> kFit = {'main': 2, 'sub': 1, 'want': 0};

/// 팀 구성 템플릿. 대각 규칙(S↔OP, OH↔OH, MB↔Li or MB)을 만족하도록 구성됨.
class AnchigiTemplate {
  final String id;
  final int size;
  final String labelKey;
  final String descKey;
  final List<String> slots;

  const AnchigiTemplate({
    required this.id,
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
];

AnchigiTemplate? templateById(String id) {
  for (final t in kTemplates) {
    if (t.id == id) return t;
  }
  return null;
}

/// 게임 성격별 가중치. budget은 팀당 허용되는 비주(non-main) 슬롯 수(하드 제약).
class FeelWeights {
  final int budget;
  final double fitW;
  final double varietyW;
  final double newBonus;
  final double playW;
  final double balanceW;

  const FeelWeights({
    required this.budget,
    required this.fitW,
    required this.varietyW,
    required this.newBonus,
    required this.playW,
    required this.balanceW,
  });
}

const List<String> kFeels = ['comp', 'real', 'mix', 'exp'];

const Map<String, FeelWeights> kFeel = {
  'comp': FeelWeights(
    budget: 0,
    fitW: 3.0,
    varietyW: 0.8,
    newBonus: 0.0,
    playW: 1.5,
    balanceW: 8.0,
  ),
  'real': FeelWeights(
    budget: 1,
    fitW: 2.0,
    varietyW: 1.2,
    newBonus: 1.5,
    playW: 1.5,
    balanceW: 5.0,
  ),
  'mix': FeelWeights(
    budget: 2,
    fitW: 0.8,
    varietyW: 2.5,
    newBonus: 4.0,
    playW: 1.0,
    balanceW: 2.5,
  ),
  // exp의 budget 99는 budStart()에서 7로 클램프됨(사실상 무제한).
  'exp': FeelWeights(
    budget: 99,
    fitW: 0.0,
    varietyW: 4.0,
    newBonus: 6.0,
    playW: 0.6,
    balanceW: 1.0,
  ),
};

FeelWeights feelOf(String feel) => kFeel[feel] ?? kFeel['real']!;

/// 예산 완화 상한. budStart()는 feel 예산을 7로 클램프해서 시작한다.
const int kMaxBudget = 7;

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
