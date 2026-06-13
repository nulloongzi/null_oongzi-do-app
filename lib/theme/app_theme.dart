import 'package:flutter/material.dart';

/// 누룽지(Nurungji) 브랜드 색상 — 웹 css/main.css :root 변수와 동일.
class AppColors {
  static const Color yellow = Color(0xFFFAC710); // --nurungji-yellow
  static const Color brown = Color(0xFF8D6E63); // --nurungji-brown
  static const Color dark = Color(0xFF4E342E); // --nurungji-dark (본문 텍스트)
  static const Color bg = Color(0xFFFFF8E1); // --nurungji-bg (크림 배경)
  static const Color light = Color(0xFFFFFDE7); // --nurungji-light
  static const Color urgent = Color(0xFFFF7043); // --urgent-color (편집/긴급)
  static const Color today = Color(0xFFD84315); // --today-color

  // 도시락 슬롯별 배경/테두리 색 (lunchbox.js slotColors/borderColors)
  static const List<Color> slotColors = [
    Color(0xFFFFFDE7),
    Color(0xFFFFF3E0),
    Color(0xFFF1F8E9),
    Color(0xFFFBE9E7),
    Color(0xFFF3E5F5),
  ];
  static const List<Color> slotBorderColors = [
    Color(0xFFFBC02D),
    Color(0xFFF57C00),
    Color(0xFF689F38),
    Color(0xFFD84315),
    Color(0xFF8E24AA),
  ];
}

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.yellow),
    scaffoldBackgroundColor: AppColors.bg,
    useMaterial3: true,
  );
}
