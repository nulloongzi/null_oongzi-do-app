// rice_dex.dart — 밥 종류 25가지와 밥도감. 웹 js/profile.js riceData · window.riceDex 와 같은 표.
//
// 번호 = 이 목록 순서(1~25). 희귀도 = 뽑기 가중치(50 흔함 · 10 드묾 · 1 전설).
// 밥도감은 나 + 밥친구 전체의 밥 종류를 모은다. 상차림 단계:
// 혼밥 1 · 밥상 2–5 · 한상차림 6–12 · 잔칫상 13–24 · 수라상 25 (docs/design-system.md §7-4).
// 한쪽만 바꾸면 웹·앱의 도감 번호가 어긋난다.

typedef RiceEntry = ({String name, int weight, String color});

/// 밥이름 생성(profile_service)과 밥도감이 같이 쓰는 표. 순서를 바꾸지 말 것 — 도감 번호다.
const List<RiceEntry> kRiceData = [
  (name: '현미밥', weight: 50, color: '#FFF9C4'),
  (name: '백미밥', weight: 50, color: '#FFF59D'),
  (name: '흑미밥', weight: 50, color: '#FFF176'),
  (name: '보리밥', weight: 50, color: '#FFEE58'),
  (name: '콩밥', weight: 50, color: '#FFD54F'),
  (name: '오곡밥', weight: 50, color: '#FFCA28'),
  (name: '차조밥', weight: 10, color: '#FFE082'),
  (name: '기장밥', weight: 10, color: '#FFECB3'),
  (name: '숭늉', weight: 10, color: '#FFE0B2'),
  (name: '볶음밥', weight: 10, color: '#FFCC80'),
  (name: '비빔밥', weight: 10, color: '#FFB74D'),
  (name: '김밥', weight: 10, color: '#FFF8E1'),
  (name: '주먹밥', weight: 10, color: '#FFECB3'),
  (name: '유부초밥', weight: 10, color: '#FFE082'),
  (name: '덮밥', weight: 10, color: '#FFF59D'),
  (name: '국밥', weight: 10, color: '#FFCCBC'),
  (name: '솥밥', weight: 10, color: '#D7CCC8'),
  (name: '약밥', weight: 10, color: '#CFD8DC'),
  (name: '죽', weight: 10, color: '#F5F5F5'),
  (name: '곤드레밥', weight: 10, color: '#C5E1A5'),
  (name: '영양밥', weight: 10, color: '#E6EE9C'),
  (name: '치밥', weight: 10, color: '#FFAB91'),
  (name: '햇반', weight: 10, color: '#FFFFFF'),
  (name: '고봉밥', weight: 10, color: '#BCAAA4'),
  (name: '밥아저씨', weight: 1, color: '#81D4FA'),
];

enum RiceRarity { common, rare, legend }

RiceRarity _rarityOf(int w) => w >= 50
    ? RiceRarity.common
    : (w >= 10 ? RiceRarity.rare : RiceRarity.legend);

class DexItem {
  final int no; // 1~25
  final String name;
  final String color; // "#FFF9C4"
  final RiceRarity rarity;
  const DexItem(this.no, this.name, this.color, this.rarity);
}

class DexStage {
  final int lv; // 1 혼밥 · 2 밥상 · 3 한상차림 · 4 잔칫상 · 5 수라상 (0 = 하나도 없음)
  final int next; // 다음 단계 lv, 다 모았으면 0
  final int need; // 다음 단계까지 남은 종류 수
  const DexStage(this.lv, this.next, this.need);
}

const _stages = [
  (min: 1, lv: 1),
  (min: 2, lv: 2),
  (min: 6, lv: 3),
  (min: 13, lv: 4),
  (min: 25, lv: 5),
];

class RiceDex {
  final DexItem? mine; // 내 밥(도감 밖 닉네임이면 null)
  final Set<String> owned; // 모은 밥 이름
  const RiceDex(this.mine, this.owned);

  int get count => owned.length;
  static int get total => kRiceData.length;
  DexStage get stage => stageOf(count);

  static final List<DexItem> list = [
    for (var i = 0; i < kRiceData.length; i++)
      DexItem(
        i + 1,
        kRiceData[i].name,
        kRiceData[i].color,
        _rarityOf(kRiceData[i].weight),
      ),
  ];

  /// 밥 이름 → 도감 항목. 없으면 null(운영자 닉네임·옛 닉네임 등).
  static DexItem? info(String? name) {
    for (final it in list) {
      if (it.name == name) return it;
    }
    return null;
  }

  /// 닉네임("현미밥-a3k") → 밥 이름("현미밥")
  static String riceOf(String? nickname) => (nickname ?? '').split('-').first;

  static DexStage stageOf(int n) {
    var lv = 0;
    for (final s in _stages) {
      if (n >= s.min) {
        lv = s.lv;
      } else {
        return DexStage(lv, s.lv, s.min - n);
      }
    }
    return DexStage(lv, 0, 0);
  }

  /// 나 + 밥친구 전체. 같은 밥은 한 번, 도감에 없는 이름은 세지 않는다.
  static RiceDex build(String myRice, Iterable<String> friendRices) {
    final owned = <String>{};
    for (final r in [myRice, ...friendRices]) {
      final it = info(r);
      if (it != null) owned.add(it.name);
    }
    return RiceDex(info(myRice), owned);
  }
}
