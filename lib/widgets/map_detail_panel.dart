// map_detail_panel.dart — 비(非)모달 상세 바텀 패널.
// 웹 .bottom-sheet 동작 재현: 화면 바닥에만 깔리고(딤·배리어 없음) 위쪽 영역의 터치는
// 그대로 지도로 통과된다 → 시트를 띄운 채 지도 패닝/줌 가능. 핸들을 끌어 peek↔expand
// 높이를 조절하고, 아래로 충분히 내리면 닫힌다. 본문은 내부에서 스크롤.
//
// OverlayEntry로 띄우므로 Positioned가 아닌 Align(bottomCenter)을 쓴다(빈 위쪽은
// 히트테스트되지 않아 아래 지도로 패스스루).
import 'package:flutter/material.dart';

class MapDetailPanel extends StatefulWidget {
  final Widget child; // 스크롤될 상세 본문
  final VoidCallback onClose;
  const MapDetailPanel({super.key, required this.child, required this.onClose});

  @override
  State<MapDetailPanel> createState() => _MapDetailPanelState();
}

class _MapDetailPanelState extends State<MapDetailPanel> {
  double _height = 0;
  double _peek = 0;
  double _expanded = 0;
  bool _ready = false;
  bool _dragging = false;

  void _ensure(double screenH) {
    if (_ready) return;
    _peek = screenH * 0.42;
    _expanded = screenH * 0.9;
    _height = _peek;
    _ready = true;
  }

  void _onDragEnd() {
    if (_height < _peek * 0.6) {
      widget.onClose(); // 아래로 충분히 내리면 닫힘
      return;
    }
    final mid = (_peek + _expanded) / 2;
    setState(() {
      _dragging = false;
      _height = _height >= mid ? _expanded : _peek; // 가까운 지점으로 스냅
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
          color: Colors.white, // 웹 .bottom-sheet: 흰색
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            // 갈색 그림자(따뜻함) — 위로 뜨는 방향
            BoxShadow(
                color: Color(0x265D4037),
                blurRadius: 28,
                offset: Offset(0, -6)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // 드래그 핸들 (여기만 끌어 높이 조절 — 웹과 동일, 본문 스크롤과 비간섭)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => setState(() => _dragging = true),
              onVerticalDragUpdate: (d) => setState(() {
                _height = (_height - d.delta.dy).clamp(0.0, _expanded);
              }),
              onVerticalDragEnd: (_) => _onDragEnd(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                alignment: Alignment.center,
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0), // 웹 .sheet-handle
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(child: widget.child),
            ),
          ],
        ),
      ),
    );
  }
}
