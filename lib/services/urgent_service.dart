// urgent_service.dart — 급구 올리기(서버 postUrgent)·내리기, 회원 모집 켜기·끄기.
//
// 급구를 켜는 건 서버 callable 만 할 수 있다(규칙이 클라이언트의 켜기를 막는다) —
// 인증 팀·관리자·마감·문구 검사를 서버가 한 번 더 하고 기록(urgent_log)을 남긴다.
// 끄기와 회원 모집은 팀 관리자가 직접 쓴다. 팀 정보 확인(last_verified_at)으로
// 치지 않으므로 DataRepository.updateClub 대신 문서를 바로 고친다(웹과 같음).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'i18n.dart';
import 'urgent.dart';

class UrgentService {
  UrgentService({FirebaseFirestore? db, FirebaseFunctions? functions})
    : _dbOverride = db,
      _fnOverride = functions;

  final FirebaseFirestore? _dbOverride;
  final FirebaseFunctions? _fnOverride;
  // 테스트에서 Firebase 를 띄우지 않아도 되게, 실제 인스턴스는 쓸 때 꺼낸다.
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _fn => _fnOverride ?? FirebaseFunctions.instance;

  /// 급구 올리기(수정도 같은 길). 반환: null=성공, 그 외=사용자에게 보일 문구.
  Future<String?> post(String clubId, DateTime until, String msg) async {
    try {
      await _fn.httpsCallable('postUrgent').call({
        'clubId': clubId,
        'until': until.millisecondsSinceEpoch,
        'msg': msg.trim(),
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('postUrgent: ${e.code} ${e.details}');
      return t(urgentErrorKey(urgentReasonFromDetails(e.details)));
    } catch (e) {
      debugPrint('postUrgent: $e');
      return t('ug_err_generic');
    }
  }

  /// 급구 내리기 — 마감·올린 시각도 함께 지운다(규칙이 끌 때만 허용).
  Future<void> turnOff(String clubId) =>
      _db.collection('clubs').doc(clubId).update(urgentOffFields());

  /// 회원 모집 켜기·끄기. 켤 때마다 recruit_at 을 서버 시각으로 새로 찍는다
  /// (규칙이 켜거나 문구를 바꿀 때 recruit_at == request.time 을 요구한다).
  Future<void> setRecruiting(
    String clubId, {
    required bool on,
    String msg = '',
  }) => _db
      .collection('clubs')
      .doc(clubId)
      .update(on ? recruitOnFields(msg) : recruitOffFields());
}

/// 급구 끄기 필드(웹·계약과 같은 집합).
Map<String, dynamic> urgentOffFields() => {
  'is_urgent': false,
  'urgent_msg': '',
  'urgent_until': FieldValue.delete(),
  'urgent_at': FieldValue.delete(),
};

/// 회원 모집 켜기 필드.
Map<String, dynamic> recruitOnFields(String msg) => {
  'is_recruiting': true,
  'recruit_msg': msg.trim(),
  'recruit_at': FieldValue.serverTimestamp(),
};

/// 회원 모집 끄기 필드 — 문구는 남겨 두고(다시 켤 때 채워 보이기 쉽게) 깃발만 내린다.
Map<String, dynamic> recruitOffFields() => {'is_recruiting': false};
