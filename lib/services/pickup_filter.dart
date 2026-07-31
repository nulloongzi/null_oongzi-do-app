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

/// 목록 필터. 지도 마커와 리스트가 같은 결과를 보게 하려고 한 곳에 모은다.
List<PickupSpot> filterPickupSpots(
  List<PickupSpot> spots, {
  String region = '',
  bool englishOnly = false,
  String keyword = '',
}) {
  final kw = keyword.trim().toLowerCase();
  return spots.where((s) {
    if (englishOnly && !s.englishOk) return false;
    if (!pickupRegionMatch(s, region)) return false;
    if (kw.isEmpty) return true;
    final hay =
        '${s.title} ${s.venueName ?? ''} ${s.address ?? ''} ${s.insta ?? ''}'
            .toLowerCase();
    return hay.contains(kw);
  }).toList();
}
