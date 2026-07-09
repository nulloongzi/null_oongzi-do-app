// share_menu.dart — 통합 공유 바텀시트. 웹 openShareMenu 포팅.
// 헤드라인=인스타 스토리, 그 외 링크복사 / 다른앱(OS 공유시트). 카톡 리치카드는 후속.
import 'dart:io' show Platform;
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import '../services/analytics.dart';
import '../services/i18n.dart';
import '../services/share_service.dart';
import '../theme.dart';

void showShareMenu(
  BuildContext context, {
  required String url,
  required String shareTitle,
  VoidCallback? onStory, // 인스타 스토리 (스토리 카드 렌더 → IG)
}) {
  final u = Uri.tryParse(url);
  final idP = <String, Object?>{
    if (u?.queryParameters['club'] != null) 'club_id': u!.queryParameters['club'],
    if (u?.queryParameters['spot'] != null) 'spot_id': u!.queryParameters['spot'],
  };
  showDialog(
    context: context,
    barrierColor: const Color(0x4D5D4037), // 따뜻한 갈색 딤
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(t('share_title'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: NurungjiColors.dark)),
            ),
            if (onStory != null)
              _menuButton(
                label: t('share_story'),
                hint: t('share_story_hint'),
                primary: true,
                onTap: () {
                  Navigator.pop(ctx);
                  Track.event('share', {'method': 'ig_story', ...idP});
                  onStory();
                },
              ),
            _menuButton(
              label: t('share_kakao'),
              onTap: () async {
                Navigator.pop(ctx);
                Track.event('share', {'method': 'kakao', ...idP});
                // 콘솔/SDK 없이 카톡 직접 공유(텍스트+링크, 채팅 픽커로).
                // 미설치·비안드로이드는 OS 공유시트 폴백 — 웹 카톡 공유의
                // 폴백 체인(카드→OS시트→복사)과 같은 결말. 리치카드는
                // 네이티브 앱 키+플랫폼 등록 후 kakao_flutter_sdk로 업그레이드.
                var sent = false;
                if (Platform.isAndroid) {
                  try {
                    await AndroidIntent(
                      action: 'android.intent.action.SEND',
                      type: 'text/plain',
                      package: 'com.kakao.talk',
                      arguments: {
                        'android.intent.extra.TEXT': '$shareTitle\n$url'
                      },
                    ).launch();
                    sent = true;
                  } catch (_) {}
                }
                if (!sent) {
                  try {
                    await ShareService.osShare('$shareTitle\n$url');
                  } catch (_) {}
                }
              },
            ),
            _menuButton(
              label: t('share_copy'),
              onTap: () async {
                Navigator.pop(ctx);
                Track.event('share', {'method': 'copy', ...idP});
                await ShareService.copy(url);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t('link_copied'))),
                  );
                }
              },
            ),
            _menuButton(
              label: t('share_more'),
              onTap: () async {
                Navigator.pop(ctx);
                Track.event('share', {'method': 'web', ...idP});
                try {
                  await ShareService.osShare('$shareTitle\n$url');
                } catch (_) {}
              },
            ),
            const SizedBox(height: 2),
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
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
