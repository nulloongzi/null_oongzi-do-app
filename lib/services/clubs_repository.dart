import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/club.dart';

/// clubs 컬렉션 로드 + findClub 조회. 웹 data.js와 동일한 단일 소스.
class ClubsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Map<String, Club> _clubs = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<Club> get all => _clubs.values.toList();

  /// clubs 컬렉션 1회 로드.
  Future<void> loadAll() async {
    final snapshot = await _db.collection('clubs').get();
    _clubs.clear();
    for (final doc in snapshot.docs) {
      final club = Club.fromFirestore(doc.id, doc.data());
      _clubs[club.id] = club;
    }
    _loaded = true;
  }

  /// 웹 findClub과 동일 우선순위: clubs → (호출측의) customTeams.
  /// customTeams는 LunchboxRepository가 보유하므로 fallback 맵을 받는다.
  Club? findClub(String? id, {Map<String, Club>? customTeams}) {
    if (id == null || id.isEmpty) return null;
    final strId = id.trim();
    final club = _clubs[strId];
    if (club != null) return club;
    if (customTeams != null && customTeams.containsKey(id)) {
      return customTeams[id];
    }
    return null;
  }
}
