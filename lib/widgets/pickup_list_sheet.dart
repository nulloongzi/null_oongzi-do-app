// pickup_list_sheet.dart — 픽업 목록 드래그 시트. 상세도 이 시트 안의 모드다.
// map_detail_panel.dart(상세 시트)와 동일한 부드러운 방식:
//  · 별도 StatefulWidget → 드래그 setState가 이 subtree만 리빌드(MapScreen 전체 X).
//  · 단색 배경 + AnimatedContainer(드래그 중 duration:0, 놓으면 스냅). BackdropFilter 블러 없음.
//  · Align(bottomCenter)라 시트 위쪽 영역 터치는 지도로 통과 → 지도·마커와 공존.
// (초기 구현이 GlassSurface 블러 + MapScreen 전역 setState라 드래그가 버벅여서 교체.)
//
// 상세(detail != null): 별도 MapDetailPanel을 띄우지 않고 같은 시트가 정보창이 된다 —
// 크기·모서리가 다른 두 장이 겹쳐 보이던 것을 없앤다(웹 .pickup-list-panel.detail 대응).
// 펼침 비율은 DetailPanelScope로 본문에 노출 → 시간표 morph·릴스 노출이 상세 패널과 동일.
import 'package:flutter/material.dart';
import '../models/pickup_spot.dart';
import '../services/deep_link_service.dart' show kCaptureMode;
import '../services/i18n.dart';
import '../theme.dart';
import 'map_detail_panel.dart'
    show DetailPanelScope, SheetHeight, kSheetCloseRatio, kSheetFlingVelocity;
import 'pickup_list_panel.dart';

/// 캡처 시연용: 목록·상세 시트를 이 비율(0=기본 높이 … 1=확장)까지 올린다(음수면 무시).
/// 손가락으로 끌어올릴 때와 같은 스냅 애니메이션.
final ValueNotifier<double> pickupSheetDemoTo = ValueNotifier<double>(-1);

class PickupListSheet extends StatefulWidget {
  final List<PickupSpot> spots;
  final void Function(PickupSpot) onTap;
  final void Function(PickupSpot)? onInstaTap;

  /// 상세 모드 본문. null이면 목록 모드.
  final Widget? detail;

  /// 상세 대상 식별자 — 바뀌면 상세 스크롤을 맨 위로 되돌린다.
  final String? detailId;

  /// 상세 → 목록 (뒤로가기 버튼, 시트를 아래로 충분히 내렸을 때).
  final VoidCallback? onBack;

  const PickupListSheet({
    super.key,
    required this.spots,
    required this.onTap,
    this.onInstaTap,
    this.detail,
    this.detailId,
    this.onBack,
  });

  @override
  State<PickupListSheet> createState() => _PickupListSheetState();
}

class _PickupListSheetState extends State<PickupListSheet>
    with SingleTickerProviderStateMixin {
  // 높이 — 상세 패널과 같은 컨트롤러·토큰(끌면 따라오고, 놓으면 300ms 감속으로 붙기). M02
  late final SheetHeight _h = SheetHeight(this, _onTick);
  double _peek = 0; // 기본
  double _expanded = 0; // 확장
  bool _ready = false;

  // 0(peek)~1(expand) 펼침 비율 — 상세 본문 morph가 구독(MapDetailPanel과 동일).
  final ValueNotifier<double> _expand = ValueNotifier<double>(0);
  final ScrollController _detailScroll = ScrollController();

  bool get _isDetail => widget.detail != null;

  double get _ratio => _expanded <= _peek
      ? 0
      : ((_height - _peek) / (_expanded - _peek)).clamp(0.0, 1.0);

  double get _height => _h.value;

  void _onTick() {
    if (!mounted) return;
    setState(() {});
    _expand.value = _ratio;
  }

  void _snap(double target) =>
      _h.animateTo(target, instant: MediaQuery.of(context).disableAnimations);

  void _ensure(double screenH) {
    if (_ready) return;
    _peek = screenH * 0.42;
    _expanded = screenH * 0.9;
    _h.jump(_peek);
    _ready = true;
  }

  @override
  void initState() {
    super.initState();
    if (kCaptureMode) pickupSheetDemoTo.addListener(_onDemoTo);
  }

  void _onDemoTo() {
    final r = pickupSheetDemoTo.value;
    if (!mounted || !_ready || r < 0) return;
    _snap(_peek + (_expanded - _peek) * r.clamp(0.0, 1.0));
  }

  @override
  void didUpdateWidget(covariant PickupListSheet old) {
    super.didUpdateWidget(old);
    if (old.detailId != widget.detailId && _detailScroll.hasClients) {
      _detailScroll.jumpTo(0); // 다른 크루로 바뀌면 맨 위부터
    }
  }

  @override
  void dispose() {
    pickupSheetDemoTo.removeListener(_onDemoTo);
    _h.dispose();
    _expand.dispose();
    _detailScroll.dispose();
    super.dispose();
  }

  // 드래그 종료 → 가까운 스냅 지점(기본/확장). 목록은 peek 밑으로 안 내려가고 닫지도 않는다.
  // 상세는 아래로 충분히 내리면 목록으로 돌아간다(상세 패널의 닫기 제스처와 동일).
  // 빠르게 튕기면 그 방향으로(상세 패널과 같은 기준).
  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0; // 아래가 +
    final down = v > kSheetFlingVelocity && _height <= _peek;
    if (_isDetail && (_height < _peek * kSheetCloseRatio || down)) {
      _snap(_peek);
      widget.onBack?.call();
      return;
    }
    if (v < -kSheetFlingVelocity) return _snap(_expanded);
    if (v > kSheetFlingVelocity) return _snap(_peek);
    final mid = (_peek + _expanded) / 2;
    _snap(_height >= mid ? _expanded : _peek);
  }

  // 상세 본문(시간표) 탭 → peek↔expand 토글 (웹 toggleTimeExpand 대응).
  void _toggle() {
    final mid = (_peek + _expanded) / 2;
    _snap(_height >= mid ? _peek : _expanded);
  }

  @override
  Widget build(BuildContext context) {
    _ensure(MediaQuery.of(context).size.height);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: _height,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
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
        child: Column(
          children: [
            // 드래그 핸들 — 여기만 끌어 높이 조절(본문 스크롤과 비간섭).
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => _h.jump(_height),
              onVerticalDragUpdate: (d) => _h.jump(
                (_height - d.delta.dy)
                    .clamp(_isDetail ? 0.0 : _peek, _expanded)
                    .toDouble(),
              ),
              onVerticalDragEnd: _onDragEnd,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: NurungjiColors.handle,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isDetail
                  ? _detailBody()
                  : PickupListPanel(
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

  Widget _detailBody() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Row(
          children: [
            _backButton(),
            const Spacer(),
            // 펼침 힌트 (웹 #expandHint): peek=올려보기 / expand=접기
            ValueListenableBuilder<double>(
              valueListenable: _expand,
              builder: (_, r, _) => Text(
                r >= 0.5 ? t('detail_collapse_hint') : t('detail_pull_hint'),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        // Material로 감싸 본문 텍스트 기준(theme bodyMedium)·잉크 보장.
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            controller: _detailScroll,
            // peek(ratio<0.5)에선 스크롤 잠금 — 펼쳐야 그 아래(릴스/소유자)까지 봄.
            physics: _ratio >= 0.5
                ? null
                : const NeverScrollableScrollPhysics(),
            child: DetailPanelScope(
              expand: _expand,
              toggle: _toggle,
              child: widget.detail!,
            ),
          ),
        ),
      ),
    ],
  );

  // 웹 .pl-back-btn 과 같은 톤의 알약 버튼.
  Widget _backButton() => Material(
    color: const Color(0xFFF0ECE2),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: widget.onBack,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          t('pk_back_to_list'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6D6258),
          ),
        ),
      ),
    ),
  );
}
