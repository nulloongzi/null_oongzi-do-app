// share_menu.dart — 통합 공유 바텀시트. 웹 openShareMenu 포팅.
// 헤드라인=인스타 스토리, 그 외 링크복사 / 다른앱(OS 공유시트). 카톡 리치카드는 후속.
import 'package:flutter/material.dart';
import '../services/share_service.dart';
import '../theme.dart';

void showShareMenu(
  BuildContext context, {
  required String url,
  required String shareTitle,
  VoidCallback? onStory, // 인스타 스토리 (스토리 카드 렌더 → IG)
}) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6, top: 2),
              child: Text('공유하기',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: NurungjiColors.dark)),
            ),
            if (onStory != null)
              _menuButton(
                label: '📸 인스타 스토리',
                hint: '링크 자동 복사 — 보는 사람은 탭 1번에 입장',
                primary: true,
                onTap: () {
                  Navigator.pop(ctx);
                  onStory();
                },
              ),
            _menuButton(
              label: '🔗 링크 복사',
              onTap: () async {
                Navigator.pop(ctx);
                await ShareService.copy(url);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('링크가 복사됐어요')),
                  );
                }
              },
            ),
            _menuButton(
              label: '📤 다른 앱으로 공유',
              onTap: () async {
                Navigator.pop(ctx);
                await ShareService.osShare('$shareTitle\n$url');
              },
            ),
            const SizedBox(height: 2),
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ],
        ),
      ),
    ),
  );
}

Widget _menuButton({
  required String label,
  String? hint,
  bool primary = false,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Material(
      color: primary ? NurungjiColors.yellow : NurungjiColors.chipBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight:
                          primary ? FontWeight.w800 : FontWeight.w700,
                      color: NurungjiColors.dark,
                      fontSize: 15)),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(hint,
                      style: const TextStyle(
                          fontSize: 12, color: NurungjiColors.brown)),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
