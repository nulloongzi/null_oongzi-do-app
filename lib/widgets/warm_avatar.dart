// warm_avatar.dart — 밥친구 합석 단계 그림(웹 js/friends.js fillBowl · 공유 카드와 같은 값).
//
// 합석 단계 = 같이 다니는 팀 수: 1 한 숟갈 · 2 한 그릇 · 3팀 이상 한솥밥.
// 아바타 속 밥그릇이 단계만큼 차오른다(1/3 · 2/3 · 가득). 테두리·빛남 같은 장식은 없다.
// WarmAvatar(단계 색 테두리)는 🍚 버블의 '처음 합석' 알림에만 쓴다.
import 'package:flutter/material.dart';

/// 단계 글자 색(목록·카드의 '한 그릇 · 같은 팀 2개').
const warmInk = [
  Color(0xFF8D6E63),
  Color(0xFF8D6E63),
  Color(0xFFB7791F),
  Color(0xFF9A6B00),
];

/// 단계 색 — 밥그릇 채움 · 🍚 버블 알림 테두리.
const warmRing = [
  Color(0x00000000),
  Color(0xFFF1D9A6),
  Color(0xFFF5B82E),
  Color(0xFFE0A800),
];
const mealLevel = [0.0, 1 / 3, 2 / 3, 1.0];
const _bowlTop = 4.6, _bowlBottom = 19.4;
const _ink = Color(0xFF3D2C22);

/// 밥그릇(24 단위 좌표) — 웹 friends.js 아바타·로고와 같은 모양.
Path bowlPath() => Path()
  ..moveTo(12, 4.6)
  ..cubicTo(10.1, 4.6, 8.8, 5.6, 8.1, 6.8)
  ..cubicTo(7.1, 6.4, 5.7, 7.1, 5.7, 8.5)
  ..cubicTo(5.7, 9.4, 6.4, 10, 7.1, 10)
  ..lineTo(16.9, 10)
  ..cubicTo(17.6, 10, 18.3, 9.4, 18.3, 8.5)
  ..cubicTo(18.3, 7.1, 16.9, 6.4, 15.9, 6.8)
  ..cubicTo(15.2, 5.6, 13.9, 4.6, 12, 4.6)
  ..close()
  ..moveTo(4.2, 11.6)
  ..lineTo(19.8, 11.6)
  ..cubicTo(19.8, 14.7, 17.3, 17.2, 14, 17.8)
  ..lineTo(14, 18.7)
  ..cubicTo(14, 19.1, 13.7, 19.4, 13.3, 19.4)
  ..lineTo(10.7, 19.4)
  ..cubicTo(10.3, 19.4, 10, 19.1, 10, 18.7)
  ..lineTo(10, 17.8)
  ..cubicTo(6.7, 17.2, 4.2, 14.7, 4.2, 11.6)
  ..close();

/// [rect] 안에 밥그릇을 그린다. tier 0 이면 짙은 단색, 아니면 단계만큼 차오른 그릇.
void paintMealBowl(Canvas c, Rect rect, int tier) {
  final t = tier.clamp(0, 3);
  final path = bowlPath();
  c.save();
  c.translate(rect.left, rect.top);
  c.scale(rect.width / 24);
  if (t == 0) {
    c.drawPath(path, Paint()..color = _ink);
    c.restore();
    return;
  }
  c.save();
  c.clipPath(path);
  c.drawRect(
    const Rect.fromLTWH(0, 0, 24, 24),
    Paint()..color = const Color(0x473D2C22),
  );
  final y = _bowlBottom - (_bowlBottom - _bowlTop) * mealLevel[t];
  c.drawRect(Rect.fromLTWH(0, y, 24, 24), Paint()..color = warmRing[t]);
  c.restore();
  c.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _ink,
  );
  c.restore();
}

class MealBowlPainter extends CustomPainter {
  final int tier;
  const MealBowlPainter([this.tier = 0]);

  @override
  void paint(Canvas c, Size size) => paintMealBowl(c, Offset.zero & size, tier);

  @override
  bool shouldRepaint(covariant MealBowlPainter old) => old.tier != tier;
}

/// 단계 색 테두리 — 🍚 버블의 '처음 합석' 알림용.
class WarmAvatar extends StatelessWidget {
  final Widget child;
  final double size;
  final int tier;
  final bool big;

  /// 둥근 사각형 테두리(🍚 FAB). null 이면 원.
  final BorderRadius? radius;
  const WarmAvatar({
    super.key,
    required this.child,
    required this.size,
    required this.tier,
    this.big = false,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    if (tier <= 0) return child;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius,
        border: Border.all(
          color: warmRing[tier.clamp(1, 3)],
          width: big ? 3 : 2,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      child: child,
    );
  }
}
