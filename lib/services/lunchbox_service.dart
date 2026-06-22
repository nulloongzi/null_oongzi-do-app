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

  // 트랜잭션 기반 read-modify-write(동시 쓰기 클로버 방지).
  // apply: bookmarks(길이5)·customTeams를 제자리 변형. null 반환=성공(커밋), 그 외=메시지(쓰기 없음).
  Future<String?> _mutate(
      String uid,
      String? Function(List<String?> bookmarks, Map<String, dynamic> custom)
          apply) async {
    try {
      return await _db.runTransaction<String?>((txn) async {
        final ref = _ref(uid);
        final snap = await txn.get(ref);
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
            ? Map<String, dynamic>.from(
                ct.map((k, v) => MapEntry(k.toString(), v)))
            : <String, dynamic>{};
        final err = apply(slots, custom);
        if (err != null) return err; // 검증 실패 → 쓰기 없이 메시지
        txn.set(ref, {'bookmarks': slots, 'customTeams': custom},
            SetOptions(merge: true));
        return null;
      });
    } catch (_) {
      return t('lb_save_err');
    }
  }

  /// 찜하기. null=성공, 그 외=사용자 메시지.
  Future<String?> addBookmark(String uid, String teamId) async {
    final err = await _mutate(uid, (bm, custom) {
      if (bm.contains(teamId)) return t('lb_already');
      final idx = bm.indexWhere((e) => e == null);
      if (idx == -1) return t('lb_full');
      bm[idx] = teamId;
      return null;
    });
    if (err == null) Track.event('add_bookmark');
    return err;
  }

  /// 찜 해제(도시락에서 빼기). null=성공.
  Future<String?> removeBookmark(String uid, String teamId) async {
    var removed = false;
    final err = await _mutate(uid, (bm, custom) {
      final idx = bm.indexWhere((e) => e == teamId);
      if (idx == -1) {
        removed = false; // 재시도 시 직전 시도 값 잔존 방지
        return null; // 이미 없음
      }
      bm[idx] = null;
      removed = true;
      return null;
    });
    if (err == null && removed) Track.event('remove_bookmark');
    return err;
  }

  /// 커스텀 팀 추가 + 찜. null=성공, 그 외=메시지.
  Future<String?> addCustomTeam(
      String uid, String name, String schedule) async {
    return _mutate(uid, (bm, custom) {
      final idx = bm.indexWhere((e) => e == null);
      if (idx == -1) return t('lb_full');
      final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
      custom[id] = {'id': id, 'name': name, 'schedule': schedule};
      bm[idx] = id;
      return null;
    });
  }
}
