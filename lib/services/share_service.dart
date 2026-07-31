// share_service.dart — 공유 URL 빌드 + 링크복사 + OS 공유시트. 웹 share.js 포팅.
// 카톡 리치카드는 Kakao SDK+도메인 등록 필요 → v1은 URL 공유로 대체(추가설정 0).
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  // 웹앱(GitHub Pages)을 공유 랜딩으로 사용 → 딥링크(?club=/?spot=) 그대로 호환.
  static const siteBase = 'https://nulloongzi.github.io/null_oongzi-do/';

  static String clubUrl(String id) =>
      '$siteBase?club=${Uri.encodeComponent(id)}';
  static String spotUrl(String id) =>
      '$siteBase?spot=${Uri.encodeComponent(id)}';

  /// 필터가 걸린 픽업 목록 링크. 앱이 아니라 **웹**으로 보낸다 —
  /// DM 받은 외국인은 앱을 설치하지 않고 브라우저로 열기 때문.
  static String pickupListUrl({
    String region = '',
    String level = '',
    bool englishOnly = false,
  }) {
    final q = <String>['tab=pickup'];
    if (region.isNotEmpty) q.add('region=${Uri.encodeComponent(region)}');
    if (level.isNotEmpty) q.add('level=${Uri.encodeComponent(level)}');
    if (englishOnly) q.add('english=1');
    return '$siteBase?${q.join('&')}';
  }

  /// 클립보드 복사 (IG 링크스티커 붙여넣기·일반 링크공유 공용).
  static Future<void> copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// OS 네이티브 공유시트 (다른 앱/DM). 카톡도 여기서 일반 링크로 전달 가능.
  static Future<void> osShare(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }
}
