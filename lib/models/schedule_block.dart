// schedule_block.dart — 등록폼의 요일·시간 블록. registration.js getScheduleData/group 포팅.
class ScheduleBlock {
  List<String> days; // ['월','수']
  String start; // '19:00'
  String end; // '22:00'

  ScheduleBlock({List<String>? days, this.start = '19:00', this.end = '22:00'})
      : days = days ?? [];

  /// 30분 간격 시간 옵션 06:00 ~ 23:30
  static List<String> timeOptions() {
    final out = <String>[];
    for (var h = 6; h < 24; h++) {
      for (final m in ['00', '30']) {
        out.add('${h.toString().padLeft(2, '0')}:$m');
      }
    }
    return out;
  }

  static const dayOrder = ['월', '화', '수', '목', '금', '토', '일'];

  /// 블록들 → Firestore schedule_raw: [{day,start,end}]
  static List<Map<String, String>> toRaw(List<ScheduleBlock> blocks) {
    final raw = <Map<String, String>>[];
    for (final b in blocks) {
      for (final d in b.days) {
        raw.add({'day': d, 'start': b.start, 'end': b.end});
      }
    }
    return raw;
  }

  /// 블록들 → 표시용 텍스트 "월 19:00~22:00, 수 ..." (요일 순 정렬)
  static String toText(List<ScheduleBlock> blocks) {
    final raw = toRaw(blocks)
      ..sort((a, b) =>
          dayOrder.indexOf(a['day']!).compareTo(dayOrder.indexOf(b['day']!)));
    return raw.map((r) => '${r['day']} ${r['start']}~${r['end']}').join(', ');
  }

  /// schedule_raw → 블록 묶음 (같은 start|end는 한 블록에 여러 요일). 편집 prefill용.
  static List<ScheduleBlock> groupFromRaw(List? raw) {
    if (raw == null) return [];
    final groups = <String, ScheduleBlock>{};
    for (final row in raw) {
      if (row is! Map) continue;
      final day = row['day'] as String?;
      final start = row['start'] as String?;
      final end = row['end'] as String?;
      if (day == null || start == null || end == null) continue;
      final key = '$start|$end';
      final g = groups.putIfAbsent(key, () => ScheduleBlock(start: start, end: end));
      if (!g.days.contains(day)) g.days.add(day);
    }
    return groups.values.toList();
  }
}
