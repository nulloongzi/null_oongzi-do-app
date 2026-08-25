// anchigi_record_tab.dart — 기록 탭. 누적 출전·대기·포지션별 횟수와 초기화.
import 'package:flutter/material.dart';

import '../../models/anchigi/anchigi_constants.dart';
import '../../services/anchigi/anchigi_store.dart';
import '../../services/i18n.dart';
import '../../theme.dart';
import 'anchigi_common.dart';

class AnchigiRecordTab extends StatelessWidget {
  final AnchigiStore store;

  const AnchigiRecordTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    // 기록이 있는 사람만, 명단 순서대로.
    final rows = store.players
        .where((p) => store.stat.containsKey(p.id))
        .toList();

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
                    t('ag_record_title'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: NurungjiColors.dark,
                    ),
                  ),
                  const Spacer(),
                  AgStatChip(
                    label: '',
                    value: tf('ag_rounds_confirmed', {
                      'n': '${store.round - 1}',
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    t('ag_stat_empty'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: NurungjiColors.brown,
                    ),
                  ),
                )
              else ...[
                // 가로 폭이 좁으면 표가 눌리므로 가로 스크롤을 허용한다.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _table(rows),
                ),
                const SizedBox(height: 10),
                Text(
                  t('ag_stat_hint'),
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: NurungjiColors.brown,
                  ),
                ),
              ],
            ],
          ),
        ),
        _resetCard(context),
      ],
    );
  }

  Widget _table(List<dynamic> rows) {
    const headStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: NurungjiColors.brown,
    );
    const cellStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: NurungjiColors.dark,
    );

    Widget cell(
      String text, {
      bool head = false,
      bool dim = false,
      double w = 44,
    }) => SizedBox(
      width: w,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: head
            ? headStyle
            : (dim
                  ? cellStyle.copyWith(
                      color: NurungjiColors.brown.withValues(alpha: .5),
                    )
                  : cellStyle),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 78,
                child: Text(t('ag_th_name'), style: headStyle),
              ),
              cell(t('ag_th_play'), head: true),
              cell(t('ag_th_bench'), head: true),
              for (final p in kPos) cell(p, head: true, w: 38),
            ],
          ),
        ),
        for (final p in rows) ...[
          Builder(
            builder: (_) {
              final st = store.stat[p.id]!;
              final hl = store.picked == p.id;
              return GestureDetector(
                onTap: () => store.pick(p.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: hl
                        ? NurungjiColors.yellow.withValues(alpha: .3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 78,
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: NurungjiColors.dark,
                          ),
                        ),
                      ),
                      cell('${st.play}'),
                      cell('${st.bench}'),
                      for (final q in kPos)
                        cell(
                          (st.pos[q] ?? 0) == 0 ? '·' : '${st.pos[q]}',
                          dim: (st.pos[q] ?? 0) == 0,
                          w: 38,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _resetCard(BuildContext context) => AgCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('ag_reset_title'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: NurungjiColors.dark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t('ag_reset_hint'),
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: NurungjiColors.brown,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: NurungjiColors.light,
                  content: Text(
                    t('ag_reset_confirm'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
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
              if (ok ?? false) store.resetStats();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: NurungjiColors.urgent,
              side: const BorderSide(color: NurungjiColors.urgent),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              t('ag_reset_btn'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );
}
