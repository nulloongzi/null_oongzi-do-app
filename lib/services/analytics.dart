// analytics.dart — 핵심 퍼널 이벤트. 웹 window.track 포팅.
// 미초기화/차단/실패 시 조용히 no-op (앱 동작에 영향 없음).
import 'package:firebase_analytics/firebase_analytics.dart';

class Track {
  static final FirebaseAnalytics _a = FirebaseAnalytics.instance;

  /// 이벤트 기록. null 파라미터는 제거. 실패는 무시.
  static Future<void> event(String name, [Map<String, Object?>? params]) async {
    try {
      await _a.logEvent(name: name, parameters: cleanParams(params));
    } catch (_) {}
  }

  /// GA 로 보낼 파라미터 정리. null 은 빼고, 정수·참거짓은 글자로 바꾼다.
  /// 앱(Firebase)에서 숫자로 보낸 값은 GA 맞춤 측정기준에 '(not set)' 으로만 잡혔다
  /// (2026-10 분석: has_reel·six·english 가 웹은 잡히고 앱만 비었다). 웹 gtag 는 글자로 보내므로
  /// 글자로 맞추면 두 플랫폼이 같은 칸에 모인다. 참거짓은 Firebase 가 받지 않아 이벤트째 버려질 수 있었다.
  /// 정수 1/0 → '1'/'0', true/false → '1'/'0'. 실수(double)는 측정값일 수 있어 그대로 둔다.
  static Map<String, Object>? cleanParams(Map<String, Object?>? params) {
    if (params == null) return null;
    final clean = <String, Object>{};
    params.forEach((k, v) {
      if (v == null) return;
      if (v is bool) {
        clean[k] = v ? '1' : '0';
      } else if (v is int) {
        clean[k] = v.toString();
      } else {
        clean[k] = v;
      }
    });
    return clean.isEmpty ? null : clean;
  }

  /// 사용자 속성(모든 이벤트에 붙는 차원). 예: ui_lang — 외국인 교두보를 KO/EN 으로 나눠 본다.
  static Future<void> userProp(String name, String? value) async {
    try {
      await _a.setUserProperty(name: name, value: value);
    } catch (_) {}
  }

  /// 수집 끄기(캡처 모드 등). 디버그 빌드는 매니페스트에서 이미 꺼져 있다.
  static Future<void> disable() async {
    try {
      await _a.setAnalyticsCollectionEnabled(false);
    } catch (_) {}
  }
}
