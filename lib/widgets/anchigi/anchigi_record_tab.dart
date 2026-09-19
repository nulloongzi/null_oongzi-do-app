// anchigi_record_tab.dart — 기록 탭. 누적 출전·대기·포지션별 횟수와 초기화.
import 'package:flutter/material.dart';

import 'package:share_plus/share_plus.dart';

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
        _meetsCard(context),
        _backupCard(context),
        _resetCard(context),
      ],
    );
  }

  Future<bool> _confirm(BuildContext context, String msg) async {
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

  /// 모임 단위로 끊어 보관한다 — 기록이 한 모임에 영영 묶이지 않게.
  Widget _meetsCard(BuildContext context) => AgCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              t('ag_meet_title'),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: NurungjiColors.dark,
              ),
            ),
            const Spacer(),
            Text(
              '${store.meets.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: NurungjiColors.brown,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (store.meets.isEmpty)
          Text(
            t('ag_meet_none'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: NurungjiColors.brown,
            ),
          )
        else
          for (var i = 0; i < store.meets.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${store.meets[i].date}  '
                      '${store.meets[i].rounds}${t('ag_meet_rounds_suf')} · '
                      '${t('ag_sport_${store.meets[i].sport}')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: NurungjiColors.dark,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      if (await _confirm(context, t('ag_meet_del_confirm'))) {
                        store.deleteMeet(i);
                      }
                    },
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    color: NurungjiColors.brown,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              if (store.round <= 1 && store.pastRounds.isEmpty) {
                messenger.showSnackBar(
                  SnackBar(content: Text(t('ag_meet_archive_empty'))),
                );
                return;
              }
              if (await _confirm(context, t('ag_meet_archive_confirm'))) {
                store.archiveMeet();
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              t('ag_meet_archive'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t('ag_meet_hint'),
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

  /// 백업 — 기기를 바꾸거나 앱을 지워도 명단·기록이 남게.
  Widget _backupCard(BuildContext context) => AgCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('ag_backup_title'),
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
                onPressed: () => Share.share(store.exportJson()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: Text(
                  '⬇ ${t('ag_backup_export')}',
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
                onPressed: () => _importDialog(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: Text(
                  '⬆ ${t('ag_backup_import')}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          t('ag_backup_hint'),
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

  Future<void> _importDialog(BuildContext context) async {
    final ctl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NurungjiColors.light,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('ag_backup_import_hint'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(controller: ctl, minLines: 3, maxLines: 6),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: Text(t('confirm')),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (raw == null || raw.trim().isEmpty) return;
    final ok = store.importJson(raw);
    messenger.showSnackBar(
      SnackBar(content: Text(t(ok ? 'ag_backup_done' : 'ag_backup_bad'))),
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
              for (final p in store.seats)
                cell(t('ag_posx_$p'), head: true, w: 44),
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
                      for (final q in store.seats)
                        cell(
                          (st.pos[q] ?? 0) == 0 ? '·' : '${st.pos[q]}',
                          dim: (st.pos[q] ?? 0) == 0,
                          w: 44,
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
