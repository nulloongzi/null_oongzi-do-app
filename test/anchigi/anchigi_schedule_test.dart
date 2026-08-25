// 스케줄 계산 검증 — 경기 시각, 최대 라운드, 시간 파싱.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/models/anchigi/anchigi_schedule.dart';

void main() {
  group('시간 파싱', () {
    test('HH:MM을 분으로', () {
      expect(parseTime('14:00'), 840);
      expect(parseTime('09:30'), 570);
      expect(parseTime('00:00'), 0);
      expect(parseTime('7'), 420); // 분 없으면 0으로
    });

    test('빈 값이나 잘못된 값은 null', () {
      expect(parseTime(null), isNull);
      expect(parseTime(''), isNull);
      expect(parseTime('abc'), isNull);
    });

    test('분을 HH:MM으로 (0 채움)', () {
      expect(formatTime(840), '14:00');
      expect(formatTime(570), '09:30');
      expect(formatTime(5), '00:05');
      expect(formatTime(1500), '01:00'); // 24시간 순환
    });
  });

  group('경기 시각', () {
    final s = AnchigiSchedule(warmup: '14:00', perGame: 15, rest: 10);

    test('1라운드는 몸풀기 시각부터 연달아', () {
      expect(formatTime(s.gameStartMin(1, 0, 3)), '14:00');
      expect(formatTime(s.gameEndMin(1, 0, 3)), '14:15');
      expect(formatTime(s.gameStartMin(1, 1, 3)), '14:15');
      expect(formatTime(s.gameStartMin(1, 2, 3)), '14:30');
      expect(formatTime(s.gameEndMin(1, 2, 3)), '14:45');
    });

    test('2라운드는 앞 라운드 뒤 휴식을 한 번 끼고 시작', () {
      // 1R 3경기(45분) + 휴식 10분 → 14:55
      expect(formatTime(s.gameStartMin(2, 0, 3)), '14:55');
      expect(formatTime(s.gameStartMin(3, 0, 3)), '15:50');
    });

    test('경기 수가 바뀌면 라운드 간격도 바뀐다', () {
      expect(formatTime(s.gameStartMin(2, 0, 2)), '14:40'); // 30분 + 휴식 10분
    });
  });

  group('최대 라운드', () {
    test('3시간에 3경기×15분 + 휴식 10분이면 3라운드', () {
      // 180분. 라운드당 45+10=55분, 마지막 휴식 보정 → (180+10)/55 = 3.45 → 3
      final s = AnchigiSchedule(warmup: '14:00', end: '17:00', perGame: 15, rest: 10);
      expect(s.maxRounds(3), 3);
    });

    test('휴식이 없으면 더 많이 들어간다', () {
      final s = AnchigiSchedule(warmup: '14:00', end: '17:00', perGame: 15, rest: 0);
      expect(s.maxRounds(3), 4);
    });

    test('종료가 시작보다 빠르면 99(제한 없음 취급)', () {
      final s = AnchigiSchedule(warmup: '17:00', end: '14:00');
      expect(s.maxRounds(3), 99);
    });
  });

  group('직렬화', () {
    test('JSON 왕복', () {
      final s = AnchigiSchedule(
        start: '12:00',
        warmup: '13:30',
        end: '18:00',
        perGame: 20,
        rest: 5,
      );
      final back = AnchigiSchedule.fromJson(s.toJson());
      expect(back.start, '12:00');
      expect(back.warmup, '13:30');
      expect(back.end, '18:00');
      expect(back.perGame, 20);
      expect(back.rest, 5);
    });

    test('rest가 빠진 레거시 데이터는 10으로 보정', () {
      final back = AnchigiSchedule.fromJson({'warmup': '14:00'});
      expect(back.rest, 10);
      expect(back.perGame, 15);
    });
  });
}
