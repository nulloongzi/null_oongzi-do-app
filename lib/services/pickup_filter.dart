// pickup_filter.dart — 픽업 목록 필터 순수 로직 (지역·English OK·키워드).
// 웹 js/pickup-filter.js 의 포팅 — 두 플랫폼이 같은 결과를 내야 공유 링크가 성립한다.
import '../models/pickup_spot.dart';
import 'region_match.dart';

/// 지역 매칭. `region` 칩 값이 있으면 그걸 쓰고, 없으면 주소 접두어로 폴백한다.
///
/// 왜 필드를 따로 두는가: 좌표를 선택으로 풀면 주소가 자유 텍스트로 남아 표기가 흔들리고
/// ("서울시 마포구" / "Mapo, Seoul"), 특히 외국인이 직접 등록하면 영문 주소를 써서
/// 접두어 매칭이 깨진다. 폴백은 region 칩 도입 이전 문서 호환용.
bool pickupRegionMatch(PickupSpot s, String region) {
  if (region.isEmpty) return true;

  final stored = s.region ?? '';
  if (stored.isNotEmpty) {
    if (stored == region) return true;
    return (regionGroups[region] ?? const []).contains(stored);
  }

  final addr = s.address ?? '';
  if (addr.isEmpty) return false; // 지역 미상 → 지역 필터가 걸리면 제외
  return regionMatchesAddress(addr, region);
}

const pickupLevelOptions = ['beginner', 'intermediate', 'advanced'];

/// 레벨 매칭. 외국인에게 크루를 소개할 때 "나 초보인데 가도 되나"가 핵심 질문이라
/// 지역 다음으로 중요한 필터다.
///
/// 가치필터 #1(랭킹·별점 금지)과 충돌하지 않는다 — 크루의 우열이 아니라 "나랑 맞나"
/// (적합·소속) 정보다. PHILOSOPHY 후기 원칙이 허용하는 성격 태그 쪽.
///
/// 'any'(레벨무관) 크루는 어떤 레벨 필터에도 걸린다 — 누구나 환영이라는 뜻이므로
/// 초보가 '입문'으로 걸러도 후보에서 빠지면 안 된다.
bool pickupLevelMatch(PickupSpot s, String level) {
  if (level.isEmpty) return true;
  final l = s.level ?? 'any';
  return l == 'any' || l == level;
}

/// 목록 필터. 지도 마커와 리스트가 같은 결과를 보게 하려고 한 곳에 모은다.
List<PickupSpot> filterPickupSpots(
  List<PickupSpot> spots, {
  String region = '',
  String level = '',
  bool englishOnly = false,
  String keyword = '',
}) {
  final kw = keyword.trim().toLowerCase();
  return spots.where((s) {
    if (englishOnly && !s.englishOk) return false;
    if (!pickupRegionMatch(s, region)) return false;
    if (!pickupLevelMatch(s, level)) return false;
    if (kw.isEmpty) return true;
    final hay =
        '${s.title} ${s.venueName ?? ''} ${s.address ?? ''} ${s.insta ?? ''}'
            .toLowerCase();
    return hay.contains(kw);
  }).toList();
}
