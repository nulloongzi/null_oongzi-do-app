// club_admin.dart — 팀 관리자 권한 · 위치 공개 수준의 순수 규칙.
//
// 이 파일의 값과 판정은 서버(firestore.rules · functions/lib/pure.js)와
// **반드시 같아야 한다.** 어긋나면 앱에는 버튼이 보이는데 저장은 거부되는,
// 사용자가 원인을 알 수 없는 상태가 된다. 그래서 웹·서버·앱 세 군데에
// 같은 규칙이 있고, 고칠 때는 세 군데를 같이 고쳐야 한다.
import 'dart:math' as math;

import '../models/club.dart';

/// 팀 하나당 관리자 정원. firestore.rules 의 admins.size() <= 3 과 같은 값.
const int kMaxClubAdmins = 3;

/// 이 계정이 팀 정보를 고칠 수 있는가.
/// [isOperator] 는 운영자(누룽지도 관리자) — 규칙의 isAdmin() 에 해당한다.
bool canManageClub(Club club, String? uid, {bool isOperator = false}) {
  if (isOperator) return true;
  if (uid == null || uid.isEmpty) return false;
  return club.admins.contains(uid);
}

/// 관리자 신청을 막아야 하는 이유. 막을 이유가 없으면 null.
/// 값: no_uid | already_admin | full
String? adminRequestBlockReason(Club club, String? uid) {
  if (uid == null || uid.isEmpty) return 'no_uid';
  if (club.admins.contains(uid)) return 'already_admin';
  if (club.admins.length >= kMaxClubAdmins) return 'full';
  return null;
}

/// 상세 시트에 팀 관리자 영역(신청·대기·빠지기)을 보일지.
/// 웹 club-detail.js #clubAdminArea 와 같은 조건 — 실명 로그인(익명 제외)이고
/// 운영자가 아닐 때. 인증 여부와는 무관하다(인증 안 된 팀도 관리자 신청을 받는다).
/// 익명 uid 는 신청해도 submit 이 로그인 안내로 돌려보내므로 처음부터 보이지 않는다.
bool showClubAdminArea({
  required String? uid,
  required bool isAnonymous,
  bool isOperator = false,
}) => uid != null && uid.isNotEmpty && !isAnonymous && !isOperator;

/// 관리자 신청이 승인됐는데 손에 든 팀 정보엔 내가 관리자로 없다 —
/// 목록을 읽은 뒤에 승인된 경우다. 이때만 팀 문서를 한 번 다시 읽는다.
/// (승인 뒤 스스로 빠진 사람도 여기 걸리지만, 다시 읽어도 없으니 신청 버튼이 뜬다.)
bool adminApprovalNeedsRefresh(Club club, String? uid, String? status) =>
    status == 'approved' &&
    uid != null &&
    uid.isNotEmpty &&
    !club.admins.contains(uid);

/// 서버가 club_admin_requests.reject_reason 에 쓰는 코드 — 서버가 스스로 닫을 때
/// (full · already_admin · not_found · duplicate) + 운영자가 거절하며 고른 것
/// (photo_unclear · photo_unrelated · duplicate · other). 이 밖의 값(옛 문서의
/// error 등)은 사람에게 보일 말이 없어 사유 줄을 생략한다. 옛 수동 거절은 사유가 없다.
const Set<String> kAdminRejectReasonCodes = {
  'full',
  'already_admin',
  'not_found',
  'duplicate',
  'photo_unclear',
  'photo_unrelated',
  'other',
};

/// 거절 사유 코드 → strings.dart 키. 모르는 코드·빈 값이면 null.
String? adminRejectReasonKey(String? code) {
  final c = code?.trim() ?? '';
  return kAdminRejectReasonCodes.contains(c) ? 'ad_reason_$c' : null;
}

/// leaveClubAdmin callable 의 반환값이 '실제로 빠졌다'를 뜻하는가.
/// 서버(functions/index.js)는 빠지면 {status:'left'}, 원래 관리자가 아니었으면
/// {status:'not_admin'} 을 돌려준다. 앞의 경우만 성공이다 — 아니면 '빠졌어요'
/// 라고 해 놓고 다시 열면 그대로 관리자인 상태가 된다.
bool leaveClubAdminSucceeded(Object? data) =>
    data is Map && data['status'] == 'left';

// ── 위치 공개 수준 ────────────────────────────────────────────────

/// 1/0.005° 격자. 위도로 약 550m.
const int kAreaGridDivisor = 200;

/// 좌표를 격자에 맞춰 뭉갠다. 유한수가 아니면 null.
///
/// **저장하기 전에** 뭉개야 한다. clubs 컬렉션은 누구나 읽을 수 있어서,
/// 화면에서만 흐리게 그리는 것은 아무것도 가리지 못한다.
double? roundToAreaGrid(num? v) {
  if (v == null) return null;
  final n = v.toDouble();
  if (n.isNaN || n.isInfinite) return null;
  return (n * kAreaGridDivisor).round() / kAreaGridDivisor;
}

final RegExp _sidoPrefix = RegExp(
  r'^(서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충북|충남|전북|전남|경북|경남|제주|충청|전라|경상)',
);
final RegExp _siGunGuTail = RegExp(r'[시군구]$');

/// 주소에서 행정구역만 남긴다 — '경기도 구리시 벌말로 168' → '경기도 구리시'.
/// 시/도 토큰을 찾지 못하면 빈 문자열(호출부가 판단하도록 둔다).
String areaLabel(String? address) {
  final raw = (address ?? '')
      .replaceAll(RegExp(r'[()\[\]]'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  if (raw.isEmpty) return '';
  final parts = raw.split(' ');
  var start = -1;
  for (var i = 0; i < parts.length; i++) {
    if (_sidoPrefix.hasMatch(parts[i])) {
      start = i;
      break;
    }
  }
  if (start == -1) return '';
  final out = <String>[parts[start]];
  for (var j = start + 1; j < parts.length && out.length < 3; j++) {
    if (!_siGunGuTail.hasMatch(parts[j])) break;
    out.add(parts[j]);
  }
  return out.join(' ');
}

/// 대략 위치만 공개하는 팀인가.
bool isAreaOnly(Club club) => club.locationPrecision == 'area';

/// 대략 위치 원의 반지름(m). 격자 한 칸이 덮는 범위와 맞춘다.
const double kAreaCircleRadius = 550;

/// 위도 1° 가 약 111km 이므로, 격자 한 칸의 대각선을 넘지 않는 값인지 확인용.
/// (테스트에서만 쓴다 — 상수가 격자와 따로 놀지 않도록 묶어 둔다.)
double areaGridSpanMeters() =>
    (1 / kAreaGridDivisor) * 111000 * math.sqrt(2) / 2;
