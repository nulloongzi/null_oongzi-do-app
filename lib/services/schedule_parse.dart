// schedule_parse.dart — 일정(raw/텍스트) → 요일별 시간 이벤트. 웹 parseScheduleText 포팅.
import 'i18n.dart';

class SchedEvent {
  final String day; // 월~일
  final double start; // 시(소수) 예: 19.5
  final double end;
  const SchedEvent(this.day, this.start, this.end);
}

const scheduleDays = ['월', '화', '수', '목', '금', '토', '일'];

double? _hm(String? s) {
  if (s == null) return null;
  final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
  if (m == null) return null;
  return int.parse(m.group(1)!) + int.parse(m.group(2)!) / 60.0;
}

/// schedule_raw: [{day,start,end}] (네이티브 클럽/픽업) — 가장 정확.
List<SchedEvent> eventsFromRaw(List? raw) {
  final out = <SchedEvent>[];
  if (raw == null) return out;
  for (final r in raw) {
    if (r is! Map) continue;
    final day = r['day'] as String?;
    final s = _hm(r['start'] as String?);
    final e = _hm(r['end'] as String?);
    if (day != null &&
        scheduleDays.contains(day) &&
        s != null &&
        e != null &&
        e > s) {
      out.add(SchedEvent(day, s, e));
    }
  }
  return out;
}

/// 텍스트 "월 19:00~22:00, 수 ..." / "토 14:00~17:00 / ..." → 이벤트.
/// 세그먼트(,또는/)별로 시간 1개 + 그 안에 포함된 요일들.
List<SchedEvent> eventsFromText(String? text) {
  final out = <SchedEvent>[];
  if (text == null || text.trim().isEmpty) return out;
  final timeReg = RegExp(r'(\d{1,2}):(\d{2})\s*[~-]\s*(\d{1,2}):(\d{2})');
  for (final seg in text.split(RegExp(r'[,/]'))) {
    final m = timeReg.firstMatch(seg);
    if (m == null) continue;
    final s = int.parse(m.group(1)!) + int.parse(m.group(2)!) / 60.0;
    final e = int.parse(m.group(3)!) + int.parse(m.group(4)!) / 60.0;
    if (e <= s) continue;
    for (final d in scheduleDays) {
      if (seg.contains(d)) out.add(SchedEvent(d, s, e));
    }
  }
  return out;
}

String getHourLabel(int h) {
  final p = h >= 12 ? 'PM' : 'AM';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  return '$p $h12';
}

// ── 요약 표기 (웹 club-detail 요약: "토요일 PM 1:00 ~ PM 5:00") ──
const _fullDay = {
  '월': {'ko': '월요일', 'en': 'Monday'},
  '화': {'ko': '화요일', 'en': 'Tuesday'},
  '수': {'ko': '수요일', 'en': 'Wednesday'},
  '목': {'ko': '목요일', 'en': 'Thursday'},
  '금': {'ko': '금요일', 'en': 'Friday'},
  '토': {'ko': '토요일', 'en': 'Saturday'},
  '일': {'ko': '일요일', 'en': 'Sunday'},
};

/// 요일 풀네임 (토 → 토요일 / Saturday).
String fullDayName(String day) => _fullDay[day]?[isKo ? 'ko' : 'en'] ?? day;

/// 시(소수) → 12시간제 "PM 1:00" (19.5 → "PM 7:30").
String time12(double h) {
  final hh = h.floor();
  final mm = ((h - hh) * 60).round();
  final p = hh >= 12 ? 'PM' : 'AM';
  var h12 = hh % 12;
  if (h12 == 0) h12 = 12;
  return '$p $h12:${mm.toString().padLeft(2, '0')}';
}

/// 길이 라벨 (4.0 → "4h", 3.5 → "3.5h").
String durLabel(double hours) {
  final whole = hours == hours.roundToDouble();
  final s = whole ? hours.toInt().toString() : hours.toString();
  return '${s}h';
}

/// 이벤트 → 요약 문자열 "토요일 PM 1:00 ~ PM 5:00 · 월요일 PM 7:00 ~ PM 10:00".
String scheduleSummary(List<SchedEvent> events) {
  if (events.isEmpty) return '';
  return events
      .map((e) => '${fullDayName(e.day)} ${time12(e.start)} ~ ${time12(e.end)}')
      .join(' · ');
}
