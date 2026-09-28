// warm_avatar.dart — 밥친구 익힘 단계 표시(웹 css .fr-warm 과 같은 색).
// 움직이는 효과(빛남·도는 테두리·김·부스러기) 없이 단계 색 테두리로만 구분한다.
//   1 뜸 #F1D9A6 · 2 노릇 #F5B82E · 3 누룽지 #A0522D
// big(합석 줄·친구 상세·🍚 버블)은 테두리만 조금 굵게.
import 'package:flutter/material.dart';

const warmInk = [
  Color(0xFF8D6E63),
  Color(0xFF8D6E63),
  Color(0xFFB7791F),
  Color(0xFF8B4513),
];
const warmRing = [
  Color(0x00000000),
  Color(0xFFF1D9A6),
  Color(0xFFF5B82E),
  Color(0xFFA0522D),
];

class WarmAvatar extends StatelessWidget {
  final Widget child;
  final double size;
  final int tier;
  final bool big;
  const WarmAvatar({
    super.key,
    required this.child,
    required this.size,
    required this.tier,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    if (tier <= 0) return child;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
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
