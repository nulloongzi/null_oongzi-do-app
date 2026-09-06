// data_trust_row.dart — 최종 확인일 + 신고 통로 (웹 js/data-trust.js 포팅).
//
// guidelines.html 이 약속한 두 가지를 화면에서 잇는다:
//   · "6개월마다 점검, 30일 무응답 시 표시 중단" → 최종 확인일 + 오래되면 '확인 필요'
//   · "잘못된 정보 신고 시 영업일 7일 이내 확인"  → 상세에서 바로 보내는 인앱 신고
//
// 신고는 reports 컬렉션에 쓰고, Cloud Function(onReportCreated)이 운영자 카톡으로
// 알린다 — 인증 배지 심사와 같은 파이프. 메일 앱으로 나가지 않아 이탈이 없고,
// 이력이 남아 "며칠 만에 확인했나"를 셀 수 있다.
import 'package:flutter/material.dart';

import '../services/analytics.dart';
import '../services/data_repository.dart';
import '../services/i18n.dart';
import '../theme.dart';

/// guidelines.html 2-3 의 점검 주기와 같은 값. 웹 STALE_MONTHS 와 맞춘다.
const int kStaleMonths = 6;

/// 사유 값은 firestore.rules 의 enum 과 정확히 같아야 한다(다르면 규칙에서 거부).
const List<String> kReportReasons = [
  'wrong_info',
  'closed',
  'duplicate',
  'inappropriate',
  'other',
];

/// 오래된 항목인가? 관리자가 data_status 를 명시했으면 그 값이 우선한다.
bool isStaleData(DateTime? lastVerified, String? dataStatus, {DateTime? now}) {
  if (dataStatus == 'needs_check' || dataStatus == 'dormant') return true;
  if (lastVerified == null) return false; // 확인일을 모르면 낙인찍지 않는다
  final base = now ?? DateTime.now();
  final cutoff = DateTime(base.year, base.month - kStaleMonths, base.day);
  return lastVerified.isBefore(cutoff);
}

String _fmt(DateTime d) => '${d.year}.${d.month}.${d.day}';

class DataTrustRow extends StatelessWidget {
  const DataTrustRow({
    super.key,
    required this.kind, // 'club' | 'pickup'
    required this.targetId,
    required this.targetName,
    this.lastVerified,
    this.dataStatus,
    this.repo,
  });

  final String kind;
  final String targetId;
  final String targetName;
  final DateTime? lastVerified;
  final String? dataStatus;

  /// DI 시임 — 테스트에서 fake 주입. 기본값은 프로덕션 싱글턴.
  final DataRepository? repo;

  @override
  Widget build(BuildContext context) {
    final stale = isStaleData(lastVerified, dataStatus);
    final line = lastVerified == null
        ? '🕒 ${t('dt_unknown')}'
        : '${stale ? '⚠️ ' : '🕒 '}${t('dt_last_verified')} ${_fmt(lastVerified!)}'
              '${stale ? ' · ${t('dt_needs_check')}' : ''}';

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.only(top: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0x0D000000))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                line,
                style: TextStyle(
                  fontSize: 12,
                  color: stale ? const Color(0xFFB26A00) : Colors.grey,
                  fontWeight: stale ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _openReport(context),
              child: Text(
                t('dt_report'),
                style: const TextStyle(
                  fontSize: 12,
                  color: NurungjiColors.brown,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReport(BuildContext context) async {
    Track.event('report_open', {'kind': kind, 'id': targetId});
    final messenger = ScaffoldMessenger.of(context);
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _ReportDialog(
        kind: kind,
        targetId: targetId,
        targetName: targetName,
        repo: repo ?? DataRepository(),
      ),
    );
    if (sent == true) {
      messenger.showSnackBar(SnackBar(content: Text(t('rp_done'))));
    }
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({
    required this.kind,
    required this.targetId,
    required this.targetName,
    required this.repo,
  });

  final String kind;
  final String targetId;
  final String targetName;
  final DataRepository repo;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final TextEditingController _detail = TextEditingController();
  String _reason = '';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason.isEmpty) {
      setState(() => _error = t('rp_need_reason'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.repo.createReport(
        kind: widget.kind,
        targetId: widget.targetId,
        targetName: widget.targetName,
        reason: _reason,
        detail: _detail.text.trim(),
      );
      Track.event('report_submit', {
        'kind': widget.kind,
        'id': widget.targetId,
        'reason': _reason,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      // 통로가 막혀도 사용자가 뭘 해야 할지는 알려준다(웹은 mailto 폴백).
      if (mounted) {
        setState(() {
          _sending = false;
          _error = t('rp_fail');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(t('rp_title')),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.targetName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: NurungjiColors.dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t('rp_intro'),
            style: const TextStyle(fontSize: 12, color: NurungjiColors.brown),
          ),
          const SizedBox(height: 14),
          Text(
            t('rp_reason_label'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kReportReasons.map((r) {
              final on = _reason == r;
              return GestureDetector(
                onTap: () => setState(() {
                  _reason = r;
                  _error = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: on ? NurungjiColors.yellow : NurungjiColors.chipBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    t('rp_$r'),
                    style: TextStyle(
                      fontSize: 13,
                      color: on ? NurungjiColors.dark : NurungjiColors.chipFg,
                      fontWeight: on ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _detail,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: t('rp_detail_label'),
              hintText: t('rp_detail_ph'),
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(
                color: NurungjiColors.urgent,
                fontSize: 13,
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _sending ? null : () => Navigator.pop(context, false),
        child: Text(t('cancel')),
      ),
      TextButton(
        onPressed: _sending ? null : _submit,
        child: Text(_sending ? t('rp_sending') : t('rp_submit')),
      ),
    ],
  );
}
