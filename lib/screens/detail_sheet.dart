// detail_sheet.dart — P4 상세 바텀시트 (웹 club-detail / pickup-detail 과 동일한 톤/구성)
// 칩·이번주 배너·정보행·링크버튼. 공유/릴스 임베드는 P4ب에서.
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';
import '../services/data_repository.dart';
import '../theme.dart';
import 'club_form_screen.dart';
import 'pickup_form_screen.dart';

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

// 소유자 전용: 수정/삭제 버튼 행
Widget _modifyRow({required VoidCallback onEdit, required VoidCallback onDelete}) =>
    Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('수정'),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
          label: const Text('삭제', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
        ),
      ]),
    );

// coords가 있으면 그 위치, 없으면 서울 — 폼 지도피커 초기 중심.
NLatLng _centerOf(double? lat, double? lng) => (lat != null && lng != null)
    ? NLatLng(lat, lng)
    : const NLatLng(37.5559, 127.0838);

// 삭제 확인 → 삭제 → 시트 닫기 → onChanged. sheetCtx=시트 내부, outerCtx=호출측(스낵바용).
Future<void> _confirmDelete(
  BuildContext sheetCtx,
  BuildContext outerCtx,
  Future<void> Function()? onChanged,
  Future<void> Function() doDelete,
) async {
  final ok = await showDialog<bool>(
    context: sheetCtx,
    builder: (dctx) => AlertDialog(
      title: const Text('삭제할까요?'),
      content: const Text('이 작업은 되돌릴 수 없어요.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('취소')),
        TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red))),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await doDelete();
  } catch (e) {
    if (outerCtx.mounted) {
      ScaffoldMessenger.of(outerCtx)
          .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
    return;
  }
  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
  await onChanged?.call();
}

void showSpotDetail(
  BuildContext context,
  PickupSpot s, {
  String? currentUid,
  Future<void> Function()? onChanged,
}) {
  final where = [s.venueName, s.address].where((e) => e != null && e.isNotEmpty).join(' · ');
  final canModify =
      currentUid != null && s.ownerUid != null && s.ownerUid == currentUid;
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => SingleChildScrollView(
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
        if (canModify)
          _modifyRow(
            onEdit: () async {
              Navigator.pop(sheetCtx);
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => PickupFormScreen(
                    editing: s,
                    initialCenter: _centerOf(s.lat, s.lng),
                  ),
                ),
              );
              if (ok == true) await onChanged?.call();
            },
            onDelete: () => _confirmDelete(sheetCtx, context, onChanged,
                () => DataRepository().deletePickup(s.id)),
          ),
      ]),
    ),
  );
}

void showClubDetail(
  BuildContext context,
  Club c, {
  String? currentUid,
  Future<void> Function()? onChanged,
}) {
  final tags = (c.target ?? '')
      .split(RegExp(r'[,\s]+'))
      .where((e) => e.isNotEmpty)
      .toList();
  final canModify = currentUid != null &&
      c.registeredBy != null &&
      c.registeredBy == currentUid;
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => SingleChildScrollView(
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
        if (canModify)
          _modifyRow(
            onEdit: () async {
              Navigator.pop(sheetCtx);
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ClubFormScreen(
                    editing: c,
                    initialCenter: _centerOf(c.lat, c.lng),
                  ),
                ),
              );
              if (ok == true) await onChanged?.call();
            },
            onDelete: () => _confirmDelete(sheetCtx, context, onChanged,
                () => DataRepository().deleteClub(c.id)),
          ),
      ]),
    ),
  );
}
