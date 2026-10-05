// Club 급구 파싱·판정 — 지도 마커·티커·상세 배너·릴스 미리보기가 모두
// Club.urgentActive 하나만 본다(웹과 같은 판정: 켜져 있고 문구가 있을 때).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/models/club.dart';

Future<Club> clubFrom(Map<String, dynamic> data) async {
  final db = FakeFirebaseFirestore();
  final ref = db.collection('clubs').doc('c1');
  await ref.set(data);
  return Club.fromDoc(await ref.get());
}

void main() {
  group('is_urgent 파싱', () {
    test('bool true 만 급구로 읽는다', () async {
      final c = await clubFrom({
        'name': 'A',
        'is_urgent': true,
        'urgent_msg': '세터 구해요',
      });
      expect(c.isUrgent, isTrue);
    });

    test('문자열·숫자 같은 bool 아닌 값은 죽지 않고 false', () async {
      for (final v in ['true', 1, 'yes', <String>[]]) {
        final c = await clubFrom({
          'name': 'A',
          'is_urgent': v,
          'urgent_msg': '세터 구해요',
        });
        expect(c.isUrgent, isFalse, reason: '$v');
        expect(c.urgentActive, isFalse, reason: '$v');
      }
    });

    test('필드가 없으면 false', () async {
      final c = await clubFrom({'name': 'A'});
      expect(c.isUrgent, isFalse);
      expect(c.urgentActive, isFalse);
    });

    test('urgent_msg 가 문자열이 아니면 null', () async {
      final c = await clubFrom({
        'name': 'A',
        'is_urgent': true,
        'urgent_msg': 42,
      });
      expect(c.urgentMsg, isNull);
      expect(c.urgentActive, isFalse);
    });
  });

  group('urgentActive', () {
    test('켜져 있고 문구가 있어야 보인다', () async {
      final c = await clubFrom({
        'name': 'A',
        'is_urgent': true,
        'urgent_msg': '세터 구해요',
      });
      expect(c.urgentActive, isTrue);
    });

    test('켜져 있어도 문구가 비었거나 공백뿐이면 안 보인다', () async {
      for (final m in [null, '', '   ']) {
        final c = await clubFrom({
          'name': 'A',
          'is_urgent': true,
          'urgent_msg': m,
        });
        expect(c.urgentActive, isFalse, reason: '"$m"');
      }
    });

    test('꺼져 있으면 문구가 남아 있어도 안 보인다', () async {
      final c = await clubFrom({
        'name': 'A',
        'is_urgent': false,
        'urgent_msg': '세터 구해요',
      });
      expect(c.urgentActive, isFalse);
    });
  });
}
