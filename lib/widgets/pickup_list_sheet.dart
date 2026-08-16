// pickup_list_sheet.dart — 픽업 목록 드래그 시트.
// map_detail_panel.dart(상세 시트)와 동일한 부드러운 방식:
//  · 별도 StatefulWidget → 드래그 setState가 이 subtree만 리빌드(MapScreen 전체 X).
//  · 단색 배경 + AnimatedContainer(드래그 중 duration:0, 놓으면 스냅). BackdropFilter 블러 없음.
//  · Align(bottomCenter)라 시트 위쪽 영역 터치는 지도로 통과 → 지도·마커와 공존.
// (초기 구현이 GlassSurface 블러 + MapScreen 전역 setState라 드래그가 버벅여서 교체.)
import 'package:flutter/material.dart';
import '../models/pickup_spot.dart';
import 'pickup_list_panel.dart';

class PickupListSheet extends StatefulWidget {
  final List<PickupSpot> spots;
  final void Function(PickupSpot) onTap;
  final void Function(PickupSpot)? onInstaTap;
  const PickupListSheet({
    super.key,
    required this.spots,
    required this.onTap,
    this.onInstaTap,
  });

  @override
  State<PickupListSheet> createState() => _PickupListSheetState();
}

class _PickupListSheetState extends State<PickupListSheet> {
  double _height = 0;
  double _min = 0; // 최소(살짝만)
  double _peek = 0; // 기본
  double _expanded = 0; // 확장
  bool _ready = false;
  bool _dragging = false;

  void _ensure(double screenH) {
    if (_ready) return;
    _min = screenH * 0.14;
    _peek = screenH * 0.42;
    _expanded = screenH * 0.9;
    _height = _peek;
    _ready = true;
  }

  // 드래그 종료 → 가까운 스냅 지점(최소/기본/확장). 목록이라 닫지는 않는다.
  void _onDragEnd() {
    var best = _peek;
    for (final s in [_min, _peek, _expanded]) {
      if ((_height - s).abs() < (_height - best).abs()) best = s;
    }
    setState(() {
      _dragging = false;
      _height = best;
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensure(MediaQuery.of(context).size.height);
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: Duration(milliseconds: _dragging ? 0 : 240),
        curve: Curves.easeOutCubic,
        height: _height,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x265D4037),
              blurRadius: 28,
              offset: Offset(0, -6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // 드래그 핸들 — 여기만 끌어 높이 조절(본문 스크롤과 비간섭).
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => setState(() => _dragging = true),
              onVerticalDragUpdate: (d) => setState(
                () => _height = (_height - d.delta.dy)
                    .clamp(_min, _expanded)
                    .toDouble(),
              ),
              onVerticalDragEnd: (_) => _onDragEnd(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8CFC6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PickupListPanel(
                spots: widget.spots,
                onTap: widget.onTap,
                onInstaTap: widget.onInstaTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
