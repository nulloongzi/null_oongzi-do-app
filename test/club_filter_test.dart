// ClubFilter 순수 로직 단위 테스트 (Tier 1).
// 웹 filters.js applyFilters 포팅 검증 — 지역 묶음/요일/대상/키워드 매칭.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/models/club.dart';
import 'package:nulloongzido/services/club_filter.dart';

Club _club({
  String name = '테스트클럽',
  String? address,
  String? schedule,
  String? target,
}) => Club(
  id: 'x',
  name: name,
  address: address,
  schedule: schedule,
  target: target,
);

void main() {
  group('지역 매칭', () {
    test('단순 startsWith', () {
      final c = _club(address: '서울특별시 강남구');
      expect(const ClubFilter(regions: {'서울'}).matches(c), true);
      expect(const ClubFilter(regions: {'경기'}).matches(c), false);
    });
    test('묶음 지역(충청 = 충남/충북/대전/세종)', () {
      expect(
        const ClubFilter(regions: {'충청'}).matches(_club(address: '대전 유성구')),
        true,
      );
      expect(
        const ClubFilter(regions: {'충청'}).matches(_club(address: '세종시')),
        true,
      );
      expect(
        const ClubFilter(regions: {'충청'}).matches(_club(address: '서울 강남')),
        false,
      );
    });
    test('묶음 지역(경상 = 대구/부산/울산/경남/경북)', () {
      expect(
        const ClubFilter(regions: {'경상'}).matches(_club(address: '부산 해운대')),
        true,
      );
    });
  });

  group('요일 매칭', () {
    test('schedule 포함 요일', () {
      final c = _club(schedule: '월요일 수요일 19:00~22:00');
      expect(const ClubFilter(days: {'월'}).matches(c), true);
      expect(const ClubFilter(days: {'금'}).matches(c), false);
    });
    test("'매일' 은 모든 요일 필터 통과", () {
      final c = _club(schedule: '매일 20:00~22:00');
      expect(const ClubFilter(days: {'화'}).matches(c), true);
    });
  });

  group('대상 매칭', () {
    test("특수필터 없으면 '무관' 폴백 포함", () {
      final c = _club(target: '무관');
      expect(const ClubFilter(targets: {'성인'}).matches(c), true);
    });
    test("특수필터(여성전용 등)면 '무관' 폴백 제외", () {
      final c = _club(target: '무관');
      expect(const ClubFilter(targets: {'여성전용'}).matches(c), false);
    });
    test('부분일치', () {
      expect(
        const ClubFilter(targets: {'대학생'}).matches(_club(target: '대학생 성인')),
        true,
      );
    });
  });

  group('키워드', () {
    test('name 또는 address 부분일치', () {
      final c = _club(name: '강남스파이크', address: '서울 강남구');
      expect(const ClubFilter(keyword: '스파이크').matches(c), true);
      expect(const ClubFilter(keyword: '강남').matches(c), true);
      expect(const ClubFilter(keyword: '없는말').matches(c), false);
    });
  });

  group('복합 + 빈 필터', () {
    test('빈 필터는 isEmpty, 모든 클럽 통과', () {
      const f = ClubFilter();
      expect(f.isEmpty, true);
      expect(f.matches(_club()), true);
    });
    test('AND 결합 (지역 AND 키워드)', () {
      final c = _club(name: '스파이크', address: '서울 강남');
      expect(
        const ClubFilter(regions: {'서울'}, keyword: '스파이크').matches(c),
        true,
      );
      expect(
        const ClubFilter(regions: {'경기'}, keyword: '스파이크').matches(c),
        false,
      );
    });
    test('chipCount 합산', () {
      const f = ClubFilter(regions: {'서울'}, days: {'월', '수'}, targets: {'성인'});
      expect(f.chipCount, 4);
    });
  });
}
