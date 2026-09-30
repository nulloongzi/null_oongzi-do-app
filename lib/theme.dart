// theme.dart — 웹앱(css/main.css :root)의 누룽지 디자인 토큰을 Flutter로 재현.
// CSS를 직접 못 쓰므로 색·모양·폰트를 동일하게 맞춰 통일성 확보.
// 폰트: Pretendard(가변, assets/fonts) — 웹앱과 동일 타이포. pubspec fonts에 등록.
import 'package:flutter/material.dart';
import 'design_tokens.g.dart';

// 색·그림자·모서리 토큰은 생성 파일에 있다(웹 tokens/design-tokens.json 이 원본).
// 값을 바꾸려면 그 JSON 을 고치고 다시 만든다 — design_tokens.g.dart 머리말 참고.
export 'design_tokens.g.dart';

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
            borderRadius: BorderRadius.circular(NurungjiRadius.button),
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
            borderRadius: BorderRadius.circular(NurungjiRadius.button),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NurungjiRadius.input),
          borderSide: const BorderSide(color: Color(0x22000000)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NurungjiRadius.input),
          borderSide: const BorderSide(color: NurungjiColors.yellow, width: 2),
        ),
      ),
    );
  }
}
