// schedule_parse.dart — 일정(raw/텍스트) → 요일별 시간 이벤트. 웹 parseScheduleText 포팅.
import 'i18n.dart';

class SchedEvent {
  final String day; // 월~일
  final double start; // 시(소수) 예: 19.5
  final double end;
  const SchedEvent(this.day, this.start, this.end);
}

const scheduleDays = ['월', '화', '수', '목', '금', '토', '일'];

/// 같은 요일 이벤트(시작시각 오름차순)를 겹침 레인으로 배정한다.
/// 시간표에서 겹치는 일정이 서로를 덮지 않게, 칸을 레인 수만큼 쪼개려고 쓴다.
///
/// 예전 방식은 겹칠 때마다 5~6px 들여쓰고 그대로 겹쳐 그리는 것이었다.
/// 나중 블록이 앞 블록을 덮어 좁은 띠만 남고, 겹침이 3을 넘으면 들여쓰기를
/// 0으로 되돌려 앞의 것들을 완전히 가렸다 — 정보가 사라지는 동작이었다.
///
/// 겹치는 것끼리 한 클러스터로 묶고 그 안에서만 레인을 나눈다. 이미 끝난
/// 레인은 재활용하므로(A 10~12 · C 13~15는 같은 레인) 폭이 헛되게 줄지 않는다.
/// 반환값의 lanes 는 그 이벤트가 속한 클러스터의 총 레인 수.
List<({int lane, int lanes})> assignLanes(List<SchedEvent> sorted) {
  final n = sorted.length;
  final lane = List<int>.filled(n, 0);
  final count = List<int>.filled(n, 1);
  var i = 0;
  while (i < n) {
    // 클러스터 끝: 앞선 것들의 최대 end 보다 늦게 시작하면 새 클러스터.
    var end = sorted[i].end;
    var j = i + 1;
    while (j < n && sorted[j].start < end) {
      if (sorted[j].end > end) end = sorted[j].end;
      j++;
    }
    final laneEnd = <double>[]; // 레인별 마지막 종료 시각
    for (var k = i; k < j; k++) {
      var placed = -1;
      for (var l = 0; l < laneEnd.length; l++) {
        if (sorted[k].start >= laneEnd[l]) {
          placed = l;
          break;
        }
      }
      if (placed < 0) {
        laneEnd.add(sorted[k].end);
        placed = laneEnd.length - 1;
      } else {
        laneEnd[placed] = sorted[k].end;
      }
      lane[k] = placed;
    }
    for (var k = i; k < j; k++) {
      count[k] = laneEnd.length;
    }
    i = j;
  }
  return [for (var k = 0; k < n; k++) (lane: lane[k], lanes: count[k])];
}

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
///
/// 예전엔 쉼표·슬래시로 자른 뒤 조각마다 시간 1개를 잡았다. 그런데 요일을
/// 쉼표로 나열한 표기(`월, 수, 금 19:00~22:00`)가 세 조각으로 찢어져 **금요일만**
/// 시간을 갖고 나머지는 사라졌다. 구분자를 늘리거나 줄이는 걸로는 두 표기를
/// 동시에 만족시킬 수 없다.
///
/// 그래서 시간을 기준으로 요일을 귀속시킨다(웹 parseScheduleText 와 같은 규칙):
///  · 한 덩어리에 시간이 2개 이상이면, 각 시간 **바로 앞** 구간이 그 시간의 요일.
///  · 시간이 하나뿐이면 덩어리 전체에서 요일을 찾는다 — 요일이 시간 뒤에 오는
///    `19:00~22:00 월수금` 같은 예전 표기를 살리기 위해서다.
List<SchedEvent> eventsFromText(String? text) {
  final out = <SchedEvent>[];
  if (text == null || text.trim().isEmpty) return out;
  final timeReg = RegExp(r'(\d{1,2}):(\d{2})\s*[~-]\s*(\d{1,2}):(\d{2})');

  void emit(String daySource, RegExpMatch m) {
    final s = int.parse(m.group(1)!) + int.parse(m.group(2)!) / 60.0;
    final e = int.parse(m.group(3)!) + int.parse(m.group(4)!) / 60.0;
    if (e <= s) return;
    for (final d in scheduleDays) {
      if (daySource.contains(d)) out.add(SchedEvent(d, s, e));
    }
  }

  for (final seg in text.split('/')) {
    final ms = timeReg.allMatches(seg).toList();
    if (ms.isEmpty) continue;
    if (ms.length == 1) {
      emit(seg, ms.first);
      continue;
    }
    var prevEnd = 0;
    for (final m in ms) {
      emit(seg.substring(prevEnd, m.start), m);
      prevEnd = m.end;
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
