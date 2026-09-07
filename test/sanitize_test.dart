// Sanitize 순수 로직 단위 테스트 (Tier 1).
// 웹 dom-utils 포팅 검증 — URL/핸들/파일명/인스타 permalink 정규화.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/sanitize.dart';

void main() {
  group('Sanitize.url', () {
    test('http(s)/mailto/tel 통과', () {
      expect(Sanitize.url('https://example.com'), 'https://example.com');
      expect(Sanitize.url('http://a.b'), 'http://a.b');
      expect(Sanitize.url('mailto:a@b.com'), 'mailto:a@b.com');
      expect(Sanitize.url('tel:010-1234-5678'), 'tel:010-1234-5678');
    });
    test('위험 스킴/빈값/null 차단', () {
      expect(Sanitize.url('javascript:alert(1)'), '');
      expect(Sanitize.url('data:text/html,x'), '');
      expect(Sanitize.url('   '), '');
      expect(Sanitize.url(null), '');
    });
  });

  group('Sanitize.instaHandle', () {
    test('앞 @ 제거 + 유효 핸들', () {
      expect(Sanitize.instaHandle('@volley_club.1'), 'volley_club.1');
      expect(Sanitize.instaHandle('abc'), 'abc');
    });
    test('공백/특수문자/과길이 → 빈값', () {
      expect(Sanitize.instaHandle('a b'), '');
      expect(Sanitize.instaHandle('한글핸들'), '');
      expect(Sanitize.instaHandle('x' * 31), '');
      expect(Sanitize.instaHandle(null), '');
    });
  });

  group('Sanitize.filename', () {
    test('허용문자 유지 + 공백/한글 _ 치환', () {
      expect(Sanitize.filename('photo-01.png'), 'photo-01.png');
      expect(Sanitize.filename('a b.png'), 'a_b.png');
      expect(Sanitize.filename(null), 'photo');
      expect(Sanitize.filename(''), 'photo');
    });
    test('연속 _ 압축 (웹 sanitizeFilename 동일)', () {
      expect(Sanitize.filename('a  b.png'), 'a_b.png');
      expect(Sanitize.filename('a/../b.png'), 'a_.._b.png');
    });
    test('80자 초과 시 확장자 보존하며 자르기', () {
      final long = '${'a' * 100}.png';
      final out = Sanitize.filename(long);
      expect(out.length, 80);
      expect(out.endsWith('.png'), true);
    });
  });

  group('Sanitize.collectReels', () {
    test('정규화 + 중복 제거 + 행 내 다중 링크 분해', () {
      final out = Sanitize.collectReels([
        'https://www.instagram.com/reel/AbC123/',
        'https://instagram.com/reels/AbC123/ https://www.instagram.com/p/Xyz9/',
      ]);
      expect(out, [
        'https://www.instagram.com/reel/AbC123/',
        'https://www.instagram.com/p/Xyz9/',
      ]);
    });
    test('무효 토큰이 하나라도 있으면 null', () {
      expect(Sanitize.collectReels(['https://example.com/x']), isNull);
    });
    test('빈 행은 무시', () {
      expect(Sanitize.collectReels(['', '  ']), <String>[]);
    });
  });

  group('Sanitize.instaPostUrl', () {
    test('p/reel 정규 permalink 반환', () {
      expect(
        Sanitize.instaPostUrl('https://www.instagram.com/p/ABC_123/'),
        'https://www.instagram.com/p/ABC_123/',
      );
      expect(
        Sanitize.instaPostUrl('https://instagram.com/reel/XyZ9/'),
        'https://www.instagram.com/reel/XyZ9/',
      );
    });
    test('reels → reel 정규화, 사용자경로 허용', () {
      expect(
        Sanitize.instaPostUrl('https://www.instagram.com/someuser/reels/AbC/'),
        'https://www.instagram.com/reel/AbC/',
      );
    });
    test('무효 URL → 빈값', () {
      expect(Sanitize.instaPostUrl('https://instagram.com/someuser/'), '');
      expect(Sanitize.instaPostUrl('https://evil.com/p/ABC/'), '');
      expect(Sanitize.instaPostUrl(null), '');
    });
  });
}
