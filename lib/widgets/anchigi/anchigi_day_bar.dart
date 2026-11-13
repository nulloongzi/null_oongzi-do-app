// anchigi_day_bar.dart — 어떤 날의 안치기를 열어 둘지. 웹 anchigi.html 의 날짜 막대 포팅.
// 탭 위에 늘 보이고, 날짜를 바꾸면 명단 · 참석 · 기록이 그 날짜 것으로 갈린다.
import 'package:flutter/material.dart';

import '../../models/anchigi/anchigi_day.dart';
import '../../services/anchigi/anchigi_store.dart';
import '../../services/i18n.dart';
import '../../theme.dart';

const _wdKo = ['월', '화', '수', '목', '금', '토', '일'];
const _wdEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monEn = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

DateTime? _parseDate(String s) {
  final p = s.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// '11월 21일 (토) · 정기 픽업' / 'Sat, Nov 21 · Weekly pickup'. 올해가 아니면 연도를 붙인다.
String anchigiDayLabel(AnchigiDay d) {
  final title = d.title.isEmpty ? '' : ' · ${d.title}';
  final dt = _parseDate(d.date);
  if (dt == null) return '${t('ag_day_undated')}$title';
  final other = dt.year != DateTime.now().year;
  final main = isKo
      ? '${other ? '${dt.year}. ' : ''}${dt.month}월 ${dt.day}일 (${_wdKo[dt.weekday - 1]})'
      : '${_wdEn[dt.weekday - 1]}, ${_monEn[dt.month - 1]} ${dt.day}${other ? ', ${dt.year}' : ''}';
  return '$main$title';
}

class AnchigiDayBar extends StatelessWidget {
  final AnchigiStore store;

  const AnchigiDayBar({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final days = store.sortedDays;
    return Container(
      color: NurungjiColors.bg,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x22000000)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: store.dayId,
                  isExpanded: true,
                  icon: const Icon(Icons.expand_more, size: 20),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: NurungjiColors.dark,
                    fontFamily: 'Pretendard',
                  ),
                  hint: Text(t('ag_day_pick')),
                  items: [
                    for (final d in days)
                      DropdownMenuItem(
                        value: d.id,
                        child: Text(
                          '${anchigiDayLabel(d)} · '
                          '${(d.id == store.dayId ? store.players : d.players).length}'
                          '${isKo ? '명' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) {
                    if (id != null) store.switchDay(id);
                  },
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: t('ag_day_edit'),
            color: NurungjiColors.dark,
            icon: const Icon(Icons.edit_calendar_outlined),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _DayDialog(store: store, isNew: false),
            ),
          ),
          IconButton(
            tooltip: t('ag_day_new_title'),
            color: NurungjiColors.dark,
            icon: const Icon(Icons.add),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _DayDialog(store: store, isNew: true),
            ),
          ),
        ],
      ),
    );
  }
}

/// 새 날짜 / 이 날짜 고치기.
class _DayDialog extends StatefulWidget {
  final AnchigiStore store;
  final bool isNew;

  const _DayDialog({required this.store, required this.isNew});

  @override
  State<_DayDialog> createState() => _DayDialogState();
}

class _DayDialogState extends State<_DayDialog> {
  late String _date = widget.isNew ? '' : widget.store.currentDay.date;
  late final _titleCtl = TextEditingController(
    text: widget.isNew ? '' : widget.store.currentDay.title,
  );
  bool _copy = false;
  bool _needDate = false;

  @override
  void dispose() {
    _titleCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseDate(_date) ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      helpText: t('ag_day_date'),
    );
    if (picked == null) return;
    setState(() {
      _date = _fmtDate(picked);
      _needDate = false;
    });
  }

  void _save() {
    final s = widget.store;
    if (widget.isNew) {
      if (_date.isEmpty) {
        setState(() => _needDate = true);
        return;
      }
      s.addDay(_date, _titleCtl.text, copyRoster: _copy);
    } else {
      s.editDay(_date, _titleCtl.text);
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NurungjiColors.light,
        content: Text(
          t('ag_day_del_confirm'),
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
    if (ok != true || !mounted) return;
    widget.store.deleteDay();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final dt = _parseDate(_date);
    return AlertDialog(
      backgroundColor: NurungjiColors.light,
      title: Text(
        t(widget.isNew ? 'ag_day_new_title' : 'ag_day_edit_title'),
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('ag_day_date'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: NurungjiColors.brown,
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(
                dt == null
                    ? t('ag_day_undated')
                    : anchigiDayLabel(AnchigiDay(id: '', date: _date)),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: NurungjiColors.dark,
                side: BorderSide(
                  color: _needDate
                      ? NurungjiColors.urgent
                      : const Color(0x33000000),
                ),
              ),
            ),
            if (_needDate)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  t('ag_day_need_date'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: NurungjiColors.urgent,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtl,
              maxLength: 30,
              decoration: InputDecoration(
                labelText: t('ag_day_title'),
                hintText: t('ag_day_title_ph'),
                isDense: true,
              ),
            ),
            if (widget.isNew && s.players.isNotEmpty)
              CheckboxListTile(
                value: _copy,
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: NurungjiColors.yellow,
                checkColor: NurungjiColors.dark,
                title: Text(
                  t('ag_day_copy'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onChanged: (v) => setState(() => _copy = v ?? false),
              ),
            const SizedBox(height: 4),
            Text(
              t('ag_day_hint'),
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
      actions: [
        if (!widget.isNew && s.days.length > 1)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: NurungjiColors.urgent),
            child: Text(t('ag_day_del')),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('cancel')),
        ),
        TextButton(onPressed: _save, child: Text(t('ag_day_save'))),
      ],
    );
  }
}
