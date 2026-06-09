// insta_embed.dart — 공개 인스타 릴스/게시물을 '네이티브 카드'로 제공.
// 기존: WebView로 instagram embed.js 로드 → 네이티브에서 자주 로그인벽/차단으로 오류.
// 변경: 가벼운 카드(인스타 그라데이션 + 재생) → 탭하면 인스타 앱/브라우저에서 자연 재생.
// URL은 Sanitize.instaPostUrl로 화이트리스트 검증 후에만 사용.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/i18n.dart';
import '../services/sanitize.dart';
import '../theme.dart';
import 'bounce_tap.dart';

class InstaEmbed extends StatelessWidget {
  final String url;
  const InstaEmbed({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final safe = Sanitize.instaPostUrl(url);
    if (safe.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: BounceTap(
        onTap: () async {
          final u = Uri.tryParse(safe);
          if (u == null) return;
          try {
            await launchUrl(u, mode: LaunchMode.externalApplication);
          } catch (_) {}
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x1A000000)),
          ),
          child: Row(children: [
            // 인스타 그라데이션 + 재생 아이콘
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    Color(0xFFFEDA75),
                    Color(0xFFFA7E1E),
                    Color(0xFFD62976),
                    Color(0xFF962FBF),
                    Color(0xFF4F5BD5),
                  ],
                ),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('insta_reel_title'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: NurungjiColors.dark)),
                  const SizedBox(height: 2),
                  Text(t('insta_reel_open'),
                      style: const TextStyle(
                          fontSize: 12, color: NurungjiColors.brown)),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded,
                size: 18, color: NurungjiColors.brown),
          ]),
        ),
      ),
    );
  }
}
