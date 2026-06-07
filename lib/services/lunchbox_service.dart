// lunchbox_service.dart — 도시락(찜한 팀 5칸 + 커스텀 팀). 웹 lunchbox.js 포팅.
// 네이티브는 로그인 필수(AuthGate) → Firestore 비공개 서브컬렉션 users/{uid}/private/profile 사용.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'analytics.dart';
import 'i18n.dart';

class LunchboxData {
  final List<String?> bookmarks; // 길이 5
  final Map<String, dynamic> customTeams; // id -> {name, schedule, ...}
  LunchboxData(this.bookmarks, this.customTeams);
}

class LunchboxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _db.collection('users').doc(uid).collection('private').doc('profile');

  Future<LunchboxData> load(String uid) async {
    final snap = await _ref(uid).get();
    final d = snap.data() ?? <String, dynamic>{};
    final slots = List<String?>.filled(5, null);
    final bm = d['bookmarks'];
    if (bm is List) {
      for (var i = 0; i < 5 && i < bm.length; i++) {
        final v = bm[i];
        slots[i] = v is String ? v : null;
      }
    }
    final ct = d['customTeams'];
    final custom = ct is Map
        ? ct.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    return LunchboxData(slots, custom);
  }

  Future<void> save(String uid, LunchboxData data) async {
    await _ref(uid).set({
      'bookmarks': data.bookmarks,
      'customTeams': data.customTeams,
    }, SetOptions(merge: true));
  }

  /// 찜하기. null=성공, 그 외=사용자 메시지.
  Future<String?> addBookmark(String uid, String teamId) async {
    final data = await load(uid);
    if (data.bookmarks.contains(teamId)) return t('lb_already');
    final idx = data.bookmarks.indexWhere((e) => e == null);
    if (idx == -1) return t('lb_full');
    data.bookmarks[idx] = teamId;
    await save(uid, data);
    Track.event('add_bookmark');
    return null;
  }

  /// 커스텀 팀 추가 + 찜. null=성공, 그 외=메시지.
  Future<String?> addCustomTeam(
      String uid, String name, String schedule) async {
    final data = await load(uid);
    final idx = data.bookmarks.indexWhere((e) => e == null);
    if (idx == -1) return t('lb_full');
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    data.customTeams[id] = {'id': id, 'name': name, 'schedule': schedule};
    data.bookmarks[idx] = id;
    await save(uid, data);
    return null;
  }
}
