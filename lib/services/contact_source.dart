// contact_source.dart — contact_click 계측의 '어디서(via)·어떤 상태(flag)' 값과 팀 상태 표시.
//
// North Star(주당 연락한 사용자 수)를 기능별로 나눠 보려고 연락 클릭에 두 값을 붙인다
// (웹 docs/metrics.md 와 같은 이름·값):
//  · via  — 'detail'(상세의 연락 버튼) | 'this_week'(🍚 여기 자리 있어요? 줄)
//  · flag — 누른 순간 팀 상태: 'guest'(게스트 급구) | 'drop_in'(식구 모집+맛보기) |
//           'recruit'(식구 모집) | 'none'. 픽업은 'pickup'.
import '../models/club.dart';

const kViaDetail = 'detail';
const kViaThisWeek = 'this_week';

/// 누른 순간 팀 상태 — 급구가 먼저, 그다음 맛보기, 식구 모집.
String clubContactFlag(Club c, DateTime now) {
  if (c.urgentActiveAt(now)) return 'guest';
  if (c.dropInActive) return 'drop_in';
  if (c.recruitingActive) return 'recruit';
  return 'none';
}

/// 팀 연락 클릭 파라미터(기존 channel·club_id·source 에 via·flag 를 더한다).
Map<String, Object?> clubContactParams(
  Club c, {
  required String channel,
  required String via,
  DateTime? now,
}) => {
  'channel': channel,
  'club_id': c.id,
  'source': 'club',
  'via': via,
  'flag': clubContactFlag(c, now ?? DateTime.now()),
};

/// 크루 연락 클릭 파라미터(기존 channel·id·source 에 via·flag='pickup').
Map<String, Object?> spotContactParams(
  String spotId, {
  required String channel,
  required String via,
}) => {
  'channel': channel,
  'id': spotId,
  'source': 'pickup',
  'via': via,
  'flag': 'pickup',
};

/// 지도 라벨·릴스 미리보기 앞에 붙는 팀 상태 표시 — 🔥(급구) 🍚(식구 모집) 🥄(맛보기).
/// 둘 이상이면 🔥 가 먼저. 라벨이 길어지지 않게 낱말 없이 이모지만.
String clubMarks(Club c, {DateTime? now}) {
  final b = StringBuffer();
  if (c.urgentActiveAt(now ?? DateTime.now())) b.write('🔥');
  if (c.recruitingActive) b.write('🍚');
  if (c.dropInActive) b.write('🥄');
  return b.toString();
}
