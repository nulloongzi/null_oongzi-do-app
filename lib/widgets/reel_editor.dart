// reel_editor.dart — 릴스/게시물 링크 다중 입력기. 드래그 핸들로 순서 변경.
// controllers를 직접 변형(add/removeAt/reorder) 후 onChanged()로 부모 setState 트리거.
// 맨 위 행이 instaReels.first → 마커 롱프레스 미리보기로 표시되므로 순서가 의미를 가짐.
// 핸들(≡)을 꾹 눌러(long-press) 끌면 행 순서 변경. 컨트롤러 소유권은 부모(폼).
import 'package:flutter/material.dart';
import '../services/i18n.dart';
import '../theme.dart';

class ReelEditor extends StatelessWidget {
  final List<TextEditingController> controllers;
  final VoidCallback onChanged;
  const ReelEditor(
      {super.key, required this.controllers, required this.onChanged});

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
        // 폼(스크롤뷰) 안에 중첩되므로 shrinkWrap + 스크롤 잠금. 기본 핸들 대신
        // 행 안의 ≡ 핸들만 드래그를 시작(텍스트 선택과 비간섭).
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: controllers.length,
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex -= 1;
            final moved = controllers.removeAt(oldIndex);
            controllers.insert(newIndex, moved);
            onChanged();
          },
          itemBuilder: (context, i) => _reelRow(controllers[i], i, reorderable),
        ),
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
    return Padding(
      key: ValueKey(c),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (reorderable)
            // 핸들을 꾹 눌러 끌면 순서 변경(누르고 홀드 → 드래그).
            ReorderableDelayedDragStartListener(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(Icons.drag_indicator,
                    color: NurungjiColors.brown.withValues(alpha: 0.7)),
              ),
            ),
          Expanded(
            child: TextField(
              controller: c,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(hintText: t('f_reel_hint')),
            ),
          ),
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
}
