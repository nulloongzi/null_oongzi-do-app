// pickup_spot.dart — Firestore `pickup_games` 문서 모델 (웹앱과 동일 스키마)
import 'package:cloud_firestore/cloud_firestore.dart';

double? _toD(dynamic v) => v == null ? null : (v as num).toDouble();

class PickupSpot {
  final String id;
  final String title;
  final String? sport;
  final String? level;
  final bool beginnerFriendly;
  final bool englishOk;
  final String? venueName;
  final String? address;
  final double? lat;
  final double? lng;
  final String? schedule;
  final String? scheduleText;
  final String? feeInfo;
  final String? contactLink;
  final String? thisWeek;
  final String? notes;
  final String? instaReel;

  PickupSpot({
    required this.id,
    required this.title,
    this.sport,
    this.level,
    this.beginnerFriendly = false,
    this.englishOk = false,
    this.venueName,
    this.address,
    this.lat,
    this.lng,
    this.schedule,
    this.scheduleText,
    this.feeInfo,
    this.contactLink,
    this.thisWeek,
    this.notes,
    this.instaReel,
  });

  factory PickupSpot.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    final coord = d['coordinates'] as Map<String, dynamic>?;
    return PickupSpot(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      sport: d['sport'] as String?,
      level: d['level'] as String?,
      beginnerFriendly: (d['beginner_friendly'] ?? false) as bool,
      englishOk: (d['english_ok'] ?? false) as bool,
      venueName: d['venue_name'] as String?,
      address: d['address'] as String?,
      lat: _toD(coord?['lat']),
      lng: _toD(coord?['lng']),
      schedule: d['schedule'] as String?,
      scheduleText: d['schedule_text'] as String?,
      feeInfo: d['fee_info'] as String?,
      contactLink: d['contact_link'] as String?,
      thisWeek: d['this_week'] as String?,
      notes: d['notes'] as String?,
      instaReel: d['insta_reel'] as String?,
    );
  }
}
