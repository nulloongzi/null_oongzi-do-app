// detail_sheet.dart — P4 상세 바텀시트 (웹 club-detail / pickup-detail 과 동일한 톤/구성)
// 칩·이번주 배너·정보행·링크버튼. 공유/릴스 임베드는 P4ب에서.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';
import '../theme.dart';

const _titleStyle = TextStyle(
    fontSize: 23, fontWeight: FontWeight.w800, color: NurungjiColors.dark);

String _sportLabel(String? s) =>
    s == '6s' ? '6인제' : (s == '9s' ? '9인제' : '혼성·자유');
String _levelLabel(String? l) =>
    const {'beginner': '입문', 'intermediate': '중급', 'advanced': '고급'}[l] ??
    '레벨무관';

Future<void> _open(String? url) async {
  if (url == null || url.trim().isEmpty) return;
  final u = Uri.tryParse(url.trim());
  if (u == null) return;
  try {
    await launchUrl(u, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

Widget _chip(String text, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
    );

Widget _banner(String badge, String text) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0x38FAC710),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: NurungjiColors.yellow,
              borderRadius: BorderRadius.circular(20)),
          child: Text(badge,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: NurungjiColors.dark)),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: NurungjiColors.dark))),
      ]),
    );

Widget _infoRow(String icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 17)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 15.5, color: NurungjiColors.dark, height: 1.4))),
      ]),
    );

Widget _primaryBtn(String label, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(onPressed: onTap, child: Text(label)),
      ),
    );

Widget _outlineBtn(String label, VoidCallback onTap) => OutlinedButton(
      onPressed: onTap,
      child: Text(label),
    );

Widget _sheet(List<Widget> children) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );

void showSpotDetail(BuildContext context, PickupSpot s) {
  final where = [s.venueName, s.address].where((e) => e != null && e.isNotEmpty).join(' · ');
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SingleChildScrollView(
      child: _sheet([
        Text(s.title, style: _titleStyle),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _chip(_sportLabel(s.sport), NurungjiColors.yellow, NurungjiColors.dark),
          _chip(_levelLabel(s.level), NurungjiColors.chipBg, NurungjiColors.chipFg),
          if (s.beginnerFriendly)
            _chip('🌱 초보환영', const Color(0xFFE7F6E7), const Color(0xFF2E7D32)),
          if (s.englishOk)
            _chip('🌐 English OK', const Color(0xFFE6F0FB), const Color(0xFF1565C0)),
        ]),
        if (s.thisWeek != null && s.thisWeek!.isNotEmpty) _banner('이번주', s.thisWeek!),
        if ((s.schedule ?? s.scheduleText) != null &&
            (s.schedule ?? s.scheduleText)!.isNotEmpty)
          _infoRow('🗓', (s.schedule ?? s.scheduleText)!),
        if (where.isNotEmpty) _infoRow('📍', where),
        if (s.feeInfo != null && s.feeInfo!.isNotEmpty) _infoRow('💰', s.feeInfo!),
        if (s.contactLink != null && s.contactLink!.isNotEmpty)
          _primaryBtn('💬 단톡 들어가기', () => _open(s.contactLink)),
      ]),
    ),
  );
}

void showClubDetail(BuildContext context, Club c) {
  final tags = (c.target ?? '')
      .split(RegExp(r'[,\s]+'))
      .where((e) => e.isNotEmpty)
      .toList();
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SingleChildScrollView(
      child: _sheet([
        Row(children: [
          if (c.isVerified)
            const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.verified, color: Color(0xFF1DA1F2), size: 22)),
          Expanded(child: Text(c.name, style: _titleStyle)),
        ]),
        const SizedBox(height: 12),
        if (tags.isNotEmpty)
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map((t) => _chip(t, NurungjiColors.chipBg, NurungjiColors.chipFg))
                  .toList()),
        if (c.schedule != null && c.schedule!.isNotEmpty) _infoRow('🗓', c.schedule!),
        if (c.address != null && c.address!.isNotEmpty) _infoRow('📍', c.address!),
        if (c.price != null && c.price!.isNotEmpty) _infoRow('💰', c.price!),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (c.insta != null && c.insta!.isNotEmpty)
            _outlineBtn('📷 인스타', () => _open('https://instagram.com/${c.insta}')),
          if (c.link != null && c.link!.isNotEmpty)
            _outlineBtn('🔗 홈페이지', () => _open(c.link)),
          if (c.lat != null && c.lng != null)
            _outlineBtn('🚀 길찾기',
                () => _open('https://map.kakao.com/link/to/${c.name},${c.lat},${c.lng}')),
        ]),
      ]),
    ),
  );
}
