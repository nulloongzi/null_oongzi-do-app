// 공유 링크 출처 표시(UTM) — 웹 share.js withShareUtm 과 같은 값이어야 GA 에서 한 줄로 합쳐진다.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/share_service.dart';

void main() {
  test('쿼리가 있으면 &, 없으면 ? 로 share/<medium> 을 붙인다', () {
    expect(
      ShareService.withUtm(ShareService.clubUrl('A'), 'kakao'),
      'https://do.nulloongzi.com/?club=A&utm_source=share&utm_medium=kakao',
    );
    expect(
      ShareService.withUtm(ShareService.siteBase, 'card_qr'),
      'https://do.nulloongzi.com/?utm_source=share&utm_medium=card_qr',
    );
  });
}
