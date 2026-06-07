// detail_sheet.dart — P4 상세 바텀시트 (웹 club-detail / pickup-detail 과 동일한 톤/구성)
// 칩·이번주 배너·정보행·링크버튼. 공유/릴스 임베드는 P4ب에서.
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';
import '../services/data_repository.dart';
import '../services/i18n.dart';
import '../services/lunchbox_service.dart';
import '../services/share_service.dart';
import '../services/story_share.dart';
import '../services/schedule_parse.dart';
import '../services/verification_service.dart';
import '../theme.dart';
import '../widgets/insta_embed.dart';
import '../widgets/schedule_timetable.dart';
import '../widgets/share_menu.dart';
import '../widgets/story_card.dart';
import 'club_form_screen.dart';
import 'pickup_form_screen.dart';

const _titleStyle = TextStyle(
    fontSize: 23, fontWeight: FontWeight.w800, color: NurungjiColors.dark);

String _sportLabel(String? s) =>
    s == '6s' ? t('sport_6s') : (s == '9s' ? t('sport_9s') : t('sport_mixed'));
String _levelLabel(String? l) => l == 'beginner'
    ? t('lv_beginner')
    : l == 'intermediate'
        ? t('lv_intermediate')
        : l == 'advanced'
            ? t('lv_advanced')
            : t('lv_any');

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
            label: Text(t('edit')),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
          label: Text(t('delete'), style: const TextStyle(color: Colors.red)),
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
      title: Text(t('modify_delete_title')),
      content: Text(t('modify_delete_body')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(t('cancel'))),
        TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(t('delete'), style: const TextStyle(color: Colors.red))),
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

// 동호회 급구(is_urgent) 올리기/내리기 — 소유자 전용. update merge로 나머지 보존.
Widget _urgentToggle(
  Club c,
  BuildContext sheetCtx,
  BuildContext outerCtx,
  Future<void> Function()? onChanged,
) {
  Future<void> apply(bool urgent, String msg) async {
    try {
      await DataRepository().updateClub(
          c.id, {'is_urgent': urgent, 'urgent_msg': urgent ? msg : ''});
    } catch (e) {
      if (outerCtx.mounted) {
        ScaffoldMessenger.of(outerCtx)
            .showSnackBar(SnackBar(content: Text('실패: $e')));
      }
      return;
    }
    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
    await onChanged?.call();
  }

  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          if (c.isUrgent) {
            await apply(false, '');
          } else {
            final msg = await _promptText(sheetCtx,
                title: t('urgent_on'), hint: t('urgent_msg_hint'));
            if (msg != null && msg.trim().isNotEmpty) await apply(true, msg.trim());
          }
        },
        icon: Icon(c.isUrgent ? Icons.notifications_off : Icons.campaign,
            size: 18),
        label: Text(c.isUrgent ? t('urgent_off') : t('urgent_on')),
      ),
    ),
  );
}

// 인증 신청(사진 제출) — 소유자 & 미인증일 때만.
Widget _verifyBtn(Club c, BuildContext outerCtx) {
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final err = await VerificationService()
              .submit(clubId: c.id, clubName: c.name);
          if (err == 'cancelled') return;
          if (outerCtx.mounted) {
            ScaffoldMessenger.of(outerCtx).showSnackBar(SnackBar(
                content: Text(err ?? t('verify_done'))));
          }
        },
        icon: const Icon(Icons.verified_outlined, size: 18),
        label: Text(t('verify_btn')),
      ),
    ),
  );
}

Future<String?> _promptText(BuildContext ctx,
    {required String title, required String hint}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: ctx,
    builder: (dctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 200,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dctx), child: Text(t('cancel'))),
        TextButton(
            onPressed: () => Navigator.pop(dctx, ctrl.text),
            child: Text(t('confirm'))),
      ],
    ),
  );
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
            _chip(t('beginner_ok'), const Color(0xFFE7F6E7), const Color(0xFF2E7D32)),
          if (s.englishOk)
            _chip(t('english_ok'), const Color(0xFFE6F0FB), const Color(0xFF1565C0)),
        ]),
        if (s.thisWeek != null && s.thisWeek!.isNotEmpty) _banner(t('this_week'), s.thisWeek!),
        if ((s.schedule ?? s.scheduleText) != null &&
            (s.schedule ?? s.scheduleText)!.isNotEmpty)
          _infoRow('🗓', i18nSchedule(s.schedule ?? s.scheduleText)),
        ScheduleTimetable(
          events: (s.scheduleRaw != null && s.scheduleRaw!.isNotEmpty)
              ? eventsFromRaw(s.scheduleRaw)
              : eventsFromText(s.schedule ?? s.scheduleText),
          accent: NurungjiColors.teal,
        ),
        if (where.isNotEmpty) _infoRow('📍', where),
        if (s.feeInfo != null && s.feeInfo!.isNotEmpty) _infoRow('💰', i18nPrice(s.feeInfo)),
        if (s.instaReel != null && s.instaReel!.isNotEmpty)
          InstaEmbed(url: s.instaReel!),
        if (s.contactLink != null && s.contactLink!.isNotEmpty)
          _primaryBtn(t('chat_join'), () => _open(s.contactLink)),
        _primaryBtn(
          t('share_btn'),
          () => showShareMenu(
            context,
            url: ShareService.spotUrl(s.id),
            shareTitle: s.title,
            onStory: () => shareStoryCard(context, StoryCardData.fromSpot(s)),
          ),
        ),
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
                  .map((tag) => _chip(
                      i18nTarget(tag), NurungjiColors.chipBg, NurungjiColors.chipFg))
                  .toList()),
        if (c.isUrgent && c.urgentMsg != null && c.urgentMsg!.isNotEmpty)
          _banner(t('urgent'), c.urgentMsg!),
        if (c.schedule != null && c.schedule!.isNotEmpty) _infoRow('🗓', i18nSchedule(c.schedule)),
        ScheduleTimetable(
          events: (c.scheduleRaw != null && c.scheduleRaw!.isNotEmpty)
              ? eventsFromRaw(c.scheduleRaw)
              : eventsFromText(c.schedule),
          accent: NurungjiColors.yellow,
        ),
        if (c.address != null && c.address!.isNotEmpty) _infoRow('📍', c.address!),
        if (c.price != null && c.price!.isNotEmpty) _infoRow('💰', i18nPrice(c.price)),
        if (c.instaReel != null && c.instaReel!.isNotEmpty)
          InstaEmbed(url: c.instaReel!),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (c.insta != null && c.insta!.isNotEmpty)
            _outlineBtn(t('insta_btn'), () => _open('https://instagram.com/${c.insta}')),
          if (c.link != null && c.link!.isNotEmpty)
            _outlineBtn(t('home_btn'), () => _open(c.link)),
          if (c.lat != null && c.lng != null)
            _outlineBtn(t('directions_btn'),
                () => _open('https://map.kakao.com/link/to/${c.name},${c.lat},${c.lng}')),
          if (currentUid != null)
            _outlineBtn(t('bookmark_btn'), () async {
              final err = await LunchboxService().addBookmark(currentUid, c.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err ?? t('lb_added'))));
              }
            }),
        ]),
        _primaryBtn(
          t('share_btn'),
          () => showShareMenu(
            context,
            url: ShareService.clubUrl(c.id),
            shareTitle: c.name,
            onStory: () => shareStoryCard(context, StoryCardData.fromClub(c)),
          ),
        ),
        if (canModify && !c.isVerified) _verifyBtn(c, context),
        if (canModify) _urgentToggle(c, sheetCtx, context, onChanged),
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
