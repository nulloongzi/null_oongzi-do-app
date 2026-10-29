// anchigi_screen.dart — 안치기 전체화면. 4탭(배치·명단·기록·설명)을 묶는다.
// 로그인 불필요한 로컬 도구라 Firebase에 아무것도 쓰지 않는다.
import 'package:flutter/material.dart';

import '../services/anchigi/anchigi_store.dart';
import '../services/deep_link_service.dart' show kCaptureMode;
import '../services/i18n.dart';
import '../theme.dart';
import '../widgets/anchigi/anchigi_help_tab.dart';
import '../widgets/anchigi/anchigi_lineup_tab.dart';
import '../widgets/anchigi/anchigi_record_tab.dart';
import '../widgets/anchigi/anchigi_roster_tab.dart';

class AnchigiScreen extends StatefulWidget {
  const AnchigiScreen({super.key});

  @override
  State<AnchigiScreen> createState() => _AnchigiScreenState();
}

/// 캡처 시연 명령(값이 바뀌면 실행, 같은 명령을 다시 보내려면 뒤에 '#n'). 화면과 탭이 함께 듣는다.
///   화면: 'backup' 'reset' 'restore' 'tab:N' 'sport:v6|v9'
///   배치 탭: 'draw' 'game:N' 'commit' 'scroll:end'
///   명단 탭: 'paste:이름,이름,…'(한 자씩 쳐 넣고 '한 번에 추가')
/// 명단은 폰에 저장되는 개인 자료라, 시연 전에 백업하고 끝나면(또는 화면이 닫히면) 되돌린다.
final ValueNotifier<String> anchigiDemo = ValueNotifier<String>('');

/// '#n' 꼬리를 뗀 명령.
String anchigiDemoCmd() => anchigiDemo.value.split('#').first;

class _AnchigiScreenState extends State<AnchigiScreen>
    with SingleTickerProviderStateMixin {
  // 상태 조각이 탭을 넘나들며 얽혀 있어 화면이 저장소를 소유하고 탭에 넘긴다.
  final _store = AnchigiStore();
  late final TabController _tabs = TabController(length: 4, vsync: this);

  String? _demoBackup; // 시연 전 명단·기록(끝나면 되돌린다)

  @override
  void initState() {
    super.initState();
    _store.load();
    if (kCaptureMode) anchigiDemo.addListener(_onDemo);
  }

  void _onDemo() {
    final c = anchigiDemoCmd();
    if (!mounted || !_store.loaded) return;
    if (c == 'backup') {
      _demoBackup = _store.exportJson();
    } else if (c == 'reset') {
      if (_demoBackup == null) return; // 백업 없이 지우지 않는다
      _store.clearRoster();
      _store.resetStats();
      _store.setSport('v6');
    } else if (c == 'restore') {
      _restoreDemo();
    } else if (c.startsWith('tab:')) {
      _tabs.animateTo(int.tryParse(c.substring(4)) ?? 0);
    } else if (c.startsWith('sport:')) {
      _store.setSport(c.substring(6));
    }
  }

  void _restoreDemo() {
    final b = _demoBackup;
    if (b == null) return;
    _store.importJson(b);
    _demoBackup = null;
  }

  @override
  void dispose() {
    anchigiDemo.removeListener(_onDemo);
    _restoreDemo(); // 시연이 중간에 끊겨도 폰의 명단은 원래대로
    _tabs.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      // 전체화면 라우트라 main.dart의 언어 리빌드가 여기까지 닿지 않는다.
      // appLang을 직접 구독해야 화면 안 EN/KO 토글이 즉시 반영된다.
      ValueListenableBuilder<String>(
        valueListenable: appLang,
        builder: (context, _, _) => _build(context),
      );

  Widget _build(BuildContext context) => Scaffold(
    backgroundColor: NurungjiColors.bg,
    appBar: AppBar(
      title: Text(
        t('ag_title'),
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
      ),
      actions: [
        // 지도 화면과 같은 자리에서 언어를 바꿀 수 있게.
        TextButton(
          onPressed: toggleLang,
          style: TextButton.styleFrom(foregroundColor: NurungjiColors.dark),
          child: Text(
            isKo ? 'EN' : 'KO',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
      ],
      bottom: TabBar(
        controller: _tabs,
        // 노란 AppBar 위라 기본 대비가 부족해 색을 명시한다.
        labelColor: NurungjiColors.dark,
        unselectedLabelColor: NurungjiColors.dark.withValues(alpha: .55),
        indicatorColor: NurungjiColors.dark,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        tabs: [
          Tab(text: t('ag_tab_lineup')),
          Tab(text: t('ag_tab_roster')),
          Tab(text: t('ag_tab_record')),
          Tab(text: t('ag_tab_help')),
        ],
      ),
    ),
    body: ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        if (!_store.loaded) {
          return const Center(
            child: CircularProgressIndicator(color: NurungjiColors.yellow),
          );
        }
        return TabBarView(
          controller: _tabs,
          children: [
            AnchigiLineupTab(
              store: _store,
              onGoRoster: () => _tabs.animateTo(1),
            ),
            AnchigiRosterTab(store: _store),
            AnchigiRecordTab(store: _store),
            const AnchigiHelpTab(),
          ],
        );
      },
    ),
  );
}
