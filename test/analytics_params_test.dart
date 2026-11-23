// GA 파라미터 정리 — 앱에서 숫자로 보내면 맞춤 측정기준이 '(not set)' 으로만 잡혔다(2026-10).
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/analytics.dart';

void main() {
  test('정수·참거짓은 글자로, null 은 뺀다', () {
    expect(
      Track.cleanParams({
        'has_reel': 1,
        'six': 0,
        'english': true,
        'urgent': false,
        'club_id': 'abc',
        'gone': null,
      }),
      {
        'has_reel': '1',
        'six': '0',
        'english': '1',
        'urgent': '0',
        'club_id': 'abc',
      },
    );
  });

  test('실수는 그대로, 비면 null', () {
    expect(Track.cleanParams({'ratio': 0.5}), {'ratio': 0.5});
    expect(Track.cleanParams({'gone': null}), isNull);
    expect(Track.cleanParams(null), isNull);
  });
}
