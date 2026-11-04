// map_scene.dart — 지도에 그릴 "장면" 계산(순수). 무엇을 어느 층에 그릴지만 정하고,
// 실제로 지도에 올리고 지우는 건 widgets/map_marker_layers.dart 가 한다.
//
// 층이 둘인 이유(웹 map-core.js 와 같은 나눔):
//  · 발견 층 — 일반 팀·픽업. "집 근처에 뭐가 있나" 훑어보는 핀이라 멀면 묶음 숫자로 합친다.
//    핀의 주인은 지도 라이브러리의 묶음 기능이다(풀 때마다 핀을 새로 만든다).
//  · 신호 층 — 급구 팀. "지금 사람 찾는 곳"이라 묶음에 넣지 않고 항상 보인다.
import '../models/club.dart';
import '../models/pickup_spot.dart';
import 'club_admin.dart' show isAreaOnly;
import 'club_filter.dart';
import 'contact_source.dart' show clubMarks;

/// 핀 하나. [id] 는 'c_<팀 id>' · 's_<픽업 id>' — 팀 id 는 데이터베이스 문서 id 그대로다.
class MarkerSpec {
  final String id;
  final String refId; // 팀·픽업 문서 id (탭했을 때 찾는다)
  final bool isClub;
  final double lat, lng;
  final String name;
  final bool red; // 빨강 핀(급구 팀 · 픽업)
  final bool urgent;
  // 이름표 앞 상태 표시 — 🔥(급구) 🍚(식구 모집) 🥄(맛보기). 픽업·일반 팀은 ''.
  final String marks;
  final bool verified;
  final bool areaOnly; // 대략 위치만 공개 → 핀 아래 범위 원도 그린다

  const MarkerSpec({
    required this.id,
    required this.refId,
    required this.isClub,
    required this.lat,
    required this.lng,
    required this.name,
    required this.red,
    required this.urgent,
    this.marks = '',
    required this.verified,
    this.areaOnly = false,
  });

  /// 그림을 정하는 값 전부. 같으면 같은 핀이다(다시 만들 필요 없음).
  String get look => '$lat|$lng|$name|$red|$urgent|$marks|$verified|$areaOnly';
}

class MapScene {
  final List<MarkerSpec> discovery; // 묶음에 들어가는 핀
  final List<MarkerSpec> signal; // 급구 — 항상 보이는 핀
  const MapScene(this.discovery, this.signal);

  static const empty = MapScene([], []);

  /// 발견 층이 바뀌었는지 비교하는 열쇠. 같으면 발견 층은 다시 그리지 않는다.
  String get discoveryKey =>
      discovery.map((s) => '${s.id}|${s.look}').join('\n');
}

/// 동호회 탭 장면: 필터(검색어 포함)에 맞고 좌표가 있는 팀. 급구 팀은 신호 층.
MapScene clubScene(Iterable<Club> clubs, ClubFilter filter, {DateTime? now}) {
  final discovery = <MarkerSpec>[];
  final signal = <MarkerSpec>[];
  for (final c in clubs) {
    if (c.lat == null || c.lng == null || !filter.matches(c)) continue;
    final urgent = now == null ? c.urgentActive : c.urgentActiveAt(now);
    final spec = MarkerSpec(
      id: 'c_${c.id}',
      refId: c.id,
      isClub: true,
      lat: c.lat!,
      lng: c.lng!,
      name: c.name,
      red: urgent,
      urgent: urgent,
      marks: clubMarks(c, now: now),
      verified: c.isVerified,
      areaOnly: isAreaOnly(c),
    );
    (urgent ? signal : discovery).add(spec);
  }
  return MapScene(discovery, signal);
}

/// 픽업 탭 장면: 이미 걸러진 픽업 중 좌표가 있는 것. 모두 발견 층(빨강 핀).
MapScene spotScene(Iterable<PickupSpot> spots) {
  final discovery = <MarkerSpec>[];
  for (final s in spots) {
    if (s.lat == null || s.lng == null) continue;
    discovery.add(
      MarkerSpec(
        id: 's_${s.id}',
        refId: s.id,
        isClub: false,
        lat: s.lat!,
        lng: s.lng!,
        name: s.title,
        red: true,
        urgent: false,
        verified: false,
      ),
    );
  }
  return MapScene(discovery, const []);
}
