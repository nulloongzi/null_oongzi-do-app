// lunchbox_screen.dart — 내 도시락(찜한 팀 5칸 + 커스텀 + 식단표). 웹 lunchbox.js 포팅.
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../services/data_repository.dart';
import '../services/i18n.dart';
import '../services/lunchbox_service.dart';
import '../services/schedule_parse.dart';
import '../theme.dart';
import '../widgets/diet_grid.dart';

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

  static const _placeholders = ['밥', '국', '반찬 1', '반찬 2', '반찬 3'];
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

  Future<void> _save() async {
    final uid = _repo.currentUid;
    final d = _data;
    if (uid == null || d == null) return;
    try {
      await _svc.save(uid, d);
    } catch (e) {
      _snack('저장 실패: $e');
    }
  }

  Future<void> _removeSlot(int i) async {
    final d = _data;
    if (d == null) return;
    setState(() {
      d.bookmarks[i] = null;
      _selectedSlot = null;
    });
    await _save();
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
    final tmp = d.bookmarks[from];
    d.bookmarks[from] = d.bookmarks[i];
    d.bookmarks[i] = tmp;
    setState(() => _selectedSlot = null);
    await _save();
  }

  Future<void> _addCustom() async {
    final uid = _repo.currentUid;
    if (uid == null) return;
    final name = await _prompt(t('lb_team_name'), '예: 우리 동호회');
    if (name == null || name.trim().isEmpty) return;
    final sched = await _prompt(t('lb_sched_hint'), '토 14:00~17:00');
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
      final name = (m is Map ? m['name'] : null) as String? ?? '커스텀 팀';
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
    return Scaffold(
      appBar: AppBar(title: Text(t('lunchbox_title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
              tooltip: '빼기',
            ),
        ],
      ),
      ),
    );
  }
}
