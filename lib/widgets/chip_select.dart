// chip_select.dart — 등록폼용 칩 선택 (단일/다중). 웹 data-val 코드와 동일하게 사용.
import 'package:flutter/material.dart';
import '../theme.dart';
import 'bounce_tap.dart';

typedef ChipOption = ({String label, String value});

class SingleChoiceChips extends StatelessWidget {
  final List<ChipOption> options;
  final String? selected;
  final ValueChanged<String> onChanged;
  const SingleChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final on = o.value == selected;
        return BounceTap(
          child: ChoiceChip(
            label: Text(o.label),
            selected: on,
            onSelected: (_) => onChanged(o.value),
            selectedColor: NurungjiColors.yellow,
            backgroundColor: NurungjiColors.chipBg,
            labelStyle: TextStyle(
              color: NurungjiColors.dark,
              fontWeight: on ? FontWeight.w800 : FontWeight.w600,
            ),
            shape: const StadiumBorder(),
            showCheckmark: false,
          ),
        );
      }).toList(),
    );
  }
}

class MultiChoiceChips extends StatelessWidget {
  final List<ChipOption> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  const MultiChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final on = selected.contains(o.value);
        return BounceTap(
          child: FilterChip(
            label: Text(o.label),
            selected: on,
            onSelected: (sel) {
              final s = Set<String>.of(selected);
              sel ? s.add(o.value) : s.remove(o.value);
              onChanged(s);
            },
            selectedColor: NurungjiColors.yellow,
            backgroundColor: NurungjiColors.chipBg,
            labelStyle: TextStyle(
              color: NurungjiColors.dark,
              fontWeight: on ? FontWeight.w800 : FontWeight.w600,
            ),
            shape: const StadiumBorder(),
            showCheckmark: false,
          ),
        );
      }).toList(),
    );
  }
}
