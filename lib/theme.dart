// theme.dart — 웹앱(css/main.css :root)의 누룽지 디자인 토큰을 Flutter로 재현.
// CSS를 직접 못 쓰므로 색·모양·폰트를 동일하게 맞춰 통일성 확보.
// 폰트: Pretendard(가변, assets/fonts) — 웹앱과 동일 타이포. pubspec fonts에 등록.
import 'package:flutter/material.dart';
import 'design_tokens.g.dart';

// 색·그림자·모서리 토큰은 생성 파일에 있다(웹 tokens/design-tokens.json 이 원본).
// 값을 바꾸려면 그 JSON 을 고치고 다시 만든다 — design_tokens.g.dart 머리말 참고.
export 'design_tokens.g.dart';

/// 입력 칸 아래 오류 글자 — 웹 .field-error(13px/600, --error-color)와 같은 값.
const fieldErrorStyle = TextStyle(
  fontFamily: 'Pretendard',
  color: NurungjiColors.error,
  fontSize: 13,
  fontWeight: FontWeight.w600,
  height: 1.4,
);

class AppTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: NurungjiColors.yellow,
          brightness: Brightness.light,
        ).copyWith(
          primary: NurungjiColors.yellow,
          surface: Colors.white,
          error: NurungjiColors.error,
        );

    // fontFamily: Pretendard → 전 textTheme에 적용. 가변폰트라 각 스타일의
    // fontWeight가 wght 축으로 매핑됨(w400~w900).
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Pretendard',
    );

    return base.copyWith(
      scaffoldBackgroundColor: NurungjiColors.bg,
      // 화면 머리: 진한 옐로 띠 대신 크림 바탕 + 다크 글자(웹 시트·팝업 머리처럼). 옐로는 누르는 것에만 아낀다.
      appBarTheme: const AppBarTheme(
        backgroundColor: NurungjiColors.bg,
        foregroundColor: NurungjiColors.dark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          color: NurungjiColors.dark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      // 칩: 웹 .chip 과 같은 모양 — 반투명 흰 알약 + 옅은 갈색 테두리, 고르면 옐로 + 굵은 글자.
      // Material 기본(진한 옐로 컨테이너 + 체크 표시)은 쓰지 않는다.
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? NurungjiColors.yellow
              : s.contains(WidgetState.disabled)
              ? NurungjiColors.chipBg
              : const Color(0xCCFFFFFF),
        ),
        side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.selected)
                ? NurungjiColors.yellow
                : const Color(0x4D8D6E63),
          ),
        ),
        shape: const StadiumBorder(),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
        surfaceTintColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        // 글자: 웹 .chip(14/600 · #5d4037). 상태별 굵기는 주지 않는다 — WidgetStateTextStyle 은
        // 칩 기본 스타일과 합쳐지며 글꼴이 빠진다.
        labelStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: NurungjiColors.dark,
        ),
      ),
      // 켜고 끄기: 웹 .fr-switch 와 같은 값 — 켜면 브라운 길, 끄면 베이지 길, 손잡이는 늘 흰색.
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? NurungjiColors.brown
              : const Color(0xFFD8CBB6),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      // 체크 상자: 웹 accent-color(옐로) — 체크 표시는 다크.
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? NurungjiColors.yellow
              : Colors.white,
        ),
        checkColor: const WidgetStatePropertyAll(NurungjiColors.dark),
        side: const BorderSide(color: NurungjiColors.brown, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      // 도는 표시: 크림 바탕에서 옐로는 안 보여서 브라운.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NurungjiColors.brown,
        linearTrackColor: NurungjiColors.chipBg,
        circularTrackColor: Colors.transparent,
      ),
      // 탭: 고른 탭은 다크 + 옐로 밑줄, 나머지는 브라운.
      tabBarTheme: const TabBarThemeData(
        labelColor: NurungjiColors.dark,
        unselectedLabelColor: NurungjiColors.brown,
        indicatorColor: NurungjiColors.yellow,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      // 메뉴(⋯ 누르면 나오는 목록): 흰 카드, 모서리 둥글게, 따뜻한 그림자.
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: NurungjiColors.shadow,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NurungjiRadius.input),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Pretendard',
          color: NurungjiColors.dark,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      // 카드: 흰 바탕 + 따뜻한 옅은 그림자(검정·보라 틴트 없이).
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: NurungjiColors.shadowSm,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NurungjiRadius.button),
        ),
      ),
      // 접고 펴는 줄: 펼쳐도 위아래 선이 생기지 않게, 화살표는 브라운.
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
        iconColor: NurungjiColors.dark,
        collapsedIconColor: NurungjiColors.brown,
        textColor: NurungjiColors.dark,
        collapsedTextColor: NurungjiColors.dark,
      ),
      // 펼침 목록(드롭다운): 흰 카드 + 둥근 모서리.
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(NurungjiColors.shadow),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NurungjiRadius.input),
            ),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x143D2C22),
        thickness: 1,
        space: 1,
      ),
      // 말풍선 도움말: 토스트와 같은 다크 브라운 + 크림 글자.
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: NurungjiColors.dark,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Pretendard',
          color: NurungjiColors.bg,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      // 날짜 고르기: 흰 카드 + 크림 머리, 고른 날은 옐로 원 + 다크 글자, 오늘은 브라운 테두리.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: NurungjiColors.bg,
        headerForegroundColor: NurungjiColors.dark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NurungjiRadius.dialog),
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? NurungjiColors.handle
              : NurungjiColors.dark,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? NurungjiColors.yellow
              : Colors.transparent,
        ),
        todayForegroundColor: const WidgetStatePropertyAll(NurungjiColors.dark),
        todayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? NurungjiColors.yellow
              : Colors.transparent,
        ),
        todayBorder: const BorderSide(color: NurungjiColors.brown),
        yearForegroundColor: const WidgetStatePropertyAll(NurungjiColors.dark),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? NurungjiColors.yellow
              : Colors.transparent,
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: NurungjiColors.brown,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: NurungjiColors.dark,
        ),
      ),
      // 시간 고르기: 같은 톤 — 고른 칸·바늘은 옐로, 글자는 다크.
      timePickerTheme: TimePickerThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NurungjiRadius.dialog),
        ),
        dialBackgroundColor: NurungjiColors.bg,
        dialHandColor: NurungjiColors.yellow,
        dialTextColor: NurungjiColors.dark,
        hourMinuteColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? NurungjiColors.yellow
              : NurungjiColors.bg,
        ),
        hourMinuteTextColor: NurungjiColors.dark,
        dayPeriodColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? NurungjiColors.yellow
              : Colors.transparent,
        ),
        dayPeriodTextColor: NurungjiColors.dark,
        dayPeriodBorderSide: const BorderSide(color: NurungjiColors.handle),
        entryModeIconColor: NurungjiColors.brown,
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: NurungjiColors.brown,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: NurungjiColors.dark,
        ),
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
      // 팝업(AlertDialog): 웹 js/dialog.js(.nz-dialog)와 같은 모양 — 흰 바탕, 모서리 dialog(20), 17/800 제목
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(NurungjiRadius.dialog),
          ),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          color: NurungjiColors.dark,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          height: 1.4,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          color: NurungjiColors.dark,
          fontSize: 14,
          height: 1.55,
        ),
      ),
      // 글자 버튼: 기본값(primary = 옐로)은 흰 바탕에서 1.6:1 이라 안 읽힌다 → 다크
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NurungjiColors.dark,
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      // 토스트(SnackBar): 웹 js/toast.js(.nz-toast)와 같은 모양 — 다크 브라운 + 크림 글자, 떠 있는 카드.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: NurungjiColors.dark,
        contentTextStyle: const TextStyle(
          fontFamily: 'Pretendard',
          color: NurungjiColors.bg,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
        actionTextColor: NurungjiColors.yellow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NurungjiRadius.toast),
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
        // 입력 오류: 빨간 테두리 + 칸 아래 이유 한 줄(웹 .field-invalid · .field-error 와 같은 색·크기)
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NurungjiRadius.input),
          borderSide: const BorderSide(color: NurungjiColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NurungjiRadius.input),
          borderSide: const BorderSide(color: NurungjiColors.error, width: 2),
        ),
        errorStyle: fieldErrorStyle,
        errorMaxLines: 3,
      ),
    );
  }
}
