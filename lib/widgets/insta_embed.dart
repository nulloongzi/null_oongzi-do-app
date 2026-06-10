// insta_embed.dart — 공개 인스타 릴스/게시물을 상세 안에 '인라인 임베드'(플라이휠 차별점).
// 방식: 인스타 공식 '/embed/' 페이지를 WebView로 직접 로드(인스타 origin이라 안정적 렌더).
//   기존 loadHtmlString(blockquote+embed.js)은 about:blank origin이라 cross-origin 처리에서
//   자주 실패/오류 → permalink + 'embed/' 직접 로드로 교체.
// 실패(네트워크/차단) 시에만 '탭하면 인스타에서 보기' 카드로 폴백(깨진 오류화면 방지).
// URL은 Sanitize.instaPostUrl로 화이트리스트 검증 후에만 사용(XSS/lookalike 차단).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/i18n.dart';
import '../services/sanitize.dart';
import '../theme.dart';
import 'bounce_tap.dart';

class InstaEmbed extends StatefulWidget {
  final String url;
  const InstaEmbed({super.key, required this.url});

  @override
  State<InstaEmbed> createState() => _InstaEmbedState();
}

class _InstaEmbedState extends State<InstaEmbed> {
  WebViewController? _ctrl;
  String _safe = '';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _safe = Sanitize.instaPostUrl(widget.url); // .../reel/<code>/ (끝 슬래시)
    if (_safe.isEmpty) return;
    final embedUrl = '${_safe}embed/';
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (e) {
          if (mounted && e.isForMainFrame == true) {
            setState(() => _failed = true);
          }
        },
        // 임베드 안에서 게시물/프로필 탭 → 인스타 앱/브라우저로(WebView 내 이탈 방지)
        onNavigationRequest: (req) {
          if (req.isMainFrame && !req.url.contains('/embed')) {
            final u = Uri.tryParse(req.url);
            if (u != null) {
              launchUrl(u, mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(embedUrl));
  }

  @override
  Widget build(BuildContext context) {
    if (_safe.isEmpty) return const SizedBox.shrink();
    if (_failed || _ctrl == null) return _fallbackCard();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 600, // 릴스(세로) 임베드 — 기기에서 보고 조정 가능
          color: Colors.white,
          child: WebViewWidget(controller: _ctrl!),
        ),
      ),
    );
  }

  // 임베드 실패 시 폴백: 탭하면 인스타에서 보기 카드.
  Widget _fallbackCard() => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: BounceTap(
          onTap: () async {
            final u = Uri.tryParse(_safe);
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
