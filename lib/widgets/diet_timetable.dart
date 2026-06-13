import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule.dart';
import '../state/lunchbox_controller.dart';
import '../theme/app_theme.dart';

/// 주간 식단표. 웹 lunchbox.js renderCombinedSchedule 포팅.
class DietTimetable extends StatelessWidget {
  const DietTimetable({super.key});

  static const double _timeColWidth = 40;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LunchboxController>();

    // 1) 북마크된 팀들의 일정 → 이벤트 수집
    final events = <_Event>[];
    var minH = 24, maxH = 0;
    var hasData = false;

    for (var idx = 0; idx < c.slots.length; idx++) {
      final teamId = c.slots[idx];
      if (teamId == null) continue;
      final team = c.findClub(teamId);
      if (team == null) continue;
      final scheduleMap = parseScheduleText(team.schedule);
      scheduleMap.forEach((day, d) {
        minH = math.min(minH, d.startH);
        maxH = math.max(maxH, d.endH);
        hasData = true;
        events.add(_Event(
          teamName: team.name,
          day: day,
          start: d.startHour,
          end: d.endHour,
          slotIdx: idx,
          isCustom: team.isCustom,
        ));
      });
    }

    if (!hasData) {
      minH = 18;
      maxH = 22;
    }
    final displayStart = math.max(6, minH - 1);
    final displayEnd = math.min(24, maxH + 1);
    final totalHours = displayEnd - displayStart;
    final rowHeight = math.max(30.0, 300.0 / totalHours);
    final totalContentHeight = totalHours * rowHeight;

    return Column(
      children: [
        _headerRow(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dayColWidth = (constraints.maxWidth - _timeColWidth) / 7;
              return SingleChildScrollView(
                child: SizedBox(
                  height: totalContentHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _timeColumn(displayStart, displayEnd, rowHeight),
                      for (final day in kWeekDays)
                        _dayColumn(
                          day: day,
                          width: dayColWidth,
                          events: events
                              .where((e) => e.day == day)
                              .toList()
                            ..sort((a, b) => a.start.compareTo(b.start)),
                          displayStart: displayStart,
                          displayEnd: displayEnd,
                          rowHeight: rowHeight,
                          totalContentHeight: totalContentHeight,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _headerRow() {
    return Container(
      height: 35,
      decoration: const BoxDecoration(
        color: Color(0xFFEFEBE9),
        border: Border(
          bottom: BorderSide(color: AppColors.brown, width: 2),
        ),
      ),
      child: Row(
        children: [
          Container(width: _timeColWidth, color: const Color(0xFFD7CCC8)),
          for (final d in kWeekDays)
            Expanded(
              child: Container(
                color: const Color(0xFFD7CCC8),
                alignment: Alignment.center,
                child: Text(
                  d,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeColumn(int displayStart, int displayEnd, double rowHeight) {
    return Container(
      width: _timeColWidth,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF8E1),
        border: Border(
          right: BorderSide(color: Color(0xFFD7CCC8)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var h = displayStart; h < displayEnd; h++)
            Container(
              height: rowHeight,
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 2),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEFEBE9)),
                ),
              ),
              child: Text(
                getHourLabel(h),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brown,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayColumn({
    required String day,
    required double width,
    required List<_Event> events,
    required int displayStart,
    required int displayEnd,
    required double rowHeight,
    required double totalContentHeight,
  }) {
    return SizedBox(
      width: width,
      height: totalContentHeight,
      child: Stack(
        children: [
          // 시간 그리드 라인
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var h = displayStart; h < displayEnd; h++)
                Container(
                  height: rowHeight,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF5F5F5)),
                      right: BorderSide(color: Color(0xFFEFEBE9)),
                    ),
                  ),
                ),
            ],
          ),
          // 이벤트 블록
          for (var i = 0; i < events.length; i++)
            _eventBlock(events, i, displayStart, rowHeight, width),
        ],
      ),
    );
  }

  Widget _eventBlock(List<_Event> events, int i, int displayStart,
      double rowHeight, double colWidth) {
    final evt = events[i];

    // 겹치는 이전 이벤트 수 → 들여쓰기 (최대 2, 초과 시 0으로 리셋)
    var indent = 0;
    for (var j = 0; j < i; j++) {
      final prev = events[j];
      if (evt.start < prev.end && evt.end > prev.start) indent++;
    }
    if (indent > 2) indent = 0;

    final topPx = (evt.start - displayStart) * rowHeight;
    final heightPx = math.max((evt.end - evt.start) * rowHeight - 2, 20.0);
    final leftPx = colWidth * (indent * 0.10);
    final widthPx = colWidth * ((95 - indent * 5) / 100.0);

    return Positioned(
      top: topPx,
      left: leftPx,
      width: widthPx,
      height: heightPx,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.slotColors[evt.slotIdx],
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(
              color: AppColors.slotBorderColors[evt.slotIdx],
              width: 4,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: _verticalTitle(
          evt.isCustom ? '🍙${evt.teamName}' : evt.teamName,
        ),
      ),
    );
  }

  /// 세로쓰기 제목 (웹 .evt-title writing-mode: vertical-rl 흉내).
  Widget _verticalTitle(String text) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in text.runes)
            Text(
              String.fromCharCode(r),
              style: const TextStyle(
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: Color(0xFF3E2723),
              ),
            ),
        ],
      ),
    );
  }
}

class _Event {
  final String teamName;
  final String day;
  final double start;
  final double end;
  final int slotIdx;
  final bool isCustom;

  const _Event({
    required this.teamName,
    required this.day,
    required this.start,
    required this.end,
    required this.slotIdx,
    required this.isCustom,
  });
}
