// map_detail_panel.dart — 비(非)모달 상세 바텀 패널.
// 웹 .bottom-sheet 동작 재현: 화면 바닥에만 깔리고(딤·배리어 없음) 위쪽 영역의 터치는
// 그대로 지도로 통과된다 → 시트를 띄운 채 지도 패닝/줌 가능. 핸들을 끌어 peek↔expand
// 높이를 조절하고, 아래로 충분히 내리면 닫힌다. 본문은 내부에서 스크롤.
//
// 펼침 비율(_expand: 0=peek..1=expand)을 DetailPanelScope로 본문에 노출 → 시간표 morph
// (요약↔그리드)와 펼침 힌트가 이 비율에 연동된다(웹 interpolateMorph 대응).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../services/deep_link_service.dart' show kCaptureMode;
import '../services/i18n.dart';
import '../theme.dart';

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

/// 상세 패널의 현재 **상단 y(논리 px)**. 패널이 떠 있지 않으면 -1.
/// 마케팅 시연 영상 합성기가 시트 슬라이드업을 정확한 위치로 재현하는 데 쓴다.
/// (패널은 화면을 채우는 Align 안에 있어 렌더박스 상단을 재면 항상 0 이 나온다.)
final ValueNotifier<double> detailPanelTop = ValueNotifier<double>(-1);

/// 캡처 시연용: 패널을 펼친다(peek → expand). 핸들을 끌거나 본문을 탭했을 때와
/// 같은 경로다. 인증 신청·릴스는 _ExpandReveal 안에 있어 펼치지 않으면 화면에
/// 아예 나타나지 않는다 — 자막은 인증을 말하는데 아무 일도 안 일어나 보였다.
final ValueNotifier<int> detailPanelDemoExpand = ValueNotifier<int>(0);

/// 캡처 시연용: 다시 접는다(expand → peek). 펼친 상태에선 제목줄(🍱 포함)이
/// 화면 맨 위, 자막 띠(위 14~27%) 뒤로 들어간다 — 담기를 눌러도 아이콘이
/// 바뀌는 게 영상에 안 보였다(실측: 7차 촬영본 10~13초).
final ValueNotifier<int> detailPanelDemoPeek = ValueNotifier<int>(0);

/// 캡처 시연용: 펼친 본문을 맨 아래까지 스크롤한다. 관리자 영역·급구·식구 모집
/// 버튼은 본문 맨 끝이라 펼치기만 해서는 화면 아래로 밀려 안 보인다.
final ValueNotifier<int> detailPanelDemoScrollEnd = ValueNotifier<int>(0);

/// 쓸어내려 닫는 기준: 접힌 높이의 60% 아래에서 놓으면 닫힌다.
/// 웹 club-detail.js SHEET_CLOSE_RATIO 와 같은 값(design-system §3-1).
const kSheetCloseRatio = 0.6;

/// 빠르게 튕기면(px/s) 위치와 상관없이 그 방향 단계로 간다: 위 → 펼침, 아래 → 접힘(펼침에서)·닫힘(접힘 근처).
/// 웹 club-detail.js SHEET_FLING_VELOCITY(0.8px/ms) 와 같은 값. docs/motion-spec.md M02
const kSheetFlingVelocity = 800.0;

/// 마커를 눌러 시트를 띄울 때 지도 카메라는 이만큼 늦게 출발한다. 둘이 같은 프레임에 시작하면
/// 네이티브 지도 애니메이션이 시트 첫 프레임들을 잡아먹었다(2.13.0). docs/motion-spec.md M01·M16
const kSheetCameraLag = Duration(milliseconds: 120);

/// 시트 높이를 움직이는 컨트롤러 — 상세 패널·픽업 목록 시트가 같이 쓴다.
/// 끄는 동안은 손가락을 그대로 따라가고, 놓으면 토큰 시간·곡선(NurungjiMotion)으로 붙는다.
/// 높이가 매 프레임 바뀌므로 펼침 비율(→ 시간표 모프)도 붙는 동안 함께 움직인다.
class SheetHeight {
  SheetHeight(TickerProvider vsync, VoidCallback onTick)
    : _c = AnimationController.unbounded(vsync: vsync)..addListener(onTick);
  final AnimationController _c;
  double get value => _c.value;

  void jump(double h) {
    _c.stop();
    _c.value = h;
  }

  /// [exit] 이면 닫힘 시간·가속 곡선, 아니면 올라오기·붙기 시간·감속 곡선.
  /// [instant] 는 '애니메이션 줄이기' 설정일 때.
  Future<void> animateTo(double h, {bool exit = false, bool instant = false}) {
    if (instant) {
      jump(h);
      return Future.value();
    }
    return _c
        .animateTo(
          h,
          duration: exit ? NurungjiMotion.sheetExit : NurungjiMotion.sheetEnter,
          curve: exit
              ? NurungjiMotion.sheetExitCurve
              : NurungjiMotion.sheetCurve,
        )
        .orCancel
        .catchError((_) {}); // 끌기·다른 이동으로 끊기면 조용히 끝
  }

  void dispose() => _c.dispose();
}

/// 떠 있는 상세 패널을 내려가는 모션으로 닫는다(뒤로가기 등). 패널이 없으면 false.
bool closeDetailPanelAnimated() {
  final s = _MapDetailPanelState._current;
  if (s == null || !s.mounted) return false;
  s._close();
  return true;
}

class MapDetailPanel extends StatefulWidget {
  final Widget child; // 스크롤될 상세 본문
  final VoidCallback onClose;
  const MapDetailPanel({super.key, required this.child, required this.onClose});

  @override
  State<MapDetailPanel> createState() => _MapDetailPanelState();
}

class _MapDetailPanelState extends State<MapDetailPanel>
    with SingleTickerProviderStateMixin {
  static _MapDetailPanelState? _current;

  late final SheetHeight _h = SheetHeight(this, _onTick);
  double _peek = 0;
  final ScrollController _body = ScrollController(); // 본문 스크롤(시연이 맨 아래로 내린다)
  double _expanded = 0;
  bool _ready = false;
  bool _closing = false;

  // 0(peek)~1(expand) 펼침 비율 — 본문 morph가 구독.
  final ValueNotifier<double> _expand = ValueNotifier<double>(0);

  double get _height => _h.value;

  double get _ratio => _expanded <= _peek
      ? 0
      : ((_height - _peek) / (_expanded - _peek)).clamp(0.0, 1.0);

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  void _onTick() {
    if (!mounted) return;
    setState(() {});
    _expand.value = _ratio;
    _publishTop();
  }

  void _publishTop() {
    if (!mounted) return;
    final sh = MediaQuery.of(context).size.height;
    detailPanelTop.value = sh - _height;
  }

  // 처음 그릴 때 높이 0 에서 접힘 높이까지 아래에서 올라온다(웹 #bottomSheet 와 같음). M01
  void _ensure(double screenH) {
    if (_ready) return;
    _peek = screenH * 0.42;
    _expanded = screenH * 0.9;
    _ready = true;
    final instant = _reduceMotion || kCaptureMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _h.animateTo(_peek, instant: instant);
    });
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await _h.animateTo(0, exit: true, instant: _reduceMotion);
    if (mounted) widget.onClose();
  }

  void _snap(double target) => _h.animateTo(target, instant: _reduceMotion);

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0; // 아래가 +
    if (v < -kSheetFlingVelocity) return _snap(_expanded);
    if (v > kSheetFlingVelocity) {
      if (_height > _peek) return _snap(_peek);
      _close();
      return;
    }
    if (_height < _peek * kSheetCloseRatio) {
      _close(); // 아래로 충분히 내리면 닫힘
      return;
    }
    final mid = (_peek + _expanded) / 2;
    _snap(_height >= mid ? _expanded : _peek); // 가까운 지점으로 스냅
  }

  // 본문(시간표) 탭 → peek↔expand 토글 (웹 toggleTimeExpand 대응).
  void _toggle() {
    final mid = (_peek + _expanded) / 2;
    _snap(_height >= mid ? _peek : _expanded);
  }

  @override
  void initState() {
    super.initState();
    _current = this;
    if (kCaptureMode) {
      detailPanelDemoExpand.addListener(_onDemoExpand);
      detailPanelDemoPeek.addListener(_onDemoPeek);
      detailPanelDemoScrollEnd.addListener(_onDemoScrollEnd);
    }
  }

  void _onDemoExpand() => _snapTo(_expanded);
  void _onDemoPeek() => _snapTo(_peek);
  void _onDemoScrollEnd() {
    if (!mounted || !_body.hasClients) return;
    unawaited(
      _body.animateTo(
        _body.position.maxScrollExtent,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _snapTo(double h) {
    if (!mounted || !_ready) return;
    _snap(h);
  }

  @override
  void dispose() {
    if (identical(_current, this)) _current = null;
    detailPanelDemoExpand.removeListener(_onDemoExpand);
    detailPanelDemoPeek.removeListener(_onDemoPeek);
    detailPanelDemoScrollEnd.removeListener(_onDemoScrollEnd);
    _h.dispose();
    _body.dispose();
    _expand.dispose();
    detailPanelTop.value = -1; // 패널이 사라지면 좌표도 무효화
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensure(MediaQuery.of(context).size.height);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: _height.clamp(0.0, double.infinity),
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white, // 웹 .bottom-sheet: 흰색
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NurungjiRadius.sheet),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x265D4037),
              blurRadius: 28,
              offset: Offset(0, -6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        // 올라오고 내려가는 동안(높이가 내용보다 작을 때)도 안쪽은 접힘 높이 이상으로 그려 잘라 보인다
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: math.max(_height, _peek),
          child: Column(
            children: [
              // 드래그 핸들 (여기만 끌어 높이 조절 — 본문 스크롤과 비간섭).
              // 손가락으론 쓸어내려 닫고, 화면 낭독기(TalkBack·VoiceOver)엔 '닫기' 버튼으로 읽힌다.
              // Semantics.onTap 은 접근성 동작만 추가한다 — 손가락 탭 동작은 그대로(웹 #sheetHandle 과 같음)
              Semantics(
                button: true,
                label: t('sheet_close'),
                onTap: _close,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) => _h.jump(_height),
                  onVerticalDragUpdate: (d) =>
                      _h.jump((_height - d.delta.dy).clamp(0.0, _expanded)),
                  onVerticalDragEnd: _onDragEnd,
                  child: Container(
                    width: double.infinity,
                    // 터치 영역 ≥44px 확보(시각 바는 5px 유지) — 드래그 잡기 쉽게.
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    alignment: Alignment.center,
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: NurungjiColors.handle, // 웹 .sheet-handle
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              // 펼침 힌트 (웹 #expandHint): peek=올려보기 / expand=접기
              ValueListenableBuilder<double>(
                valueListenable: _expand,
                builder: (_, r, _) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    r >= 0.5
                        ? t('detail_collapse_hint')
                        : t('detail_pull_hint'),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
              ),
              Expanded(
                // Material로 감싸 본문 텍스트 기준(theme bodyMedium)·잉크 보장
                // (오버레이라 Material 조상이 없으면 텍스트가 과대 기본값으로 렌더됨).
                child: Material(
                  type: MaterialType.transparency,
                  child: SingleChildScrollView(
                    controller: _body,
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
      ),
    );
  }
}
