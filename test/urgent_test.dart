// 급구·회원 모집 순수 로직 테스트 — 문구 검사 정규식은 서버(functions/lib/pure.js)·웹과
// 같아야 하고, 회차·마감 표기는 웹과 같은 말을 해야 한다(급구·회원 모집 계약).
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/l10n/strings.dart';
import 'package:nulloongzido/models/club.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/services/schedule_parse.dart';
import 'package:nulloongzido/services/urgent.dart';
import 'package:nulloongzido/services/urgent_service.dart';

void main() {
  tearDown(() => appLang.value = 'ko');

  group('urgentMsgProblem — 서버와 같은 검사', () {
    test('평범한 문구는 통과 — 숫자가 섞인 한국어도 전화번호가 아니다', () {
      for (final m in [
        '센터 1명 19시',
        '센터 1명, 여자 레프트 1명',
        '토 19:00~22:00 세터 2명',
        '20~30대 여성 회원',
        '3.5시간 운동해요',
        '  리베로 1명  ',
      ]) {
        expect(urgentMsgProblem(m), isNull, reason: m);
      }
    });

    test('비었거나 공백뿐이면 msg_empty', () {
      expect(urgentMsgProblem(''), 'msg_empty');
      expect(urgentMsgProblem('   \n '), 'msg_empty');
    });

    test('길이는 코드 포인트 — 앞뒤 공백을 뺀 60자까지', () {
      expect(urgentMsgProblem('가' * 60), isNull);
      expect(urgentMsgProblem('  ${'가' * 60}  '), isNull);
      expect(urgentMsgProblem('가' * 61), 'msg_too_long');
      // 이모지는 UTF-16 두 칸이지만 코드 포인트 하나 — .length 로 재면 서버와 어긋난다
      expect(urgentMsgProblem('🔥' * 60), isNull);
      expect(urgentMsgProblem('🔥' * 61), 'msg_too_long');
    });

    test('링크는 msg_link', () {
      for (final m in [
        'open.kakao.com/o/xx',
        'insta.com',
        'https://example.org/a',
        'http://x',
        'www.naver',
        'WWW.ABC 들어오세요',
        'naver.me/abc',
        '오픈카톡 open.kakao 로',
        'Team.KR',
      ]) {
        expect(urgentMsgProblem(m), 'msg_link', reason: m);
      }
    });

    test('전화번호는 msg_phone', () {
      for (final m in [
        '010-1234-5678',
        '01012345678',
        '연락 010 1234 5678',
        '010.123.4567',
        '02-123-4567',
        '031-1234-5678',
      ]) {
        expect(urgentMsgProblem(m), 'msg_phone', reason: m);
      }
    });

    test('모집 문구는 비어도 되고, 나머지 검사는 같다', () {
      expect(recruitMsgProblem(''), isNull);
      expect(recruitMsgProblem('  '), isNull);
      expect(recruitMsgProblem('010-1234-5678'), 'msg_phone');
      expect(recruitMsgProblem('insta.com'), 'msg_link');
      expect(recruitMsgProblem('가' * 61), 'msg_too_long');
    });
  });

  group('urgentUntilProblem — 서버 경계(지금+5분 초과 · 지금+8일 이하)', () {
    final now = DateTime(2026, 10, 9, 20);
    test('5분 이내·지난 시각은 past', () {
      expect(urgentUntilProblem(now, now), 'past');
      expect(
        urgentUntilProblem(now.add(const Duration(minutes: 5)), now),
        'past',
      );
      expect(
        urgentUntilProblem(now.subtract(const Duration(hours: 1)), now),
        'past',
      );
    });
    test('8일 넘으면 too_far', () {
      expect(urgentUntilProblem(now.add(const Duration(days: 8)), now), isNull);
      expect(
        urgentUntilProblem(now.add(const Duration(days: 8, minutes: 1)), now),
        'too_far',
      );
    });
    test('그 사이는 통과', () {
      expect(
        urgentUntilProblem(now.add(const Duration(minutes: 6)), now),
        isNull,
      );
    });
  });

  group('nextSessions — 팀 일정 → 7일 안 다음 회차', () {
    // 2026-10-09 은 금요일
    final fri20 = DateTime(2026, 10, 9, 20);
    const events = [
      SchedEvent('금', 19, 21),
      SchedEvent('월', 19, 22),
      SchedEvent('수', 20, 22.5),
    ];

    test('진행 중인 운동 포함, 주가 바뀌어도(일→월) 가까운 순', () {
      expect(nextSessions(events, fri20), [
        UrgentSession(DateTime(2026, 10, 9, 19), DateTime(2026, 10, 9, 21)),
        UrgentSession(DateTime(2026, 10, 12, 19), DateTime(2026, 10, 12, 22)),
        UrgentSession(
          DateTime(2026, 10, 14, 20),
          DateTime(2026, 10, 14, 22, 30),
        ),
      ]);
    });

    test('최대 3개 — 더 가까운 회차가 생기면 먼 것이 빠진다', () {
      final s = nextSessions([...events, const SchedEvent('토', 10, 12)], fri20);
      expect(s.length, 3);
      expect(s.map((e) => e.start.day), [9, 10, 12]);
    });

    test('끝나기 5분 전부터는 고를 수 없다', () {
      final s = nextSessions([
        const SchedEvent('금', 19, 21),
      ], DateTime(2026, 10, 9, 20, 56));
      // 오늘 회차는 4분 남음 → 빠짐. 다음 주 금요일은 7일 범위 밖(21:00 > 20:56+7일)
      expect(s, isEmpty);
    });

    test('7일 뒤 같은 요일도 끝나는 시각이 범위 안이면 포함', () {
      final s = nextSessions([
        const SchedEvent('금', 19, 21),
      ], DateTime(2026, 10, 9, 21, 30));
      expect(s, [
        UrgentSession(DateTime(2026, 10, 16, 19), DateTime(2026, 10, 16, 21)),
      ]);
    });

    test('같은 회차가 두 번 적혀 있으면 하나만', () {
      final s = nextSessions(const [
        SchedEvent('토', 10, 12),
        SchedEvent('토', 10, 12),
      ], fri20);
      expect(s.length, 1);
    });

    test('월말을 넘겨도 날짜가 맞다', () {
      final s = nextSessions(const [
        SchedEvent('월', 19, 21),
      ], DateTime(2026, 10, 30, 12)); // 금요일
      expect(s.single.start, DateTime(2026, 11, 2, 19));
    });

    test('max — 기본 3개, 숫자로 바꾸거나 null 이면 7일 안 모두', () {
      final daily = [for (final d in scheduleDays) SchedEvent(d, 19, 21)];
      expect(nextSessions(daily, fri20), hasLength(3));
      expect(nextSessions(daily, fri20, max: 5), hasLength(5));
      // 금 20:00 기준 오늘 회차(21:00 끝)부터 다음 금 19~21 직전까지 = 7회
      expect(nextSessions(daily, fri20, max: null), hasLength(7));
    });

    test('일정이 없으면 빈 목록', () {
      expect(nextSessions(const [], fri20), isEmpty);
      expect(nextSessions(eventsFromText('매주 아무 때나'), fri20), isEmpty);
    });

    test('텍스트·raw 일정 모두에서 회차가 나온다', () {
      expect(
        nextSessions(eventsFromText('토 14:00~17:00'), fri20).single.end,
        DateTime(2026, 10, 10, 17),
      );
      expect(
        nextSessions(
          eventsFromRaw([
            {'day': '일', 'start': '09:30', 'end': '12:00'},
          ]),
          fri20,
        ).single.start,
        DateTime(2026, 10, 11, 9, 30),
      );
    });
  });

  group('표기', () {
    final s = UrgentSession(
      DateTime(2026, 10, 7, 19),
      DateTime(2026, 10, 7, 21),
    );
    test('회차 칩 KO / EN', () {
      appLang.value = 'ko';
      expect(sessionChipLabel(s), '수 10/7 19:00~21:00');
      appLang.value = 'en';
      expect(sessionChipLabel(s), 'Wed 10/7 19:00–21:00');
    });

    final now = DateTime(2026, 10, 9, 20); // 금
    test('마감 — 오늘 / 내일 / D-n (KO)', () {
      appLang.value = 'ko';
      expect(urgentDeadlineLabel(DateTime(2026, 10, 9, 22), now), '오늘 22:00까지');
      expect(
        urgentDeadlineLabel(DateTime(2026, 10, 10, 1, 30), now),
        '내일 01:30까지',
      );
      expect(
        urgentDeadlineLabel(DateTime(2026, 10, 12, 22), now),
        'D-3 · 월 22:00까지',
      );
    });

    test('마감 — 오늘 / 내일 / D-n (EN)', () {
      appLang.value = 'en';
      expect(
        urgentDeadlineLabel(DateTime(2026, 10, 9, 22), now),
        'Until 22:00 today',
      );
      expect(
        urgentDeadlineLabel(DateTime(2026, 10, 10, 9, 5), now),
        'Until 09:05 tomorrow',
      );
      expect(
        urgentDeadlineLabel(DateTime(2026, 10, 16, 19), now),
        'D-7 · until Fri 19:00',
      );
    });

    test('날짜 차이는 시각이 아니라 날짜로 센다(밤 11시 → 다음 날 새벽 = 내일)', () {
      appLang.value = 'ko';
      expect(
        urgentDeadlineLabel(
          DateTime(2026, 10, 10, 0, 30),
          DateTime(2026, 10, 9, 23, 50),
        ),
        '내일 00:30까지',
      );
    });
  });

  group('오류 사유 → 문구 키', () {
    test('아는 사유는 ug_err_*', () {
      for (final r in [
        'unverified',
        'past',
        'too_far',
        'msg_empty',
        'msg_too_long',
        'msg_link',
        'msg_phone',
        'not_manager',
        'blocked',
      ]) {
        expect(urgentErrorKey(r), 'ug_err_$r');
        expect(kStrings.containsKey('ug_err_$r'), isTrue, reason: r);
      }
    });
    test('모르는 사유·사유 없음은 ug_err_generic, login 은 공통 로그인 안내', () {
      expect(urgentErrorKey(null), 'ug_err_generic');
      expect(urgentErrorKey('bad_input'), 'ug_err_generic');
      expect(urgentErrorKey('not_found'), 'ug_err_generic');
      expect(urgentErrorKey('login'), 'login_required');
    });
    test('callable details 에서 reason 꺼내기', () {
      expect(urgentReasonFromDetails({'reason': 'blocked'}), 'blocked');
      expect(urgentReasonFromDetails({'reason': 3}), isNull);
      expect(urgentReasonFromDetails({}), isNull);
      expect(urgentReasonFromDetails(null), isNull);
      expect(urgentReasonFromDetails('blocked'), isNull);
    });
  });

  test('계약 문구 키가 모두 한/영으로 있다', () {
    const keys = [
      'ug_when', 'ug_other_day', 'ug_end_time', 'ug_msg_label', //
      'ug_msg_hint', 'ug_auto_off', 'ug_submit', 'ug_edit',
      'ug_err_unverified', 'ug_err_past', 'ug_err_too_far',
      'ug_err_msg_empty', 'ug_err_msg_too_long', 'ug_err_msg_link',
      'ug_err_msg_phone', 'ug_err_not_manager', 'ug_err_blocked',
      'ug_err_generic', 'ug_until_today', 'ug_until_tomorrow',
      'ug_until_day', 'ug_filter', 'rc_badge', 'rc_on', 'rc_off',
      'rc_msg_hint', 'rc_auto_off', 'rc_filter',
    ];
    for (final k in keys) {
      expect(kStrings[k]?['ko']?.isNotEmpty, isTrue, reason: '$k ko');
      expect(kStrings[k]?['en']?.isNotEmpty, isTrue, reason: '$k en');
    }
  });

  test('티커 순서 — 마감 가까운 순, 마감 없는 예전 급구는 뒤(원래 순서 유지)', () {
    Club c(String id, DateTime? until) => Club(
      id: id,
      name: id,
      isUrgent: true,
      urgentMsg: '세터',
      urgentUntil: until,
    );
    final out = sortByUrgentDeadline([
      c('a', null),
      c('b', DateTime(2026, 10, 12)),
      c('c', DateTime(2026, 10, 10)),
      c('d', null),
      c('e', DateTime(2026, 10, 11)),
    ]);
    expect(out.map((e) => e.id), ['c', 'e', 'b', 'a', 'd']);
  });

  group('UrgentService 직접 쓰기', () {
    test('급구 내리기 — 끄고 문구 비우고 마감·올린 시각 지움', () async {
      final db = FakeFirebaseFirestore();
      final ref = db.collection('clubs').doc('c1');
      await ref.set({
        'name': 'A',
        'is_urgent': true,
        'urgent_msg': '세터',
        'urgent_until': DateTime(2026, 10, 10),
        'urgent_at': DateTime(2026, 10, 9),
      });
      await UrgentService(db: db).turnOff('c1');
      final d = (await ref.get()).data()!;
      expect(d['is_urgent'], false);
      expect(d['urgent_msg'], '');
      expect(d.containsKey('urgent_until'), isFalse);
      expect(d.containsKey('urgent_at'), isFalse);
      expect(d.containsKey('last_verified_at'), isFalse);
    });

    test('회원 모집 켜기 — 문구·서버 시각, 끄기는 깃발만', () async {
      final db = FakeFirebaseFirestore();
      final ref = db.collection('clubs').doc('c1');
      await ref.set({'name': 'A'});
      final svc = UrgentService(db: db);
      await svc.setRecruiting('c1', on: true, msg: '  20대 여성  ');
      var c = Club.fromDoc(await ref.get());
      expect(c.recruitingActive, isTrue);
      expect(c.recruitMsg, '20대 여성');
      expect(c.recruitAt, isNotNull);
      await svc.setRecruiting('c1', on: false);
      c = Club.fromDoc(await ref.get());
      expect(c.recruitingActive, isFalse);
    });

    test('식구 모집 켜기·고치기 — 맛보기도 함께 쓰고, 끄기는 문구·맛보기를 남긴다', () async {
      final db = FakeFirebaseFirestore();
      final ref = db.collection('clubs').doc('c1');
      await ref.set({'name': 'A'});
      final svc = UrgentService(db: db);
      await svc.setRecruiting('c1', on: true, msg: '초보 환영', dropIn: true);
      var d = (await ref.get()).data()!;
      expect(d['is_recruiting'], true);
      expect(d['recruit_drop_in'], true);
      expect(d['recruit_at'], isNotNull);
      expect(Club.fromDoc(await ref.get()).dropInActive, isTrue);
      // 고치기(맛보기 끄기)도 같은 길 — recruit_at 을 다시 찍는다
      await svc.setRecruiting('c1', on: true, msg: '초보 환영', dropIn: false);
      d = (await ref.get()).data()!;
      expect(d['recruit_drop_in'], false);
      await svc.setRecruiting('c1', on: true, msg: '', dropIn: true);
      await svc.setRecruiting('c1', on: false);
      d = (await ref.get()).data()!;
      expect(d['is_recruiting'], false);
      expect(d['recruit_drop_in'], true); // 남아 있다
      expect(Club.fromDoc(await ref.get()).dropInActive, isFalse);
    });

    test('켜기 필드 집합(계약) · 끄기는 is_recruiting 하나', () {
      expect(recruitOnFields(' x ', dropIn: true).keys.toSet(), {
        'is_recruiting',
        'recruit_msg',
        'recruit_drop_in',
        'recruit_at',
      });
      expect(recruitOnFields(' x ')['recruit_msg'], 'x');
      expect(recruitOnFields('x')['recruit_drop_in'], false);
      expect(recruitOnFields('x')['recruit_at'], isA<FieldValue>());
      expect(recruitOffFields(), {'is_recruiting': false});
    });
  });
}
