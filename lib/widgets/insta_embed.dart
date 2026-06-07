// insta_embed.dart — 공개 인스타 게시물/릴스 임베드. 웹 insta-embed.js 포팅.
// webview_flutter로 공식 blockquote + embed.js를 로드. 차단/실패 시 'View on Instagram' 링크 폴백.
// URL은 Sanitize.instaPostUrl로 화이트리스트 검증 후에만 삽입(XSS 방지).
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/sanitize.dart';

class InstaEmbed extends StatefulWidget {
  final String url;
  const InstaEmbed({super.key, required this.url});

  @override
  State<InstaEmbed> createState() => _InstaEmbedState();
}

class _InstaEmbedState extends State<InstaEmbed> {
  WebViewController? _ctrl;

  @override
  void initState() {
    super.initState();
    final safe = Sanitize.instaPostUrl(widget.url);
    if (safe.isEmpty) return;
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadHtmlString(_html(safe));
  }

  String _html(String safe) {
    return '''<!DOCTYPE html>
<html><head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<style>body{margin:0;padding:0;background:transparent;}</style>
</head><body>
<blockquote class="instagram-media" data-instgrm-permalink="$safe" data-instgrm-version="14" style="margin:0 auto;max-width:100%;border:0;">
<a href="$safe" target="_blank" rel="noopener noreferrer">View on Instagram</a>
</blockquote>
<script async src="https://www.instagram.com/embed.js"></script>
</body></html>''';
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      height: 580,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
      child: WebViewWidget(controller: _ctrl!),
    );
  }
}
