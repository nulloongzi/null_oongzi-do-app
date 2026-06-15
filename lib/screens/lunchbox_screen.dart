// lunchbox_screen.dart — 내 도시락(찜한 팀 5칸 반찬통 + 커스텀 + 식단표). 웹 lunchbox.js 포팅.
// 반찬통 벤토 그리드(윗줄 반찬1·2·3 / 아랫줄 밥·국) + 🍽 편집 모드(삭제·탭스왑) +
// 📅 식단표 애니메이션 펼침(now라인·범례). 빈 도시락엔 안내 배너.
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
  bool _editMode = false;
  int? _selectedSlot; // 편집모드 탭스왑: 선택된 칸

  List<String> get _placeholders => [
        t('lb_slot_rice'),
        t('lb_slot_soup'),
        t('lb_slot_side1'),
        t('lb_slot_side2'),
        t('lb_slot_side3'),
      ];

  int get _filledCount => _data?.bookmarks.where((e) => e != null).length ?? 0;

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

  void _toggleEdit() {
    setState(() {
      _editMode = !_editMode;
      _selectedSlot = null;
    });
  }

  // 편집모드 탭: 빈 칸 시작 불가, 같은 칸 재탭=해제, 다른 칸 탭=스왑(순서 재배치).
  Future<void> _onSlotTap(int i) async {
    if (!_editMode) return;
    final d = _data;
    if (d == null) return;
    if (_selectedSlot == null) {
      if (d.bookmarks[i] == null) return;
      setState(() => _selectedSlot = i);
      return;
    }
    if (_selectedSlot == i) {
      setState(() => _selectedSlot = null);
      return;
    }
    final from = _selectedSlot!;
    final tmp = d.bookmarks[from];
    d.bookmarks[from] = d.bookmarks[i];
    d.bookmarks[i] = tmp;
    setState(() => _selectedSlot = null);
    await _save();
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
    setState(() {
      d.bookmarks[i] = null;
      if (_selectedSlot == i) _selectedSlot = null;
    });
    await _save();
    _snack(t('lb_removed'));
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
      final name =
          (m is Map ? m['name'] : null) as String? ?? t('lb_custom_team');
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
            else ...[
              // 상단 액션: 🍙 직접추가 · 🍽 편집/완료
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addCustom,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(t('add_custom')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_filledCount > 0)
                    OutlinedButton(
                      onPressed: _toggleEdit,
                      style: _editMode
                          ? OutlinedButton.styleFrom(
                              backgroundColor: NurungjiColors.yellow,
                              side: const BorderSide(
                                  color: NurungjiColors.yellow))
                          : null,
                      child: Text(_editMode ? t('lb_done') : t('lb_edit')),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (_filledCount == 0) _emptyBanner(),
              _bentoTray(),
              if (_editMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _selectedSlot == null
                        ? t('lb_reorder_hint')
                        : t('lb_reorder_pick'),
                    style: const TextStyle(
                        fontSize: 12, color: NurungjiColors.brown),
                  ),
                ),
              const SizedBox(height: 14),
              // 📅 식단표 토글(브라운 채움 버튼) + 애니메이션 펼침
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _showDiet = !_showDiet),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NurungjiColors.brown,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_showDiet ? t('lb_diet_close') : t('lb_diet_open')),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: _showDiet
                    ? Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 12,
                                offset: Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _legend(),
                            DietGrid(teams: _dietTeams()),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
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

  Widget _emptyBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NurungjiColors.light,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: Column(
        children: [
          Text(
            '🍱 ${t('lb_empty_title')}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: NurungjiColors.dark),
          ),
          const SizedBox(height: 6),
          Text(
            t('lb_empty_desc'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, height: 1.5, color: NurungjiColors.brown),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(t('lb_find_on_map')),
          ),
        ],
      ),
    );
  }

  /// 반찬통 벤토: 윗줄 반찬1·2·3(작게) / 아랫줄 밥·국(크게). 웹 .lunchbox-grid(6col,0.8:1.2) 대응.
  Widget _bentoTray() {
    return Column(
      children: [
        SizedBox(
          height: 70,
          child: Row(
            children: [
              Expanded(child: _slotCell(2)),
              const SizedBox(width: 8),
              Expanded(child: _slotCell(3)),
              const SizedBox(width: 8),
              Expanded(child: _slotCell(4)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: Row(
            children: [
              Expanded(child: _slotCell(0)),
              const SizedBox(width: 8),
              Expanded(child: _slotCell(1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _slotCell(int i) {
    final id = _data?.bookmarks[i];
    final r = id == null ? null : _resolve(id);
    final filled = id != null;
    final label = !filled
        ? _placeholders[i]
        : (r == null
            ? t('deleted_team')
            : (r.isCustom ? '🍙 ${r.name}' : r.name));
    final selected = _selectedSlot == i;

    // 웹 .lb-cell 규칙: 빈 칸=회색 점선, 채움=흰 배경+노란 실선, 선택=urgent+#ffecb3.
    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: filled ? 13 : 12,
              fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
              color: filled ? NurungjiColors.dark : const Color(0xFFBCAAA4),
            ),
          ),
        ),
        if (_editMode && filled)
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: () => _removeSlot(i),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x66FF5252),
                        blurRadius: 8,
                        offset: Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.close, size: 13, color: Colors.white),
              ),
            ),
          ),
      ],
    );

    final inner = filled
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFECB3) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    selected ? NurungjiColors.urgent : NurungjiColors.yellow,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? const Color(0x33FF7043)
                      : const Color(0x0A000000),
                  blurRadius: selected ? 15 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: content,
          )
        : CustomPaint(
            foregroundPainter: _DashedRRectPainter(
              color: const Color(0x66BCAAA4),
              radius: 16,
              strokeWidth: 1.5,
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0x80FFFDE7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: content,
            ),
          );

    return GestureDetector(onTap: () => _onSlotTap(i), child: inner);
  }

  /// 식단표 색상 범례: 담은 팀 ↔ 칸 색 매핑.
  Widget _legend() {
    final teams = _dietTeams();
    if (teams.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
}

/// 빈 슬롯 점선 테두리(웹 .lb-cell.empty의 dashed border 재현).
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    this.dashWidth = 5,
    this.dashGap = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = dist + dashWidth;
        canvas.drawPath(
          metric.extractPath(dist, next.clamp(0, metric.length)),
          paint,
        );
        dist = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}
