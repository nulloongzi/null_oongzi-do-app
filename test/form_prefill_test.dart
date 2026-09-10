// 수정 폼 프리필 — 저장된 값이 폼으로 되돌아오는가.
//
// 2026-09-10 신고: 팀 정보 수정을 누르면 모집 대상 '기타'란과 운동 시간이 빈 채로
// 떠서 다시 입력해야 했다. 불편에서 끝나지 않는다 — 기타란은 그대로 저장하면
// 괄호 안이 **소리 없이 삭제**된다(저장은 `base (note)` 로 합치는데 복원이
// note 를 못 꺼냈다).
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/models/schedule_block.dart';
import 'package:nulloongzido/services/schedule_parse.dart';
import 'package:nulloongzido/services/target_parse.dart';

const chips = ['성인', '대학생', '청소년', '무관', '여성전용', '남성전용', '선출가능', '6인제'];

void main() {
  group('parseTargetValue — 칩 + 기타 메모 복원', () {
    test('괄호 안을 메모로 되살린다 (회귀)', () {
      final r = parseTargetValue('성인, 대학생 (구력 1년 이상)', chips);
      expect(r.chips, ['성인', '대학생']);
      expect(r.note, '구력 1년 이상');
    });

    test('칩만 있으면 메모는 빈 값', () {
      final r = parseTargetValue('성인, 여성전용', chips);
      expect(r.chips, ['성인', '여성전용']);
      expect(r.note, '');
    });

    test('메모만 있는 경우', () {
      final r = parseTargetValue('(주말만 운영)', chips);
      expect(r.chips, isEmpty);
      expect(r.note, '주말만 운영');
    });

    // 칩 도입 전 자유입력분. 버리면 재저장 때 사라진다.
    test('괄호 없는 잔여 표현도 메모로 살린다', () {
      final r = parseTargetValue('성인 남녀', chips);
      expect(r.chips, ['성인']);
      expect(r.note, '남녀');
    });

    test('구분자만 남으면 메모는 비운다', () {
      expect(parseTargetValue('성인, 대학생', chips).note, '');
      expect(parseTargetValue('성인 · 청소년', chips).note, '');
    });

    test('빈 값·null 안전', () {
      for (final v in [null, '', '   ']) {
        final r = parseTargetValue(v, chips);
        expect(r.chips, isEmpty, reason: '$v');
        expect(r.note, '', reason: '$v');
      }
    });

    // 저장(_targetValue)과 복원이 맞물리는지 — 왕복해도 그대로여야 한다.
    test('저장 포맷 왕복', () {
      for (final (base, note) in [
        ('성인, 대학생', '구력 1년 이상'),
        ('여성전용', ''),
        ('', '문의 후 결정'),
      ]) {
        final saved = note.isEmpty
            ? base
            : (base.isEmpty ? note : '$base ($note)');
        final r = parseTargetValue(saved, chips);
        expect(r.chips.join(', '), base, reason: saved);
        expect(r.note, note, reason: saved);
      }
    });
  });

  group('eventsFromText — 요일 귀속', () {
    String hhmm(double h) {
      final hh = h.floor();
      final mm = ((h - hh) * 60).round();
      return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
    }

    // 예전엔 [,/] 로 잘라서 이게 세 조각이 됐고 **금요일만** 시간을 가졌다.
    test('요일을 쉼표로 나열해도 전부 같은 시간을 갖는다 (회귀)', () {
      final ev = eventsFromText('월, 수, 금 19:00~22:00');
      expect(ev.map((e) => e.day).toList(), ['월', '수', '금']);
      for (final e in ev) {
        expect(hhmm(e.start), '19:00');
        expect(hhmm(e.end), '22:00');
      }
    });

    test('블록마다 다른 시간이면 각자 갖는다', () {
      final ev = eventsFromText('수 19:00~21:30, 일 14:00~18:00');
      expect(ev.length, 2);
      expect(hhmm(ev.firstWhere((e) => e.day == '수').start), '19:00');
      expect(hhmm(ev.firstWhere((e) => e.day == '일').start), '14:00');
    });

    test("예전 '/' 구분자도 동작", () {
      final ev = eventsFromText('수 19:00~21:30 / 일 14:00~18:00');
      expect(ev.length, 2);
      expect(hhmm(ev.firstWhere((e) => e.day == '일').end), '18:00');
    });

    test('요일이 시간 뒤에 와도 잡는다', () {
      final ev = eventsFromText('19:00~22:00 월수금');
      expect(ev.map((e) => e.day).toSet(), {'월', '수', '금'});
    });

    test('끝시각이 시작보다 빠르면 버린다', () {
      expect(eventsFromText('월 22:00~19:00'), isEmpty);
    });
  });

  group('ScheduleBlock.groupFromText — schedule_raw 없는 문서', () {
    test('요일별 시간을 블록으로 되살린다 (회귀)', () {
      final b = ScheduleBlock.groupFromText('수 19:00~21:30, 일 14:00~18:00');
      expect(b.length, 2);
      final wed = b.firstWhere((x) => x.days.contains('수'));
      expect(wed.start, '19:00');
      expect(wed.end, '21:30');
      final sun = b.firstWhere((x) => x.days.contains('일'));
      expect(sun.start, '14:00');
    });

    test('같은 시간대는 한 블록으로 묶고 요일 순서를 지킨다', () {
      final b = ScheduleBlock.groupFromText('금 19:00~22:00, 월 19:00~22:00');
      expect(b.length, 1);
      expect(b.first.days, ['월', '금']);
    });

    test('한 자리 시각도 HH:MM 으로 (select 값과 맞아야 선택됨)', () {
      final b = ScheduleBlock.groupFromText('토 6:00~8:30');
      expect(b.first.start, '06:00');
      expect(b.first.end, '08:30');
    });

    test('빈 값·시간 없는 글은 빈 목록 (호출부가 빈 블록 하나를 띄운다)', () {
      for (final v in [null, '', '협의 후 결정']) {
        expect(ScheduleBlock.groupFromText(v), isEmpty, reason: '$v');
      }
    });
  });
}
