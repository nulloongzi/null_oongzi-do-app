import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/club.dart';
import '../state/lunchbox_controller.dart';
import '../theme/app_theme.dart';

/// 5칸 도시락 트레이. 웹 .lunchbox-grid (6열 2행) 레이아웃 재현.
/// 상단: 반찬1/2/3 (slot 2,3,4) — 각 2칸. 하단: 밥/국 (slot 0,1) — 각 3칸.
class LunchboxTray extends StatelessWidget {
  const LunchboxTray({super.key});

  // 슬롯 placeholder (웹 i18n lb_slot_* 한국어).
  static const _placeholders = [
    '밥을\n담아주세요🍚', // slot0 rice
    '국을\n담아주세요🥘', // slot1 soup
    '반찬1🍳', // slot2
    '반찬2🥗', // slot3
    '반찬3🥢', // slot4
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LunchboxController>();
    const gap = 6.0;

    return SizedBox(
      height: 220,
      child: Column(
        children: [
          // 상단 행 (0.8fr): 반찬1/2/3 = slot 2,3,4
          Expanded(
            flex: 8,
            child: Row(
              children: [
                Expanded(child: _cell(context, c, 2)),
                const SizedBox(width: gap),
                Expanded(child: _cell(context, c, 3)),
                const SizedBox(width: gap),
                Expanded(child: _cell(context, c, 4)),
              ],
            ),
          ),
          const SizedBox(height: gap),
          // 하단 행 (1.2fr): 밥/국 = slot 0,1
          Expanded(
            flex: 12,
            child: Row(
              children: [
                Expanded(child: _cell(context, c, 0)),
                const SizedBox(width: gap),
                Expanded(child: _cell(context, c, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, LunchboxController c, int index) {
    final teamId = c.slots[index];
    final isSelected = c.selectedSlotIndex == index;
    final Club? team = teamId == null ? null : c.findClub(teamId);
    final isFilled = teamId != null;
    final isDeleted = isFilled && team == null;

    BoxDecoration decoration;
    Widget child;

    if (isSelected) {
      decoration = BoxDecoration(
        color: const Color(0xFFFFECB3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.urgent, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33FF7043),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      );
    } else if (isFilled) {
      decoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.yellow, width: 2),
      );
    } else {
      decoration = BoxDecoration(
        color: const Color(0x80FFFDE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0x66BCAAA4),
          width: 1.5,
          style: BorderStyle.solid,
        ),
      );
    }

    if (isFilled) {
      final label = isDeleted
          ? '삭제된 팀'
          : (team!.isCustom ? '🍙 ${team.name}' : team.name);
      child = Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.dark,
        ),
      );
    } else {
      child = Text(
        _placeholders[index],
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.4,
          color: Color(0xFFBCAAA4),
        ),
      );
    }

    final cell = Container(
      decoration: decoration,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: child,
    );

    return GestureDetector(
      onTap: () => _onTap(context, c, index, isFilled),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: cell),
          if (c.isEditMode && isFilled)
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () => _confirmDelete(context, c, index),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66FF5252),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '✕',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onTap(
      BuildContext context, LunchboxController c, int index, bool isFilled) {
    if (c.isEditMode) {
      // 편집모드: 빈 칸/채운 칸 모두 선택→스왑
      c.handleSlotTap(index);
      return;
    }
    if (isFilled) {
      final team = c.findClub(c.slots[index]);
      if (team != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${team.name} · ${team.schedule}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, LunchboxController c, int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('이 반찬을 도시락에서 뺄까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('빼기'),
          ),
        ],
      ),
    );
    if (ok == true) c.deleteSlot(index);
  }
}
