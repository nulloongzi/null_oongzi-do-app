// schedule_editor.dart — 요일·시간 블록 편집기. registration.js addScheduleBlock 대체.
// blocks를 직접 변형 후 onChanged()로 부모 setState 트리거.
import 'package:flutter/material.dart';
import '../models/schedule_block.dart';
import '../services/i18n.dart';
import '../theme.dart';
import 'chip_select.dart';

class ScheduleEditor extends StatelessWidget {
  final List<ScheduleBlock> blocks;
  final VoidCallback onChanged;
  const ScheduleEditor({
    super.key,
    required this.blocks,
    required this.onChanged,
  });

  // 요일 칩: 라벨만 현지화, 값은 한글 유지(웹 registration.js:57 i18nDay 대응).
  // 언어 토글 시 재평가되도록 getter(정적 캐시 금지).
  static List<ChipOption> get _dayOptions => ScheduleBlock.dayOrder
      .map((d) => (label: i18nDay(d), value: d))
      .toList();

  @override
  Widget build(BuildContext context) {
    final times = ScheduleBlock.timeOptions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) _blockCard(blocks[i], i, times),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            blocks.add(ScheduleBlock());
            onChanged();
          },
          icon: const Icon(Icons.add),
          label: Text(t('sched_add')),
        ),
      ],
    );
  }

  Widget _blockCard(ScheduleBlock b, int i, List<String> times) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MultiChoiceChips(
            options: _dayOptions,
            selected: b.days.toSet(),
            onChanged: (s) {
              b.days = ScheduleBlock.dayOrder.where(s.contains).toList();
              onChanged();
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _timeDropdown(times, b.start, (v) {
                b.start = v;
                onChanged();
              }),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('~'),
              ),
              _timeDropdown(times, b.end, (v) {
                b.end = v;
                onChanged();
              }),
              const Spacer(),
              IconButton(
                onPressed: () {
                  blocks.removeAt(i);
                  onChanged();
                },
                icon: const Icon(
                  Icons.delete_outline,
                  color: NurungjiColors.brown,
                ),
                tooltip: t('delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeDropdown(
    List<String> times,
    String value,
    ValueChanged<String> onCh,
  ) {
    final v = times.contains(value) ? value : times.first;
    return DropdownButton<String>(
      value: v,
      items: times
          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
          .toList(),
      onChanged: (x) {
        if (x != null) onCh(x);
      },
    );
  }
}
