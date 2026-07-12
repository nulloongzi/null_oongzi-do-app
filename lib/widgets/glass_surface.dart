// glass_surface.dart — 반투명+블러+흰테두리+갈색그림자 글래스 표면. design §1.4.
// 검색바/탭바/패널 등 떠있는 chrome 공통. 성능: 과다 중첩 금지 + ClipRRect 격리.
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassSurface extends StatelessWidget {
  final Widget child;
  final double blur; // ImageFilter sigma (CSS px의 ~절반)
  final Color color; // 반투명 표면색
  final BorderRadius radius;
  final EdgeInsetsGeometry? padding;
  final bool shadow;

  const GlassSurface({
    super.key,
    required this.child,
    this.blur = 8,
    this.color = const Color(0xD9FFFFFF), // 흰 85%
    this.radius = const BorderRadius.all(Radius.circular(16)),
    this.padding,
    this.shadow = true,
  });

  /// 크림 톤(프로필/도시락 카드용) — rgba(255,248,225,0.85)
  const GlassSurface.cream({
    super.key,
    required this.child,
    this.blur = 12,
    this.radius = const BorderRadius.all(Radius.circular(24)),
    this.padding,
    this.shadow = true,
  }) : color = const Color(0xD9FFF8E1);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // 갈색 그림자(검정 아님) — 따뜻함의 핵심 디테일
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x265D4037), // rgba(93,64,55,0.15)
                  blurRadius: 32,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color,
              borderRadius: radius,
              border: Border.all(
                color: const Color(0x80FFFFFF),
                width: 1,
              ), // 흰 50% 테두리
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
