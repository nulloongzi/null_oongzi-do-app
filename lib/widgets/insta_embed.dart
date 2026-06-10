// insta_embed.dart — 공개 인스타 릴스/게시물을 상세 안에 '인라인 임베드'(플라이휠 차별점).
// 인스타 공식 '/embed/' 페이지를 WebView로 직접 로드(인스타 origin → 안정적, 탭하면 인라인 재생).
// 높이는 페이지 scrollHeight를 JS 채널로 받아 자동 맞춤(빈 공간/잘림 없이 세로 릴스형).
// 실패 시에만 '탭→인스타' 카드로 폴백. URL은 Sanitize.instaPostUrl로 검증.
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
  double _height = 640; // 측정 전 기본(세로 릴스 가정). JS가 실제 높이로 갱신.

  @override
  void initState() {
    super.initState();
    _safe = Sanitize.instaPostUrl(widget.url); // .../reel/<code>/
    if (_safe.isEmpty) return;
    final embedUrl = '${_safe}embed/';
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      // 임베드 페이지 높이를 받아 컨테이너에 맞춤(빈 공간/잘림 제거)
      ..addJavaScriptChannel('NurungjiResize', onMessageReceived: (m) {
        final h = double.tryParse(m.message);
        if (h != null && h > 80 && mounted) {
          setState(() => _height = h.clamp(220.0, 1000.0).toDouble());
        }
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _ctrl?.runJavaScript(
            "(function(){function p(){try{NurungjiResize.postMessage(String(document.body.scrollHeight));}catch(e){}}"
            "p();setTimeout(p,500);setTimeout(p,1500);setTimeout(p,3000);"
            "window.addEventListener('resize',p);})();",
          );
        },
        onWebResourceError: (e) {
          if (mounted && e.isForMainFrame == true) {
            setState(() => _failed = true);
          }
        },
        // 임베드 안에서 게시물/프로필 등 '링크' 탭 → 인스타 앱/브라우저로(영상 재생은 인라인 유지).
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
          height: _height,
          width: double.infinity,
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
