// theme.dart — 웹앱(css/main.css :root)의 누룽지 디자인 토큰을 Flutter로 재현.
// CSS를 직접 못 쓰므로 색·모양·폰트를 동일하게 맞춰 통일성 확보.
// 폰트: Pretendard(가변, assets/fonts) — 웹앱과 동일 타이포. pubspec fonts에 등록.
import 'package:flutter/material.dart';

class NurungjiColors {
  static const yellow = Color(0xFFFAC710); // --nurungji-yellow
  static const dark = Color(0xFF4E342E); // --nurungji-dark
  static const brown = Color(0xFF8D6E63); // --nurungji-brown
  static const bg = Color(0xFFFFF8E1); // --nurungji-bg
  static const light = Color(0xFFFFFDE7); // --nurungji-light
  static const chipBg = Color(0xFFF0ECE2);
  static const chipFg = Color(0xFF6D6258);
  static const teal = Color(0xFF13A89E); // 픽업 핀 색
  static const urgent = Color(0xFFFF7043); // --urgent-color (급구/주의)
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: NurungjiColors.yellow,
      brightness: Brightness.light,
    ).copyWith(primary: NurungjiColors.yellow, surface: Colors.white);

    // fontFamily: Pretendard → 전 textTheme에 적용. 가변폰트라 각 스타일의
    // fontWeight가 wght 축으로 매핑됨(w400~w900).
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Pretendard',
    );

    return base.copyWith(
      scaffoldBackgroundColor: NurungjiColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: NurungjiColors.yellow,
        foregroundColor: NurungjiColors.dark,
        elevation: 0,
        centerTitle: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NurungjiColors.light,
        modalBackgroundColor: NurungjiColors.light,
        // 웹 오버레이(rgba(93,64,55,.35))처럼 검정이 아닌 따뜻한 갈색 딤.
        modalBarrierColor: Color(0x4D5D4037),
        // 드래그 핸들: 웹 .sheet-handle(#d8cfc6, 44x5)과 동일 톤.
        showDragHandle: true,
        dragHandleColor: Color(0xFFD8CFC6),
        dragHandleSize: Size(44, 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NurungjiColors.yellow,
          foregroundColor: NurungjiColors.dark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NurungjiColors.dark,
          side: const BorderSide(color: NurungjiColors.brown),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x22000000)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NurungjiColors.yellow, width: 2),
        ),
      ),
    );
  }
}
