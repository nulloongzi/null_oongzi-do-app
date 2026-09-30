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
  static const today = Color(0xFFD84315); // --today-color ("오늘" 강조)
  static const handle = Color(0xFFD8CFC6); // --handle-color (시트 드래그 핸들)
  static const dim = Color(0x595D4037); // --dim rgba(93,64,55,.35) (모달 딤)
  // 그림자는 갈색만(검정 금지) — 웹 --shadow 계열과 같은 색. 알파만 바꿔 쓴다.
  static const shadow = Color(0x265D4037); // --shadow rgba(93,64,55,.15)
  static const shadowSm = Color(0x1F5D4037); // --shadow-sm rgba(93,64,55,.12)
}

/// 모양 토큰 — 웹 css/main.css :root 와 같은 값 (docs/design-system.md §3).
class NurungjiRadius {
  static const sheet = 28.0; // --radius-sheet (카드/시트)
  static const button = 14.0;
  static const fab = 20.0; // 웹 .fab-btn (50px 버튼의 모서리)
  static const fabProfile = 24.0; // 웹 .fab-profile (55px)
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
        // 웹 오버레이(--dim rgba(93,64,55,.35))처럼 검정이 아닌 따뜻한 갈색 딤.
        modalBarrierColor: NurungjiColors.dim,
        // 드래그 핸들: 웹 .sheet-handle(--handle-color, 44x5)과 같은 값.
        showDragHandle: true,
        dragHandleColor: NurungjiColors.handle,
        dragHandleSize: Size(44, 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NurungjiRadius.sheet),
          ),
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
          // ButtonStyle 의 textStyle 은 상속이 아니라 대체라 패밀리를 다시 준다.
          // 안 주면 이 버튼만 기본 폰트(Roboto)로 떨어져 나머지와 글꼴이 달라진다.
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
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
