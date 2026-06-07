// theme.dart — 웹앱(css/main.css :root)의 누룽지 디자인 토큰을 Flutter로 재현.
// CSS를 직접 못 쓰므로 색·모양·폰트를 동일하게 맞춰 통일성 확보.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NurungjiColors {
  static const yellow = Color(0xFFFAC710); // --nurungji-yellow
  static const dark = Color(0xFF4E342E); // --nurungji-dark
  static const brown = Color(0xFF8D6E63); // --nurungji-brown
  static const bg = Color(0xFFFFF8E1); // --nurungji-bg
  static const light = Color(0xFFFFFDE7); // --nurungji-light
  static const chipBg = Color(0xFFF0ECE2);
  static const chipFg = Color(0xFF6D6258);
  static const teal = Color(0xFF13A89E); // 픽업 핀 색
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: NurungjiColors.yellow,
      brightness: Brightness.light,
    ).copyWith(primary: NurungjiColors.yellow, surface: Colors.white);

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: NurungjiColors.bg,
      // 폰트: Noto Sans KR (google_fonts) — 누룽지 따뜻한 톤. 런타임 페치+캐시.
      textTheme: GoogleFonts.notoSansKrTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: NurungjiColors.yellow,
        foregroundColor: NurungjiColors.dark,
        elevation: 0,
        centerTitle: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NurungjiColors.light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NurungjiColors.yellow,
          foregroundColor: NurungjiColors.dark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NurungjiColors.dark,
          side: const BorderSide(color: NurungjiColors.brown),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0x22000000))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: NurungjiColors.yellow, width: 2)),
      ),
    );
  }
}
