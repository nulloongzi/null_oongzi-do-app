// map_detail_panel.dart — 비(非)모달 상세 바텀 패널.
// 웹 .bottom-sheet 동작 재현: 화면 바닥에만 깔리고(딤·배리어 없음) 위쪽 영역의 터치는
// 그대로 지도로 통과된다 → 시트를 띄운 채 지도 패닝/줌 가능. 핸들을 끌어 peek↔expand
// 높이를 조절하고, 아래로 충분히 내리면 닫힌다. 본문은 내부에서 스크롤.
//
// 펼침 비율(_expand: 0=peek..1=expand)을 DetailPanelScope로 본문에 노출 → 시간표 morph
// (요약↔그리드)와 펼침 힌트가 이 비율에 연동된다(웹 interpolateMorph 대응).
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../services/i18n.dart';

/// 패널의 펼침 비율과 토글을 본문(시간표 morph 등)에 전달하는 스코프.
class DetailPanelScope extends InheritedWidget {
  final ValueListenable<double> expand; // 0=peek, 1=expand
  final VoidCallback toggle; // peek↔expand 스냅
  const DetailPanelScope({
    super.key,
    required this.expand,
    required this.toggle,
    required super.child,
  });

  static DetailPanelScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DetailPanelScope>();

  @override
  bool updateShouldNotify(DetailPanelScope old) =>
      expand != old.expand || toggle != old.toggle;
}

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

  // 0(peek)~1(expand) 펼침 비율 — 본문 morph가 구독.
  final ValueNotifier<double> _expand = ValueNotifier<double>(0);

  double get _ratio => _expanded <= _peek
      ? 0
      : ((_height - _peek) / (_expanded - _peek)).clamp(0.0, 1.0);

  // 핸들러에서만 호출(build 중 호출 금지) — 높이 + 펼침비율 동기.
  void _apply(double h) {
    _height = h;
    _expand.value = _ratio;
  }

  void _ensure(double screenH) {
    if (_ready) return;
    _peek = screenH * 0.42;
    _expanded = screenH * 0.9;
    _height = _peek; // _expand 초기값 0 = peek 비율과 일치
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
      _apply(_height >= mid ? _expanded : _peek); // 가까운 지점으로 스냅
    });
  }

  // 본문(시간표) 탭 → peek↔expand 토글 (웹 toggleTimeExpand 대응).
  void _toggle() {
    final mid = (_peek + _expanded) / 2;
    setState(() {
      _dragging = false;
      _apply(_height >= mid ? _peek : _expanded);
    });
  }

  @override
  void dispose() {
    _expand.dispose();
    super.dispose();
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
            BoxShadow(
                color: Color(0x265D4037), blurRadius: 28, offset: Offset(0, -6)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // 드래그 핸들 (여기만 끌어 높이 조절 — 본문 스크롤과 비간섭)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => setState(() => _dragging = true),
              onVerticalDragUpdate: (d) => setState(
                  () => _apply((_height - d.delta.dy).clamp(0.0, _expanded))),
              onVerticalDragEnd: (_) => _onDragEnd(),
              child: Container(
                width: double.infinity,
                // 터치 영역 ≥44px 확보(시각 바는 5px 유지) — 드래그 잡기 쉽게.
                padding: const EdgeInsets.symmetric(vertical: 20),
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
            // 펼침 힌트 (웹 #expandHint): peek=올려보기 / expand=접기
            ValueListenableBuilder<double>(
              valueListenable: _expand,
              builder: (_, r, __) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  r >= 0.5 ? t('detail_collapse_hint') : t('detail_pull_hint'),
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF9E9E9E)),
                ),
              ),
            ),
            Expanded(
              // Material로 감싸 본문 텍스트 기준(theme bodyMedium)·잉크 보장
              // (오버레이라 Material 조상이 없으면 텍스트가 과대 기본값으로 렌더됨).
              child: Material(
                type: MaterialType.transparency,
                child: SingleChildScrollView(
                  // peek(ratio<0.5)에선 스크롤 잠금 — 펼쳐야 그 아래(릴스/소유자)까지 봄.
                  physics: _ratio >= 0.5
                      ? null
                      : const NeverScrollableScrollPhysics(),
                  child: DetailPanelScope(
                    expand: _expand,
                    toggle: _toggle,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
