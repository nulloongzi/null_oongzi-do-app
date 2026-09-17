// reel_card.dart — 릴스 발견 카드: 정지 커버(우리 Storage 캐시) → 탭 한 번 → 인스타.
//
// 왜 임베드가 아니라 커버인가 (2026-09-16 결정, 웹 레포 docs/OPEN-QUESTIONS.md):
// 인스타 공식 /embed/ 는 로그아웃 상태에서 인라인 재생이 안 된다 — 포스터 + "Instagram에서 보기"만
// 보여주고 결국 인스타로 넘긴다. 그러면 시트 안에 남의 크롬(프로필 보기·♡·댓글 달기·좋아요 수)이
// 통째로 들어오면서 얻는 게 없고, 스크롤 경로에 WebView(플랫폼뷰)만 남는다.
// 커버 한 장 + 한 번 탭이 같은 결과를 더 깨끗하게 낸다. WebView 는 쓰지 않는다.
//
// 커버는 Cloud Function(insta-cover.js)이 문서의 insta_reel_covers(code→URL)에 채운다.
// 없거나 로드 실패면 제네릭 카드(그라데이션 + ▶). 둘 다 탭 → 인스타. 웹 insta-embed.js 와 동일.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/analytics.dart';
import '../services/i18n.dart';
import '../services/sanitize.dart';
import '../theme.dart';
import 'bounce_tap.dart';

const _instaGradient = LinearGradient(
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
  colors: [
    Color(0xFFFEDA75),
    Color(0xFFFA7E1E),
    Color(0xFFD62976),
    Color(0xFF962FBF),
    Color(0xFF4F5BD5),
  ],
);

Future<void> _launch(String url) async {
  final u = Uri.tryParse(url);
  if (u == null) return;
  try {
    await launchUrl(u, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class ReelCard extends StatelessWidget {
  final String url;
  final String? cover; // 없으면 제네릭 카드
  // reel_play 계측용: 어느 팀/스팟(source: club|pickup|peek)의 몇 번째 릴스인지.
  final String source;
  final String id;
  final int index;
  // 테스트 주입용. 기본은 url_launcher 로 인스타 앱/브라우저.
  final Future<void> Function(String url) openUrl;

  const ReelCard({
    super.key,
    required this.url,
    this.cover,
    required this.source,
    required this.id,
    this.index = 0,
    this.openUrl = _launch,
  });

  // 화이트리스트 통과한 정규 permalink 만 연다(쿼리·유저네임 프리픽스 제거). 무효면 ''.
  String get _safeUrl => Sanitize.instaPostUrl(url);

  void _tap(String poster) {
    // 릴스 탭 = reel_play(이제 "인스타로 나간 횟수"). view_*/…_contact 의 has_reel 과
    // 묶어 "릴스가 물꼬에 도움이 되는가"를 본다.
    Track.event('reel_play', {
      'source': source,
      'id': id,
      'index': index,
      'poster': poster,
    });
    openUrl(_safeUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (_safeUrl.isEmpty) return const SizedBox.shrink();
    final c = cover;
    if (c == null || c.isEmpty) return _generic();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Center(
        child: BounceTap(
          onTap: () => _tap('cover'),
          child: ConstrainedBox(
            // 9:16 세로 카드. 높이 상한으로 시트 리듬 유지(웹과 동일: min(480, 60vh)).
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height * 0.6).clamp(
                240.0,
                480.0,
              ),
            ),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFE9DD),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x265D4037),
                      blurRadius: 32,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      c,
                      fit: BoxFit.cover,
                      // 커버 로드 실패(만료/차단) → 제네릭 카드 본문으로 폴백.
                      errorBuilder: (_, _, _) => _genericBody(),
                    ),
                    // 하단 스크림(▶·필 대비)
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.55, 1.0],
                          colors: [Color(0x00000000), Color(0x73000000)],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x6B000000),
                          border: Border.all(
                            color: const Color(0xEBFFFFFF),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xEBFFFFFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${t('insta_view')} ↗',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: NurungjiColors.dark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 제네릭 카드(커버 없음): 아이콘 + '탭하면 인스타그램에서 봐요' 한 줄.
  Widget _generic() => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: BounceTap(
      onTap: () => _tap('generic'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x1A000000)),
        ),
        child: _genericBody(),
      ),
    ),
  );

  Widget _genericBody() => Row(
    children: [
      Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: _instaGradient,
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
          mainAxisSize: MainAxisSize.min,
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
              t('insta_reel_open'),
              style: const TextStyle(fontSize: 12, color: NurungjiColors.brown),
            ),
          ],
        ),
      ),
      const Icon(Icons.open_in_new, size: 20, color: NurungjiColors.brown),
    ],
  );
}
