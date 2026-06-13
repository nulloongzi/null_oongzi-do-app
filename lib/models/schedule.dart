/// 웹 club-detail.js의 parseScheduleText / getHourLabel 포팅.

/// 요일별 일정 한 건.
class DaySchedule {
  final int startH;
  final int startM;
  final int endH;
  final int endM;
  final String text; // "PM 7:00~PM 9:00" 형식

  const DaySchedule({
    required this.startH,
    required this.startM,
    required this.endH,
    required this.endM,
    required this.text,
  });

  double get startHour => startH + startM / 60.0;
  double get endHour => endH + endM / 60.0;
}

/// 한국 요일 순서 (웹과 동일: 월~일).
const List<String> kWeekDays = ['월', '화', '수', '목', '금', '토', '일'];

String _format12(int h, int m) {
  final p = h >= 12 ? 'PM' : 'AM';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  final mStr = m < 10 ? '0$m' : '$m';
  return '$p $h12:$mStr';
}

/// "월 19:00~21:00 / 화 20:00~22:00" → { '월': DaySchedule, '화': ... }
Map<String, DaySchedule> parseScheduleText(String? text) {
  final Map<String, DaySchedule> map = {};
  if (text == null || text.isEmpty) return map;

  final segments = text.split(RegExp(r'\s*/\s*'));
  final timeReg = RegExp(r'(\d{1,2}):(\d{2})\s*[~-]\s*(\d{1,2}):(\d{2})');

  for (final segment in segments) {
    final match = timeReg.firstMatch(segment);
    if (match == null) continue;

    final startH = int.parse(match.group(1)!);
    final startM = int.parse(match.group(2)!);
    final endH = int.parse(match.group(3)!);
    final endM = int.parse(match.group(4)!);
    final displayTime =
        '${_format12(startH, startM)}~${_format12(endH, endM)}';

    for (final day in kWeekDays) {
      if (segment.contains(day)) {
        map[day] = DaySchedule(
          startH: startH,
          startM: startM,
          endH: endH,
          endM: endM,
          text: displayTime,
        );
      }
    }
  }
  return map;
}

/// 0~23 → "AM 12", "PM 1" 등.
String getHourLabel(int h) {
  final p = h >= 12 ? 'PM' : 'AM';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  return '$p $h12';
}
