// urgent.dart — 급구·회원 모집 순수 로직(문구 검사·운동 회차·마감 표기·오류 코드).
//
// 문구 검사 정규식은 서버(functions/lib/pure.js)·웹과 **글자 하나까지 같아야** 한다.
// 앱이 통과시킨 문구를 서버가 거절하면, 사용자는 왜 안 되는지 모른 채 다시 누른다.
// 길이는 코드 포인트(웹 [...s].length, 여기 s.runes.length)로 잰다 — 이모지 하나가
// UTF-16 두 칸이라 .length 로 재면 서버와 어긋난다.
import '../models/club.dart';
import 'i18n.dart';
import 'schedule_parse.dart';

/// 새로 올리는 급구·모집 문구의 최대 길이(코드 포인트).
const kUrgentMsgMax = 60;

/// 운동이 이보다 덜 남았으면 고를 수 없다(서버 'past' 와 같은 여유).
const kUrgentMinLead = Duration(minutes: 5);

/// 회차를 보여 줄 범위 — 7일 안의 운동만.
const kUrgentHorizon = Duration(days: 7);

/// 서버가 받아 주는 마감의 끝(지금+8일). '다른 날'로 7일째 늦은 시각을 골라도 통과한다.
const kUrgentServerMax = Duration(days: 8);

final RegExp _linkRe = RegExp(
  r'(https?:\/\/|www\.|open\.kakao|[a-z0-9-]+\.(com|net|org|kr|co|io|me|ly|gl|link|app|page)\b)',
  caseSensitive: false,
);
final RegExp _phoneRe = RegExp(
  r'(01[016789]|0\d{1,2})[-.\s]?\d{3,4}[-.\s]?\d{4}',
);

/// 급구 문구 검사. 문제가 없으면 null, 있으면 서버와 같은 사유 코드
/// ('msg_empty' · 'msg_too_long' · 'msg_link' · 'msg_phone').
/// 연락은 팀 연락처로 받는다 — 링크·전화번호는 문구에 넣지 못한다.
String? urgentMsgProblem(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return 'msg_empty';
  if (s.runes.length > kUrgentMsgMax) return 'msg_too_long';
  if (_linkRe.hasMatch(s)) return 'msg_link';
  if (_phoneRe.hasMatch(s)) return 'msg_phone';
  return null;
}

/// 회원 모집 문구 검사 — 급구와 같은 규칙이지만 비어 있어도 된다.
String? recruitMsgProblem(String raw) {
  final p = urgentMsgProblem(raw);
  return p == 'msg_empty' ? null : p;
}

/// 마감 시각 검사(서버와 같은 경계). 문제 없으면 null, 아니면 'past' · 'too_far'.
String? urgentUntilProblem(DateTime until, DateTime now) {
  if (!until.isAfter(now.add(kUrgentMinLead))) return 'past';
  if (until.isAfter(now.add(kUrgentServerMax))) return 'too_far';
  return null;
}

/// 운동 한 회차(기기 시각).
class UrgentSession {
  final DateTime start;
  final DateTime end;
  const UrgentSession(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      other is UrgentSession && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'UrgentSession($start → $end)';
}

DateTime _at(DateTime day, double hours) {
  final minutes = (hours * 60).round();
  return DateTime(day.year, day.month, day.day, 0, minutes);
}

/// 팀 일정 → 급구로 고를 수 있는 다음 회차들(가까운 순, 최대 [max]개 — null 이면 모두).
/// 끝나는 시각이 지금+5분보다 뒤이고 지금+7일 안인 것만 — 진행 중인 운동도
/// 끝나기 5분 전까지는 고를 수 있다. 같은 회차가 두 번 적혀 있으면 하나만.
List<UrgentSession> nextSessions(
  List<SchedEvent> events,
  DateTime now, {
  int? max = 3,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final minEnd = now.add(kUrgentMinLead);
  final maxEnd = now.add(kUrgentHorizon);
  final out = <UrgentSession>{};
  for (final e in events) {
    final wd = scheduleDays.indexOf(e.day) + 1; // 월=1 … 일=7 (DateTime.weekday)
    if (wd <= 0) continue;
    // 어제부터 8일째까지 — 7일 뒤 같은 요일의 이른 회차까지 범위에 걸칠 수 있고,
    // 어제 시작해 오늘 새벽에 끝나는(자정을 넘는) 회차도 아직 진행 중일 수 있다.
    for (var d = -1; d <= 7; d++) {
      final day = DateTime(today.year, today.month, today.day + d);
      if (day.weekday != wd) continue;
      final s = UrgentSession(_at(day, e.start), _at(day, e.end));
      if (s.end.isAfter(minEnd) && !s.end.isAfter(maxEnd)) out.add(s);
    }
  }
  final list = out.toList()
    ..sort((a, b) {
      final c = a.start.compareTo(b.start);
      return c != 0 ? c : a.end.compareTo(b.end);
    });
  return (max != null && list.length > max) ? list.sublist(0, max) : list;
}

const _wdKo = ['월', '화', '수', '목', '금', '토', '일'];
const _wdEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// 요일 짧은 이름(월 / Mon).
String weekdayShort(DateTime d, {bool? ko}) =>
    ((ko ?? isKo) ? _wdKo : _wdEn)[d.weekday - 1];

String _two(int n) => n.toString().padLeft(2, '0');

/// 24시간제 HH:mm.
String hhmm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// 날짜+시각 짧은 표기 "목 10/9 21:00" (EN "Thu 10/9 21:00").
String dayTimeLabel(DateTime d, {bool? ko}) =>
    '${weekdayShort(d, ko: ko)} ${d.month}/${d.day} ${hhmm(d)}';

/// 회차 칩 표기 "수 10/8 19:00~21:00" (EN "Wed 10/8 19:00–21:00").
String sessionChipLabel(UrgentSession s, {bool? ko}) {
  final k = ko ?? isKo;
  final sep = k ? '~' : '–';
  final start = s.start.toLocal();
  return '${weekdayShort(start, ko: k)} ${start.month}/${start.day} '
      '${hhmm(start)}$sep${hhmm(s.end.toLocal())}';
}

/// 급구 마감 표기 — 오늘 / 내일 / D-n · 요일 시각. 날짜 차이는 기기 날짜로 센다.
String urgentDeadlineLabel(DateTime until, DateTime now) {
  final u = until.toLocal();
  final n = now.toLocal();
  // 자정 기준 날짜 차이 — DateTime.utc 로 세야 일광절약 시각이 끼어도 하루가 24시간이다.
  final days = DateTime.utc(
    u.year,
    u.month,
    u.day,
  ).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
  final time = hhmm(u);
  if (days <= 0) return tf('ug_until_today', {'time': time});
  if (days == 1) return tf('ug_until_tomorrow', {'time': time});
  return tf('ug_until_day', {
    'n': '$days',
    'day': weekdayShort(u),
    'time': time,
  });
}

/// 급구 티커 순서 — 마감이 가까운 팀부터, 마감이 없는 예전 급구는 맨 뒤.
/// 같은 마감끼리는 원래 순서를 지킨다(List.sort 는 안정 정렬이 아니라 인덱스로 가른다).
List<Club> sortByUrgentDeadline(Iterable<Club> clubs) {
  final indexed = clubs.toList().asMap().entries.toList()
    ..sort((a, b) {
      final ua = a.value.urgentUntil;
      final ub = b.value.urgentUntil;
      if (ua != null && ub != null) {
        final c = ua.compareTo(ub);
        if (c != 0) return c;
      } else if (ua != null) {
        return -1;
      } else if (ub != null) {
        return 1;
      }
      return a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}

/// 화면에 문구 키가 있는 사유들(서버 postUrgent 의 details.reason · 앱 검사 코드).
const _knownReasons = {
  'unverified',
  'past',
  'too_far',
  'msg_empty',
  'msg_too_long',
  'msg_link',
  'msg_phone',
  'not_manager',
  'blocked',
};

/// 사유 코드 → 문구 키. 모르는 코드·사유 없음은 'ug_err_generic'.
/// 'login' 은 급구 전용 문구 대신 앱 공통 로그인 안내(login_required)를 쓴다.
String urgentErrorKey(String? reason) {
  if (reason == 'login') return 'login_required';
  if (reason != null && _knownReasons.contains(reason)) return 'ug_err_$reason';
  return 'ug_err_generic';
}

/// callable 오류의 details 에서 사유 코드를 꺼낸다({reason: '...'} 가 아니면 null).
String? urgentReasonFromDetails(Object? details) {
  if (details is Map) {
    final r = details['reason'];
    if (r is String && r.isNotEmpty) return r;
  }
  return null;
}
