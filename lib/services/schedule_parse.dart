// schedule_parse.dart — 일정(raw/텍스트) → 요일별 시간 이벤트. 웹 parseScheduleText 포팅.
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
    if (day != null && scheduleDays.contains(day) && s != null && e != null && e > s) {
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
