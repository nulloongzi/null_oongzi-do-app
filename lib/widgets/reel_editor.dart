// reel_editor.dart — 릴스/게시물 링크 다중 입력기. ScheduleEditor 패턴 미러링.
// controllers를 직접 변형(add/removeAt/swap) 후 onChanged()로 부모 setState 트리거.
// 맨 위 행이 instaReels.first → 마커 롱프레스 미리보기로 표시되므로 위/아래 순서 변경 지원.
// 컨트롤러 소유권은 부모(폼)에 있고, 제거 행은 다음 프레임 이후 dispose.
import 'package:flutter/material.dart';
import '../services/i18n.dart';
import '../theme.dart';

class ReelEditor extends StatelessWidget {
  final List<TextEditingController> controllers;
  final VoidCallback onChanged;
  const ReelEditor(
      {super.key, required this.controllers, required this.onChanged});

  void _swap(int a, int b) {
    final tmp = controllers[a];
    controllers[a] = controllers[b];
    controllers[b] = tmp;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final reorderable = controllers.length >= 2; // 2개 이상일 때만 순서 UI 노출
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reorderable)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              t('reel_first_hint'),
              style: const TextStyle(fontSize: 12, color: NurungjiColors.brown),
            ),
          ),
        for (var i = 0; i < controllers.length; i++)
          _reelRow(controllers[i], i, reorderable),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            controllers.add(TextEditingController());
            onChanged();
          },
          icon: const Icon(Icons.add),
          label: Text(t('reel_add')),
        ),
      ],
    );
  }

  // key: 컨트롤러 identity로 행 추적 → 순서 변경/삭제 시 입력·포커스가 올바른 행을 따라감.
  Widget _reelRow(TextEditingController c, int i, bool reorderable) {
    final last = i == controllers.length - 1;
    return Padding(
      key: ValueKey(c),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: c,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(hintText: t('f_reel_hint')),
            ),
          ),
          if (reorderable) ...[
            _miniIcon(Icons.arrow_upward, t('move_up'),
                i == 0 ? null : () => _swap(i, i - 1)),
            _miniIcon(Icons.arrow_downward, t('move_down'),
                last ? null : () => _swap(i, i + 1)),
          ],
          IconButton(
            onPressed: () {
              final removed = controllers.removeAt(i);
              onChanged();
              // 리빌드로 TextField가 트리에서 빠진 뒤 dispose(사용 후 dispose 방지).
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => removed.dispose());
            },
            icon: const Icon(Icons.delete_outline, color: NurungjiColors.brown),
            tooltip: t('delete'),
          ),
        ],
      ),
    );
  }

  // 화살표 버튼: 양 끝(첫/마지막) 행에선 비활성(회색)으로 표시.
  Widget _miniIcon(IconData icon, String tip, VoidCallback? onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      color: NurungjiColors.dark,
      disabledColor: Colors.black26,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      tooltip: tip,
    );
  }
}
