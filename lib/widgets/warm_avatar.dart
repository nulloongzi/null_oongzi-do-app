// warm_avatar.dart — 밥친구 합석 단계 그림(웹 js/friends.js avatar 와 같은 값).
//
// 합석 단계 = 같이 다니는 팀 수: 1 한 숟갈 · 2 한 그릇 · 3팀 이상 한솥밥.
// 아바타 속 밥그릇(단색 로고)이 단계만큼 차오른다(1/3 · 2/3 · 가득). 테두리·빛남 같은 장식은 없다.
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
const _ink = Color(0xFF3D2C22);

/// 단색 아이콘: 이음선을 구멍으로 뺀 밥그릇. 로그인 수단 도장(웹 js/profile.js rice)과 같다.
Path bowlSolidPath() => Path()
  ..fillType = PathFillType.evenOdd
  ..moveTo(11.04, 19.56)
  ..cubicTo(9.67, 19.44, 8.56, 19.07, 8.31, 18.66)
  ..cubicTo(8.25, 18.56, 8.21, 18.41, 8.21, 18.24)
  ..cubicTo(8.21, 18.01, 8.20, 17.97, 8.08, 17.90)
  ..cubicTo(7.08, 17.30, 6.03, 16.32, 5.47, 15.47)
  ..cubicTo(4.74, 14.36, 4.32, 13.19, 4.22, 11.94)
  ..cubicTo(4.18, 11.41, 4.22, 11.23, 4.43, 11.01)
  ..lineTo(4.61, 10.82)
  ..lineTo(4.68, 11.06)
  ..cubicTo(4.75, 11.28, 4.74, 11.31, 4.65, 11.51)
  ..cubicTo(4.48, 11.85, 4.51, 11.93, 4.86, 12.27)
  ..cubicTo(5.26, 12.65, 5.56, 12.79, 6.56, 13.05)
  ..cubicTo(7.18, 13.21, 7.74, 13.30, 8.78, 13.42)
  ..cubicTo(9.03, 13.45, 9.31, 13.48, 9.40, 13.50)
  ..cubicTo(10.09, 13.60, 14.41, 13.56, 15.05, 13.45)
  ..cubicTo(15.09, 13.44, 15.28, 13.42, 15.48, 13.40)
  ..cubicTo(15.99, 13.35, 17.09, 13.14, 17.63, 12.99)
  ..cubicTo(18.44, 12.77, 18.71, 12.64, 19.08, 12.29)
  ..cubicTo(19.45, 11.93, 19.48, 11.84, 19.32, 11.52)
  ..cubicTo(19.25, 11.38, 19.24, 11.30, 19.27, 11.21)
  ..cubicTo(19.30, 11.14, 19.32, 11.01, 19.32, 10.93)
  ..lineTo(19.32, 10.77)
  ..lineTo(19.52, 10.97)
  ..cubicTo(19.77, 11.22, 19.81, 11.38, 19.76, 11.95)
  ..cubicTo(19.53, 14.36, 18.17, 16.52, 16.10, 17.77)
  ..lineTo(15.77, 17.97)
  ..lineTo(15.75, 18.29)
  ..cubicTo(15.73, 18.54, 15.70, 18.65, 15.61, 18.74)
  ..cubicTo(15.33, 19.03, 14.50, 19.35, 13.69, 19.46)
  ..cubicTo(13.47, 19.50, 13.23, 19.53, 13.15, 19.54)
  ..cubicTo(12.84, 19.59, 11.49, 19.60, 11.04, 19.56)
  ..close()
  ..moveTo(10.29, 13.00)
  ..cubicTo(10.28, 12.99, 10.04, 12.97, 9.75, 12.95)
  ..cubicTo(8.63, 12.88, 7.33, 12.69, 6.51, 12.48)
  ..cubicTo(5.97, 12.34, 5.95, 12.33, 5.72, 12.08)
  ..cubicTo(5.36, 11.68, 5.21, 11.44, 5.28, 11.38)
  ..cubicTo(5.32, 11.34, 5.32, 11.29, 5.28, 11.23)
  ..cubicTo(5.20, 11.08, 5.22, 10.76, 5.32, 10.61)
  ..cubicTo(5.38, 10.51, 5.40, 10.40, 5.39, 10.22)
  ..cubicTo(5.38, 9.91, 5.48, 9.70, 5.69, 9.57)
  ..cubicTo(5.83, 9.49, 5.84, 9.46, 5.84, 9.19)
  ..cubicTo(5.84, 8.91, 5.84, 8.89, 6.04, 8.72)
  ..cubicTo(6.43, 8.38, 6.38, 8.37, 6.79, 8.79)
  ..cubicTo(7.67, 9.71, 8.83, 10.46, 10.13, 10.96)
  ..cubicTo(10.59, 11.14, 11.47, 11.39, 11.64, 11.39)
  ..cubicTo(11.70, 11.39, 11.76, 11.44, 11.79, 11.52)
  ..cubicTo(11.88, 11.75, 12.13, 12.78, 12.13, 12.91)
  ..lineTo(12.13, 13.03)
  ..lineTo(11.22, 13.02)
  ..cubicTo(10.72, 13.02, 10.30, 13.01, 10.29, 13.00)
  ..close()
  ..moveTo(12.85, 12.80)
  ..cubicTo(12.81, 12.50, 12.61, 11.69, 12.50, 11.40)
  ..lineTo(12.43, 11.18)
  ..lineTo(12.61, 10.96)
  ..cubicTo(12.88, 10.64, 13.62, 10.00, 14.11, 9.66)
  ..lineTo(14.52, 9.38)
  ..lineTo(14.64, 9.53)
  ..cubicTo(15.17, 10.19, 15.71, 11.20, 15.97, 12.01)
  ..cubicTo(16.23, 12.83, 16.28, 12.74, 15.53, 12.83)
  ..cubicTo(14.79, 12.92, 14.35, 12.96, 13.49, 13.01)
  ..lineTo(12.89, 13.04)
  ..lineTo(12.85, 12.80)
  ..close()
  ..moveTo(16.86, 12.46)
  ..cubicTo(16.66, 11.51, 16.06, 10.26, 15.32, 9.25)
  ..lineTo(15.15, 9.02)
  ..lineTo(15.44, 8.90)
  ..cubicTo(16.03, 8.63, 16.47, 8.49, 17.36, 8.29)
  ..cubicTo(17.53, 8.25, 18.18, 9.00, 18.18, 9.24)
  ..cubicTo(18.18, 9.31, 18.23, 9.39, 18.30, 9.43)
  ..cubicTo(18.48, 9.55, 18.58, 9.81, 18.57, 10.14)
  ..cubicTo(18.56, 10.35, 18.59, 10.49, 18.67, 10.67)
  ..cubicTo(18.77, 10.89, 18.78, 10.94, 18.73, 11.13)
  ..cubicTo(18.68, 11.30, 18.69, 11.37, 18.74, 11.48)
  ..cubicTo(18.89, 11.77, 18.87, 11.94, 18.65, 12.07)
  ..cubicTo(18.42, 12.20, 17.72, 12.43, 17.23, 12.54)
  ..lineTo(16.89, 12.62)
  ..lineTo(16.86, 12.46)
  ..close()
  ..moveTo(11.29, 10.57)
  ..cubicTo(10.68, 10.40, 10.03, 10.16, 9.64, 9.97)
  ..cubicTo(9.25, 9.77, 9.25, 9.83, 9.58, 9.13)
  ..cubicTo(10.45, 7.27, 11.86, 5.97, 13.66, 5.36)
  ..cubicTo(14.58, 5.04, 15.19, 5.14, 15.49, 5.63)
  ..cubicTo(15.60, 5.80, 15.67, 5.86, 15.87, 5.93)
  ..cubicTo(16.07, 6.00, 16.14, 6.05, 16.24, 6.23)
  ..cubicTo(16.33, 6.39, 16.42, 6.46, 16.53, 6.49)
  ..cubicTo(16.72, 6.54, 17.10, 6.96, 17.07, 7.09)
  ..cubicTo(17.06, 7.14, 17.07, 7.19, 17.09, 7.20)
  ..cubicTo(17.12, 7.22, 17.14, 7.31, 17.14, 7.41)
  ..lineTo(17.14, 7.60)
  ..lineTo(16.73, 7.69)
  ..cubicTo(15.18, 8.03, 13.16, 9.24, 12.15, 10.42)
  ..cubicTo(11.89, 10.73, 11.88, 10.74, 11.29, 10.57)
  ..close()
  ..moveTo(8.23, 9.12)
  ..cubicTo(7.76, 8.77, 7.34, 8.39, 7.07, 8.07)
  ..lineTo(6.87, 7.82)
  ..lineTo(7.00, 7.38)
  ..cubicTo(7.12, 6.99, 7.16, 6.93, 7.28, 6.88)
  ..cubicTo(7.37, 6.85, 7.43, 6.79, 7.45, 6.70)
  ..cubicTo(7.56, 6.21, 7.80, 5.92, 8.15, 5.86)
  ..cubicTo(8.52, 5.80, 8.56, 5.78, 8.64, 5.64)
  ..cubicTo(8.72, 5.48, 8.83, 5.41, 9.11, 5.37)
  ..cubicTo(9.25, 5.35, 9.32, 5.30, 9.41, 5.16)
  ..cubicTo(9.59, 4.87, 9.80, 4.79, 10.22, 4.82)
  ..cubicTo(10.49, 4.85, 10.60, 4.83, 10.72, 4.77)
  ..cubicTo(10.82, 4.72, 10.93, 4.71, 11.06, 4.73)
  ..cubicTo(11.22, 4.75, 11.27, 4.74, 11.38, 4.63)
  ..cubicTo(11.65, 4.37, 12.04, 4.33, 12.42, 4.52)
  ..cubicTo(12.61, 4.61, 12.70, 4.63, 12.93, 4.61)
  ..cubicTo(13.39, 4.57, 13.45, 4.63, 13.10, 4.78)
  ..cubicTo(11.28, 5.52, 9.84, 6.93, 8.90, 8.88)
  ..cubicTo(8.77, 9.17, 8.65, 9.41, 8.64, 9.41)
  ..cubicTo(8.63, 9.41, 8.44, 9.28, 8.23, 9.12)
  ..close();

/// 밥그릇 = 단색 로고(assets/logo_mono.png — 웹 assets/logo/nulloongzido-mono-small-*.svg).
/// tier 0 이면 짙은 단색, 아니면 같은 로고가 아래부터 단계 색으로 차오른다(1/3 · 2/3 · 가득).
/// 웹 js/friends.js avatar 와 같은 모양·색.
class MealBowl extends StatelessWidget {
  final double size;
  final int tier;
  const MealBowl({super.key, required this.size, this.tier = 0});

  @override
  Widget build(BuildContext context) {
    final t = tier.clamp(0, 3);
    final img = Image.asset(
      'assets/logo_mono.png',
      width: size,
      color: t == 0 ? _ink : null,
      colorBlendMode: BlendMode.srcIn,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      excludeFromSemantics: true,
    );
    if (t == 0) return img;
    final lv = mealLevel[t];
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [warmRing[t], warmRing[t], _empty, _empty],
        stops: [0, lv, lv, 1],
      ).createShader(r),
      child: img,
    );
  }
}

const _empty = Color(0x6B3D2C22); // 안 찬 부분 — 짙은 갈색 42%

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
