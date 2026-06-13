// 도시락 네이티브 로직 단위 테스트.
// (이전 카운터 스모크 테스트는 WebView 앱에 맞지 않아 제거됨)

import 'package:flutter_test/flutter_test.dart';

import 'package:nulloongzido/models/schedule.dart';
import 'package:nulloongzido/services/lunchbox_repository.dart';

void main() {
  group('parseScheduleText', () {
    test('단일 요일 파싱', () {
      final map = parseScheduleText('월 19:00~21:00');
      expect(map.keys, contains('월'));
      final d = map['월']!;
      expect(d.startH, 19);
      expect(d.startM, 0);
      expect(d.endH, 21);
      expect(d.text, 'PM 7:00~PM 9:00');
    });

    test('여러 세그먼트(/) 파싱', () {
      final map = parseScheduleText('월 19:00~21:00 / 수 20:00~22:00');
      expect(map.keys, containsAll(['월', '수']));
      expect(map['수']!.startHour, 20.0);
    });

    test('빈/널 입력은 빈 맵', () {
      expect(parseScheduleText(null), isEmpty);
      expect(parseScheduleText(''), isEmpty);
    });

    test('AM/PM 경계', () {
      final map = parseScheduleText('토 09:30~11:00');
      expect(map['토']!.text, 'AM 9:30~AM 11:00');
    });
  });

  group('getHourLabel', () {
    test('자정/정오/오후', () {
      expect(getHourLabel(0), 'AM 12');
      expect(getHourLabel(12), 'PM 12');
      expect(getHourLabel(13), 'PM 1');
      expect(getHourLabel(9), 'AM 9');
    });
  });

  group('normalizeSlots', () {
    test('부족분은 null 패딩', () {
      expect(normalizeSlots(['a']), ['a', null, null, null, null]);
    });
    test('초과분은 5개로 절단', () {
      expect(normalizeSlots(['a', 'b', 'c', 'd', 'e', 'f']),
          ['a', 'b', 'c', 'd', 'e']);
    });
    test('null 입력은 5개 null', () {
      expect(normalizeSlots(null), [null, null, null, null, null]);
    });
  });
}
