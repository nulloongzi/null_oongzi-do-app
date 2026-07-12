// filter_sheet.dart — 동호회 필터 바텀시트 (지역/요일/대상 + 검색). 웹 filterSheet 포팅.
// 적용 시 ClubFilter 반환(null=취소). 검색어도 함께 담아 반환.
import 'package:flutter/material.dart';
import '../services/club_filter.dart';
import '../services/i18n.dart';
import '../theme.dart';
import 'chip_select.dart';

Future<ClubFilter?> showFilterSheet(BuildContext context, ClubFilter current) {
  return showModalBottomSheet<ClubFilter>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends StatefulWidget {
  final ClubFilter initial;
  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final Set<String> _regions = {...widget.initial.regions};
  late final Set<String> _days = {...widget.initial.days};
  late final Set<String> _targets = {...widget.initial.targets};
  late final TextEditingController _kw = TextEditingController(
    text: widget.initial.keyword,
  );

  // 값(KO)은 필터 매칭용으로 유지, 라벨만 표시 언어로 변환.
  static List<ChipOption> _opts(
    List<String> v,
    String Function(String) labelOf,
  ) => v.map((e) => (label: labelOf(e), value: e)).toList();

  // 대상: 영어모드면 6인제를 맨 앞 + '🏐 6s' 강조(외국인 축), 나머지는 i18nTarget.
  List<ChipOption> _targetOpts() {
    const base = ClubFilter.targetOptions;
    if (isKo) return base.map((e) => (label: e, value: e)).toList();
    final ordered = ['6인제', ...base.where((e) => e != '6인제')];
    return ordered
        .map((e) => (label: e == '6인제' ? '🏐 6s' : i18nTarget(e), value: e))
        .toList();
  }

  @override
  void dispose() {
    _kw.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _regions.clear();
      _days.clear();
      _targets.clear();
      _kw.clear();
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      ClubFilter(
        regions: _regions,
        days: _days,
        targets: _targets,
        keyword: _kw.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('filter_title'),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: NurungjiColors.dark,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _kw,
              decoration: InputDecoration(
                hintText: t('filter_search_hint'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            _section(
              t('filter_region'),
              _opts(ClubFilter.regionOptions, i18nRegion),
              _regions,
            ),
            _section(
              t('filter_day'),
              _opts(ClubFilter.dayOptions, i18nDay),
              _days,
            ),
            _section(t('filter_target'), _targetOpts(), _targets),
            if (!isKo) _enHint(),
            const SizedBox(height: 18),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _reset,
                  child: Text(t('filter_reset')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    child: Text(t('filter_apply')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _enHint() => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: const BoxDecoration(
      color: Color(0x1AFAC710),
      border: Border(left: BorderSide(color: NurungjiColors.yellow, width: 4)),
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    child: Text(
      t('fs_en_hint'),
      style: const TextStyle(
        fontSize: 13,
        height: 1.35,
        color: NurungjiColors.dark,
      ),
    ),
  );

  Widget _section(
    String label,
    List<ChipOption> options,
    Set<String> selected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: NurungjiColors.dark,
            ),
          ),
          const SizedBox(height: 8),
          MultiChoiceChips(
            options: options,
            selected: selected,
            onChanged: (s) => setState(() {
              selected
                ..clear()
                ..addAll(s);
            }),
          ),
        ],
      ),
    );
  }
}
