// app_sheet.dart — 공용 모달 바텀시트 표시 헬퍼.
// 웹앱의 "지도 위에 뜨는 팝업/바텀시트" 동작을 네이티브로 재현한다:
// 풀스크린 라우트(Navigator.push)로 화면을 갈아끼우지 않고, 지도가 뒤에 남는
// 모달 시트로 슬라이드업. 상세/필터/공유 시트와 동일한 톤(크림 배경·드래그핸들·
// 상단 라운드 — theme.dart bottomSheetTheme)을 그대로 쓴다.
import 'package:flutter/material.dart';
import '../theme.dart';
import 'bowl_text.dart';

/// 화면 콘텐츠를 모달 바텀시트로 띄운다.
/// - [child]는 Scaffold/AppBar 없이 시트 본문만 담은 위젯.
/// - 키보드/긴 폼에서도 거의 전체 높이까지 커질 수 있게 isScrollControlled + maxHeight 캡.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget child,
  Color? background, // null이면 테마(크림). 등록폼 등 흰 배경엔 Colors.white 전달.
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: background,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.94,
    ),
    sheetAnimationStyle: kModalSheetMotion,
    builder: (_) => child,
  );
}

/// 모달 바텀시트 모션 — 토큰(웹 --motion-modal-* · --ease-modal)과 같은 값. 웹 🍚 시트도 이 값. M01
final kModalSheetMotion = AnimationStyle(
  duration: NurungjiMotion.modalEnter,
  reverseDuration: NurungjiMotion.modalExit,
  curve: NurungjiMotion.modalCurve,
  reverseCurve: NurungjiMotion.modalCurve,
);

/// 시트 본문 상단 제목 (AppBar를 대체). 좌측 정렬·굵게, 누룽지 다크.
class SheetTitle extends StatelessWidget {
  final String text;
  const SheetTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: BowlText(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF4E342E), // NurungjiColors.dark
        ),
      ),
    );
  }
}

/// 위에서 내려오는 모달 시트(탑시트) — 검색바 옆 필터처럼 화면 위쪽에서 여는 시트.
/// 웹 #filterSheet 와 같은 동작(docs/motion-spec.md §5):
///  · 위에서 [NurungjiMotion.modalEnter] 로 내려오고 [NurungjiMotion.modalExit] 로 올라가 닫힌다(뒤 딤도 함께).
///  · 손잡이는 시트 아래쪽. 위로 끌면 따라 올라가고, 50px 넘게 올리거나 위로 빠르게 튕기면 닫힌다.
///  · 바깥(딤)을 누르거나 뒤로가기도 닫기(취소).
Future<T?> showTopSheet<T>(BuildContext context, {required Widget child}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: NurungjiColors.dim,
      transitionDuration: NurungjiMotion.modalEnter,
      reverseTransitionDuration: NurungjiMotion.modalExit,
      pageBuilder: (_, _, _) => _TopSheet(child: child),
      transitionsBuilder: (_, anim, _, page) => SlideTransition(
        position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: anim,
            curve: NurungjiMotion.modalCurve,
            reverseCurve: NurungjiMotion.modalCurve,
          ),
        ),
        child: page,
      ),
    ),
  );
}

/// 탑시트를 위로 끌어 닫는 기준(px). 웹 js/filters.js 와 같은 값.
const kTopSheetCloseDrag = 50.0;

class _TopSheet extends StatefulWidget {
  final Widget child;
  const _TopSheet({required this.child});

  @override
  State<_TopSheet> createState() => _TopSheetState();
}

class _TopSheetState extends State<_TopSheet> {
  double _dy = 0; // 위로 끈 만큼(음수)
  bool _dragging = false;

  void _end(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0; // 아래가 +
    if (_dy < -kTopSheetCloseDrag || v < -800) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _dragging = false;
      _dy = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxH = (mq.size.height - mq.viewInsets.bottom) * 0.85;
    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedContainer(
        duration: _dragging ? Duration.zero : NurungjiMotion.modalEnter,
        curve: NurungjiMotion.modalCurve,
        transform: Matrix4.translationValues(0, _dy, 0),
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(
          color: Colors.white, // 웹 .filter-sheet
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(NurungjiRadius.sheet),
          ),
          boxShadow: [NurungjiShadows.md],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: mq.padding.top + 8), // 상태 표시줄 아래부터
              Flexible(child: widget.child),
              // 손잡이(아래) — 위로 끌어 닫는다. 화면 낭독기엔 '닫기' 버튼
              Semantics(
                button: true,
                label: MaterialLocalizations.of(context).closeButtonLabel,
                onTap: () => Navigator.of(context).maybePop(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) => setState(() => _dragging = true),
                  onVerticalDragUpdate: (d) => setState(
                    () => _dy = (_dy + d.delta.dy).clamp(-maxH, 0.0),
                  ),
                  onVerticalDragEnd: _end,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
