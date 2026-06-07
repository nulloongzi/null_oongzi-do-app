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

  /// 업로드 파일명 정규화: 영숫자/._- 만 유지, 나머지 _ 치환, 최대 50자(확장자 보존 위해 끝 50자).
  static String filename(String? v) {
    final s = (v ?? 'photo').trim();
    final cleaned = s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final out = cleaned.isEmpty ? 'photo' : cleaned;
    return out.length > 50 ? out.substring(out.length - 50) : out;
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
