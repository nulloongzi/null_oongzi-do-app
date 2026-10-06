// recruit_sheet.dart — 🍚 식구 모집 시작·수정 시트. 웹 club-detail.js 의 식구 모집 창과 같은 구성.
//
// 문구는 선택(비워도 된다), 60자·링크·전화번호 금지는 급구와 같은 검사.
// 🥄 맛보기 환영 — "한 번 와서 뛰어 봐도 돼요"(체험·게스트). 켜면 이번 주 차림표에 팀 운동이 뜬다.
// 저장은 팀 관리자가 직접 쓴다(UrgentService.setRecruiting) — 서버 호출이 없다.
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/club.dart';
import '../services/capture_demo.dart';
import '../services/deep_link_service.dart' show kCaptureMode;
import '../services/i18n.dart';
import '../services/urgent.dart';
import '../theme.dart';
import 'app_sheet.dart';
import 'field_error_text.dart';

/// 캡처 시연용: 문구를 쳐 넣고 🥄 맛보기를 켠다(값이 바뀌면 시작).
final ValueNotifier<int> recruitDemoFill = ValueNotifier<int>(0);

/// 캡처 시연용: '🍚 식구 모집 시작'을 누른다 — 사용자가 누를 때와 같은 _submit()(실제 저장).
final ValueNotifier<int> recruitDemoSubmit = ValueNotifier<int>(0);

/// 시연 문구 — 칸의 예시와 같은 말.
const kRecruitDemoMsg = '20~30대 회원 모집해요';

/// 식구 모집 시작(또는 수정) 시트를 띄운다. 저장했으면 true.
/// [save] 는 저장 — null=성공, 그 외=보일 문구.
Future<bool> showRecruitSheet(
  BuildContext context,
  Club club, {
  required Future<String?> Function(String msg, bool dropIn) save,
}) async {
  final ok = await showAppSheet<bool>(
    context,
    child: RecruitSheet(
      editing: club.recruitingActive,
      // 꺼 둔 뒤 다시 켤 때도 지난 문구·맛보기를 채워 둔다(끄기는 깃발만 내린다).
      initialMsg: club.recruitMsg?.trim() ?? '',
      initialDropIn: club.recruitDropIn,
      onSubmit: save,
    ),
  );
  return ok == true;
}

class RecruitSheet extends StatefulWidget {
  final bool editing;
  final String initialMsg;
  final bool initialDropIn;
  final Future<String?> Function(String msg, bool dropIn) onSubmit;

  const RecruitSheet({
    super.key,
    required this.onSubmit,
    this.editing = false,
    this.initialMsg = '',
    this.initialDropIn = false,
  });

  @override
  State<RecruitSheet> createState() => _RecruitSheetState();
}

class _RecruitSheetState extends State<RecruitSheet> {
  late final TextEditingController _msg = TextEditingController(
    text: widget.initialMsg,
  );
  late bool _dropIn = widget.initialDropIn;
  bool _busy = false;
  String? _serverErr;
  Timer? _typing; // 캡처 시연의 타이핑

  @override
  void initState() {
    super.initState();
    if (kCaptureMode) {
      recruitDemoFill.addListener(_onDemoFill);
      recruitDemoSubmit.addListener(_onDemoSubmit);
    }
  }

  @override
  void dispose() {
    recruitDemoFill.removeListener(_onDemoFill);
    recruitDemoSubmit.removeListener(_onDemoSubmit);
    _typing?.cancel();
    _msg.dispose();
    super.dispose();
  }

  void _onDemoFill() {
    if (!mounted) return;
    _typing?.cancel();
    _typing = demoType(
      _msg,
      kRecruitDemoMsg,
      onChanged: () {
        if (mounted) setState(() => _serverErr = null);
      },
      // 다 친 뒤 맛보기 체크 — 영상에서 두 동작이 따로 보이게.
      onDone: () {
        if (mounted) setState(() => _dropIn = true);
      },
    );
  }

  void _onDemoSubmit() {
    if (mounted && !_busy) unawaited(_submit());
  }

  Future<void> _submit() async {
    if (recruitMsgProblem(_msg.text) != null) return; // 칸 아래에 이미 보인다
    setState(() {
      _busy = true;
      _serverErr = null;
    });
    final err = await widget.onSubmit(_msg.text.trim(), _dropIn);
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

  @override
  Widget build(BuildContext context) {
    // 비어 있어도 되므로 '적어 주세요' 오류는 없다 — 링크·전화번호·길이는 쓰는 중에 바로 보인다.
    final problem = recruitMsgProblem(_msg.text);
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
            SheetTitle(widget.editing ? t('rc_edit') : t('rc_badge')),
            TextField(
              key: const ValueKey('rc_msg'),
              controller: _msg,
              enabled: !_busy,
              maxLength: kUrgentMsgMax,
              onChanged: (_) => setState(() => _serverErr = null),
              decoration: InputDecoration(
                labelText: t('rc_msg_label'),
                hintText: t('rc_msg_hint'),
                errorText: problem != null ? t(urgentErrorKey(problem)) : null,
              ),
            ),
            const SizedBox(height: 4),
            // 맛보기 — 체크 상자와 글 전체가 누르는 곳(작은 상자만 누르게 두지 않는다)
            CheckboxListTile(
              key: const ValueKey('rc_drop_in'),
              value: _dropIn,
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      _dropIn = v ?? false;
                      _serverErr = null;
                    }),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: NurungjiColors.dark,
              title: Text(
                t('rc_drop_in_ask'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: NurungjiColors.dark,
                ),
              ),
              subtitle: Text(
                t('rc_drop_in_desc'),
                style: const TextStyle(
                  fontSize: 13,
                  color: NurungjiColors.brown,
                ),
              ),
            ),
            const SizedBox(height: 4),
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
                    t('rc_auto_off'),
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
                key: const ValueKey('rc_submit'),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.editing ? t('rc_save') : t('rc_on')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
