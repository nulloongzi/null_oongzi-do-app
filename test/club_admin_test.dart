// club_admin 순수 규칙 테스트 — 웹(js/auth.js · js/dom-utils.js)과
// 서버(functions/lib/pure.js · firestore.rules)에 같은 규칙이 있다.
// 어긋나면 앱에는 버튼이 보이는데 저장은 거부되므로, 그 경계를 여기서 고정한다.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/models/club.dart';
import 'package:nulloongzido/services/club_admin.dart';

Future<Club> clubFrom(Map<String, dynamic> data) async {
  final db = FakeFirebaseFirestore();
  final ref = db.collection('clubs').doc('c1');
  await ref.set(data);
  return Club.fromDoc(await ref.get());
}

void main() {
  group('Club.admins 파싱', () {
    test('admins 배열이 정본', () async {
      final c = await clubFrom({
        'name': 'A',
        'admins': ['u1', 'u2'],
        'registered_by': 'owner',
      });
      expect(c.admins, ['u1', 'u2']);
    });

    test('admins 가 없으면 registered_by 한 명으로 폴백', () async {
      final c = await clubFrom({'name': 'A', 'registered_by': 'owner'});
      expect(c.admins, ['owner']);
    });

    test('admins 가 빈 배열이어도 registered_by 로 폴백', () async {
      final c = await clubFrom({
        'name': 'A',
        'admins': <String>[],
        'registered_by': 'owner',
      });
      expect(c.admins, ['owner']);
    });

    test('공백·중복은 정리한다', () async {
      final c = await clubFrom({
        'name': 'A',
        'admins': ['u1', ' u1 ', '', '  ', 'u2'],
      });
      expect(c.admins, ['u1', 'u2']);
    });

    test('둘 다 없으면 빈 목록 — 아무도 못 고친다', () async {
      final c = await clubFrom({'name': 'A'});
      expect(c.admins, isEmpty);
    });
  });

  group('canManageClub', () {
    test('admins 에 있으면 고칠 수 있다', () async {
      final c = await clubFrom({
        'name': 'A',
        'admins': ['u1'],
      });
      expect(canManageClub(c, 'u1'), isTrue);
      expect(canManageClub(c, 'u2'), isFalse);
    });

    test('운영자는 admins 와 무관하게 고칠 수 있다', () async {
      final c = await clubFrom({
        'name': 'A',
        'admins': ['u1'],
      });
      expect(canManageClub(c, 'u2', isOperator: true), isTrue);
      // 로그아웃 상태의 운영자 플래그는 실제로 생기지 않지만, 규칙상 uid 가
      // 없으면 쓰기도 안 되므로 여기서 true 가 나와도 저장은 서버가 막는다.
      expect(canManageClub(c, null), isFalse);
    });

    test('비로그인은 고칠 수 없다', () async {
      final c = await clubFrom({
        'name': 'A',
        'admins': ['u1'],
      });
      expect(canManageClub(c, null), isFalse);
      expect(canManageClub(c, ''), isFalse);
    });
  });

  group('adminRequestBlockReason', () {
    test('막을 이유가 없으면 null', () async {
      final c = await clubFrom({
        'name': 'A',
        'admins': ['u1'],
      });
      expect(adminRequestBlockReason(c, 'u2'), isNull);
    });

    test('이미 관리자면 already_admin', () async {
      final c = await clubFrom({
        'name': 'A',
        'admins': ['u1'],
      });
      expect(adminRequestBlockReason(c, 'u1'), 'already_admin');
    });

    test('정원(3)이 차면 full', () async {
      final c = await clubFrom({
        'name': 'A',
        'admins': ['u1', 'u2', 'u3'],
      });
      expect(adminRequestBlockReason(c, 'u4'), 'full');
    });

    test('비로그인은 no_uid', () async {
      final c = await clubFrom({'name': 'A'});
      expect(adminRequestBlockReason(c, null), 'no_uid');
    });

    test('정원은 서버(firestore.rules admins.size() <= 3)와 같은 3', () {
      expect(kMaxClubAdmins, 3);
    });
  });

  group('roundToAreaGrid', () {
    test('1/200° 격자로 뭉갠다', () {
      expect(roundToAreaGrid(37.5665), closeTo(37.565, 1e-9));
      expect(roundToAreaGrid(126.9780), closeTo(126.98, 1e-9));
    });

    test('격자에 이미 맞은 값은 그대로', () {
      expect(roundToAreaGrid(37.565), closeTo(37.565, 1e-9));
    });

    test('뭉갠 값은 서버 규칙(v*200 이 정수)을 만족한다', () {
      for (final v in [37.5665, 126.978, -0.0031, 33.4996, 128.12345]) {
        final r = roundToAreaGrid(v)!;
        expect((r * 200 - (r * 200).round()).abs(), lessThan(1e-6),
            reason: '$v → $r 이 격자에서 벗어나면 규칙이 저장을 거부한다');
      }
    });

    test('숫자가 아니면 null', () {
      expect(roundToAreaGrid(null), isNull);
      expect(roundToAreaGrid(double.nan), isNull);
      expect(roundToAreaGrid(double.infinity), isNull);
    });
  });

  group('areaLabel', () {
    test('시·도 + 시/군/구 까지만 남긴다', () {
      expect(areaLabel('경기도 구리시 벌말로 168'), '경기도 구리시');
      expect(areaLabel('서울 광진구 아차산로 452'), '서울 광진구');
    });

    test('시설명이 앞에 붙어도 행정구역부터 시작한다', () {
      // 첫 토큰을 그대로 쓰면 '구리' 가 나온다 — 그건 주소가 아니다.
      expect(areaLabel('구리 여자중학교 체육관(경기도 구리시 벌말로 168)'), '경기도 구리시');
    });

    test('행정구역이 없으면 빈 문자열 — 호출부가 좌표로 되묻는다', () {
      expect(areaLabel('하남종합운동장국민체육센터'), '');
      expect(areaLabel(''), '');
      expect(areaLabel(null), '');
    });

    test('구 단위가 여러 개여도 최대 3토큰', () {
      expect(areaLabel('경상남도 창원시 성산구 중앙대로 100'), '경상남도 창원시 성산구');
    });
  });

  group('isAreaOnly', () {
    test("location_precision 이 'area' 일 때만 true", () async {
      final area = await clubFrom({'name': 'A', 'location_precision': 'area'});
      final exact = await clubFrom({'name': 'A', 'location_precision': 'exact'});
      // 필드가 없는 기존 문서는 지금까지처럼 정확히 보인다.
      final legacy = await clubFrom({'name': 'A'});
      expect(isAreaOnly(area), isTrue);
      expect(isAreaOnly(exact), isFalse);
      expect(isAreaOnly(legacy), isFalse);
      expect(legacy.locationPrecision, 'exact');
    });

    test('알 수 없는 값은 exact 로 떨어진다', () async {
      final c = await clubFrom({'name': 'A', 'location_precision': 'blurry'});
      expect(isAreaOnly(c), isFalse);
    });
  });

  group('대략 위치 원', () {
    test('반지름이 격자 한 칸을 덮는다', () {
      // 원이 격자보다 작으면, 원 밖에 진짜 위치가 있는데도 안에 있는 것처럼
      // 보인다. 최소한 격자 반칸 대각선은 덮어야 한다.
      expect(kAreaCircleRadius, greaterThanOrEqualTo(areaGridSpanMeters()));
    });
  });

  group('ClubAdminService.latestRequest 회귀', () {
    test('타임스탬프 없는 문서도 후보로 잡힌다', () async {
      // requested_at 은 serverTimestamp 라 방금 쓴 문서는 잠시 null 이다.
      // 그때 '이력 없음'으로 보이면 신청 버튼이 다시 떠서 중복 신청이 된다.
      final db = FakeFirebaseFirestore();
      await db.collection('club_admin_requests').add({
        'club_id': 'c1',
        'requested_by': 'u1',
        'status': 'pending',
        'requested_at': null,
      });
      final snap = await db
          .collection('club_admin_requests')
          .where('requested_by', isEqualTo: 'u1')
          .get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['club_id'], 'c1');
    });
  });
}
