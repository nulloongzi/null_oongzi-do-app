// analytics.dart — 핵심 퍼널 이벤트. 웹 window.track 포팅.
// 미초기화/차단/실패 시 조용히 no-op (앱 동작에 영향 없음).
import 'package:firebase_analytics/firebase_analytics.dart';

class Track {
  static final FirebaseAnalytics _a = FirebaseAnalytics.instance;

  /// 이벤트 기록. null 파라미터는 제거. 실패는 무시.
  static Future<void> event(String name, [Map<String, Object?>? params]) async {
    try {
      Map<String, Object>? clean;
      if (params != null) {
        clean = <String, Object>{};
        params.forEach((k, v) {
          if (v != null) clean![k] = v;
        });
        if (clean.isEmpty) clean = null;
      }
      await _a.logEvent(name: name, parameters: clean);
    } catch (_) {}
  }
}
