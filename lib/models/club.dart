// club.dart — Firestore `clubs` 문서 모델 (웹앱과 동일 스키마)
import 'package:cloud_firestore/cloud_firestore.dart';

double? _toD(dynamic v) => v == null ? null : (v as num).toDouble();

DateTime? _ts(dynamic v) =>
    v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

// 최종 확인일: last_verified_at > metadata.updated_at > metadata.created_at.
// 폴백이 있어야 기존 문서들도 첫 배포부터 날짜가 뜬다(웹 data-trust.js 와 동일 순서).
DateTime? _verifiedAt(Map d) {
  final meta = d['metadata'];
  return _ts(d['last_verified_at']) ??
      (meta is Map ? _ts(meta['updated_at']) ?? _ts(meta['created_at']) : null);
}

// admins(배열)가 정본이다. registered_by 한 명으로 폴백하는 건 admins 필드가
// **없거나 배열이 아닐 때뿐**이다 — 빈 배열은 '관리자 없음'(마지막 관리자가 빠진 팀)이다.
// 빈 배열까지 폴백하면 스스로 빠진 등록자가 다시 관리자로 보인다.
// firestore.rules 의 clubAdmins() · functions/lib/pure.js 의 clubAdminUids() ·
// 웹 js/auth.js 의 window.clubAdminUids() 와 **같은 규칙이어야 한다.**
// 어긋나면 화면엔 수정 버튼이 보이는데 저장은 거부되는, 원인을 알 수 없는 상태가 된다.
List<String> _admins(Map d) {
  final raw = d['admins'];
  if (raw is! List) {
    final owner = d['registered_by'];
    final s = owner == null ? '' : '$owner'.trim();
    return s.isEmpty ? <String>[] : <String>[s];
  }
  final out = <String>[];
  for (final v in raw) {
    final s = (v == null ? '' : '$v').trim();
    if (s.isNotEmpty && !out.contains(s)) out.add(s);
  }
  return out;
}

// insta_reels(배열) 우선, 없으면 insta_reel(단일) 폴백 → 항상 List로.
List<String> _reels(Map d) {
  final raw = d['insta_reels'];
  if (raw is List) {
    final out = raw
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (out.isNotEmpty) return out;
  }
  final single = d['insta_reel'] as String?;
  if (single != null && single.trim().isNotEmpty) return [single];
  return const [];
}

// insta_reel_covers(맵) → code→URL. 문자열 값만 받는다(스키마 변형 방어).
Map<String, String> _reelCovers(Map d) {
  final raw = d['insta_reel_covers'];
  if (raw is! Map) return const {};
  final out = <String, String>{};
  raw.forEach((k, v) {
    if (k is String && v is String && v.trim().isNotEmpty) out[k] = v;
  });
  return out;
}

class Club {
  final String id;
  final String name;
  final String? registeredBy; // 최초 등록자(admins 필드가 없을 때의 폴백)
  final List<String> admins; // 팀 정보를 고칠 수 있는 계정들(최대 3)
  // 'exact' 가 기본이다. 필드가 없는 기존 문서는 지금까지처럼 정확히 보인다 —
  // 조용히 뭉개면 팀이 모르는 사이에 지도에서 옮겨진 것처럼 보인다.
  final String locationPrecision; // exact | area
  final String? target;
  final String? address;
  final String? price;
  final String? schedule;
  final List? scheduleRaw; // [{day,start,end}] 편집 prefill용
  final double? lat;
  final double? lng;
  final String? insta;
  final String? link;
  final String? instaReel;
  final List<String> instaReels; // 멀티 릴스(없으면 [instaReel])
  // 릴스 shortcode → 우리 Storage 의 정지 커버 URL(Cloud Function insta-cover.js 가 채움)
  final Map<String, String> instaReelCovers;
  // 운영자가 릴스를 숨김(reels_hidden) — 챗봇 '신고관리'의 🙈 릴스 숨김.
  // 켜져 있으면 fromDoc 이 릴스·커버를 비워서 상세·지도·계측 어디에도 나오지 않는다.
  // 수정 폼은 이 값으로 릴스 칸을 잠근다(firestore.rules 가 관리자·소유자의 변경을 막는다).
  final bool reelsHidden;
  final bool isVerified;
  final bool isUrgent;
  final String? urgentMsg;
  // 급구가 내려가는 시각 = 고른 운동이 끝나는 시각(서버 postUrgent 가 쓴다).
  // 없으면 예전 급구 — 서버 정리(sweep)가 지금+7일을 채워 넣을 때까지 마감 없이 보인다.
  final DateTime? urgentUntil;
  final DateTime? urgentAt; // 급구를 올린 시각(서버 시각)
  // 회원 모집 중 — 급구와 따로, 인증 여부와 상관없이 팀 관리자가 켠다.
  final bool isRecruiting;
  final String? recruitMsg; // 비어 있을 수 있다
  final DateTime? recruitAt; // 켜거나 문구를 바꾼 시각(서버 시각)

  /// 급구를 실제로 보여 줄지 — 켜져 있고, 문구가 비어 있지 않고, 마감이 안 지났을 때만.
  /// 지도 마커·티커·상세 배너·릴스 미리보기가 모두 이 하나만 본다(웹과 같은 판정).
  /// 문구 없이 켜진 급구는 '무엇이 급한지' 알 수 없어 보이지 않는다.
  /// 마감이 지난 급구는 서버 정리(매시)가 내리기 전이라도 바로 숨긴다.
  bool get urgentActive => urgentActiveAt(DateTime.now());

  /// [now] 기준 급구 판정 — 테스트·정렬에서 시각을 고정하려고 따로 둔다.
  bool urgentActiveAt(DateTime now) =>
      isUrgent &&
      (urgentMsg?.trim().isNotEmpty ?? false) &&
      (urgentUntil == null || urgentUntil!.isAfter(now));

  /// 회원 모집 중 표시 여부 — is_recruiting 이 bool true 일 때만(웹과 같은 판정).
  bool get recruitingActive => isRecruiting;
  // 데이터 신뢰도(웹 guidelines.html 2-3). last_verified_at 이 없는 레거시 문서는
  // metadata.updated_at → created_at 으로 폴백하므로 마이그레이션 없이 값이 나온다.
  final DateTime? lastVerifiedAt;
  final String? dataStatus; // active | needs_check | dormant

  Club({
    required this.id,
    required this.name,
    this.registeredBy,
    this.admins = const [],
    this.locationPrecision = 'exact',
    this.target,
    this.address,
    this.price,
    this.schedule,
    this.scheduleRaw,
    this.lat,
    this.lng,
    this.insta,
    this.link,
    this.instaReel,
    this.instaReels = const [],
    this.instaReelCovers = const {},
    this.reelsHidden = false,
    this.isVerified = false,
    this.isUrgent = false,
    this.urgentMsg,
    this.urgentUntil,
    this.urgentAt,
    this.isRecruiting = false,
    this.recruitMsg,
    this.recruitAt,
    this.lastVerifiedAt,
    this.dataStatus,
  });

  factory Club.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    final hidden = d['reels_hidden'] == true;
    final coord = d['coordinates'] as Map<String, dynamic>?;
    final contact = d['contact'] as Map<String, dynamic>?;
    return Club(
      id: doc.id,
      name: (d['name'] ?? '') as String,
      registeredBy: d['registered_by'] as String?,
      admins: _admins(d),
      locationPrecision: d['location_precision'] == 'area' ? 'area' : 'exact',
      target: d['target'] as String?,
      address: d['address'] as String?,
      price: d['price'] as String?,
      schedule: d['schedule'] as String?,
      scheduleRaw: d['schedule_raw'] as List?,
      lat: _toD(coord?['lat']),
      lng: _toD(coord?['lng']),
      insta: (d['insta'] ?? contact?['insta']) as String?,
      link: (d['link'] ?? contact?['link']) as String?,
      instaReel: hidden ? null : d['insta_reel'] as String?,
      instaReels: hidden ? const [] : _reels(d),
      instaReelCovers: hidden ? const {} : _reelCovers(d),
      reelsHidden: hidden,
      isVerified: (d['is_verified'] ?? false) as bool,
      // 규칙이 bool 만 받게 됐지만, 그 전에 들어간 문서가 문자열·숫자일 수 있다.
      // `as bool` 이면 그 한 문서 때문에 목록 전체 파싱이 죽는다.
      isUrgent: d['is_urgent'] == true,
      urgentMsg: d['urgent_msg'] is String ? d['urgent_msg'] as String : null,
      urgentUntil: _ts(d['urgent_until']),
      urgentAt: _ts(d['urgent_at']),
      isRecruiting: d['is_recruiting'] == true,
      recruitMsg: d['recruit_msg'] is String
          ? d['recruit_msg'] as String
          : null,
      recruitAt: _ts(d['recruit_at']),
      lastVerifiedAt: _verifiedAt(d),
      dataStatus: d['data_status'] as String?,
    );
  }
}
