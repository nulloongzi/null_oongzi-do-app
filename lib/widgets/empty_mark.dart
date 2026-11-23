import 'package:flutter/material.dart';

import '../theme.dart';

/// 빈 화면의 단색 로고 — 연한 갈색 밥그릇+공(작은 크기용 단색 로고).
/// 웹 css/main.css `.empty-mark` 와 같은 모양·진하기. 글자 위에 크게(64), 알림 알약 안에선 작게(22).
class EmptyMark extends StatelessWidget {
  final double size;
  final double opacity;
  const EmptyMark({super.key, this.size = 64, this.opacity = 0.32});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/logo_mono.png',
    width: size,
    color: NurungjiColors.brown.withValues(alpha: opacity),
    colorBlendMode: BlendMode.srcIn,
    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
    excludeFromSemantics: true,
  );
}
