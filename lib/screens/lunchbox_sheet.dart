import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/lunchbox_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/diet_timetable.dart';
import '../widgets/lunchbox_tray.dart';

/// 도시락 오버레이를 모달로 띄운다. 웹 #lunchboxOverlay 재현.
Future<void> showLunchboxSheet(BuildContext context) {
  final controller = context.read<LunchboxController>();
  final auth = context.read<AuthService>();
  controller.open();

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x595D4037), // rgba(93,64,55,0.35)
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        Provider.value(value: auth),
      ],
      child: const _LunchboxSheet(),
    ),
  ).whenComplete(controller.close);
}

class _LunchboxSheet extends StatelessWidget {
  const _LunchboxSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LunchboxController>();
    final maxH = MediaQuery.of(context).size.height * 0.9;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xD9FFF8E1), // --glass-bg-darker
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xB3FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x335D4037),
                blurRadius: 50,
                offset: Offset(0, 20),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(15, 20, 15, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, c),
                const SizedBox(height: 12),
                const LunchboxTray(),
                const SizedBox(height: 12),
                _dietToggle(c),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: c.isDietOpen
                      ? Container(
                          margin: const EdgeInsets.only(top: 10),
                          height: 380,
                          decoration: BoxDecoration(
                            color: const Color(0xE6FFFFFF),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: const Color(0x99FFFFFF)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          padding: const EdgeInsets.all(10),
                          child: const DietTimetable(),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
                _authRow(context, c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _authRow(BuildContext context, LunchboxController c) {
    final auth = context.read<AuthService>();
    if (c.isLoggedIn) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: auth.signOut,
          child: const Text(
            '로그아웃',
            style: TextStyle(fontSize: 12, color: AppColors.brown),
          ),
        ),
      );
    }
    return Row(
      children: [
        const Expanded(
          child: Text(
            '로그인하면 웹과 도시락이 동기화돼요',
            style: TextStyle(fontSize: 12, color: AppColors.brown),
          ),
        ),
        TextButton(
          onPressed: () async {
            try {
              final user = await auth.signInWithGoogle();
              if (user != null) {
                await c.loadData();
                c.open(); // 로그인 후 트레이 갱신
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('로그인 실패: $e')),
                );
              }
            }
          },
          child: const Text('Google 로그인'),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, LunchboxController c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Flexible(
          child: Text(
            '도시락 🍱',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pillButton(
              label: '🍙 직접추가',
              background: AppColors.light,
              onTap: () => _promptAddCustom(context, c),
            ),
            const SizedBox(width: 8),
            _pillButton(
              label: c.isEditMode ? '✅ 완료' : '🍽 편집',
              background: c.isEditMode ? AppColors.urgent : Colors.white,
              foreground: c.isEditMode ? Colors.white : AppColors.dark,
              onTap: c.toggleEdit,
            ),
          ],
        ),
      ],
    );
  }

  Widget _pillButton({
    required String label,
    required VoidCallback onTap,
    Color background = Colors.white,
    Color foreground = AppColors.dark,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dietToggle(LunchboxController c) {
    return Material(
      color: AppColors.brown,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: c.toggleDiet,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            c.isDietOpen ? '📅 식단표 접기' : '📅 식단표 (스케줄 확인)',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _promptAddCustom(
      BuildContext context, LunchboxController c) async {
    final nameCtrl = TextEditingController(text: '개인운동');
    final timeCtrl = TextEditingController(text: '월 19:00~21:00');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🍙 직접 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '팀/일정 이름',
                hintText: '예: 개인운동',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: timeCtrl,
              decoration: const InputDecoration(
                labelText: '시간',
                hintText: '예: 월 19:00~21:00',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('담기'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final schedule = timeCtrl.text.trim();
    if (name.isEmpty || schedule.isEmpty) return;

    final idx = c.addCustomTeam(name, schedule);
    if (!context.mounted) return;
    if (idx == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('도시락이 꽉 찼습니다! (최대 5개) 🍱')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('나만의 메뉴가 추가되었습니다! 🍙')),
      );
    }
  }
}
