// reel_editor.dart — 릴스/게시물 링크 다중 입력기. ScheduleEditor 패턴 미러링.
// controllers를 직접 변형(add/removeAt) 후 onChanged()로 부모 setState 트리거.
// 컨트롤러 소유권은 부모(폼)에 있고, 제거 행은 다음 프레임 이후 dispose.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < controllers.length; i++)
          _reelRow(controllers[i], i),
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

  Widget _reelRow(TextEditingController c, int i) {
    return Padding(
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
