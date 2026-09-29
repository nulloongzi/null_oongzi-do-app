// 릴스 모더레이션 — 운영자 숨김(reels_hidden) · 개수 상한.
// 웹(js/dom-utils.js stripHiddenReels · MAX_REELS)과 서버(firestore.rules reelFieldsValid ·
// functions chatbotReportHideReels)에 같은 규칙이 있다. 어긋나면 한쪽에서만 숨긴 릴스가
// 보이거나, 폼은 통과했는데 저장이 거부된다.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/models/club.dart';
import 'package:nulloongzido/models/pickup_spot.dart';
import 'package:nulloongzido/services/sanitize.dart';

const _reel = 'https://www.instagram.com/reel/ABC/';
const _cover =
    'https://firebasestorage.googleapis.com/v0/b/x/o/reel_covers%2FABC.jpg?alt=media&token=t';

Future<Club> clubFrom(Map<String, dynamic> data) async {
  final db = FakeFirebaseFirestore();
  final ref = db.collection('clubs').doc('c1');
  await ref.set(data);
  return Club.fromDoc(await ref.get());
}

Future<PickupSpot> spotFrom(Map<String, dynamic> data) async {
  final db = FakeFirebaseFirestore();
  final ref = db.collection('pickup_games').doc('p1');
  await ref.set(data);
  return PickupSpot.fromDoc(await ref.get());
}

void main() {
  group('운영자 숨김(reels_hidden)', () {
    test('동호회: 숨기면 릴스·커버가 모두 비고 플래그는 남는다', () async {
      final c = await clubFrom({
        'name': 'A',
        'insta_reel': _reel,
        'insta_reels': [_reel],
        'insta_reel_covers': {'ABC': _cover},
        'reels_hidden': true,
      });
      expect(c.reelsHidden, isTrue);
      expect(c.instaReels, isEmpty);
      expect(c.instaReel, isNull);
      expect(c.instaReelCovers, isEmpty);
    });

    test('동호회: 숨김이 아니면 그대로', () async {
      final c = await clubFrom({
        'name': 'A',
        'insta_reels': [_reel],
        'insta_reel_covers': {'ABC': _cover},
      });
      expect(c.reelsHidden, isFalse);
      expect(c.instaReels, [_reel]);
      expect(c.instaReelCovers, {'ABC': _cover});
    });

    test('true 가 아닌 값(문자열 등)은 숨김으로 치지 않는다 — 웹과 같은 판정', () async {
      final c = await clubFrom({
        'name': 'A',
        'insta_reels': [_reel],
        'reels_hidden': 'true',
      });
      expect(c.reelsHidden, isFalse);
      expect(c.instaReels, [_reel]);
    });

    test('픽업: 숨기면 단일 insta_reel 폴백까지 비운다', () async {
      final s = await spotFrom({
        'title': 'P',
        'insta_reel': _reel,
        'insta_reel_covers': {'ABC': _cover},
        'reels_hidden': true,
      });
      expect(s.reelsHidden, isTrue);
      expect(s.instaReels, isEmpty);
      expect(s.instaReel, isNull);
      expect(s.instaReelCovers, isEmpty);
    });
  });

  group('릴스 개수 상한', () {
    test('웹 MAX_REELS · 룰과 같은 10', () {
      expect(Sanitize.maxReels, 10);
    });

    test('중복은 상한 계산 전에 하나로 친다', () {
      final rows = List.filled(12, _reel);
      expect(Sanitize.collectReels(rows), [_reel]);
    });
  });
}
