// lunchbox_screen.dart — 내 도시락(찜한 팀 5칸 + 커스텀 + 식단표). 웹 lunchbox.js 포팅.
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
  int? _selectedSlot; // 순서 바꾸기: 선택된 칸

  List<String> get _placeholders => [
        t('lb_slot_rice'),
        t('lb_slot_soup'),
        t('lb_slot_side1'),
        t('lb_slot_side2'),
        t('lb_slot_side3'),
      ];
  static const _slotBg = [
    Color(0xFFFFFDE7), Color(0xFFFFF3E0), Color(0xFFF1F8E9),
    Color(0xFFFBE9E7), Color(0xFFF3E5F5),
  ];
  static const _slotBorder = [
    Color(0xFFFBC02D), Color(0xFFF57C00), Color(0xFF689F38),
    Color(0xFFD84315), Color(0xFF8E24AA),
  ];

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

  Future<bool> _save() async {
    final uid = _repo.currentUid;
    final d = _data;
    if (uid == null || d == null) return false;
    try {
      await _svc.save(uid, d);
      return true;
    } catch (e) {
      _snack('${t('lb_save_fail')}: $e');
      return false;
    }
  }

  Future<void> _removeSlot(int i) async {
    final d = _data;
    if (d == null) return;
    final prev = d.bookmarks[i];
    setState(() {
      d.bookmarks[i] = null;
      _selectedSlot = null;
    });
    if (!await _save() && mounted) {
      setState(() => d.bookmarks[i] = prev); // 저장 실패 → 롤백
    }
  }

  // 탭 1: 칸 선택, 탭 2: 두 칸 스왑(순서 변경) → 저장.
  Future<void> _onSlotTap(int i) async {
    final d = _data;
    if (d == null) return;
    if (_selectedSlot == null) {
      if (d.bookmarks[i] == null) return; // 빈 칸은 선택 시작 불가
      setState(() => _selectedSlot = i);
      return;
    }
    if (_selectedSlot == i) {
      setState(() => _selectedSlot = null); // 같은 칸 다시 → 해제
      return;
    }
    final from = _selectedSlot!;
    final a = d.bookmarks[from];
    final b = d.bookmarks[i];
    d.bookmarks[from] = b;
    d.bookmarks[i] = a;
    setState(() => _selectedSlot = null);
    if (!await _save() && mounted) {
      setState(() {
        d.bookmarks[from] = a; // 저장 실패 → 롤백
        d.bookmarks[i] = b;
      });
    }
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

  ({String name, bool isCustom, List<SchedEvent> events})? _resolve(String id) {
    final d = _data;
    if (d == null) return null;
    if (d.customTeams.containsKey(id)) {
      final m = d.customTeams[id];
      final name = (m is Map ? m['name'] : null) as String? ?? t('lb_custom_team');
      final sched = (m is Map ? m['schedule'] : null) as String?;
      return (name: name, isCustom: true, events: eventsFromText(sched));
    }
    final c = _clubs[id];
    if (c != null) {
      final ev = (c.scheduleRaw != null && c.scheduleRaw!.isNotEmpty)
          ? eventsFromRaw(c.scheduleRaw)
          : eventsFromText(c.schedule);
      return (name: c.name, isCustom: false, events: ev);
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
            SheetTitle(t('lunchbox_title')),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _selectedSlot == null
                      ? t('lb_reorder_hint')
                      : t('lb_reorder_pick'),
                  style: const TextStyle(
                      fontSize: 12, color: NurungjiColors.brown),
                ),
              ),
              for (var i = 0; i < 5; i++) _slotTile(i),
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
              if (_showDiet) DietGrid(teams: _dietTeams()),
            ],
          ],
        ),
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
        : (r == null ? t('deleted_team') : (r.isCustom ? '🍙 ${r.name}' : r.name));
    final selected = _selectedSlot == i;

    return GestureDetector(
      onTap: () => _onSlotTap(i),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: filled ? _slotBg[i] : NurungjiColors.chipBg,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: _slotBorder[i], width: 5)),
        boxShadow: selected
            ? const [BoxShadow(color: NurungjiColors.teal, spreadRadius: 2)]
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                color: filled ? NurungjiColors.dark : NurungjiColors.brown,
              ),
            ),
          ),
          if (filled)
            IconButton(
              onPressed: () => _removeSlot(i),
              icon: const Icon(Icons.close, size: 18, color: NurungjiColors.brown),
              tooltip: t('lb_remove'),
            ),
        ],
      ),
      ),
    );
  }
}
