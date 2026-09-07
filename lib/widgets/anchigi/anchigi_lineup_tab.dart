// anchigi_lineup_tab.dart — 배치 탭. 스케줄·설정, 뽑기, 결과 표시, 과거 라운드.
// 결과가 나오면 설정 카드가 접혀 결과가 위로 올라온다(원본 UX).
import 'package:flutter/material.dart';

import '../../models/anchigi/anchigi_constants.dart';
import '../../models/anchigi/anchigi_round.dart';
import '../../models/anchigi/anchigi_schedule.dart';
import '../../services/anchigi/anchigi_solver.dart';
import '../../services/anchigi/anchigi_store.dart';
import '../../services/i18n.dart';
import '../../theme.dart';
import 'anchigi_common.dart';
import 'anchigi_court.dart';

class AnchigiLineupTab extends StatefulWidget {
  final AnchigiStore store;

  /// 온보딩에서 명단 탭으로 보낼 때.
  final VoidCallback onGoRoster;

  const AnchigiLineupTab({
    super.key,
    required this.store,
    required this.onGoRoster,
  });

  @override
  State<AnchigiLineupTab> createState() => _AnchigiLineupTabState();
}

class _AnchigiLineupTabState extends State<AnchigiLineupTab> {
  /// 뽑은 뒤 뽑기 버튼 위치로 돌아오기 위한 앵커(맨 위로 튀지 않게).
  final _drawKey = GlobalKey();

  AnchigiStore get s => widget.store;

  /// 진단 사유를 사람이 읽는 문장으로.
  String _reasonText(InfeasibleReason r) {
    final p = r.params;
    return switch (r.kind) {
      'short' => tf('ag_dg_short', {
        'mc': p['mc'] ?? '',
        'n': p['n'] ?? '',
        'gap':
            '${(int.tryParse(p['mc'] ?? '0') ?? 0) - (int.tryParse(p['n'] ?? '0') ?? 0)}',
      }),
      'only' => tf('ag_dg_only', {
        'pos': p['pos'] ?? '',
        'posko': t('ag_pos_${p['pos']}'),
        'cnt': p['cnt'] ?? '',
        'names': p['names'] ?? '',
        'max': p['max'] ?? '',
        'bench': p['bench'] ?? '',
      }),
      'few' => tf('ag_dg_few', {
        'pos': p['pos'] ?? '',
        'posko': t('ag_pos_${p['pos']}'),
        'able': p['able'] ?? '',
        'min': p['min'] ?? '',
      }),
      'abc' => tf('ag_dg_abc', {
        'ranges': p['ranges'] ?? '',
        'n': p['n'] ?? '',
      }),
      _ => t('ag_dg_generic'),
    };
  }

  Future<void> _draw() async {
    await s.draw();
    if (!mounted) return;
    // 결과가 길어도 뽑기 버튼이 보이는 자리로 되돌린다.
    final ctx = _drawKey.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    }
  }

  Future<void> _pickTime(
    String label,
    String cur,
    ValueChanged<String> set,
  ) async {
    final m = parseTime(cur) ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      helpText: label,
    );
    if (picked == null) return;
    set(formatTime(picked.hour * 60 + picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    if (s.players.isEmpty) return _onboarding();

    final cur = s.current;
    final diag = s.failure.isNotEmpty ? s.failure : s.diagnosis;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
      children: [
        // 결과가 있으면 설정을 접어 결과를 위로 올린다.
        _scheduleCard(open: cur == null),
        _settingsCard(open: cur == null),
        if (diag.isNotEmpty)
          AgMessage(diag.map(_reasonText).join('\n\n'), kind: AgMsgKind.err),
        _drawCard(),
        if (cur != null) ..._result(cur),
        if (s.pastRounds.isNotEmpty) ..._past(),
      ],
    );
  }

  // ── 빈 상태 ───────────────────────────────────────────────────────────────

  Widget _onboarding() => ListView(
    padding: const EdgeInsets.fromLTRB(14, 24, 14, 40),
    children: [
      AgCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('ag_intro_title'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: NurungjiColors.dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t('ag_hero_sub'),
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: NurungjiColors.brown,
              ),
            ),
            const SizedBox(height: 18),
            _step(1, t('ag_intro_s1')),
            _step(2, t('ag_intro_s2')),
            _step(3, t('ag_intro_s3')),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onGoRoster,
                child: Text(t('ag_intro_go')),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _step(int n, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: NurungjiColors.yellow,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$n',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: NurungjiColors.dark,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: NurungjiColors.dark,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // ── 스케줄 ────────────────────────────────────────────────────────────────

  Widget _scheduleCard({required bool open}) {
    final mr = s.maxRounds;
    final lastEnd = mr > 0
        ? formatTime(s.schedule.gameEndMin(mr, s.nGames - 1, s.nGames))
        : '—';

    return AgFoldCard(
      title: t('ag_card_time'),
      trailing: '${s.schedule.warmup}–${s.schedule.end}',
      initiallyExpanded: open,
      children: [
        Row(
          children: [
            Expanded(
              child: _timeField(
                t('ag_lb_start'),
                s.schedule.start,
                (v) => s.setSchedule(start: v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _timeField(
                t('ag_lb_gamestart'),
                s.schedule.warmup,
                (v) => s.setSchedule(warmup: v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _timeField(
                t('ag_lb_end'),
                s.schedule.end,
                (v) => s.setSchedule(end: v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _numField(t('ag_lb_pergame'), s.schedule.perGame, const [
                10,
                12,
                15,
                20,
                25,
                30,
              ], (v) => s.setSchedule(perGame: v)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numField(t('ag_lb_rest'), s.schedule.rest, const [
                0,
                5,
                10,
                15,
                20,
              ], (v) => s.setSchedule(rest: v)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${t('ag_est')} $mr${t('ag_round_unit')} · '
          '${t('ag_ends')} $lastEnd',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: NurungjiColors.brown,
          ),
        ),
      ],
    );
  }

  Widget _timeField(String label, String value, ValueChanged<String> onSet) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: NurungjiColors.brown,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _pickTime(label, value, onSet),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x22000000)),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: NurungjiColors.dark,
                ),
              ),
            ),
          ),
        ],
      );

  Widget _numField(
    String label,
    int value,
    List<int> options,
    ValueChanged<int> onSet,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: NurungjiColors.brown,
        ),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x22000000)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: options.contains(value) ? value : options.first,
            isExpanded: true,
            isDense: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: NurungjiColors.dark,
              fontFamily: 'Pretendard',
            ),
            items: [
              for (final o in options)
                DropdownMenuItem(value: o, child: Text('$o')),
            ],
            onChanged: (v) {
              if (v != null) onSet(v);
            },
          ),
        ),
      ),
    ],
  );

  // ── 설정 ──────────────────────────────────────────────────────────────────

  Widget _settingsCard({required bool open}) {
    final (lo, hi) = s.benchRange;
    return AgFoldCard(
      title: t('ag_card_settings'),
      trailing: '${t('ag_feel_${s.feel}')} · ${s.nGames}${t('ag_game_word')}',
      initiallyExpanded: open,
      children: [
        AgSegmented(
          options: [
            (value: 'abc', label: t('ag_mode_abc'), sub: t('ag_mode_abc_sub')),
            (
              value: 'free',
              label: t('ag_mode_free'),
              sub: t('ag_mode_free_sub'),
            ),
          ],
          selected: s.mode,
          onChanged: s.setMode,
        ),
        const SizedBox(height: 14),
        Text(
          t('ag_feel_title'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: NurungjiColors.dark,
          ),
        ),
        const SizedBox(height: 6),
        AgSegmented(
          options: [
            for (final f in kFeels)
              (value: f, label: t('ag_feel_$f'), sub: t('ag_feel_${f}_sub')),
          ],
          selected: s.feel,
          onChanged: s.setFeel,
        ),
        const SizedBox(height: 6),
        Text(
          t('ag_feel_hint'),
          style: const TextStyle(
            fontSize: 11,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: NurungjiColors.brown,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              t('ag_tpl_title'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: NurungjiColors.dark,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                t('ag_tpl_hint'),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: NurungjiColors.brown,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final tpl in kTemplates) ...[
              Expanded(child: _tplChip(tpl)),
              if (tpl != kTemplates.last) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              t('ag_games_count'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: NurungjiColors.dark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  for (var n = 1; n <= 6; n++) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () => s.setNGames(n),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: s.nGames == n
                                ? NurungjiColors.yellow
                                : NurungjiColors.chipBg,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '$n',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: s.nGames == n
                                  ? NurungjiColors.dark
                                  : NurungjiColors.chipFg,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (n != 6) const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            AgStatChip(
              label: t('ag_attend'),
              value: '${s.present.length}${t('ag_people')}',
            ),
            const SizedBox(width: 8),
            AgStatChip(
              label: t('ag_bench_per'),
              value: lo == hi
                  ? '$hi${t('ag_people')}'
                  : '$lo~$hi${t('ag_people')}',
            ),
          ],
        ),
      ],
    );
  }

  Widget _tplChip(AnchigiTemplate tpl) {
    final on = s.allowed.contains(tpl.id);
    return GestureDetector(
      onTap: () => s.toggleTemplate(tpl.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: on ? NurungjiColors.yellow : NurungjiColors.chipBg,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          children: [
            Text(
              t(tpl.labelKey),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: on ? NurungjiColors.dark : NurungjiColors.chipFg,
              ),
            ),
            Text(
              '${tpl.size}${t('ag_tpl_person')}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: on ? NurungjiColors.dark : NurungjiColors.brown,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              t(tpl.descKey),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: on
                    ? NurungjiColors.dark.withValues(alpha: .7)
                    : NurungjiColors.brown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 뽑기 ──────────────────────────────────────────────────────────────────

  Widget _drawCard() => AgCard(
    key: _drawKey,
    child: Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: s.drawing ? null : _draw,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: s.drawing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: NurungjiColors.dark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(t('ag_drawing')),
                    ],
                  )
                : Text(
                    '🎲 ${s.round}R ${t('ag_draw_btn')}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t('ag_draw_hint'),
          textAlign: TextAlign.center,
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

  // ── 결과 ──────────────────────────────────────────────────────────────────

  List<Widget> _result(RoundResult cur) {
    final relaxed = cur.budget > feelOf(cur.feel).budget;
    final cores = cur.games.first.cores;
    final noC = cores != null && cores[2].isEmpty;

    return [
      AgMessage(
        '✓ ${tf('ag_ok_done', {'r': '${cur.round}'})} — '
        '${cur.mode == 'abc' ? t('ag_ok_abc') : t('ag_ok_free')}',
        kind: AgMsgKind.ok,
      ),
      if (relaxed) AgMessage(tf('ag_relaxed', {'n': '${cur.budget}'})),
      if (cores != null)
        AgMessage(
          '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('ag_core_title'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: NurungjiColors.dark,
                ),
              ),
              const SizedBox(height: 4),
              for (var c = 0; c < 3; c++)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${kTeamName[c]}  '
                    '${cores[c].isEmpty ? t('ag_core_none') : cores[c].map((m) => m.name).join(' · ')}',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: NurungjiColors.chipFg,
                    ),
                  ),
                ),
            ],
          ),
        ),
      if (noC) AgMessage(t('ag_no_c_core')),
      _timeline(cur.round, cur.games),
      for (var gi = 0; gi < cur.games.length; gi++)
        _gameCard(cur.round, gi, cur.games[gi]),
      AgCard(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: s.drawing ? null : _draw,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      '🎲 ${t('ag_again')}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: s.commit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      t('ag_confirm_next'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t('ag_confirm_hint'),
              textAlign: TextAlign.center,
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
    ];
  }

  Widget _timeline(int rnd, List<GameResult> games) => AgCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('ag_timeline'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: NurungjiColors.dark,
          ),
        ),
        const SizedBox(height: 8),
        _tlRow(
          '${s.schedule.start}–${s.schedule.warmup}',
          t('ag_warmup'),
          dim: true,
        ),
        for (var gi = 0; gi < games.length; gi++)
          _tlRow(
            '${formatTime(s.schedule.gameStartMin(rnd, gi, s.nGames))}'
                '–${formatTime(s.schedule.gameEndMin(rnd, gi, s.nGames))}',
            '${gi + 1}${t('ag_game_word')}'
                '${games[gi].left.isEmpty ? '' : '   ${games[gi].left.map((l) => l.name).join(', ')} ${t('ag_leave_word')}'}',
            warn: games[gi].left.isNotEmpty,
          ),
        if (s.schedule.rest > 0 && rnd < s.maxRounds)
          _tlRow(
            '${s.schedule.rest}${t('ag_min')}',
            t('ag_rest_word'),
            dim: true,
          ),
      ],
    ),
  );

  Widget _tlRow(
    String time,
    String label, {
    bool dim = false,
    bool warn = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            time,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: dim ? NurungjiColors.brown : NurungjiColors.dark,
            ),
          ),
        ),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: warn
                  ? NurungjiColors.urgent
                  : (dim ? NurungjiColors.brown : NurungjiColors.chipFg),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _gameCard(int rnd, int gi, GameResult g) {
    // ABC 모드에서 이 경기의 두 팀에 해당하는 코어를 골라 차출 표시에 쓴다.
    final pair = kPairs[gi % 3];
    final teamCores = g.cores == null
        ? null
        : [g.cores![pair[0]], g.cores![pair[1]]];

    return AgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${gi + 1}${t('ag_game_word')}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: NurungjiColors.dark,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${formatTime(s.schedule.gameStartMin(rnd, gi, s.nGames))}'
                '–${formatTime(s.schedule.gameEndMin(rnd, gi, s.nGames))}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: NurungjiColors.brown,
                ),
              ),
              const Spacer(),
              Text(
                g.fitGap < 0.35 ? t('ag_fitgap_even') : t('ag_fitgap_off'),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: NurungjiColors.brown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnchigiCourt(
            game: g,
            teamCores: teamCores,
            picked: s.picked,
            onPick: s.pick,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t('ag_bench_label')}  ',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: NurungjiColors.brown,
                ),
              ),
              Expanded(
                child: g.bench.isEmpty
                    ? Text(
                        t('ag_bench_none'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: NurungjiColors.brown,
                        ),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final b in g.bench)
                            GestureDetector(
                              onTap: () => s.pick(b.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: s.picked == b.id
                                      ? NurungjiColors.yellow
                                      : NurungjiColors.chipBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  b.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: NurungjiColors.chipFg,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 과거 라운드 ───────────────────────────────────────────────────────────

  List<Widget> _past() {
    final rounds = s.pastRounds.reversed.toList();
    return [
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Row(
          children: [
            Text(
              '${t('ag_past_title')} ${rounds.length}${t('ag_past_unit')}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: NurungjiColors.dark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t('ag_past_hint'),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: NurungjiColors.brown,
                ),
              ),
            ),
          ],
        ),
      ),
      for (var i = 0; i < rounds.length; i++)
        AgFoldCard(
          title: '${rounds[i].round}${t('ag_past_round_suf')}',
          // 가장 최근 라운드만 펼쳐 둔다.
          initiallyExpanded: i == 0,
          children: [
            for (var gi = 0; gi < rounds[i].games.length; gi++)
              _gameCard(rounds[i].round, gi, rounds[i].games[gi]),
          ],
        ),
    ];
  }
}
