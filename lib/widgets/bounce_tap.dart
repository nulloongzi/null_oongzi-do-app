// bounce_tap.dart — 누르면 살짝 축소(scale 0.9~0.98)되는 spring 피드백.
// 디자인 노스스타: 거의 모든 탭 요소에 적용("빠지면 차가운 앱 느낌"). design §1.3.
import 'package:flutter/material.dart';

class BounceTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale; // 눌렀을 때 크기 (기본 0.94)
  final BorderRadius? borderRadius; // 잉크 splash 없이 순수 스케일

  const BounceTap({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.94,
    this.borderRadius,
  });

  @override
  State<BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends State<BounceTap> {
  bool _down = false;

  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    // Listener는 수동 관찰자 — 자식(Material 칩/버튼)의 탭을 가로채지 않으면서
    // 누름 시각 효과만 준다. onTap이 주어지면 GestureDetector로 탭도 처리.
    Widget c = Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack, // spring(통통)
        child: widget.child,
      ),
    );
    if (widget.onTap != null) {
      c = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: c,
      );
    }
    return c;
  }
}
