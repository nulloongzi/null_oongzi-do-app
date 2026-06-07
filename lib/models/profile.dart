// profile.dart — 공개 프로필(users 문서). 룰 화이트리스트: nickname/suffix/full_nickname/color/created_at.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Profile {
  final String fullNickname; // "백미밥-a3z"
  final String nickname; // 밥 종류(배경색 결정) "백미밥"
  final String color; // "#FFF9C4"
  final DateTime? createdAt;

  Profile({
    required this.fullNickname,
    required this.nickname,
    required this.color,
    this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> d) {
    DateTime? created;
    final c = d['created_at'];
    if (c is Timestamp) created = c.toDate();
    final full = (d['full_nickname'] ?? d['nickname'] ?? '') as String;
    return Profile(
      fullNickname: full,
      nickname: (d['nickname'] ?? full.split('-').first) as String,
      color: (d['color'] ?? '#FFF9C4') as String,
      createdAt: created,
    );
  }

  /// "#FFF9C4" → Color
  Color get bgColor {
    final s = color.replaceFirst('#', '');
    final v = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16);
    return v == null ? const Color(0xFFFFF9C4) : Color(v);
  }
}
