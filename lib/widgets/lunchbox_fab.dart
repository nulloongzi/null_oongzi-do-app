import 'package:flutter/material.dart';

import '../screens/lunchbox_sheet.dart';
import '../theme/app_theme.dart';

/// 🍱 도시락 FAB. WebView 위에 오버레이되어 네이티브 도시락 시트를 연다.
/// 웹 .fab-lunchbox(좌하단)와 같은 위치.
class LunchboxFab extends StatelessWidget {
  const LunchboxFab({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showLunchboxSheet(context),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.light,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x335D4037),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text('🍱', style: TextStyle(fontSize: 26)),
      ),
    );
  }
}
