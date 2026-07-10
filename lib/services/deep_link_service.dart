// deep_link_service.dart — 딥링크(?club=ID / ?spot=ID) 수신. 웹 deep_link 처리 포팅.
// 콜드스타트 초기 링크 + 실행 중 스트림 둘 다 처리. 미검증 도메인이면 안 열려 웹 폴백(안전).
import 'dart:async';
import 'package:app_links/app_links.dart';

class DeepLink {
  final String kind; // 'club' | 'spot'
  final String id;
  const DeepLink(this.kind, this.id);
}

/// URI 쿼리에서 club/spot id 추출. 둘 다 없으면 null.
DeepLink? parseDeepLink(Uri uri) {
  final club = uri.queryParameters['club'];
  if (club != null && club.trim().isNotEmpty) {
    return DeepLink('club', club.trim());
  }
  final spot = uri.queryParameters['spot'];
  if (spot != null && spot.trim().isNotEmpty) {
    return DeepLink('spot', spot.trim());
  }
  return null;
}

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// 콜드스타트 초기 링크 + 이후 스트림을 onLink로 전달.
  Future<void> start(void Function(DeepLink) onLink) async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        final d = parseDeepLink(initial);
        if (d != null) onLink(d);
      }
    } catch (_) {}
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        final d = parseDeepLink(uri);
        if (d != null) onLink(d);
      },
      onError: (_) {},
    );
  }

  void dispose() {
    _sub?.cancel();
  }
}
