// add_custom_team_sheet.dart — 도시락 '🍙 직접추가' 폼. 팀 등록 폼과 동일 톤(흰 배경 시트).
// 지도에 없는 나만의 팀/일정을 이름 + 요일·시간 블록으로 입력 → (name, schedule) 반환.
import 'package:flutter/material.dart';
import '../models/schedule_block.dart';
import '../services/i18n.dart';
import '../theme.dart';
import '../widgets/app_sheet.dart';
import '../widgets/schedule_editor.dart';

/// 직접추가 시트. 완료 시 (name, schedule) 레코드 반환, 취소면 null.
Future<({String name, String schedule})?> showAddCustomTeamSheet(
        BuildContext context) =>
    showAppSheet<({String name, String schedule})>(
      context,
      background: Colors.white,
      child: const AddCustomTeamSheet(),
    );

class AddCustomTeamSheet extends StatefulWidget {
  const AddCustomTeamSheet({super.key});

  @override
  State<AddCustomTeamSheet> createState() => _AddCustomTeamSheetState();
}

class _AddCustomTeamSheetState extends State<AddCustomTeamSheet> {
  final _name = TextEditingController();
  final List<ScheduleBlock> _blocks = [ScheduleBlock()];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('lb_team_name'))));
      return;
    }
    Navigator.pop(
        context, (name: name, schedule: ScheduleBlock.toText(_blocks)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle('🍙 ${t('add_custom')}'),
            _group(
              t('lb_team_name'),
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(hintText: t('lb_add_name_hint')),
              ),
            ),
            _group(
              t('lb_sched_hint'),
              ScheduleEditor(blocks: _blocks, onChanged: () => setState(() {})),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _submit,
              child: Text(t('add_custom')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: NurungjiColors.dark)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
