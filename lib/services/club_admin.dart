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
