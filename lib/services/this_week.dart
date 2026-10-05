// this_week.dart — 🍚 여기 자리 있어요? 순수 로직(웹과 같은 규칙, 식구 모집·자리 있어요 계약).
// 처음 이름이 '이번 주 차림표'여서 파일·함수 이름이 this_week 이다.
//
// 자리 있어요 = 앞으로 7일 안에 "가서 뛸 수 있는 곳"을 시간순으로 한 줄에 모은 것:
//  · 🔥 게스트 급구(guest) — 급구가 올라가 있는 팀. 끝 = urgent_until.
//    시작은 팀 일정에서 끝 시각(같은 날·같은 HH:mm)이 맞는 회차로 짐작하고, 없으면 비운다("~21:00").
//    마감이 없는 예전 급구는 넣지 않는다 — 서버 정리가 한 시간 안에 마감을 채운다.
//    떠 있는 급구는 7일 창으로 자르지 않는다(서버가 받는 마감은 8일까지 — 웹과 같음).
//  · 🥄 맛보기(drop_in) — 식구 모집 + 맛보기 환영 팀의 일정 회차(팀당 3개까지).
//    같은 팀의 급구 운동과 끝 시각이 같은 회차는 빼고(급구 줄 하나만), 남은 것에서 3개.
//  · 픽업(pickup) — 유효기간이 안 지난 크루의 일정 회차(크루당 3개까지). 문구 = 이번주 메모.
// 회차는 급구 회차 칩과 같은 함수(nextSessions)로 센다 — 끝이 지금+5분보다 뒤, 지금+7일 안.
// 지역 필터는 따르지 않는다. 자리 목록은 따로 보는 목록이고 종류·날짜 칩이 따로 있다.
import '../l10n/strings.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';
import 'i18n.dart';
import 'schedule_parse.dart';
import 'urgent.dart';

/// 항목 종류 — GA contact_click 의 flag 값과 같은 낱말(웹과 같음).
const kTwGuest = 'guest';
const kTwDropIn = 'drop_in';
const kTwPickup = 'pickup';

/// 칩·정렬 순서.
const kTwKinds = [kTwGuest, kTwDropIn, kTwPickup];

/// 팀·크루 하나가 자리 목록에 낼 수 있는 회차 수(급구 줄은 따로).
const kTwMaxPerPlace = 3;

/// 자리 목록 한 줄.
class ThisWeekItem {
  final String kind; // guest | drop_in | pickup
  final DateTime? start; // 급구인데 일정에서 회차를 못 찾으면 null("~21:00")
  final DateTime end;
  final String title; // 팀·크루 이름
  final String place; // 장소(크루 장소 이름 → 지역 → 주소 앞 두 낱말)
  final String? msg; // 급구 문구 · 모집 문구 · 이번주 메모
  final String refId;
  final String refType; // club | pickup
  final String? channel; // 주 연락처 'instagram' | 'link' — 없으면 연락 버튼을 숨긴다

  const ThisWeekItem({
    required this.kind,
    this.start,
    required this.end,
    required this.title,
    required this.place,
    this.msg,
    required this.refId,
    required this.refType,
    this.channel,
  });

  /// 정렬·날짜 묶음 기준 시각 — 시작, 없으면 끝.
  DateTime get at => start ?? end;

  /// 같은 곳(팀·크루) 판정 키 — 입구 띠의 "{n}곳" 을 센다.
  String get placeKey => '$refType:$refId';

  @override
  String toString() => 'ThisWeekItem($kind $title $start→$end)';
}

/// 팀 일정 → 이벤트(일정표가 있으면 그것, 없으면 글로 적은 일정).
List<SchedEvent> clubEvents(Club c) =>
    (c.scheduleRaw != null && c.scheduleRaw!.isNotEmpty)
    ? eventsFromRaw(c.scheduleRaw, overnight: true)
    : eventsFromText(c.schedule, overnight: true);

/// 크루 일정 → 이벤트(상세와 같은 순서: 일정표 → 일정 → 일정 메모).
List<SchedEvent> spotEvents(PickupSpot s) =>
    (s.scheduleRaw != null && s.scheduleRaw!.isNotEmpty)
    ? eventsFromRaw(s.scheduleRaw, overnight: true)
    : eventsFromText(s.schedule ?? s.scheduleText, overnight: true);

/// 주소 앞 두 낱말("서울 마포구 …" → "서울 마포구"). 긴 주소가 한 줄을 다 먹지 않게.
String shortPlace(String? address) {
  final a = (address ?? '').trim();
  if (a.isEmpty) return '';
  final parts = a.split(RegExp(r'\s+'));
  return parts.length <= 2 ? a : '${parts[0]} ${parts[1]}';
}

String? _nonEmpty(String? s) {
  final v = s?.trim() ?? '';
  return v.isEmpty ? null : v;
}

/// 팀의 주 연락처 — 상세 제목 줄의 첫 아이콘과 같은 순서(인스타 → 홈페이지).
String? clubContactChannel(Club c) {
  if (_nonEmpty(c.insta) != null) return 'instagram';
  if (_nonEmpty(c.link) != null) return 'link';
  return null;
}

/// 크루의 주 연락처 — 상세 버튼과 같은 순서(인스타 → 단톡 링크).
String? spotContactChannel(PickupSpot s) {
  if (_nonEmpty(s.insta) != null) return 'instagram';
  if (_nonEmpty(s.contactLink) != null) return 'link';
  return null;
}

bool _sameMinute(DateTime a, DateTime b) =>
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day &&
    a.hour == b.hour &&
    a.minute == b.minute;

DateTime _at(DateTime day, double hours) =>
    DateTime(day.year, day.month, day.day, 0, (hours * 60).round());

/// 급구 마감(= 고른 운동이 끝나는 시각)에 맞는 일정 회차의 시작. 없으면 null.
/// 같은 날 같은 HH:mm 에 끝나는 회차만 본다('다른 날'로 올린 급구는 시작을 모른다).
DateTime? guestStartFor(List<SchedEvent> events, DateTime until) {
  final u = until.toLocal();
  // 자정을 넘기는 운동(22:00~01:00)은 마감 전날 시작한다 — 그날과 전날을 함께 본다.
  for (final back in const [0, 1]) {
    final day = DateTime(u.year, u.month, u.day - back);
    for (final e in events) {
      final wd = scheduleDays.indexOf(e.day) + 1;
      if (wd != day.weekday) continue;
      if (_sameMinute(_at(day, e.end), u)) return _at(day, e.start);
    }
  }
  return null;
}

int _kindOrder(String k) {
  final i = kTwKinds.indexOf(k);
  return i < 0 ? kTwKinds.length : i;
}

/// 자리 목록 항목을 만든다(시간순). [now] 는 기기 시각.
List<ThisWeekItem> buildThisWeek({
  required Iterable<Club> clubs,
  required Iterable<PickupSpot> spots,
  required DateTime now,
}) {
  final out = <ThisWeekItem>[];

  for (final c in clubs) {
    final events = clubEvents(c);
    final place = shortPlace(c.address);
    final channel = clubContactChannel(c);
    DateTime? guestEnd;

    final until = c.urgentUntil?.toLocal();
    if (c.urgentActiveAt(now) && until != null) {
      guestEnd = until;
      out.add(
        ThisWeekItem(
          kind: kTwGuest,
          start: guestStartFor(events, until),
          end: until,
          title: c.name,
          place: place,
          msg: _nonEmpty(c.urgentMsg),
          refId: c.id,
          refType: 'club',
          channel: channel,
        ),
      );
    }

    if (c.dropInActive) {
      // 급구 운동과 끝이 같은 회차를 먼저 빼고 3개(웹 this-week.js 와 같은 순서).
      final sessions = nextSessions(events, now, max: null)
          .where((s) => guestEnd == null || !_sameMinute(s.end, guestEnd))
          .take(kTwMaxPerPlace);
      for (final s in sessions) {
        out.add(
          ThisWeekItem(
            kind: kTwDropIn,
            start: s.start,
            end: s.end,
            title: c.name,
            place: place,
            msg: _nonEmpty(c.recruitMsg),
            refId: c.id,
            refType: 'club',
            channel: channel,
          ),
        );
      }
    }
  }

  for (final s in spots) {
    // 공개 정보로 운영자가 대신 올린 크루(source 'curated')는 넣지 않는다 — 크루가 직접 올린 게
    // 아니라 일정이 바뀌어도 그대로라, '이번 주 몇 시'로 보여 주면 헛걸음을 만들 수 있다.
    // 픽업 탭·상세에는 그대로 나온다. 웹 js/this-week.js 와 같은 규칙.
    if (s.source == 'curated') continue;
    if (s.expireAt != null && !s.expireAt!.isAfter(now)) continue;
    final place =
        _nonEmpty(s.venueName) ?? _nonEmpty(s.region) ?? shortPlace(s.address);
    for (final o in nextSessions(spotEvents(s), now, max: kTwMaxPerPlace)) {
      out.add(
        ThisWeekItem(
          kind: kTwPickup,
          start: o.start,
          end: o.end,
          title: s.title,
          place: place,
          msg: _nonEmpty(s.thisWeek),
          refId: s.id,
          refType: 'pickup',
          channel: spotContactChannel(s),
        ),
      );
    }
  }

  // 시각 → 종류(급구·맛보기·픽업) → 넣은 순서(웹 this-week.js 와 같은 정렬).
  final indexed = out.asMap().entries.toList()
    ..sort((a, b) {
      final x = a.value, y = b.value;
      final c = x.at.compareTo(y.at);
      if (c != 0) return c;
      final k = _kindOrder(x.kind).compareTo(_kindOrder(y.kind));
      return k != 0 ? k : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}

/// 서로 다른 곳(팀·크루) 수 — 입구 띠 "{n}곳".
int thisWeekPlaceCount(Iterable<ThisWeekItem> items) =>
    items.map((e) => e.placeKey).toSet().length;

/// 기기 날짜(자정).
DateTime localDay(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// 날짜 칩 — 오늘부터 6일 뒤까지 7개. 7일째 새벽 회차나 8일 마감 급구처럼 그 뒤 날짜의
/// 항목이 있으면 그날까지 늘린다(웹 twDayChips 와 같음).
List<DateTime> thisWeekDays(
  DateTime now, [
  Iterable<ThisWeekItem> items = const [],
]) {
  final t = localDay(now);
  var last = DateTime(t.year, t.month, t.day + 6);
  for (final e in items) {
    final d = localDay(e.at);
    if (d.isAfter(last)) last = d;
  }
  final out = <DateTime>[];
  for (var i = 0; ; i++) {
    final d = DateTime(t.year, t.month, t.day + i);
    if (d.isAfter(last)) break;
    out.add(d);
  }
  return out;
}

/// 종류 칩·날짜 칩으로 거른다. [day] 가 null 이면 7일 전체.
List<ThisWeekItem> filterThisWeek(
  Iterable<ThisWeekItem> items, {
  required Set<String> kinds,
  DateTime? day,
}) => [
  for (final e in items)
    if (kinds.contains(e.kind) && (day == null || localDay(e.at) == day)) e,
];

/// 날짜별 묶음(시간순 목록을 받아 순서를 지킨다).
List<({DateTime day, List<ThisWeekItem> items})> groupThisWeekByDay(
  Iterable<ThisWeekItem> items,
) {
  final out = <({DateTime day, List<ThisWeekItem> items})>[];
  for (final e in items) {
    final d = localDay(e.at);
    if (out.isEmpty || out.last.day != d) {
      out.add((day: d, items: <ThisWeekItem>[]));
    }
    out.last.items.add(e);
  }
  return out;
}

/// 날짜 칩·묶음 제목 "수 10/8" (EN "Wed 10/8") — 급구 회차 칩과 같은 표기.
String thisWeekDayLabel(DateTime day, {bool? ko}) =>
    '${weekdayShort(day, ko: ko)} ${day.month}/${day.day}';

// "~21:00" / "until 21:00" — [ko] 를 따로 받는 표기 함수들이 같은 언어로 맞추게 사전을 바로 본다.
String _until(String time, bool ko) =>
    kStrings['tw_until']![ko ? 'ko' : 'en']!.replaceAll('{time}', time);

/// 줄의 시각 "19:00~21:00" (EN "19:00–21:00"), 시작을 모르면 "~21:00" (EN "until 21:00").
String thisWeekTimeLabel(ThisWeekItem e, {bool? ko}) {
  final k = ko ?? isKo;
  final end = hhmm(e.end.toLocal());
  if (e.start == null) return _until(end, k);
  return '${hhmm(e.start!.toLocal())}${k ? '~' : '–'}$end';
}

/// 종류 표시(줄의 작은 이모지) — 급구 🔥 · 맛보기 🥄 · 픽업은 없음.
String thisWeekKindMark(String kind) => switch (kind) {
  kTwGuest => '🔥',
  kTwDropIn => '🥄',
  _ => '',
};

/// 입구 띠의 굴러가는 줄 "수 19:00 · 이름 · 🔥 문구".
String thisWeekTickerLine(ThisWeekItem e, {bool? ko}) {
  final k = ko ?? isKo;
  final at = e.at.toLocal();
  final when = e.start == null
      ? '${weekdayShort(at, ko: k)} ${_until(hhmm(at), k)}'
      : '${weekdayShort(at, ko: k)} ${hhmm(at)}';
  final tail = '${thisWeekKindMark(e.kind)} ${e.msg ?? ''}'.trim();
  return [when, e.title, if (tail.isNotEmpty) tail].join(' · ');
}
