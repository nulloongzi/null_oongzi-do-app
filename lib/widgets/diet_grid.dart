// diet_grid.dart — 식단표(찜한 팀 주간 시간표). 웹 renderCombinedSchedule 포팅.
// 요일×시간 그리드에 팀별 일정 블록을 슬롯 색으로 표시.
import 'package:flutter/material.dart';
import '../services/i18n.dart';
import '../services/schedule_parse.dart';
import '../theme.dart';

class DietTeam {
  final String name;
  final bool isCustom;
  final int slotIdx; // 0~4 (색)
  final List<SchedEvent> events;
  DietTeam({
    required this.name,
    required this.isCustom,
    required this.slotIdx,
    required this.events,
  });
}

class DietGrid extends StatelessWidget {
  final List<DietTeam> teams;
  const DietGrid({super.key, required this.teams});

  static const _slotBg = [
    Color(0xFFFFFDE7),
    Color(0xFFFFF3E0),
    Color(0xFFF1F8E9),
    Color(0xFFFBE9E7),
    Color(0xFFF3E5F5),
  ];
  static const _slotBorder = [
    Color(0xFFFBC02D),
    Color(0xFFF57C00),
    Color(0xFF689F38),
    Color(0xFFD84315),
    Color(0xFF8E24AA),
  ];

  @override
  Widget build(BuildContext context) {
    final all = <({SchedEvent e, DietTeam t})>[];
    for (final t in teams) {
      for (final e in t.events) {
        all.add((e: e, t: t));
      }
    }
    if (all.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            t('lb_no_sched'),
            style: const TextStyle(color: NurungjiColors.brown),
          ),
        ),
      );
    }

    var minH = 24.0, maxH = 0.0;
    for (final x in all) {
      if (x.e.start < minH) minH = x.e.start;
      if (x.e.end > maxH) maxH = x.e.end;
    }
    final displayStart = (minH.floor() - 1).clamp(6, 22).toInt();
    final displayEnd = (maxH.ceil() + 1).clamp(displayStart + 1, 24).toInt();
    final totalHours = displayEnd - displayStart;
    final rowH = (320.0 / totalHours).clamp(34.0, 70.0).toDouble();
    final contentH = totalHours * rowH;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerRow(),
        SizedBox(
          height: contentH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _timeCol(displayStart, displayEnd, rowH),
              for (final day in scheduleDays)
                Expanded(
                  child: _dayCol(day, all, displayStart, totalHours, rowH),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerRow() {
    return Row(
      children: [
        const SizedBox(width: 36),
        for (final d in scheduleDays)
          Expanded(
            child: Center(
              child: Text(
                i18nDay(d),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: NurungjiColors.dark,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _timeCol(int start, int end, double rowH) {
    return SizedBox(
      width: 36,
      child: Column(
        children: [
          for (int h = start; h < end; h++)
            SizedBox(
              height: rowH,
              child: Text(
                getHourLabel(h),
                style: const TextStyle(
                  fontSize: 9,
                  color: NurungjiColors.brown,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayCol(
    String day,
    List<({SchedEvent e, DietTeam t})> all,
    int displayStart,
    int totalHours,
    double rowH,
  ) {
    final dayEvents = all.where((x) => x.e.day == day).toList()
      ..sort((a, b) => a.e.start.compareTo(b.e.start));

    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0x11000000))),
      ),
      child: Stack(
        children: [
          // 가로 시간선
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
          // 이벤트 블록
          for (var i = 0; i < dayEvents.length; i++)
            _eventBlock(dayEvents, i, displayStart, rowH),
        ],
      ),
    );
  }

  Widget _eventBlock(
    List<({SchedEvent e, DietTeam t})> dayEvents,
    int i,
    int displayStart,
    double rowH,
  ) {
    final evt = dayEvents[i].e;
    final team = dayEvents[i].t;
    // 겹침 들여쓰기 (웹과 동일)
    var indent = 0;
    for (var j = 0; j < i; j++) {
      final p = dayEvents[j].e;
      if (evt.start < p.end && evt.end > p.start) indent++;
    }
    if (indent > 2) indent = 0;

    final top = (evt.start - displayStart) * rowH;
    final height = ((evt.end - evt.start) * rowH - 2)
        .clamp(18.0, 9999.0)
        .toDouble();
    final slot = team.slotIdx % 5;

    return Positioned(
      top: top,
      left: 1 + indent * 6.0,
      right: 1,
      height: height,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: _slotBg[slot],
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: _slotBorder[slot], width: 3)),
        ),
        child: Text(
          team.isCustom ? '🍙${team.name}' : team.name,
          style: const TextStyle(
            fontSize: 9,
            height: 1.1,
            color: NurungjiColors.dark,
          ),
          maxLines: (height ~/ 12).clamp(1, 6).toInt(),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
