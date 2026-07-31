// club_filter.dart — 동호회 필터/검색 순수 로직. 웹 filters.js applyFilters 매칭 포팅.
// 지역(주소 startsWith, 충청/전라/경상 묶음) · 요일(schedule 포함, '매일') · 대상(부분일치,
// 특수필터 없으면 '무관' 포함) · 키워드(name/address 포함).
import '../models/club.dart';
import 'region_match.dart';

class ClubFilter {
  final Set<String> regions;
  final Set<String> days;
  final Set<String> targets;
  final String keyword;

  const ClubFilter({
    this.regions = const {},
    this.days = const {},
    this.targets = const {},
    this.keyword = '',
  });

  static const regionOptions = regionOptionsAll;
  static const dayOptions = ['월', '화', '수', '목', '금', '토', '일'];
  static const targetOptions = [
    '성인',
    '대학생',
    '청소년',
    '여성전용',
    '남성전용',
    '선출가능',
    '6인제',
  ];
  static const _special = {'여성전용', '남성전용', '선출가능', '6인제'};

  int get chipCount => regions.length + days.length + targets.length;
  bool get isEmpty => chipCount == 0 && keyword.trim().isEmpty;

  ClubFilter copyWith({
    Set<String>? regions,
    Set<String>? days,
    Set<String>? targets,
    String? keyword,
  }) => ClubFilter(
    regions: regions ?? this.regions,
    days: days ?? this.days,
    targets: targets ?? this.targets,
    keyword: keyword ?? this.keyword,
  );

  bool matches(Club c) {
    final addr = c.address ?? '';

    if (regions.isNotEmpty) {
      // 광역 묶음(충청/전라/경상) 전개는 region_match.dart 에 공통화 — 픽업 필터와 규칙 공유.
      if (!regions.any((r) => regionMatchesAddress(addr, r))) return false;
    }

    if (days.isNotEmpty) {
      final sched = (c.schedule ?? '').replaceAll('요일', '');
      var ok = sched.contains('매일');
      if (!ok) {
        for (final d in days) {
          if (sched.contains(d)) {
            ok = true;
            break;
          }
        }
      }
      if (!ok) return false;
    }

    if (targets.isNotEmpty) {
      final tgt = c.target ?? '';
      var ok = false;
      for (final t in targets) {
        if (tgt.contains(t)) {
          ok = true;
          break;
        }
      }
      final hasSpecial = targets.any(_special.contains);
      if (!ok && !hasSpecial && tgt.contains('무관')) ok = true;
      if (!ok) return false;
    }

    final kw = keyword.trim();
    if (kw.isNotEmpty) {
      if (!c.name.contains(kw) && !addr.contains(kw)) return false;
    }

    return true;
  }
}
