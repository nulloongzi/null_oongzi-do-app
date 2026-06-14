// lunchbox_screen.dart — 내 도시락(찜한 팀 5칸 + 커스텀 + 식단표). 웹 lunchbox.js 포팅.
// 개선: 빈 상태 안내 · 드래그 순서 변경 · 슬롯 일정 요약 · 빼기 확인 · 식단표 색상 범례.
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../services/data_repository.dart';
import '../services/i18n.dart';
import '../services/lunchbox_service.dart';
import '../services/schedule_parse.dart';
import '../theme.dart';
import '../widgets/app_sheet.dart';
import '../widgets/diet_grid.dart';

/// 도시락 팝업: 풀스크린 라우트 대신 지도 위로 뜨는 모달 바텀시트(웹 도시락 오버레이 대응).
Future<void> showLunchboxSheet(BuildContext context) =>
    showAppSheet<void>(context, child: const LunchboxScreen());

/// 슬롯/식단표 공통 색(밥·국·반찬1~3). 위치(=반찬 칸)에 색이 고정된다.
const kSlotBg = [
  Color(0xFFFFFDE7), Color(0xFFFFF3E0), Color(0xFFF1F8E9),
  Color(0xFFFBE9E7), Color(0xFFF3E5F5),
];
const kSlotBorder = [
  Color(0xFFFBC02D), Color(0xFFF57C00), Color(0xFF689F38),
  Color(0xFFD84315), Color(0xFF8E24AA),
];

class LunchboxScreen extends StatefulWidget {
  const LunchboxScreen({super.key});

  @override
  State<LunchboxScreen> createState() => _LunchboxScreenState();
}

class _LunchboxScreenState extends State<LunchboxScreen> {
  final _svc = LunchboxService();
  final _repo = DataRepository();
  LunchboxData? _data;
  final Map<String, Club> _clubs = {};
  bool _loading = true;
  bool _showDiet = false;

  List<String> get _placeholders => [
        t('lb_slot_rice'),
        t('lb_slot_soup'),
        t('lb_slot_side1'),
        t('lb_slot_side2'),
        t('lb_slot_side3'),
      ];

  int get _filledCount =>
      _data?.bookmarks.where((e) => e != null).length ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _repo.currentUid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([_repo.loadClubs(), _svc.load(uid)]);
      final clubs = results[0] as List<Club>;
      _clubs
        ..clear()
        ..addEntries(clubs.map((c) => MapEntry(c.id, c)));
      _data = results[1] as LunchboxData;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _save() async {
    final uid = _repo.currentUid;
    final d = _data;
    if (uid == null || d == null) return;
    try {
      await _svc.save(uid, d);
    } catch (e) {
      _snack('${t('lb_save_fail')}: $e');
    }
  }

  Future<void> _removeSlot(int i) async {
    final d = _data;
    if (d == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        content: Text(t('lb_remove_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: Text(t('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: Text(t('lb_remove'))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => d.bookmarks[i] = null);
    await _save();
    _snack(t('lb_removed'));
  }

  // 드래그로 순서 변경. 칸 색(반찬 위치)은 고정, 팀만 이동한다.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final d = _data;
    if (d == null) return;
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = d.bookmarks.removeAt(oldIndex);
      d.bookmarks.insert(newIndex, item);
    });
    await _save();
  }

  Future<void> _addCustom() async {
    final uid = _repo.currentUid;
    if (uid == null) return;
    final name = await _prompt(t('lb_team_name'), t('lb_add_name_hint'));
    if (name == null || name.trim().isEmpty) return;
    final sched = await _prompt(t('lb_sched_hint'), t('lb_add_sched_hint'));
    if (sched == null || sched.trim().isEmpty) return;
    final err = await _svc.addCustomTeam(uid, name.trim(), sched.trim());
    if (err != null) {
      _snack(err);
      return;
    }
    await _load();
    _snack(t('lb_added'));
  }

  Future<String?> _prompt(String title, String hint) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: c,
            autofocus: true,
            decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx), child: Text(t('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(dctx, c.text),
              child: Text(t('confirm'))),
        ],
      ),
    );
  }

  ({String name, bool isCustom, String? sched, List<SchedEvent> events})?
      _resolve(String id) {
    final d = _data;
    if (d == null) return null;
    if (d.customTeams.containsKey(id)) {
      final m = d.customTeams[id];
      final name =
          (m is Map ? m['name'] : null) as String? ?? t('lb_custom_team');
      final sched = (m is Map ? m['schedule'] : null) as String?;
      return (
        name: name,
        isCustom: true,
        sched: sched,
        events: eventsFromText(sched)
      );
    }
    final c = _clubs[id];
    if (c != null) {
      final ev = (c.scheduleRaw != null && c.scheduleRaw!.isNotEmpty)
          ? eventsFromRaw(c.scheduleRaw)
          : eventsFromText(c.schedule);
      return (name: c.name, isCustom: false, sched: c.schedule, events: ev);
    }
    return null;
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
            Row(
              children: [
                Expanded(child: SheetTitle(t('lunchbox_title'))),
                if (!_loading && _filledCount > 0) _countPill(),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filledCount == 0)
              _emptyState()
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  t('lb_drag_hint'),
                  style: const TextStyle(
                      fontSize: 12, color: NurungjiColors.brown),
                ),
              ),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: _onReorder,
                children: [for (var i = 0; i < 5; i++) _slotTile(i)],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addCustom,
                icon: const Icon(Icons.add, size: 18),
                label: Text(t('add_custom')),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(t('lb_diet'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: NurungjiColors.dark)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _showDiet = !_showDiet),
                    child: Text(_showDiet ? t('collapse') : t('expand')),
                  ),
                ],
              ),
              if (_showDiet) ...[
                _legend(),
                DietGrid(teams: _dietTeams()),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _countPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: NurungjiColors.chipBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${t('lb_count')} $_filledCount/5',
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: NurungjiColors.chipFg),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Column(
        children: [
          const Text('🍱', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            t('lb_empty_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: NurungjiColors.dark),
          ),
          const SizedBox(height: 8),
          Text(
            t('lb_empty_desc'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, height: 1.5, color: NurungjiColors.brown),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _addCustom,
            icon: const Icon(Icons.add, size: 18),
            label: Text(t('add_custom')),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(t('lb_find_on_map')),
          ),
        ],
      ),
    );
  }

  /// 식단표 색상 범례: 담은 팀 ↔ 칸 색 매핑.
  Widget _legend() {
    final teams = _dietTeams();
    if (teams.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        children: [
          for (final tm in teams)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: kSlotBorder[tm.slotIdx % 5],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  tm.isCustom ? '🍙 ${tm.name}' : tm.name,
                  style: const TextStyle(
                      fontSize: 11, color: NurungjiColors.dark),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<DietTeam> _dietTeams() {
    final out = <DietTeam>[];
    final d = _data;
    if (d == null) return out;
    for (var i = 0; i < 5; i++) {
      final id = d.bookmarks[i];
      if (id == null) continue;
      final r = _resolve(id);
      if (r == null) continue;
      out.add(DietTeam(
          name: r.name, isCustom: r.isCustom, slotIdx: i, events: r.events));
    }
    return out;
  }

  Widget _slotTile(int i) {
    final id = _data?.bookmarks[i];
    final r = id == null ? null : _resolve(id);
    final filled = id != null;
    final label = !filled
        ? _placeholders[i]
        : (r == null
            ? t('deleted_team')
            : (r.isCustom ? '🍙 ${r.name}' : r.name));
    final sched = filled && r != null ? (r.sched ?? '') : '';

    return Padding(
      key: ValueKey('lb-slot-$i'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          color: filled ? kSlotBg[i] : NurungjiColors.chipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: kSlotBorder[i], width: 5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                      color:
                          filled ? NurungjiColors.dark : NurungjiColors.brown,
                    ),
                  ),
                  if (sched.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sched,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: NurungjiColors.brown),
                    ),
                  ],
                ],
              ),
            ),
            if (filled) ...[
              IconButton(
                onPressed: () => _removeSlot(i),
                icon: const Icon(Icons.close,
                    size: 18, color: NurungjiColors.brown),
                tooltip: t('lb_remove'),
                visualDensity: VisualDensity.compact,
              ),
              ReorderableDragStartListener(
                index: i,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.drag_handle,
                      size: 20, color: NurungjiColors.brown),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
