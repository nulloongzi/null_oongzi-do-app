// urgent_sheet.dart — 급구 올리기·수정 시트. 웹 club-detail.js 의 급구 창과 같은 구성.
//
// 급구는 운동 한 회차에 묶인다: 팀 일정에서 7일 안의 다음 회차(최대 3개)를 칩으로 보이고,
// 일정에 없는 운동은 '다른 날'로 날짜와 끝나는 시각을 고른다. 고른 운동이 끝나면
// 서버가 급구를 내린다. 문구는 60자, 링크·전화번호는 넣을 수 없다(서버와 같은 검사).
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/club.dart';
import '../services/capture_demo.dart';
import '../services/deep_link_service.dart' show kCaptureMode;
import '../services/i18n.dart';
import '../services/schedule_parse.dart';
import '../services/urgent.dart';
import '../theme.dart';
import 'app_sheet.dart';
import 'field_error_text.dart';

/// 캡처 시연용: '어떤 사람이 필요해요?' 칸에 문구를 쳐 넣는다(값이 바뀌면 시작).
final ValueNotifier<int> urgentDemoType = ValueNotifier<int>(0);

/// 캡처 시연용: '급구 올리기'를 누른다 — 사용자가 누를 때와 같은 _submit()(서버 postUrgent 실제).
final ValueNotifier<int> urgentDemoSubmit = ValueNotifier<int>(0);

/// 시연 문구 — 칸의 예시와 같은 말(지어낸 상황을 새로 만들지 않는다).
const kUrgentDemoMsg = '센터 1명, 여자 레프트 1명';

/// 급구 올리기(또는 수정) 시트를 띄운다. 올렸으면 true.
/// [post] 는 서버 호출 — null=성공, 그 외=보일 문구(UrgentService.post).
Future<bool> showUrgentSheet(
  BuildContext context,
  Club club, {
  required Future<String?> Function(DateTime until, String msg) post,
}) async {
  final events = (club.scheduleRaw != null && club.scheduleRaw!.isNotEmpty)
      ? eventsFromRaw(club.scheduleRaw, overnight: true)
      : eventsFromText(club.schedule, overnight: true);
  final editing = club.urgentActive;
  final ok = await showAppSheet<bool>(
    context,
    child: UrgentSheet(
      events: events,
      editing: editing,
      initialMsg: editing ? club.urgentMsg?.trim() : null,
      initialUntil: editing ? club.urgentUntil : null,
      onSubmit: post,
    ),
  );
  return ok == true;
}

class UrgentSheet extends StatefulWidget {
  final List<SchedEvent> events;
  final bool editing;
  final String? initialMsg;
  final DateTime? initialUntil;
  final Future<String?> Function(DateTime until, String msg) onSubmit;
  final DateTime Function() clock; // 테스트에서 시각을 고정한다

  const UrgentSheet({
    super.key,
    required this.events,
    required this.onSubmit,
    this.editing = false,
    this.initialMsg,
    this.initialUntil,
    this.clock = DateTime.now,
  });

  @override
  State<UrgentSheet> createState() => _UrgentSheetState();
}

class _UrgentSheetState extends State<UrgentSheet> {
  static const _other = -1; // '다른 날' 칩
  late final List<UrgentSession> _sessions;
  late final TextEditingController _msg;
  int? _sel; // 회차 인덱스, _other, 또는 null(아직 안 고름)
  DateTime? _otherUntil;
  bool _busy = false;
  bool _tried = false; // 올리기를 한 번 눌렀나 — 빈 문구 오류는 그 뒤에만 보인다
  String? _serverErr;
  Timer? _typing; // 캡처 시연의 타이핑

  @override
  void initState() {
    super.initState();
    final now = widget.clock();
    _sessions = nextSessions(widget.events, now);
    _msg = TextEditingController(text: widget.initialMsg ?? '');
    final init = widget.initialUntil;
    if (init != null) {
      final i = _sessions.indexWhere((s) => s.end == init);
      if (i >= 0) {
        _sel = i;
      } else if (init.isAfter(now)) {
        _sel = _other;
        _otherUntil = init;
      }
    }
    if (_sel == null && _sessions.isNotEmpty) _sel = 0;
    if (kCaptureMode) {
      urgentDemoType.addListener(_onDemoType);
      urgentDemoSubmit.addListener(_onDemoSubmit);
    }
  }

  @override
  void dispose() {
    urgentDemoType.removeListener(_onDemoType);
    urgentDemoSubmit.removeListener(_onDemoSubmit);
    _typing?.cancel();
    _msg.dispose();
    super.dispose();
  }

  void _onDemoType() {
    if (!mounted) return;
    _typing?.cancel();
    _typing = demoType(
      _msg,
      kUrgentDemoMsg,
      onChanged: () {
        if (mounted) setState(() => _serverErr = null);
      },
    );
  }

  void _onDemoSubmit() {
    if (mounted && !_busy) unawaited(_submit());
  }

  DateTime? get _until => _sel == null
      ? null
      : (_sel == _other ? _otherUntil : _sessions[_sel!].end);

  Future<void> _pickOther() async {
    final now = widget.clock();
    final today = DateTime(now.year, now.month, now.day);
    final base = _otherUntil;
    final date = await showDatePicker(
      context: context,
      initialDate: base != null && !base.isBefore(today) ? base : today,
      firstDate: today,
      lastDate: DateTime(today.year, today.month, today.day + 7),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: base != null
          ? TimeOfDay.fromDateTime(base)
          : const TimeOfDay(hour: 22, minute: 0),
      helpText: t('ug_end_time'),
    );
    if (time == null || !mounted) return;
    setState(() {
      _sel = _other;
      _otherUntil = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _serverErr = null;
    });
  }

  Future<void> _submit() async {
    setState(() => _tried = true);
    final until = _until;
    if (until == null ||
        urgentMsgProblem(_msg.text) != null ||
        urgentUntilProblem(until, widget.clock()) != null) {
      return;
    }
    setState(() {
      _busy = true;
      _serverErr = null;
    });
    final err = await widget.onSubmit(until, _msg.text.trim());
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _serverErr = err;
    });
  }

  Widget _chip(String label, bool on, VoidCallback onTap, {Key? key}) =>
      ChoiceChip(
        key: key,
        label: Text(label),
        selected: on,
        onSelected: _busy ? null : (_) => onTap(),
        selectedColor: NurungjiColors.yellow,
        backgroundColor: NurungjiColors.chipBg,
        labelStyle: TextStyle(
          color: NurungjiColors.dark,
          fontWeight: on ? FontWeight.w800 : FontWeight.w600,
        ),
        shape: const StadiumBorder(),
        showCheckmark: false,
      );

  @override
  Widget build(BuildContext context) {
    final until = _until;
    final msgProblem = urgentMsgProblem(_msg.text);
    final showMsgErr =
        msgProblem != null && (msgProblem != 'msg_empty' || _tried);
    final untilProblem = until == null
        ? null
        : urgentUntilProblem(until, widget.clock());
    // 회차만 골랐으면 누를 수 있다 — 문구 문제는 누른 뒤 칸 아래에 무엇이 틀렸는지 보인다
    // (말없이 꺼진 버튼은 왜 안 눌리는지 알려 주지 않는다).
    final canSubmit = !_busy && until != null;
    final otherOn = _sel == _other && _otherUntil != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetTitle(widget.editing ? t('ug_edit') : t('urgent_on')),
            Text(
              t('ug_when'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: NurungjiColors.dark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _sessions.length; i++)
                  _chip(
                    sessionChipLabel(_sessions[i]),
                    _sel == i,
                    () => setState(() {
                      _sel = i;
                      _serverErr = null;
                    }),
                    key: ValueKey('ug_session_$i'),
                  ),
                _chip(
                  otherOn
                      ? '${t('ug_other_day')} · ${dayTimeLabel(_otherUntil!)}'
                      : t('ug_other_day'),
                  otherOn,
                  _pickOther,
                  key: const ValueKey('ug_other'),
                ),
              ],
            ),
            if (untilProblem != null)
              FieldErrorText(t(urgentErrorKey(untilProblem))),
            const SizedBox(height: 18),
            TextField(
              key: const ValueKey('ug_msg'),
              controller: _msg,
              enabled: !_busy,
              maxLength: kUrgentMsgMax,
              onChanged: (_) => setState(() => _serverErr = null),
              decoration: InputDecoration(
                labelText: t('ug_msg_label'),
                hintText: t('ug_msg_hint'),
                errorText: showMsgErr ? t(urgentErrorKey(msgProblem)) : null,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.schedule,
                  size: 16,
                  color: NurungjiColors.brown,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t('ug_auto_off'),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: NurungjiColors.brown,
                    ),
                  ),
                ),
              ],
            ),
            if (_serverErr != null) FieldErrorText(_serverErr!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const ValueKey('ug_submit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NurungjiColors.urgentInk,
                  foregroundColor: Colors.white,
                ),
                onPressed: canSubmit ? _submit : null,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(t('ug_submit')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
