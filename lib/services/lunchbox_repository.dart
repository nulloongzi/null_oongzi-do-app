import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/club.dart';

/// 북마크 슬롯 + 커스텀 팀의 영속화.
/// 로그인: Firestore users/{uid}/private/profile (웹 userPrivateRef와 동일 경로).
/// 비로그인: shared_preferences (웹 localStorage와 같은 키명, 단 저장소는 분리됨).
class LunchboxData {
  final List<String?> bookmarks; // 길이 5 정규화
  final Map<String, Club> customTeams;

  const LunchboxData({required this.bookmarks, required this.customTeams});
}

const _lsBookmarksKey = 'nulloong_bookmarks';
const _lsCustomTeamsKey = 'nulloong_custom_teams';

/// 항상 길이 5로 정규화 (부족분 null, 초과분 절단) — 웹과 동일.
List<String?> normalizeSlots(List<String?>? slots) {
  final out = List<String?>.from(slots ?? const []);
  while (out.length < 5) {
    out.add(null);
  }
  if (out.length > 5) return out.sublist(0, 5);
  return out;
}

class LunchboxRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _privateRef(String uid) =>
      _db.collection('users').doc(uid).collection('private').doc('profile');

  /// 현재 사용자(uid) 또는 게스트(null)의 도시락 데이터 로드.
  Future<LunchboxData> load(String? uid) async {
    if (uid != null) {
      final snap = await _privateRef(uid).get();
      final data = snap.data() ?? const {};
      return LunchboxData(
        bookmarks: normalizeSlots(_parseBookmarks(data['bookmarks'])),
        customTeams: _parseCustomTeams(data['customTeams']),
      );
    }
    // 게스트: shared_preferences
    final prefs = await SharedPreferences.getInstance();
    return LunchboxData(
      bookmarks: normalizeSlots(_parseBookmarks(
          _decode(prefs.getString(_lsBookmarksKey)))),
      customTeams:
          _parseCustomTeams(_decode(prefs.getString(_lsCustomTeamsKey))),
    );
  }

  /// 도시락 데이터 저장 (Optimistic UI 후 비동기 호출 권장).
  Future<void> save(
    String? uid, {
    required List<String?> bookmarks,
    required Map<String, Club> customTeams,
  }) async {
    final slots = normalizeSlots(bookmarks);
    final teamsMap = <String, dynamic>{
      for (final e in customTeams.entries) e.key: e.value.toMap(),
    };

    if (uid != null) {
      await _privateRef(uid).set(
        {'bookmarks': slots, 'customTeams': teamsMap},
        SetOptions(merge: true),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lsBookmarksKey, jsonEncode(slots));
    await prefs.setString(_lsCustomTeamsKey, jsonEncode(teamsMap));
  }

  // ── helpers ──

  dynamic _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  List<String?>? _parseBookmarks(dynamic raw) {
    if (raw is! List) return null;
    return raw.map((e) => e == null ? null : e.toString()).toList();
  }

  Map<String, Club> _parseCustomTeams(dynamic raw) {
    if (raw is! Map) return {};
    final out = <String, Club>{};
    raw.forEach((key, value) {
      if (value is Map) {
        out[key.toString()] =
            Club.fromMap(Map<String, dynamic>.from(value));
      }
    });
    return out;
  }
}
