// app_sheet.dart — 공용 모달 바텀시트 표시 헬퍼.
// 웹앱의 "지도 위에 뜨는 팝업/바텀시트" 동작을 네이티브로 재현한다:
// 풀스크린 라우트(Navigator.push)로 화면을 갈아끼우지 않고, 지도가 뒤에 남는
// 모달 시트로 슬라이드업. 상세/필터/공유 시트와 동일한 톤(크림 배경·드래그핸들·
// 상단 라운드 — theme.dart bottomSheetTheme)을 그대로 쓴다.
import 'package:flutter/material.dart';

/// 화면 콘텐츠를 모달 바텀시트로 띄운다.
/// - [child]는 Scaffold/AppBar 없이 시트 본문만 담은 위젯.
/// - 키보드/긴 폼에서도 거의 전체 높이까지 커질 수 있게 isScrollControlled + maxHeight 캡.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget child,
  Color? background, // null이면 테마(크림). 등록폼 등 흰 배경엔 Colors.white 전달.
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: background,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.94,
    ),
    builder: (_) => child,
  );
}

/// 화면 중앙 다이얼로그(웹 .lunchbox-overlay / .profile-overlay 대응).
/// 배경 dim=black54, 둥근 베이지 카드, 내부 스크롤 가능(maxHeight 캡).
/// 바텀시트 대신 중앙 모달로 띄울 때 사용(도시락·프로필).
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required Widget child,
  Color? background,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) {
      final h = MediaQuery.of(ctx).size.height;
      return Dialog(
        backgroundColor: background ?? const Color(0xFFFFF8E1), // 연 베이지
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 380, maxHeight: h * 0.9),
          child: child,
        ),
      );
    },
  );
}

/// 시트 본문 상단 제목 (AppBar를 대체). 좌측 정렬·굵게, 누룽지 다크.
class SheetTitle extends StatelessWidget {
  final String text;
  const SheetTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4E342E), // NurungjiColors.dark
            ),
      ),
    );
  }
}
