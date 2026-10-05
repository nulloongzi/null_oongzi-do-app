// Club 급구·회원 모집 파싱·판정 — 지도 마커·티커·상세 배너·릴스 미리보기가 모두
// Club.urgentActive 하나만 본다(웹과 같은 판정: 켜져 있고, 문구가 있고, 마감 전).
import 'package:cloud_firestore/cloud_firestore.dart';
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

  group('urgent_until · urgentActiveAt', () {
    final now = DateTime(2026, 10, 9, 20);

    test('마감 시각을 읽는다(Timestamp)', () async {
      final until = DateTime(2026, 10, 9, 22);
      final at = DateTime(2026, 10, 9, 18);
      final c = await clubFrom({
        'name': 'A',
        'is_urgent': true,
        'urgent_msg': '세터',
        'urgent_until': Timestamp.fromDate(until),
        'urgent_at': Timestamp.fromDate(at),
      });
      expect(c.urgentUntil, until);
      expect(c.urgentAt, at);
    });

    test('마감 전이면 보이고, 지났으면(같은 시각 포함) 안 보인다', () {
      Club c(DateTime? until) => Club(
        id: 'x',
        name: 'A',
        isUrgent: true,
        urgentMsg: '세터',
        urgentUntil: until,
      );
      expect(
        c(now.add(const Duration(minutes: 1))).urgentActiveAt(now),
        isTrue,
      );
      expect(c(now).urgentActiveAt(now), isFalse);
      expect(
        c(now.subtract(const Duration(hours: 1))).urgentActiveAt(now),
        isFalse,
      );
    });

    test('마감이 없는 예전 급구는 계속 보인다(서버 정리가 채울 때까지)', () {
      final c = Club(id: 'x', name: 'A', isUrgent: true, urgentMsg: '세터');
      expect(c.urgentUntil, isNull);
      expect(c.urgentActiveAt(now), isTrue);
      expect(c.urgentActive, isTrue);
    });

    test('urgentActive 는 지금 시각 기준', () {
      final past = Club(
        id: 'x',
        name: 'A',
        isUrgent: true,
        urgentMsg: '세터',
        urgentUntil: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      final future = Club(
        id: 'y',
        name: 'B',
        isUrgent: true,
        urgentMsg: '세터',
        urgentUntil: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(past.urgentActive, isFalse);
      expect(future.urgentActive, isTrue);
    });

    test('마감이 timestamp 가 아니면 null(파싱이 죽지 않는다)', () async {
      final c = await clubFrom({
        'name': 'A',
        'is_urgent': true,
        'urgent_msg': '세터',
        'urgent_until': '2026-10-09',
      });
      expect(c.urgentUntil, isNull);
    });
  });

  group('회원 모집 파싱', () {
    test('bool true 만 모집 중, 문구·시각을 읽는다', () async {
      final at = DateTime(2026, 9, 1);
      final c = await clubFrom({
        'name': 'A',
        'is_recruiting': true,
        'recruit_msg': '20대 여성',
        'recruit_at': Timestamp.fromDate(at),
      });
      expect(c.isRecruiting, isTrue);
      expect(c.recruitingActive, isTrue);
      expect(c.recruitMsg, '20대 여성');
      expect(c.recruitAt, at);
    });

    test('문구가 비어도 모집 중', () async {
      final c = await clubFrom({
        'name': 'A',
        'is_recruiting': true,
        'recruit_msg': '',
      });
      expect(c.recruitingActive, isTrue);
    });

    test('bool 이 아닌 값·필드 없음은 false, 문자열 아닌 문구는 null', () async {
      for (final v in ['true', 1, null]) {
        final c = await clubFrom({
          'name': 'A',
          'is_recruiting': v,
          'recruit_msg': 7,
        });
        expect(c.recruitingActive, isFalse, reason: '$v');
        expect(c.recruitMsg, isNull);
      }
      final none = await clubFrom({'name': 'A'});
      expect(none.recruitingActive, isFalse);
      expect(none.recruitAt, isNull);
    });
  });

  group('🥄 맛보기 환영 파싱', () {
    test('식구 모집이 켜져 있고 recruit_drop_in 이 bool true 일 때만 보인다', () async {
      final c = await clubFrom({
        'name': 'A',
        'is_recruiting': true,
        'recruit_drop_in': true,
      });
      expect(c.recruitDropIn, isTrue);
      expect(c.dropInActive, isTrue);
    });

    test('모집을 끄면 값이 남아 있어도 보이지 않는다(다시 켤 때 채워 보이는 용도)', () async {
      final c = await clubFrom({
        'name': 'A',
        'is_recruiting': false,
        'recruit_drop_in': true,
      });
      expect(c.recruitDropIn, isTrue);
      expect(c.dropInActive, isFalse);
    });

    test('bool 이 아닌 값·필드 없음은 false', () async {
      for (final v in ['true', 1, null]) {
        final c = await clubFrom({
          'name': 'A',
          'is_recruiting': true,
          'recruit_drop_in': v,
        });
        expect(c.dropInActive, isFalse, reason: '$v');
      }
    });
  });
}
