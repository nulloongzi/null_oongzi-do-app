// club.dart — Firestore `clubs` 문서 모델 (웹앱과 동일 스키마)
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/sanitize.dart';

double? _toD(dynamic v) => v == null ? null : (v as num).toDouble();

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

// insta_reel_covers: {shortcode: coverUrl} — Cloud Function이 oEmbed로 캐싱.
Map<String, String> _covers(Map d) {
  final raw = d['insta_reel_covers'];
  if (raw is Map) {
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (k is String && v is String && v.isNotEmpty) out[k] = v;
    });
    return out;
  }
  return const {};
}

class Club {
  final String id;
  final String name;
  final String? registeredBy; // 소유자(수정/삭제 권한)
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
  final Map<String, String> instaReelCovers; // shortcode→커버URL(발견 카드용)
  final bool isVerified;
  final bool isUrgent;
  final String? urgentMsg;

  // 릴스 URL의 정지 커버(있으면). shortcode로 조회. 없으면 null → 클라이언트는 제네릭 카드.
  String? coverFor(String url) {
    final code = Sanitize.reelCode(url);
    return code == null ? null : instaReelCovers[code];
  }

  Club({
    required this.id,
    required this.name,
    this.registeredBy,
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
    this.isVerified = false,
    this.isUrgent = false,
    this.urgentMsg,
  });

  factory Club.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    final coord = d['coordinates'] as Map<String, dynamic>?;
    final contact = d['contact'] as Map<String, dynamic>?;
    return Club(
      id: doc.id,
      name: (d['name'] ?? '') as String,
      registeredBy: d['registered_by'] as String?,
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
      instaReelCovers: _covers(d),
      isVerified: (d['is_verified'] ?? false) as bool,
      isUrgent: (d['is_urgent'] ?? false) as bool,
      urgentMsg: d['urgent_msg'] as String?,
    );
  }
}
