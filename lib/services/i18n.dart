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

// ── 데이터 표시 변환 (저장은 KO, 영어모드에서 표시만 변환) — 웹 i18n.js 포팅 ──
// 모르는 토큰은 원문 유지(best-effort). 긴 토큰부터(부분 겹침 방지).
const List<List<String>> _targetMap = [
  ['여성전용', 'Women only'],
  ['남성전용', 'Men only'],
  ['선출가능', 'Ex-players OK'],
  ['군미필 상관x', 'pre-service OK'],
  ['군미필', 'pre-service OK'],
  ['대학생', 'College'],
  ['청소년', 'Youth'],
  ['성인', 'Adults'],
  ['6인제', '6s'],
  ['9인제', '9s'],
  ['무관', 'Anyone'],
  ['선출', 'Ex-player'],
  ['구력', 'exp.'],
  ['이상', '+'],
  ['남', 'M'],
  ['여', 'W'],
];

/// 대상/특징 어휘 변환. KO 모드면 원문.
String i18nTarget(String? str) {
  if (isKo || str == null || str.isEmpty) return str ?? '';
  var s = str;
  for (final p in _targetMap) {
    s = s.replaceAll(p[0], p[1]);
  }
  return s;
}

const List<List<String>> _priceMap = [
  ['게스트비', 'Guest fee'],
  ['게스트', 'Guest'],
  ['학생', 'Student'],
  ['회비', 'Fee'],
  ['분기', 'Quarterly'],
  ['무료', 'Free'],
  ['주1회', '1×/wk'],
  ['주2회', '2×/wk'],
  ['주3회', '3×/wk'],
  ['주 1회', '1×/wk'],
  ['주 2회', '2×/wk'],
  ['주 3회', '3×/wk'],
  ['월 기준', '/mo'],
  ['월', 'Monthly'],
  ['없음', 'none'],
];
final RegExp _reMan = RegExp(r'(\d+(?:\.\d+)?)\s*만\s*원?');
final RegExp _reCheon = RegExp(r'(\d+(?:\.\d+)?)\s*천\s*원?');

/// 회비 표시 변환. "6.5만원"→"₩65,000", "8천원"→"₩8,000" + 어휘.
String i18nPrice(String? str) {
  if (isKo || str == null || str.isEmpty) return str ?? '';
  var s = str;
  s = s.replaceAllMapped(
    _reMan,
    (m) => '₩${_comma((double.parse(m[1]!) * 10000).round())}',
  );
  s = s.replaceAllMapped(
    _reCheon,
    (m) => '₩${_comma((double.parse(m[1]!) * 1000).round())}',
  );
  for (final p in _priceMap) {
    s = s.replaceAll(p[0], p[1]);
  }
  return s;
}

String _comma(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

const Map<String, String> _dayKey = {
  '월': 'd_mon',
  '화': 'd_tue',
  '수': 'd_wed',
  '목': 'd_thu',
  '금': 'd_fri',
  '토': 'd_sat',
  '일': 'd_sun',
};

/// 한글 요일 글자 → 현재 언어 표기('월'→Mon). 스케줄 키는 KO 유지, 표시만.
String i18nDay(String kchar) {
  final k = _dayKey[kchar];
  return k != null ? t(k) : kchar;
}

const Map<String, String> _regionEn = {
  '서울': 'Seoul',
  '경기': 'Gyeonggi',
  '인천': 'Incheon',
  '강원': 'Gangwon',
  '충청': 'Chungcheong',
  '전라': 'Jeolla',
  '경상': 'Gyeongsang',
  '제주': 'Jeju',
};

/// 지역명 표시 변환(서울→Seoul). 값은 KO 유지, 표시만.
String i18nRegion(String ko) => isKo ? ko : (_regionEn[ko] ?? ko);

/// 스케줄 문자열의 요일만 표시 변환("토 19:00"→"Sat 19:00"). KO면 원문.
String i18nSchedule(String? s) {
  if (s == null || s.isEmpty || isKo) return s ?? '';
  var out = s.replaceAll('매일', 'Daily');
  _dayKey.forEach((ko, key) {
    out = out.replaceAll(ko, t(key));
  });
  return out;
}

/// 저장된 언어 로드. 없으면 기기 로케일(비한국어→en).
Future<void> initLang() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('lang');
    if (saved == 'ko' || saved == 'en') {
      appLang.value = saved!;
      return;
    }
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
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
