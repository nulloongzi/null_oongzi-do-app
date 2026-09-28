// warm_avatar.dart — 밥친구 익힘 효과(웹 css .fr-warm 과 같은 단계).
//   1 뜸: 옅은 테두리 + 김 한 줄
//   2 노릇: 금빛 테두리가 숨 쉬듯 빛남 + 김 두 줄
//   3 누룽지: 갈색·금빛이 도는 테두리 + 김 + 바삭한 부스러기
// big 이 아니면 테두리 색만 — 목록 스크롤이 요란하지 않게. 움직임 줄이기 설정이면 멈춘다.
import 'dart:math' as math;
import 'package:flutter/material.dart';

const warmInk = [
  Color(0xFF8D6E63),
  Color(0xFF8D6E63),
  Color(0xFFB7791F),
  Color(0xFF8B4513),
];
const _ring = [
  Color(0x00000000),
  Color(0xFFF1D9A6),
  Color(0xFFF5B82E),
  Color(0xFFA0522D),
];

class WarmAvatar extends StatefulWidget {
  final Widget child;
  final double size;
  final int tier;
  final bool big;

  /// 누룽지 부스러기. 지도 위 🍚 버블처럼 작은 자리에서는 끈다.
  final bool crumbs;
  const WarmAvatar({
    super.key,
    required this.child,
    required this.size,
    required this.tier,
    this.big = false,
    this.crumbs = true,
  });

  @override
  State<WarmAvatar> createState() => _WarmAvatarState();
}

class _WarmAvatarState extends State<WarmAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  bool get _animate =>
      widget.big &&
      widget.tier > 0 &&
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(WarmAvatar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_animate) {
      if (!_c.isAnimating) _c.repeat();
    } else if (_c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tier <= 0) return widget.child;
    final tier = widget.tier.clamp(1, 3);
    if (!widget.big) {
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _ring[tier],
            width: tier == 1 ? 2 : 2.5,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child: widget.child,
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => CustomPaint(
        painter: _RingPainter(tier, _animate ? _c.value : 0),
        foregroundPainter: _animate
            ? _SteamPainter(tier, _c.value, widget.crumbs)
            : null,
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _RingPainter extends CustomPainter {
  final int tier;
  final double t;
  const _RingPainter(this.tier, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (tier == 3) {
      // 도는 갈색·금빛 테두리 (한 바퀴 3.2초 → 2.6초 주기에 맞춰 한 바퀴)
      final rect = Rect.fromCircle(center: c, radius: r + 4);
      final p = Paint()
        ..shader = SweepGradient(
          transform: GradientRotation(t * 2 * math.pi),
          colors: const [
            Color(0xFF8B4513),
            Color(0xFFF5B82E),
            Color(0xFFC9772B),
            Color(0xFF6D3B1A),
            Color(0xFFF5B82E),
            Color(0xFF8B4513),
          ],
        ).createShader(rect);
      canvas.drawCircle(c, r + 4, p);
      canvas.drawCircle(c, r + 2, Paint()..color = const Color(0xFFFFFDF8));
      return;
    }
    if (tier == 2) {
      final breath = (1 - math.cos(t * 2 * math.pi)) / 2; // 0→1→0
      canvas.drawCircle(
        c,
        r + 3,
        Paint()
          ..color = Color.fromRGBO(245, 184, 46, 0.25 + 0.45 * breath)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + 8 * breath),
      );
    }
    canvas.drawCircle(
      c,
      r + (tier == 1 ? 1 : 1.25),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tier == 1 ? 2 : 2.5
        ..color = _ring[tier],
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.t != t || o.tier != tier;
}

class _SteamPainter extends CustomPainter {
  final int tier;
  final double t;
  final bool crumbs;
  const _SteamPainter(this.tier, this.t, this.crumbs);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // 김: 머리 위로 피어오르는 곡선 (두 줄이면 반 주기 어긋나게)
    for (var i = 0; i < math.min(tier, 2); i++) {
      final ph = (t + i * 0.5) % 1;
      final alpha = ph < 0.35 ? ph / 0.35 : (1 - ph) / 0.65;
      final x = w * (i == 0 ? 0.44 : 0.58);
      final y = -4 - ph * 12;
      final path = Path()
        ..moveTo(x, y + 12)
        ..quadraticBezierTo(x - 4, y + 6, x, y)
        ..quadraticBezierTo(x + 3, y - 4, x - 1, y - 7);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = Color.fromRGBO(141, 110, 99, 0.45 * alpha),
      );
    }
    if (tier < 3 || !crumbs) return;
    // 부스러기: 가운데에서 튀어 나가며 사라진다
    const dirs = [
      Offset(-34, -22),
      Offset(32, -26),
      Offset(36, 14),
      Offset(-30, 20),
      Offset(4, -38),
    ];
    final c = size.center(Offset.zero);
    for (var k = 0; k < dirs.length; k++) {
      final ph = (t + k * 0.19) % 1;
      if (ph < 0.55) continue;
      final q = (ph - 0.55) / 0.45;
      final pos = c + dirs[k] * (size.width / 56) * q;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(q * 2.8);
      canvas.drawRect(
        const Rect.fromLTWH(-2, -2, 4, 4),
        Paint()
          ..color =
              (k.isOdd ? const Color(0xFFE0A45A) : const Color(0xFFB8733A))
                  .withValues(alpha: q < 0.15 ? q / 0.15 : 1 - q),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SteamPainter o) => o.t != t || o.tier != tier;
}
