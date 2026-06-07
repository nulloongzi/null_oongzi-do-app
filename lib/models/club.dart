// club.dart — Firestore `clubs` 문서 모델 (웹앱과 동일 스키마)
import 'package:cloud_firestore/cloud_firestore.dart';

double? _toD(dynamic v) => v == null ? null : (v as num).toDouble();

class Club {
  final String id;
  final String name;
  final String? target;
  final String? address;
  final String? price;
  final String? schedule;
  final double? lat;
  final double? lng;
  final String? insta;
  final String? link;
  final String? instaReel;
  final bool isVerified;
  final bool isUrgent;
  final String? urgentMsg;

  Club({
    required this.id,
    required this.name,
    this.target,
    this.address,
    this.price,
    this.schedule,
    this.lat,
    this.lng,
    this.insta,
    this.link,
    this.instaReel,
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
      target: d['target'] as String?,
      address: d['address'] as String?,
      price: d['price'] as String?,
      schedule: d['schedule'] as String?,
      lat: _toD(coord?['lat']),
      lng: _toD(coord?['lng']),
      insta: (d['insta'] ?? contact?['insta']) as String?,
      link: (d['link'] ?? contact?['link']) as String?,
      instaReel: d['insta_reel'] as String?,
      isVerified: (d['is_verified'] ?? false) as bool,
      isUrgent: (d['is_urgent'] ?? false) as bool,
      urgentMsg: d['urgent_msg'] as String?,
    );
  }
}
