// 🍚 여기 자리 있어요?(이번 주에 가서 뛸 수 있는 곳) 순수 로직 — 무엇이 들어가고(게스트 급구·맛보기·픽업), 무엇이 빠지고
// (예전 급구·7일 밖·유효기간 지난 픽업), 어떤 순서로 묶이는지. 웹과 같은 규칙.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/l10n/strings.dart';
import 'package:nulloongzido/models/club.dart';
import 'package:nulloongzido/models/pickup_spot.dart';
import 'package:nulloongzido/services/contact_source.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/services/schedule_parse.dart';
import 'package:nulloongzido/services/this_week.dart';

// 2026-10-07 수요일 18:00 (기기 시각)
final now = DateTime(2026, 10, 7, 18);

List<Map<String, String>> raw(List<List<String>> rows) => [
  for (final r in rows) {'day': r[0], 'start': r[1], 'end': r[2]},
];

Club club(
  String id, {
  List? schedule,
  bool urgent = false,
  String? urgentMsg,
  DateTime? until,
  bool recruiting = false,
  bool dropIn = false,
  String? recruitMsg,
  String? insta,
  String? link,
  String? address = '서울 마포구 성미산로 1',
}) => Club(
  id: id,
  name: '팀$id',
  scheduleRaw: schedule,
  isUrgent: urgent,
  urgentMsg: urgentMsg,
  urgentUntil: until,
  isRecruiting: recruiting,
  recruitDropIn: dropIn,
  recruitMsg: recruitMsg,
  insta: insta,
  link: link,
  address: address,
);

PickupSpot spot(
  String id, {
  List? schedule,
  String? text,
  DateTime? expireAt,
  String? thisWeek,
  String? venue,
  String? region,
  String? address,
  String? insta,
  String? contactLink,
}) => PickupSpot(
  id: id,
  title: '크루$id',
  scheduleRaw: schedule,
  schedule: text,
  expireAt: expireAt,
  thisWeek: thisWeek,
  venueName: venue,
  region: region,
  address: address,
  insta: insta,
  contactLink: contactLink,
);

List<ThisWeekItem> build({
  List<Club> clubs = const [],
  List<PickupSpot> spots = const [],
}) => buildThisWeek(clubs: clubs, spots: spots, now: now);

void main() {
  setUp(() => appLang.value = 'ko');

  group('게스트 급구', () {
    test('일정에서 끝 시각이 맞는 회차로 시작을 짐작한다', () {
      final items = build(
        clubs: [
          club(
            'a',
            schedule: raw([
              ['목', '19:00', '21:00'],
            ]),
            urgent: true,
            urgentMsg: '세터 1명',
            until: DateTime(2026, 10, 8, 21),
          ),
        ],
      );
      expect(items, hasLength(1));
      final e = items.single;
      expect(e.kind, kTwGuest);
      expect(e.start, DateTime(2026, 10, 8, 19));
      expect(e.end, DateTime(2026, 10, 8, 21));
      expect(e.msg, '세터 1명');
      expect(e.refType, 'club');
      expect(e.place, '서울 마포구');
      expect(thisWeekTimeLabel(e), '19:00~21:00');
      expect(thisWeekTimeLabel(e, ko: false), '19:00–21:00');
    });

    test('일정에 없는 운동(다른 날)이면 시작 없이 "~21:00"', () {
      final e = build(
        clubs: [
          club(
            'a',
            schedule: raw([
              ['목', '19:00', '22:00'],
            ]),
            urgent: true,
            urgentMsg: '레프트',
            until: DateTime(2026, 10, 8, 21),
          ),
        ],
      ).single;
      expect(e.start, isNull);
      expect(e.at, DateTime(2026, 10, 8, 21));
      expect(thisWeekTimeLabel(e), '~21:00');
      appLang.value = 'en';
      expect(thisWeekTimeLabel(e), 'until 21:00');
    });

    test('같은 요일이어도 다른 날짜의 회차와는 맞추지 않는다', () {
      // 수요일 일정인데 마감은 다음 주 수요일이 아니라 이번 주 목요일
      expect(
        guestStartFor([
          const SchedEvent('수', 19, 21),
        ], DateTime(2026, 10, 8, 21)),
        isNull,
      );
    });

    test('마감 없는 예전 급구·지난 급구·7일 넘는 급구는 빠진다', () {
      final items = build(
        clubs: [
          club('legacy', urgent: true, urgentMsg: '급구'),
          club(
            'past',
            urgent: true,
            urgentMsg: '급구',
            until: DateTime(2026, 10, 7, 17),
          ),
          club(
            'far',
            urgent: true,
            urgentMsg: '급구',
            until: DateTime(2026, 10, 14, 19), // 지금+7일 1시간 뒤
          ),
          club(
            'edge',
            urgent: true,
            urgentMsg: '급구',
            until: DateTime(2026, 10, 14, 18), // 딱 7일
          ),
          club('nomsg', urgent: true, until: DateTime(2026, 10, 8, 21)),
        ],
      );
      expect(items.map((e) => e.refId), ['edge']);
    });
  });

  group('맛보기', () {
    final everyDay = raw([
      for (final d in scheduleDays) [d, '19:00', '21:00'],
    ]);

    test('식구 모집 + 맛보기 환영일 때만, 팀당 3회까지', () {
      final items = build(
        clubs: [
          club(
            'both',
            schedule: everyDay,
            recruiting: true,
            dropIn: true,
            recruitMsg: '초보 환영',
          ),
          club('rcOnly', schedule: everyDay, recruiting: true),
          club('dropOnly', schedule: everyDay, dropIn: true),
        ],
      );
      expect(items.map((e) => e.refId).toSet(), {'both'});
      expect(items, hasLength(3));
      expect(items.every((e) => e.kind == kTwDropIn), isTrue);
      expect(items.first.start, DateTime(2026, 10, 7, 19)); // 오늘 회차부터
      expect(items.first.msg, '초보 환영');
    });

    test('곧 끝나는 회차(5분 안)는 빼고, 7일 밖은 넣지 않는다', () {
      final items = build(
        clubs: [
          club(
            'a',
            schedule: raw([
              ['수', '16:00', '18:04'], // 오늘, 4분 남음
              ['화', '19:00', '21:00'], // 다음 화요일 10/13
            ]),
            recruiting: true,
            dropIn: true,
          ),
        ],
      );
      expect(items.map((e) => e.start), [DateTime(2026, 10, 13, 19)]);
    });

    test('일정을 못 읽으면 맛보기 줄이 없다', () {
      final items = build(
        clubs: [
          Club(
            id: 'x',
            name: 'X',
            schedule: '매주 아무 때나',
            isRecruiting: true,
            recruitDropIn: true,
          ),
        ],
      );
      expect(items, isEmpty);
    });

    test('급구 운동과 겹치는 맛보기 회차는 급구 줄 하나만 남긴다', () {
      final items = build(
        clubs: [
          club(
            'a',
            schedule: everyDay,
            recruiting: true,
            dropIn: true,
            urgent: true,
            urgentMsg: '센터',
            until: DateTime(2026, 10, 8, 21),
          ),
        ],
      );
      expect(items.map((e) => '${e.kind} ${e.end.day}'), [
        'drop_in 7',
        'guest 8',
        'drop_in 9',
      ]);
      expect(thisWeekPlaceCount(items), 1);
    });
  });

  group('픽업', () {
    test('유효기간이 지난 크루는 빠지고, 상시·남은 크루는 크루당 3회', () {
      final daily = raw([
        for (final d in scheduleDays) [d, '20:00', '22:00'],
      ]);
      final items = build(
        spots: [
          spot('old', schedule: daily, expireAt: DateTime(2026, 10, 7, 17)),
          spot('ok', schedule: daily, expireAt: DateTime(2026, 11, 1)),
          spot('always', schedule: daily),
        ],
      );
      expect(items.where((e) => e.refId == 'old'), isEmpty);
      expect(items.where((e) => e.refId == 'ok'), hasLength(3));
      expect(items.where((e) => e.refId == 'always'), hasLength(3));
      expect(items.every((e) => e.kind == kTwPickup), isTrue);
    });

    test('글로 적은 일정도 읽고, 문구는 이번주 메모, 장소는 장소 이름 → 지역 → 주소', () {
      final items = build(
        spots: [
          spot(
            'v',
            text: '토 14:00~17:00',
            thisWeek: '  이번 주는 2코트  ',
            venue: '망원 체육관',
            region: '서울',
          ),
          spot('r', text: '토 10:00~12:00', region: '경기'),
          spot('a', text: '토 08:00~10:00', address: '부산 해운대구 우동 1'),
        ],
      );
      final byId = {for (final e in items) e.refId: e};
      expect(byId['v']!.msg, '이번 주는 2코트');
      expect(byId['v']!.place, '망원 체육관');
      expect(byId['r']!.place, '경기');
      expect(byId['r']!.msg, isNull);
      expect(byId['a']!.place, '부산 해운대구');
    });
  });

  group('정렬·묶음·거르기', () {
    late List<ThisWeekItem> items;
    setUp(() {
      items = build(
        clubs: [
          club(
            'g',
            urgent: true,
            urgentMsg: '세터',
            until: DateTime(2026, 10, 8, 21), // 시작 모름 → 21:00 에 선다
            insta: 'team_g',
          ),
          club(
            'd',
            schedule: raw([
              ['목', '19:00', '21:00'],
            ]),
            recruiting: true,
            dropIn: true,
            link: 'https://open.kakao.com/x',
          ),
        ],
        spots: [
          spot(
            'p',
            schedule: raw([
              ['수', '20:00', '22:00'],
              ['목', '19:00', '21:00'],
            ]),
          ),
        ],
      );
    });

    test('시작(없으면 끝) 순, 같은 시각이면 급구·맛보기·픽업 순', () {
      expect(items.map((e) => '${e.kind}:${e.refId}'), [
        'pickup:p', // 수 20:00
        'drop_in:d', // 목 19:00
        'pickup:p', // 목 19:00
        'guest:g', // 목 ~21:00
      ]);
      expect(thisWeekPlaceCount(items), 3);
    });

    test('기기 날짜별로 묶는다', () {
      final groups = groupThisWeekByDay(items);
      expect(groups.map((g) => g.day), [
        DateTime(2026, 10, 7),
        DateTime(2026, 10, 8),
      ]);
      expect(groups[1].items, hasLength(3));
      expect(thisWeekDayLabel(groups[1].day), '목 10/8');
      expect(thisWeekDayLabel(groups[1].day, ko: false), 'Thu 10/8');
    });

    test('종류 칩·날짜 칩', () {
      expect(
        filterThisWeek(items, kinds: {kTwGuest, kTwDropIn}).map((e) => e.kind),
        [kTwDropIn, kTwGuest],
      );
      expect(
        filterThisWeek(
          items,
          kinds: kTwKinds.toSet(),
          day: DateTime(2026, 10, 7),
        ).map((e) => e.refId),
        ['p'],
      );
      expect(filterThisWeek(items, kinds: {}), isEmpty);
    });

    test('날짜 칩은 오늘부터 7일', () {
      final days = thisWeekDays(now);
      expect(days.first, DateTime(2026, 10, 7));
      expect(days.last, DateTime(2026, 10, 13));
      expect(days, hasLength(7));
    });

    test('연락 버튼 채널 — 인스타 → 링크, 없으면 null', () {
      final byKind = {for (final e in items) '${e.kind}:${e.refId}': e};
      expect(byKind['guest:g']!.channel, 'instagram');
      expect(byKind['drop_in:d']!.channel, 'link');
      expect(byKind['pickup:p']!.channel, isNull);
    });

    test('굴러가는 줄 "수 19:00 · 이름 · 🔥 문구"', () {
      final g = items.firstWhere((e) => e.kind == kTwGuest);
      expect(thisWeekTickerLine(g), '목 ~21:00 · 팀g · 🔥 세터');
      final d = items.firstWhere((e) => e.kind == kTwDropIn);
      expect(thisWeekTickerLine(d), '목 19:00 · 팀d · 🥄');
      final p = items.first;
      expect(thisWeekTickerLine(p), '수 20:00 · 크루p');
      expect(thisWeekTickerLine(g, ko: false), 'Thu until 21:00 · 팀g · 🔥 세터');
    });
  });

  group('연락 출처(via·flag)·상태 표시', () {
    test('flag — 급구 > 맛보기 > 식구 모집 > none', () {
      final until = DateTime(2026, 10, 8, 21);
      expect(
        clubContactFlag(
          club(
            'a',
            urgent: true,
            urgentMsg: 'x',
            until: until,
            recruiting: true,
            dropIn: true,
          ),
          now,
        ),
        'guest',
      );
      expect(
        clubContactFlag(club('a', recruiting: true, dropIn: true), now),
        'drop_in',
      );
      expect(clubContactFlag(club('a', recruiting: true), now), 'recruit');
      expect(clubContactFlag(club('a', dropIn: true), now), 'none');
      // 마감이 지난 급구는 급구가 아니다
      expect(
        clubContactFlag(
          club('a', urgent: true, urgentMsg: 'x', until: DateTime(2026, 10, 7)),
          now,
        ),
        'none',
      );
    });

    test('파라미터 — 팀은 club_id, 크루는 id + flag pickup', () {
      expect(
        clubContactParams(
          club('a', recruiting: true),
          channel: 'instagram',
          via: kViaThisWeek,
          now: now,
        ),
        {
          'channel': 'instagram',
          'club_id': 'a',
          'source': 'club',
          'via': 'this_week',
          'flag': 'recruit',
        },
      );
      expect(spotContactParams('p', channel: 'link', via: kViaDetail), {
        'channel': 'link',
        'id': 'p',
        'source': 'pickup',
        'via': 'detail',
        'flag': 'pickup',
      });
    });

    test('표시 — 🔥 먼저, 🍚, 🥄 는 식구 모집일 때만', () {
      final until = DateTime(2026, 10, 8, 21);
      expect(clubMarks(club('a'), now: now), '');
      expect(clubMarks(club('a', recruiting: true), now: now), '🍚');
      expect(
        clubMarks(club('a', recruiting: true, dropIn: true), now: now),
        '🍚🥄',
      );
      expect(clubMarks(club('a', dropIn: true), now: now), '');
      expect(
        clubMarks(
          club(
            'a',
            urgent: true,
            urgentMsg: 'x',
            until: until,
            recruiting: true,
            dropIn: true,
          ),
          now: now,
        ),
        '🔥🍚🥄',
      );
    });
  });

  test('계약 문구 그대로(웹 js/i18n.js 와 같은 키·글자)', () {
    const want = {
      'rc_badge': ['🍚 식구 모집', "🍚 Taking new members"],
      'rc_on': ['🍚 식구 모집 시작', "🍚 Start taking members"],
      'rc_off': ['식구 모집 마감', "Stop taking members"],
      'rc_filter': ['🍚 식구 모집', "🍚 Taking members"],
      'rc_badge_desc': ['새 회원을 받고 있어요', "This team is taking new members."],
      'rc_edit': ['식구 모집 수정', "Edit"],
      'rc_msg_label': [
        '어떤 식구를 찾나요? (선택)',
        "Who are you looking for? (optional)",
      ],
      'rc_drop_in': ['🥄 맛보기 환영', "🥄 Drop-ins welcome"],
      'rc_drop_in_desc': [
        '한 번 와서 같이 뛰어 봐도 돼요',
        "You can come and play once to try it out.",
      ],
      'rc_drop_in_ask': [
        '맛보기(체험·게스트)도 받아요',
        "We also welcome drop-ins (try-outs and guests)",
      ],
      'rc_save': ['저장하기', "Save"],
      'rc_saved': ['🍚 식구 모집을 올렸어요', "🍚 Now taking new members"],
      'rc_closed': ['식구 모집을 마감했어요', "Stopped taking members"],
      'ug_badge_desc': [
        '이번 운동에 같이 뛸 사람을 급하게 찾아요',
        "Looking for players for this session.",
      ],
      'tw_entry': ['🍚 여기 자리 있어요? · {n}곳', "🍚 Room for one more? · {n}"],
      'tw_title': ['🍚 여기 자리 있어요?', "🍚 Room for one more?"],
      'tw_sub': ['이번 주에 가서 뛸 수 있는 곳', "Places you can go and play this week"],
      'tw_empty': ['고른 조건에 맞는 곳이 아직 없어요', "Nothing matches yet."],
      'tw_kind_guest': ['🔥 게스트 급구', "🔥 Guests needed"],
      'tw_kind_drop_in': ['🥄 맛보기', "🥄 Drop-in"],
      'tw_kind_pickup': ['픽업', "Pickup"],
      'tw_all_days': ['7일 전체', "All 7 days"],
      'tw_contact': ['연락하기', "Contact"],
      'tw_until': ['~{time}', "until {time}"],
    };
    want.forEach((k, v) {
      expect(kStrings[k]?['ko'], v[0], reason: '$k ko');
      expect(kStrings[k]?['en'], v[1], reason: '$k en');
    });
  });
}
