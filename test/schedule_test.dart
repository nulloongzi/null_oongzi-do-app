// 일정 파싱/포맷 순수 로직 단위 테스트 (Tier 1).
// schedule_parse.dart(raw/텍스트 → 이벤트, 12시간 표기) + schedule_block.dart(등록폼 블록).
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/schedule_parse.dart';
import 'package:nulloongzido/models/schedule_block.dart';

void main() {
  group('eventsFromRaw', () {
    test('정상 raw → 이벤트(시=소수)', () {
      final ev = eventsFromRaw([
        {'day': '월', 'start': '19:00', 'end': '22:00'},
        {'day': '토', 'start': '13:30', 'end': '17:00'},
      ]);
      expect(ev.length, 2);
      expect(ev[0].day, '월');
      expect(ev[0].start, 19.0);
      expect(ev[0].end, 22.0);
      expect(ev[1].start, 13.5);
    });
    test('무효(end<=start, 잘못된 요일, null) 스킵', () {
      final ev = eventsFromRaw([
        {'day': '월', 'start': '22:00', 'end': '20:00'}, // 역전
        {'day': 'X', 'start': '19:00', 'end': '22:00'}, // 요일 아님
        {'day': '수'}, // 시간 누락
      ]);
      expect(ev, isEmpty);
    });
    test('null raw → 빈 리스트', () {
      expect(eventsFromRaw(null), isEmpty);
    });
  });

  group('eventsFromText', () {
    test('쉼표 세그먼트 + 요일별', () {
      final ev = eventsFromText('월 19:00~22:00, 수 20:00~21:30');
      expect(ev.length, 2);
      expect(ev[0].day, '월');
      expect(ev[1].day, '수');
      expect(ev[1].start, 20.0);
      expect(ev[1].end, 21.5);
    });
    test('슬래시 세그먼트 구분', () {
      final ev = eventsFromText('토 14:00~17:00 / 일 10:00~12:00');
      expect(ev.map((e) => e.day).toList(), ['토', '일']);
    });
    test('한 세그먼트에 여러 요일이면 각각 이벤트', () {
      final ev = eventsFromText('월수 19:00~21:00');
      expect(ev.length, 2);
      expect(ev.every((e) => e.start == 19.0 && e.end == 21.0), true);
    });
    test('빈/무효 → 빈 리스트', () {
      expect(eventsFromText(''), isEmpty);
      expect(eventsFromText(null), isEmpty);
      expect(eventsFromText('요일 미정'), isEmpty);
    });
  });

  group('12시간 표기/길이', () {
    test('time12', () {
      expect(time12(19.5), 'PM 7:30');
      expect(time12(0), 'AM 12:00');
      expect(time12(12), 'PM 12:00');
      expect(time12(9.0), 'AM 9:00');
    });
    test('durLabel', () {
      expect(durLabel(4.0), '4h');
      expect(durLabel(3.5), '3.5h');
    });
    test('getHourLabel', () {
      expect(getHourLabel(13), 'PM 1');
      expect(getHourLabel(0), 'AM 12');
      expect(getHourLabel(12), 'PM 12');
    });
  });

  group('ScheduleBlock', () {
    test('timeOptions 06:00~23:30 30분 간격', () {
      final opts = ScheduleBlock.timeOptions();
      expect(opts.length, 36); // (24-6)*2
      expect(opts.first, '06:00');
      expect(opts.last, '23:30');
    });
    test('toRaw 요일 전개', () {
      final raw = ScheduleBlock.toRaw([
        ScheduleBlock(days: ['월', '수'], start: '19:00', end: '22:00'),
      ]);
      expect(raw.length, 2);
      expect(raw[0], {'day': '월', 'start': '19:00', 'end': '22:00'});
    });
    test('toText 요일순 정렬', () {
      final text = ScheduleBlock.toText([
        ScheduleBlock(days: ['수', '월'], start: '19:00', end: '22:00'),
      ]);
      expect(text, '월 19:00~22:00, 수 19:00~22:00');
    });
    test('groupFromRaw 같은 시간대 → 한 블록', () {
      final blocks = ScheduleBlock.groupFromRaw([
        {'day': '월', 'start': '19:00', 'end': '22:00'},
        {'day': '수', 'start': '19:00', 'end': '22:00'},
        {'day': '토', 'start': '13:00', 'end': '17:00'},
      ]);
      expect(blocks.length, 2);
      final first = blocks.firstWhere((b) => b.start == '19:00');
      expect(first.days, ['월', '수']);
    });
  });
}
