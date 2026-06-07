// i18n.dart — 한/영 다국어. 웹 i18n.js 포팅 (수동 토글 + 기기 로케일 기본).
// appLang 변경 시 main.dart의 ValueListenableBuilder가 앱 전체를 리빌드 → t()가 재평가됨.
// (번역 텍스트가 든 위젯은 const가 아니어야 리빌드됩니다.)
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/strings.dart';

final ValueNotifier<String> appLang = ValueNotifier<String>('ko');

/// 키 → 현재 언어 문자열. 없으면 한국어, 그것도 없으면 키 그대로.
String t(String key) {
  final m = kStrings[key];
  if (m == null) return key;
  return m[appLang.value] ?? m['ko'] ?? key;
}

/// {param} 치환 포함.
String tf(String key, Map<String, String> params) {
  var s = t(key);
  params.forEach((k, v) => s = s.replaceAll('{$k}', v));
  return s;
}

bool get isKo => appLang.value == 'ko';

/// 저장된 언어 로드. 없으면 기기 로케일(비한국어→en).
Future<void> initLang() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('lang');
    if (saved == 'ko' || saved == 'en') {
      appLang.value = saved!;
      return;
    }
    final code =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    appLang.value = code == 'ko' ? 'ko' : 'en';
  } catch (_) {}
}

Future<void> toggleLang() async {
  appLang.value = appLang.value == 'ko' ? 'en' : 'ko';
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', appLang.value);
  } catch (_) {}
}
