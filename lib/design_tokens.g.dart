// design_tokens.g.dart — 생성 파일. 직접 고치지 말 것.
// 원본: 웹 저장소 nulloongzi/null_oongzi-do 의 tokens/design-tokens.json
// 다시 만들기(웹 저장소에서):
//   npm run tokens -- --dart ../null_oongzi-do-app/lib/design_tokens.g.dart
// 규칙과 쓰임: 웹 docs/design-system.md · CI: .github/workflows/design-tokens.yml
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// 누룽지 색 — 웹 css/main.css :root 와 같은 값.
class NurungjiColors {
  static const yellow = Color(0xFFFAC710); // --nurungji-yellow
  static const brown = Color(0xFF84675D); // --nurungji-brown
  static const dark = Color(0xFF4E342E); // --nurungji-dark
  static const bg = Color(0xFFFFF8E1); // --nurungji-bg
  static const light = Color(0xFFFFFDE7); // --nurungji-light
  static const urgent = Color(0xFFFF7043); // --urgent-color
  static const urgentInk = Color(0xFFBF360C); // --urgent-ink
  static const today = Color(0xFFCF4014); // --today-color
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

/// 모션 — 웹 --motion-* · --ease-* 와 같은 값(docs/motion-spec.md).
class NurungjiMotion {
  // --motion-sheet-enter: 상세 시트(비모달)가 올라오기 · 손을 놓았을 때 접힘/펼침으로 붙기
  static const sheetEnter = Duration(milliseconds: 300);
  // --motion-sheet-exit: 상세 시트가 내려가며 닫히기
  static const sheetExit = Duration(milliseconds: 250);
  // --motion-modal-enter: 모달 바텀시트 올라오기(Flutter 기본과 같은 값)
  static const modalEnter = Duration(milliseconds: 250);
  // --motion-modal-exit: 모달 바텀시트 내려가기(Flutter 기본과 같은 값)
  static const modalExit = Duration(milliseconds: 200);
  // --ease-sheet: 감속 — 상세 시트 올라오기·붙기
  static const sheetCurve = Cubic(0.2, 0.8, 0.2, 1.0);
  // --ease-sheet-exit: 가속 — 상세 시트 닫기(점점 빨라지며 화면 밖으로)
  static const sheetExitCurve = Cubic(0.4, 0.0, 1.0, 1.0);
  // --ease-modal: 모달 시트 열고 닫기(Flutter Easing.legacyDecelerate)
  static const modalCurve = Cubic(0.0, 0.0, 0.2, 1.0);
}
