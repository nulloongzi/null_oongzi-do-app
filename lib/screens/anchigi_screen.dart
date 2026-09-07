// anchigi_screen.dart — 안치기 전체화면. 4탭(배치·명단·기록·설명)을 묶는다.
// 로그인 불필요한 로컬 도구라 Firebase에 아무것도 쓰지 않는다.
import 'package:flutter/material.dart';

import '../services/anchigi/anchigi_store.dart';
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

class _AnchigiScreenState extends State<AnchigiScreen>
    with SingleTickerProviderStateMixin {
  // 상태 조각이 탭을 넘나들며 얽혀 있어 화면이 저장소를 소유하고 탭에 넘긴다.
  final _store = AnchigiStore();
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  void dispose() {
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
