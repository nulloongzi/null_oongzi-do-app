// region_match.dart — 지역 매칭 공통 규칙 (동호회 필터·픽업 필터 공유).
// 충청/전라/경상은 여러 시도를 묶은 광역 칩이라 하위 시도 접두어를 모두 편다.
// 웹 js/pickup-filter.js 의 REGION_GROUPS 와 같은 표를 유지해야 두 플랫폼 결과가 일치한다.

const regionOptionsAll = ['서울', '경기', '인천', '강원', '충청', '전라', '경상', '제주'];

/// 광역 칩 → 실제 주소 접두어들. 여기 없는 칩은 칩 이름 자체가 접두어다.
const regionGroups = <String, List<String>>{
  '충청': ['충남', '충북', '대전', '세종'],
  '전라': ['전남', '전북', '광주'],
  '경상': ['경남', '경북', '대구', '부산', '울산'],
};

/// `region` 칩에 해당하는 주소 접두어 목록.
List<String> regionPrefixes(String region) => regionGroups[region] ?? [region];

/// 주소가 해당 지역 칩에 속하는가 (접두어 매칭).
bool regionMatchesAddress(String address, String region) {
  for (final p in regionPrefixes(region)) {
    if (address.startsWith(p)) return true;
  }
  return false;
}
