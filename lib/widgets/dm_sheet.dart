// dm_sheet.dart — 첫 연락(물꼬): 인스타 DM + 첫 인사 문구. 웹 club-detail.js openDmSheet 포팅.
// 연락 버튼까지는 오는데(조회자의 약 35%) 첫 DM 이 어색해서 멈춘다 → 보낼 말을 먼저 보여주고,
// 복사한 채로 그 팀의 DM 창(ig.me/m/<핸들>)을 연다. '누룽지도 보고'는 팀에게 지도가 닿았다는 신호이기도 하다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/analytics.dart';
import '../services/i18n.dart';
import '../theme.dart';
import 'app_sheet.dart';

/// 현재 화면 언어의 첫 인사 문구. 팀 이름이 비면 대체어.
String dmTemplate(String? team) {
  final name = (team == null || team.trim().isEmpty)
      ? t('dm_team_fallback')
      : team.trim();
  return t('dm_template').replaceAll('{team}', name);
}

Uri dmUri(String handle) =>
    Uri.parse('https://ig.me/m/${Uri.encodeComponent(handle)}');

Future<void> showDmSheet(
  BuildContext context, {
  required String handle,
  required String team,
  required String clubId,
  required int hasReel,
}) {
  final text = dmTemplate(team);
  return showAppSheet<void>(
    context,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('dm_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: NurungjiColors.dark,
              ),
            ),
            const SizedBox(height: 14),
            // 보낼 말을 먼저 보여준다
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x738D6E63)),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.6,
                  color: NurungjiColors.dark,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('dm_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF8D6E63)),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (ctx) => FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: NurungjiColors.yellow,
                  foregroundColor: NurungjiColors.dark,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  Track.event('dm_template_copy', {
                    'club_id': clubId,
                    'source': 'club',
                  });
                  // 기존 대시보드 연속성 + NSM — 웹과 같은 스키마
                  Track.event('club_contact', {
                    'type': 'dm',
                    'club_id': clubId,
                    'has_reel': hasReel,
                  });
                  Track.event('contact_click', {
                    'channel': 'instagram_dm',
                    'club_id': clubId,
                    'source': 'club',
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  try {
                    await launchUrl(
                      dmUri(handle),
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (_) {}
                },
                child: Text(
                  t('dm_go'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            Builder(
              builder: (ctx) => TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('cancel')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
