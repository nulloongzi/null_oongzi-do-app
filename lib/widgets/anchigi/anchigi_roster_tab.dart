// anchigi_roster_tab.dart — 명단 탭. 참석 체크, 포지션 티어 편집, 퇴장 시간, 추가/삭제.
import 'package:flutter/material.dart';

import '../../models/anchigi/anchigi_constants.dart';
import '../../models/anchigi/anchigi_player.dart';
import '../../services/anchigi/anchigi_store.dart';
import '../../services/i18n.dart';
import '../../theme.dart';
import 'anchigi_common.dart';

/// 티어별 칩 색. 없음(null)은 회색.
Color _tierBg(String? tier) => switch (tier) {
  'main' => NurungjiColors.yellow,
  'sub' => const Color(0xFFCDE7C8),
  'want' => const Color(0xFFF3D9F0),
  _ => NurungjiColors.chipBg,
};

Color _tierFg(String? tier) =>
    tier == null ? NurungjiColors.chipFg : NurungjiColors.dark;

class AnchigiRosterTab extends StatefulWidget {
  final AnchigiStore store;

  const AnchigiRosterTab({super.key, required this.store});

  @override
  State<AnchigiRosterTab> createState() => _AnchigiRosterTabState();
}

class _AnchigiRosterTabState extends State<AnchigiRosterTab> {
  final _nameCtl = TextEditingController();

  /// 추가 폼에서 고르는 중인 포지션(아직 명단에 없는 상태).
  final Map<String, String> _newTier = {};

  AnchigiStore get s => widget.store;

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  /// 추가 폼 칩 순환 — 명단의 규칙과 동일하게 맞춘다.
  void _cycleNew(String pos) {
    setState(() {
      final t = _newTier[pos];
      if (t == null) {
        _newTier[pos] = _newTier.values.contains('main') ? 'sub' : 'main';
      } else if (t == 'main') {
        _newTier.remove(pos);
        final rest = kPos.where(_newTier.containsKey).toList();
        if (rest.isNotEmpty) _newTier[rest.first] = 'main';
      } else if (t == 'sub') {
        _newTier[pos] = 'want';
      } else {
        _newTier.remove(pos);
      }
    });
  }

  Future<void> _add() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) return;
    if (s.hasName(name)) {
      final ok = await _confirm(t('ag_dup_name'));
      if (!ok) return;
    }
    s.addPlayer(name, _newTier);
    setState(() {
      _nameCtl.clear();
      _newTier.clear();
    });
  }

  Future<bool> _confirm(String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NurungjiColors.light,
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('confirm')),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _pickLeave(AnchigiPlayer p) async {
    final parts = (p.leave ?? '').split(':');
    final initial = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 17,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 17, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: t('ag_leave_title'),
    );
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    s.setLeave(p.id, '$hh:$mm');
  }

  @override
  Widget build(BuildContext context) {
    final present = s.present.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
      children: [
        AgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    t('ag_roster'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: NurungjiColors.dark,
                    ),
                  ),
                  const Spacer(),
                  AgStatChip(
                    label: t('ag_attend'),
                    value: '$present / ${s.players.length}',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (s.players.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    t('ag_roster_empty'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: NurungjiColors.brown,
                    ),
                  ),
                )
              else
                for (final p in s.players) _playerRow(p),
              const SizedBox(height: 4),
              Text(
                t('ag_tier_hint'),
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: NurungjiColors.brown,
                ),
              ),
            ],
          ),
        ),
        _addCard(),
        _bulkCard(),
      ],
    );
  }

  Widget _playerRow(AnchigiPlayer p) {
    final hl = s.picked == p.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: hl ? NurungjiColors.yellow.withValues(alpha: .28) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hl ? NurungjiColors.yellow : const Color(0x18000000),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 참석 토글.
              SizedBox(
                width: 34,
                child: Checkbox(
                  value: p.here,
                  activeColor: NurungjiColors.yellow,
                  checkColor: NurungjiColors.dark,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) => s.setHere(p.id, v ?? false),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => s.pick(p.id),
                  child: Text(
                    p.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: p.here
                          ? NurungjiColors.dark
                          : NurungjiColors.brown,
                    ),
                  ),
                ),
              ),
              // 퇴장 시간.
              TextButton(
                onPressed: () => _pickLeave(p),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: p.leave == null
                      ? NurungjiColors.brown
                      : NurungjiColors.urgent,
                ),
                child: Text(
                  p.leave ?? t('ag_leave_none'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (p.leave != null)
                IconButton(
                  onPressed: () => s.setLeave(p.id, null),
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  color: NurungjiColors.brown,
                  tooltip: t('ag_leave_none'),
                  icon: const Icon(Icons.close),
                ),
              IconButton(
                onPressed: () async {
                  if (await _confirm(tf('ag_del_confirm', {'name': p.name}))) {
                    s.removePlayer(p.id);
                  }
                },
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                color: NurungjiColors.brown,
                tooltip: t('delete'),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              for (final pos in kPos) ...[
                Expanded(child: _tierChip(p, pos)),
                if (pos != kPos.last) const SizedBox(width: 5),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _tierChip(AnchigiPlayer p, String pos) {
    final tier = p.tier[pos];
    return GestureDetector(
      onTap: () => s.cycleTier(p.id, pos),
      // 길게 눌러 주 포지션으로(웹의 ☆ 버튼 대응).
      onLongPress: tier == null || tier == 'main'
          ? null
          : () => s.promoteTier(p.id, pos),
      child: Semantics(
        button: true,
        label: '$pos ${tier == null ? '' : t('ag_tier_$tier')}',
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: _tierBg(tier),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (tier == 'main')
                    const Text('★ ', style: TextStyle(fontSize: 8)),
                  Text(
                    pos,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: _tierFg(tier),
                    ),
                  ),
                ],
              ),
              Text(
                tier == null ? '·' : t('ag_tier_$tier'),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _tierFg(tier).withValues(alpha: .75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addCard() => AgCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('ag_add_person'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: NurungjiColors.dark,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameCtl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  hintText: t('ag_name_ph'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _add,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
              ),
              child: Text(t('ag_add_btn')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final pos in kPos) ...[
              Expanded(child: _newChip(pos)),
              if (pos != kPos.last) const SizedBox(width: 5),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          t('ag_add_hint'),
          style: const TextStyle(
            fontSize: 11,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: NurungjiColors.brown,
          ),
        ),
      ],
    ),
  );

  Widget _newChip(String pos) {
    final tier = _newTier[pos];
    return GestureDetector(
      onTap: () => _cycleNew(pos),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: _tierBg(tier),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          children: [
            Text(
              pos,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: _tierFg(tier),
              ),
            ),
            Text(
              tier == null ? '·' : t('ag_tier_$tier'),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _tierFg(tier).withValues(alpha: .75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulkCard() => AgCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('ag_bulk'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: NurungjiColors.dark,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => s.setAllHere(true),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  t('ag_all_on'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => s.setAllHere(false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  t('ag_all_off'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  if (await _confirm(t('ag_clear_confirm'))) s.clearRoster();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  foregroundColor: NurungjiColors.urgent,
                  side: const BorderSide(color: NurungjiColors.urgent),
                ),
                child: Text(
                  t('ag_to_default'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
