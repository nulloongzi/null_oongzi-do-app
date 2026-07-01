// lunchbox_screen.dart — 내 도시락(찜한 팀 5칸 + 커스텀 + 식단표). 웹 lunchbox.js 포팅.
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../services/data_repository.dart';
import '../services/i18n.dart';
import '../services/lunchbox_service.dart';
import '../services/schedule_parse.dart';
import '../theme.dart';
import '../widgets/app_sheet.dart';
import '../widgets/bounce_tap.dart';
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
  bool _editing = false; // 편집 모드(순서변경·빼기 활성)

  List<String> get _placeholders => [
        t('lb_slot_rice'),
        t('lb_slot_soup'),
        t('lb_slot_side1'),
        t('lb_slot_side2'),
        t('lb_slot_side3'),
      ];
  // (칸별 색상은 diet_grid.dart로 이동 — 벤토 셀은 채움=노랑테두리/빈칸=점선 균일 스타일)

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
    ).whenComplete(c.dispose);
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
                child: Row(children: [const Spacer(), _editToggle()]),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  !_editing
                      ? t('lb_edit_hint')
                      : (_selectedSlot == null
                          ? t('lb_reorder_hint')
                          : t('lb_reorder_pick')),
                  style: const TextStyle(
                      fontSize: 12, color: NurungjiColors.brown),
                ),
              ),
              _bentoGrid(),
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
              // 식단표 아코디언 애니메이션(웹 height transition 대응)
              AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.hardEdge,
                child: _showDiet
                    ? DietGrid(teams: _dietTeams())
                    : const SizedBox(width: double.infinity, height: 0),
              ),
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

  // 편집 토글 — 편집 모드에서만 칸 이동/스왑·빼기(웹 lb-edit-btn 대응).
  Widget _editToggle() {
    return BounceTap(
      onTap: () => setState(() {
        _editing = !_editing;
        _selectedSlot = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _editing ? NurungjiColors.urgent : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  _editing ? NurungjiColors.urgent : const Color(0x22000000)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Text(
          _editing ? '✅ ${t('lb_done')}' : '✏️ ${t('lb_edit')}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: _editing ? Colors.white : NurungjiColors.dark,
          ),
        ),
      ),
    );
  }

  // 도시락(벤토) 그리드 — 웹 .lunchbox-grid 대응.
  // 위 줄: 반찬1·2·3(작게, 0.8fr) / 아래 줄: 밥·국(크게, 1.2fr).
  Widget _bentoGrid() {
    const gap = 6.0;
    return SizedBox(
      height: 220,
      child: Column(
        children: [
          Expanded(
            flex: 8, // 0.8fr
            child: Row(children: [
              Expanded(child: _cell(2)),
              const SizedBox(width: gap),
              Expanded(child: _cell(3)),
              const SizedBox(width: gap),
              Expanded(child: _cell(4)),
            ]),
          ),
          const SizedBox(height: gap),
          Expanded(
            flex: 12, // 1.2fr
            child: Row(children: [
              Expanded(child: _cell(0)),
              const SizedBox(width: gap),
              Expanded(child: _cell(1)),
            ]),
          ),
        ],
      ),
    );
  }

  // 벤토 셀 하나. 채움=흰 배경+노랑 테두리 / 빈칸=옅은 점선풍 / 선택=주황 테두리.
  Widget _cell(int i) {
    final id = _data?.bookmarks[i];
    final r = id == null ? null : _resolve(id);
    final filled = id != null;
    final selected = _selectedSlot == i;
    final label = !filled
        ? _placeholders[i]
        : (r == null ? t('deleted_team') : (r.isCustom ? '🍙 ${r.name}' : r.name));

    final Color bg;
    final Border border;
    if (selected) {
      bg = const Color(0xFFFFECB3);
      border = Border.all(color: NurungjiColors.urgent, width: 2);
    } else if (filled) {
      bg = Colors.white;
      border = Border.all(color: NurungjiColors.yellow, width: 2);
    } else {
      bg = const Color(0x80FFFDE7); // 옅은 아이보리
      border = Border.all(color: const Color(0x59BCAAA4), width: 1.5);
    }

    return BounceTap(
      onTap: _editing ? () => _onSlotTap(i) : null,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: border,
          boxShadow: filled && !selected
              ? const [
                  BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 8,
                      offset: Offset(0, 3)),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
                    color:
                        filled ? NurungjiColors.dark : const Color(0xFFBCAAA4),
                  ),
                ),
              ),
            ),
            if (filled && _editing)
              Positioned(
                top: 3,
                right: 3,
                child: Semantics(
                  button: true,
                  label: t('lb_remove'),
                  child: GestureDetector(
                    onTap: () => _removeSlot(i),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5252),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x66FF5252),
                              blurRadius: 6,
                              offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.close,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
