// filter_sheet.dart — 동호회 필터 바텀시트 (지역/요일/대상 + 검색). 웹 filterSheet 포팅.
// 적용 시 ClubFilter 반환(null=취소). 검색어도 함께 담아 반환.
import 'package:flutter/material.dart';
import '../services/club_filter.dart';
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
  late final TextEditingController _kw =
      TextEditingController(text: widget.initial.keyword);

  static List<ChipOption> _opts(List<String> v) =>
      v.map((e) => (label: e, value: e)).toList();

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
          20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('검색 · 필터',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: NurungjiColors.dark)),
            const SizedBox(height: 14),
            TextField(
              controller: _kw,
              decoration: const InputDecoration(
                hintText: '팀 이름·지역 검색',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            _section('지역', ClubFilter.regionOptions, _regions),
            _section('요일', ClubFilter.dayOptions, _days),
            _section('대상', ClubFilter.targetOptions, _targets),
            const SizedBox(height: 18),
            Row(children: [
              OutlinedButton(onPressed: _reset, child: const Text('초기화')),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                    onPressed: _apply, child: const Text('적용하기')),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String label, List<String> options, Set<String> selected) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: NurungjiColors.dark)),
          const SizedBox(height: 8),
          MultiChoiceChips(
            options: _opts(options),
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
