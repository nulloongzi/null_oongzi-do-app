// reel_poster.dart — 릴스 '정지 커버' 발견 카드 (웹 renderReelPoster 대응).
//
// 커버(insta_reel_covers, oEmbed thumbnail_url) 있으면: 크롬 없는 라운드+갈색그림자
// 세로 포스터로 표시 → 탭하면 그 자리에서 InstaEmbed(WebView) 인라인 재생.
// 커버 없음 또는 이미지 로드 실패(만료/차단): 기존 제네릭 카드로 폴백(무회귀).
// 지연 로딩: 탭 전엔 플랫폼뷰(WebView)를 안 붙여 스크롤이 매끄러움(자동재생 대신 탭재생).
import 'package:flutter/material.dart';
import '../services/i18n.dart';
import '../theme.dart';
import 'bounce_tap.dart';
import 'insta_embed.dart';

class ReelPoster extends StatefulWidget {
  final String url;
  final String? coverUrl; // 정지 커버(없으면 제네릭 카드)
  const ReelPoster({super.key, required this.url, this.coverUrl});

  @override
  State<ReelPoster> createState() => _ReelPosterState();
}

class _ReelPosterState extends State<ReelPoster> {
  bool _play = false;
  bool _coverFailed = false;

  @override
  Widget build(BuildContext context) {
    if (_play) return InstaEmbed(url: widget.url); // 탭 후에만 실제 임베드
    final cover = widget.coverUrl;
    final showPoster = cover != null && cover.isNotEmpty && !_coverFailed;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: BounceTap(
        onTap: () => setState(() => _play = true),
        child: showPoster ? _poster(cover) : _genericCard(),
      ),
    );
  }

  // 정지 커버 포스터: 라운드 20 + 갈색 그림자(design-system) + 중앙 재생 글리프.
  Widget _poster(String cover) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x265D4037), // 0 8px 32px rgba(93,64,55,.15)
            blurRadius: 32,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFFEFE9DD)), // 로딩 전 배경
              Image.network(
                cover,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  // 커버 실패(만료/차단) → 제네릭 카드로 폴백
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_coverFailed) {
                      setState(() => _coverFailed = true);
                    }
                  });
                  return const SizedBox.shrink();
                },
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const SizedBox.shrink(),
              ),
              // 하단 스크림(재생 글리프 대비)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x4D000000)],
                    stops: [0.64, 1.0],
                  ),
                ),
              ),
              // 중앙 재생 버튼
              Center(
                child: Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0x6B000000),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.92),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 제네릭 카드(커버 없을 때): 아이콘 + '탭하면 재생' 한 줄.
  Widget _genericCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
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
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('insta_reel_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: NurungjiColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t('reel_tap_play'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: NurungjiColors.brown,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.play_circle_outline,
            size: 20,
            color: NurungjiColors.brown,
          ),
        ],
      ),
    );
  }
}
