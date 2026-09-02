// sanitize.dart — dom-utils.js 포팅. 입력 검증/정규화.
class Sanitize {
  /// http(s)/mailto/tel만 통과, 그 외 ''(차단). javascript:/data: 등 차단.
  static String url(String? v) {
    if (v == null) return '';
    final s = v.trim();
    if (s.isEmpty) return '';
    if (RegExp(r'^https?://', caseSensitive: false).hasMatch(s)) return s;
    if (RegExp(r'^mailto:', caseSensitive: false).hasMatch(s)) return s;
    if (RegExp(r'^tel:', caseSensitive: false).hasMatch(s)) return s;
    return '';
  }

  /// 인스타 핸들: 영문/숫자/._, 1~30자. 앞 @ 제거. 무효면 ''.
  static String instaHandle(String? v) {
    if (v == null) return '';
    final s = v.trim().replaceFirst(RegExp(r'^@'), '');
    if (RegExp(r'^[A-Za-z0-9._]{1,30}$').hasMatch(s)) return s;
    return '';
  }

  /// 업로드 파일명 정규화 (dom-utils.js sanitizeFilename과 동일):
  /// 경로 구분자·제어문자·특수문자 _ 치환, 연속 _ 압축, 80자 초과 시 확장자 보존하며 자르기.
  static String filename(String? v) {
    var s = (v ?? 'photo').trim();
    s = s.replaceAll(RegExp(r'[/\\:\x00-\x1f]'), '_');
    s = s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_');
    if (s.length > 80) {
      final dot = s.lastIndexOf('.');
      if (dot > 0 && dot > s.length - 12) {
        final ext = s.substring(dot);
        s = s.substring(0, 80 - ext.length) + ext;
      } else {
        s = s.substring(0, 80);
      }
    }
    return s.isEmpty ? 'photo' : s;
  }

  /// 릴스 입력 행들 → 정규화된 permalink 목록 (registration.js:358-368과 동일 흐름):
  /// 행 안의 개행·공백도 분해(여러 링크 붙여넣기 대응), 각각 permalink 검증, 중복 제거.
  /// 무효 토큰이 하나라도 있으면 null (호출부가 f_reel_invalid 에러 표시).
  static List<String>? collectReels(Iterable<String> rows) {
    final out = <String>[];
    for (final row in rows) {
      for (final tok in row.trim().split(RegExp(r'\s+'))) {
        if (tok.isEmpty) continue;
        final s = instaPostUrl(tok);
        if (s.isEmpty) return null;
        if (!out.contains(s)) out.add(s);
      }
    }
    return out;
  }

  /// 공개 인스타 게시물/릴스 permalink만 → 정규 permalink 반환, 무효면 ''.
  static String instaPostUrl(String? v) {
    if (v == null) return '';
    final s = v.trim();
    final m = RegExp(
      r'^https?://(?:www\.)?instagram\.com/(?:[A-Za-z0-9._]+/)?(p|reel|reels|tv)/([A-Za-z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(s);
    if (m == null) return '';
    var type = m.group(1)!.toLowerCase();
    if (type == 'reels') type = 'reel';
    return 'https://www.instagram.com/$type/${m.group(2)}/';
  }
}
