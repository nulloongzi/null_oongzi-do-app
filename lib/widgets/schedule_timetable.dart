// schedule_timetable.dart — 상세시트용 단일 팀 주간 시간표. 웹 club-detail renderTimetables 대응.
// 요일×시간 그리드에 운동 시간 블록 + 오늘 요일 강조. schedule_parse 재사용.
import 'package:flutter/material.dart';
import '../services/i18n.dart';
import '../services/schedule_parse.dart';
import '../theme.dart';

class ScheduleTimetable extends StatelessWidget {
  final List<SchedEvent> events;
  final Color accent;
  const ScheduleTimetable({
    super.key,
    required this.events,
    this.accent = NurungjiColors.yellow,
  });

  static String _fmt(double h) {
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    var minH = 24.0, maxH = 0.0;
    for (final e in events) {
      if (e.start < minH) minH = e.start;
      if (e.end > maxH) maxH = e.end;
    }
    final displayStart = (minH.floor() - 1).clamp(6, 22).toInt();
    final displayEnd = (maxH.ceil() + 1).clamp(displayStart + 1, 24).toInt();
    final totalHours = displayEnd - displayStart;
    final rowH = (260.0 / totalHours).clamp(30.0, 54.0).toDouble();
    final contentH = totalHours * rowH;
    final todayIdx = DateTime.now().weekday - 1; // 월=0 .. 일=6

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(todayIdx),
          const SizedBox(height: 2),
          SizedBox(
            height: contentH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _timeCol(displayStart, displayEnd, rowH),
                for (var i = 0; i < scheduleDays.length; i++)
                  Expanded(
                      child: _dayCol(scheduleDays[i], i == todayIdx,
                          displayStart, totalHours, rowH)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow(int todayIdx) {
    return Row(children: [
      const SizedBox(width: 32),
      for (var i = 0; i < scheduleDays.length; i++)
        Expanded(
          child: Center(
            child: Text(
              i18nDay(scheduleDays[i]),
              style: TextStyle(
                fontSize: 12,
                fontWeight: i == todayIdx ? FontWeight.w900 : FontWeight.w600,
                color: i == todayIdx ? accent : NurungjiColors.dark,
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _timeCol(int start, int end, double rowH) {
    return SizedBox(
      width: 32,
      child: Column(
        children: [
          for (int h = start; h < end; h++)
            SizedBox(
              height: rowH,
              child: Text(getHourLabel(h),
                  style: const TextStyle(
                      fontSize: 9, color: NurungjiColors.brown)),
            ),
        ],
      ),
    );
  }

  Widget _dayCol(
      String day, bool isToday, int displayStart, int totalHours, double rowH) {
    final dayEvents = events.where((e) => e.day == day).toList();
    return Container(
      decoration: BoxDecoration(
        color: isToday ? accent.withValues(alpha: 0.08) : null,
        border: const Border(left: BorderSide(color: Color(0x11000000))),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              for (int i = 0; i < totalHours; i++)
                Container(
                  height: rowH,
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x0D000000))),
                  ),
                ),
            ],
          ),
          for (final e in dayEvents)
            Positioned(
              top: (e.start - displayStart) * rowH,
              left: 1,
              right: 1,
              height: ((e.end - e.start) * rowH - 2).clamp(16.0, 9999.0).toDouble(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _fmt(e.start),
                  style: const TextStyle(
                      fontSize: 8,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: NurungjiColors.dark),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
