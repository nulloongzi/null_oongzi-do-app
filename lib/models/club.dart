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

// admins(배열)를 정본으로 읽되, 비어 있으면 registered_by 한 명으로 폴백한다.
// firestore.rules 의 clubAdmins() · functions/lib/pure.js 의 clubAdminUids() ·
// 웹 js/auth.js 의 window.clubAdminUids() 와 **같은 규칙이어야 한다.**
// 어긋나면 화면엔 수정 버튼이 보이는데 저장은 거부되는, 원인을 알 수 없는 상태가 된다.
List<String> _admins(Map d) {
  final out = <String>[];
  final raw = d['admins'];
  if (raw is List) {
    for (final v in raw) {
      final s = (v == null ? '' : '$v').trim();
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
    }
  }
  if (out.isEmpty) {
    final owner = (d['registered_by'] as String?)?.trim() ?? '';
    if (owner.isNotEmpty) out.add(owner);
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

class Club {
  final String id;
  final String name;
  final String? registeredBy; // 최초 등록자(admins 가 비었을 때의 폴백)
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
  final bool isVerified;
  final bool isUrgent;
  final String? urgentMsg;
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
    this.isVerified = false,
    this.isUrgent = false,
    this.urgentMsg,
    this.lastVerifiedAt,
    this.dataStatus,
  });

  factory Club.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
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
      instaReel: d['insta_reel'] as String?,
      instaReels: _reels(d),
      isVerified: (d['is_verified'] ?? false) as bool,
      isUrgent: (d['is_urgent'] ?? false) as bool,
      urgentMsg: d['urgent_msg'] as String?,
      lastVerifiedAt: _verifiedAt(d),
      dataStatus: d['data_status'] as String?,
    );
  }
}
