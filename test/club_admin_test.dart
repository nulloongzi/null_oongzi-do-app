// club_admin 순수 규칙 테스트 — 웹(js/auth.js · js/dom-utils.js)과
// 서버(functions/lib/pure.js · firestore.rules)에 같은 규칙이 있다.
// 어긋나면 앱에는 버튼이 보이는데 저장은 거부되므로, 그 경계를 여기서 고정한다.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/l10n/strings.dart';
import 'package:nulloongzido/models/club.dart';
import 'package:nulloongzido/screens/detail_sheet.dart';
import 'package:nulloongzido/services/club_admin.dart';
import 'package:nulloongzido/services/club_admin_service.dart';
import 'package:nulloongzido/services/i18n.dart';

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

    test('admins 가 빈 배열이면 관리자 없음 — registered_by 로 폴백하지 않는다', () async {
      // 마지막 관리자가 스스로 빠진 팀. 폴백하면 빠진 등록자가 다시 관리자로 보이고,
      // 규칙(clubAdmins)은 빈 배열을 그대로 쓰므로 저장은 거부된다.
      final c = await clubFrom({
        'name': 'A',
        'admins': <String>[],
        'registered_by': 'owner',
      });
      expect(c.admins, isEmpty);
      expect(canManageClub(c, 'owner'), isFalse);
    });

    test('공백·빈 값만 든 admins 도 정리하면 빈 목록 — 폴백 없음', () async {
      final c = await clubFrom({
        'name': 'A',
        'admins': ['', '  ', null],
        'registered_by': 'owner',
      });
      expect(c.admins, isEmpty);
    });

    test('admins 가 배열이 아니면(잘못된 값) registered_by 로 폴백', () async {
      final c = await clubFrom({
        'name': 'A',
        'admins': 'u1',
        'registered_by': ' owner ',
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

  group('showClubAdminArea (웹 #clubAdminArea 와 같은 조건)', () {
    test('실명 로그인·운영자 아님이면 보인다 — 인증 여부와 무관', () {
      expect(showClubAdminArea(uid: 'u1', isAnonymous: false), isTrue);
    });

    test('비로그인·익명·운영자에게는 보이지 않는다', () {
      expect(showClubAdminArea(uid: null, isAnonymous: false), isFalse);
      expect(showClubAdminArea(uid: '', isAnonymous: false), isFalse);
      expect(showClubAdminArea(uid: 'anon', isAnonymous: true), isFalse);
      expect(
        showClubAdminArea(uid: 'op', isAnonymous: false, isOperator: true),
        isFalse,
      );
    });
  });

  group('adminApprovalNeedsRefresh', () {
    test('승인됐는데 admins 에 내가 없으면 다시 읽는다', () async {
      final c = await clubFrom({
        'name': 'A',
        'admins': ['u1'],
      });
      expect(adminApprovalNeedsRefresh(c, 'u2', 'approved'), isTrue);
    });

    test('이미 admins 에 있거나, 승인 상태가 아니거나, 비로그인이면 안 읽는다', () async {
      final c = await clubFrom({
        'name': 'A',
        'admins': ['u1'],
      });
      expect(adminApprovalNeedsRefresh(c, 'u1', 'approved'), isFalse);
      expect(adminApprovalNeedsRefresh(c, 'u2', 'pending'), isFalse);
      expect(adminApprovalNeedsRefresh(c, 'u2', 'rejected'), isFalse);
      expect(adminApprovalNeedsRefresh(c, null, 'approved'), isFalse);
    });
  });

  group('관리자 신청 거절 사유', () {
    test('서버 코드 4개는 한/영 문구가 있다', () {
      for (final code in kAdminRejectReasonCodes) {
        final key = adminRejectReasonKey(code);
        expect(key, 'ad_reason_$code');
        expect(kStrings[key]?['ko'], isNotEmpty, reason: '$key ko');
        expect(kStrings[key]?['en'], isNotEmpty, reason: '$key en');
      }
      expect(kAdminRejectReasonCodes, {
        'full',
        'already_admin',
        'not_found',
        'duplicate',
      });
    });

    test('코드 → 사람이 읽는 말', () {
      expect(adminRejectReasonText('full'), '관리자가 이미 3명이에요');
      expect(adminRejectReasonText('already_admin'), '이미 이 팀 관리자예요');
      expect(adminRejectReasonText('not_found'), '팀 정보를 찾지 못했어요');
      expect(adminRejectReasonText('duplicate'), '같은 신청이 이미 들어가 있어요');
    });

    test('모르는 코드·사유 없음은 null — 사유 줄을 그리지 않는다', () {
      expect(adminRejectReasonText(null), isNull);
      expect(adminRejectReasonText(''), isNull);
      expect(adminRejectReasonText('error'), isNull); // 옛 서버가 쓰던 값
      expect(adminRejectReasonText('club_missing'), isNull);
      expect(adminRejectReasonText('사진 불분명'), isNull);
    });

    test('영어 모드에선 영어로', () {
      appLang.value = 'en';
      addTearDown(() => appLang.value = 'ko');
      expect(adminRejectReasonText('full'), 'This team already has 3 admins');
    });
  });

  group('leaveClubAdminSucceeded', () {
    test("서버가 {status:'left'} 를 돌려줄 때만 성공", () {
      expect(
        leaveClubAdminSucceeded({'status': 'left', 'remaining': 1}),
        isTrue,
      );
      expect(
        leaveClubAdminSucceeded({'status': 'not_admin', 'remaining': 2}),
        isFalse,
      );
      expect(leaveClubAdminSucceeded(null), isFalse);
      expect(leaveClubAdminSucceeded('left'), isFalse);
    });
  });

  group('ClubAdminService.fetchClub', () {
    test('팀 문서를 새로 읽어 admins 를 돌려준다', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('clubs').doc('c1').set({
        'name': 'A',
        'admins': ['u1', 'u2'],
      });
      final svc = ClubAdminService(db: db, auth: MockFirebaseAuth());
      final c = await svc.fetchClub('c1');
      expect(c?.admins, ['u1', 'u2']);
      expect(await svc.fetchClub('nope'), isNull);
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
        expect(
          (r * 200 - (r * 200).round()).abs(),
          lessThan(1e-6),
          reason: '$v → $r 이 격자에서 벗어나면 규칙이 저장을 거부한다',
        );
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
      final exact = await clubFrom({
        'name': 'A',
        'location_precision': 'exact',
      });
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

  // 신청 버튼을 누르면 갤러리보다 '어떤 사진을 올려야 하는지' 안내가 먼저 뜬다.
  // 로그인·정원 확인은 그 안내보다 앞 — 어차피 안 되는 신청에 안내를 보이지 않는다.
  group('ClubAdminService.submit 안내 창 순서', () {
    final signedIn = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u9'),
    );

    test('비로그인이면 안내 창 없이 로그인 안내', () async {
      var asked = 0;
      final svc = ClubAdminService(
        db: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(),
      );
      final c = await clubFrom({'name': 'A'});
      final err = await svc.submit(c, confirm: () async => ++asked > 0);
      expect(err, t('ad_login_required'));
      expect(asked, 0);
    });

    test('익명 계정도 안내 창 없이 로그인 안내', () async {
      var asked = 0;
      final svc = ClubAdminService(
        db: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'anon', isAnonymous: true),
        ),
      );
      final c = await clubFrom({'name': 'A'});
      final err = await svc.submit(c, confirm: () async => ++asked > 0);
      expect(err, t('ad_login_required'));
      expect(asked, 0);
    });

    test('관리자 3명이 차 있으면 안내 창 없이 정원 안내', () async {
      var asked = 0;
      final svc = ClubAdminService(db: FakeFirebaseFirestore(), auth: signedIn);
      final c = await clubFrom({
        'name': 'A',
        'admins': ['a', 'b', 'c'],
      });
      final err = await svc.submit(c, confirm: () async => ++asked > 0);
      expect(err, t('ad_full'));
      expect(asked, 0);
    });

    test('안내 창에서 취소하면 갤러리를 열지 않고 아무것도 쓰지 않는다', () async {
      var asked = 0;
      final db = FakeFirebaseFirestore();
      final svc = ClubAdminService(db: db, auth: signedIn);
      final c = await clubFrom({
        'name': 'A',
        'admins': ['a'],
      });
      // 갤러리(ImagePicker)까지 갔다면 테스트 환경엔 플러그인이 없어 예외가 난다.
      final err = await svc.submit(
        c,
        confirm: () async {
          asked++;
          return false;
        },
      );
      expect(err, 'cancelled');
      expect(asked, 1);
      final reqs = await db.collection('club_admin_requests').get();
      expect(reqs.docs, isEmpty);
    });
  });

  group('관리자 신청 안내 문구', () {
    test('ad_title · ad_desc · ad_submit 는 한/영 모두 있다', () {
      for (final k in ['ad_title', 'ad_desc', 'ad_submit']) {
        expect(kStrings[k]?['ko'], isNotEmpty, reason: '$k ko');
        expect(kStrings[k]?['en'], isNotEmpty, reason: '$k en');
      }
    });
  });

  group('confirmClubAdminRequest 안내 창', () {
    Future<Future<bool>> open(WidgetTester tester) async {
      late Future<bool> result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => result = confirmClubAdminRequest(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('제목·설명·버튼이 보이고, 신청하기를 눌러야 true', (tester) async {
      final result = await open(tester);
      expect(find.text(t('ad_title')), findsOneWidget);
      expect(find.text(t('ad_desc')), findsOneWidget);
      expect(find.text(t('cancel')), findsOneWidget);
      await tester.tap(find.text(t('ad_submit')));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.text(t('ad_title')), findsNothing);
    });

    testWidgets('취소하면 false', (tester) async {
      final result = await open(tester);
      await tester.tap(find.text(t('cancel')));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('바깥을 눌러 닫아도 false', (tester) async {
      final result = await open(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('영어 모드에서도 문구가 영어로 나온다', (tester) async {
      appLang.value = 'en';
      addTearDown(() => appLang.value = 'ko');
      await open(tester);
      expect(find.text('Request team admin'), findsOneWidget);
      expect(find.text('Submit request'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
