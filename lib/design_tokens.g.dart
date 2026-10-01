// design_tokens.g.dart — 생성 파일. 직접 고치지 말 것.
// 원본: 웹 저장소 nulloongzi/null_oongzi-do 의 tokens/design-tokens.json
// 다시 만들기(웹 저장소에서):
//   npm run tokens -- --dart ../null_oongzi-do-app/lib/design_tokens.g.dart
// 규칙과 쓰임: 웹 docs/design-system.md · CI: .github/workflows/design-tokens.yml
import 'package:flutter/painting.dart';

/// 누룽지 색 — 웹 css/main.css :root 와 같은 값.
class NurungjiColors {
  static const yellow = Color(0xFFFAC710); // --nurungji-yellow
  static const brown = Color(0xFF8D6E63); // --nurungji-brown
  static const dark = Color(0xFF4E342E); // --nurungji-dark
  static const bg = Color(0xFFFFF8E1); // --nurungji-bg
  static const light = Color(0xFFFFFDE7); // --nurungji-light
  static const urgent = Color(0xFFFF7043); // --urgent-color
  static const urgentInk = Color(0xFFBF360C); // --urgent-ink
  static const today = Color(0xFFD84315); // --today-color
  static const error = Color(0xFFD32F2F); // --error-color
  static const chipBg = Color(0xFFF0ECE2); // --chip-bg
  static const chipFg = Color(0xFF6D6258); // --chip-fg
  static const teal = Color(0xFF13A89E); // --pickup-teal
  static const handle = Color(0xFFD8CFC6); // --handle-color
  static const glass = Color(0xD9FFFFFF); // --glass-bg
  static const glassCream = Color(0xD9FFF8E1); // --glass-bg-darker
  static const dim = Color(0x595D4037); // --dim
  static const shadow = Color(0x265D4037); // --shadow 색
  static const shadowSm = Color(0x1F5D4037); // --shadow-sm 색
}

/// 그림자 — 갈색만(검정 금지).
class NurungjiShadows {
  // --shadow: 기본 그림자(갈색 — 검정 금지)
  static const md = BoxShadow(
    color: NurungjiColors.shadow,
    blurRadius: 32,
    offset: Offset(0, 8),
  );
  // --shadow-sm: 알약·작은 요소
  static const sm = BoxShadow(
    color: NurungjiColors.shadowSm,
    blurRadius: 12,
    offset: Offset(0, 4),
  );
}

/// 모서리 — 웹 --radius-* 와 같은 값.
class NurungjiRadius {
  static const sheet = 28.0; // --radius-sheet · 카드/바텀시트
  static const button = 14.0; // --radius-button · 버튼
  static const input = 12.0; // --radius-input · 입력창
  static const dialog = 20.0; // --radius-dialog · 가운데 팝업(공유·등록·신고)
  static const toast = 12.0; // --radius-toast · 토스트(웹 showToast · 앱 SnackBar)
  static const fab = 20.0; // --radius-fab · 지도 위 버튼 50px
  static const fabProfile = 24.0; // --radius-fab-profile · 🍚 버튼 55px
}
