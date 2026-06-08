// detail_sheet.dart — P4 상세 바텀시트 (웹 club-detail / pickup-detail 과 동일한 톤/구성)
// 칩·이번주 배너·정보행·링크버튼. 공유/릴스 임베드는 P4ب에서.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../services/analytics.dart';
import '../widgets/bounce_tap.dart';
import '../widgets/insta_embed.dart';
import '../widgets/schedule_timetable.dart';
import '../widgets/share_menu.dart';
import '../widgets/story_card.dart';
import '../widgets/map_detail_panel.dart';
import 'club_form_screen.dart';
import 'pickup_form_screen.dart';

const _titleStyle = TextStyle(
    fontSize: 20.5, fontWeight: FontWeight.w800, color: NurungjiColors.dark);

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

// 웹 .tag/.ps-tags 톤: 작고 아담한 칩.
Widget _chip(String text, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
      child: Text(text,
          style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 11.5)),
    );

// 급구/이번주 배너 — 웹처럼 컴팩트(작은 크림-오렌지). 텍스트 크기 명시.
Widget _banner(String badge, String text) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: NurungjiColors.urgent,
              borderRadius: BorderRadius.circular(20)),
          child: Text(badge,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: Colors.white)),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    height: 1.3,
                    color: NurungjiColors.dark))),
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

// 📍 주소 행 + 복사 알약 (웹 #sheetAddressVal + #btnCopy). display=표시값, copyText=복사값.
Widget _addressRow(BuildContext context, String display, String copyText) =>
    Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📍', style: TextStyle(fontSize: 17)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(display,
              style: const TextStyle(
                  fontSize: 15.5, color: NurungjiColors.dark, height: 1.4)),
        ),
        const SizedBox(width: 8),
        _outlineBtn(t('copy_address'), () async {
          await Clipboard.setData(ClipboardData(text: copyText));
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(t('address_copied'))));
          }
        }),
      ]),
    );

// 시간표 morph (웹 #timeMorphContainer/interpolateMorph): peek=요약 텍스트, expand=주간 그리드.
// 패널 펼침비율(DetailPanelScope.expand)에 연동해 crossfade, 탭하면 peek↔expand 토글.
class _ScheduleMorph extends StatelessWidget {
  final String? summaryText; // 🗓 요약 (없으면 미표시)
  final Widget full; // 전체 시간표 그리드
  const _ScheduleMorph({required this.summaryText, required this.full});

  @override
  Widget build(BuildContext context) {
    final summary = (summaryText != null && summaryText!.isNotEmpty)
        ? _infoRow('🗓', summaryText!)
        : const SizedBox(width: double.infinity);
    final scope = DetailPanelScope.of(context);
    // 패널 밖(스코프 없음)이면 요약+전체 둘 다 표시(폴백).
    if (scope == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [summary, full],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: scope.toggle,
      child: ValueListenableBuilder<double>(
        valueListenable: scope.expand,
        builder: (_, r, __) => AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOut,
          crossFadeState:
              r >= 0.5 ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: summary,
          secondChild: full,
        ),
      ),
    );
  }
}

// 🍱 북마크 토글 (웹 #btnBookmark): 타이틀 우측. 담김=진하게/안 담김=흐리게, 탭=추가/해제.
class _BookmarkButton extends StatefulWidget {
  final String uid;
  final String teamId;
  const _BookmarkButton({required this.uid, required this.teamId});

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton> {
  final _svc = LunchboxService();
  bool? _on; // null=로딩

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _svc.load(widget.uid);
      if (mounted) setState(() => _on = data.bookmarks.contains(widget.teamId));
    } catch (_) {
      if (mounted) setState(() => _on = false);
    }
  }

  Future<void> _toggle() async {
    if (_on == null) return;
    final cur = _on!;
    setState(() => _on = !cur); // 낙관적 업데이트
    final err = cur
        ? await _svc.removeBookmark(widget.uid, widget.teamId)
        : await _svc.addBookmark(widget.uid, widget.teamId);
    if (!mounted) return;
    if (err != null) {
      setState(() => _on = cur); // 실패 시 롤백
      _snack(err);
    } else {
      _snack(cur ? t('lb_removed') : t('lb_added'));
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = _on ?? false;
    return BounceTap(
      onTap: _toggle,
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: on ? 1.0 : 0.32, // 담김=진하게 / 안 담김=흐리게
          child: const Text('🍱', style: TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}

// 주 CTA(단톡·공유): 옐로 풀폭, 웹 .btn-way/.ps-join-btn 톤(약간 컴팩트).
Widget _primaryBtn(String label, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        width: double.infinity,
        child: BounceTap(
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12)),
            child: Text(label, style: const TextStyle(fontSize: 14.5)),
          ),
        ),
      ),
    );

// 보조 액션: 웹 .btn-copy 톤의 작은 연회색 알약(아기자기).
Widget _outlineBtn(String label, VoidCallback onTap) => BounceTap(
      child: Material(
        color: const Color(0xFFF0ECE2),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(label,
                style: const TextStyle(
                    color: NurungjiColors.chipFg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5)),
          ),
        ),
      ),
    );

// 인스타 아이콘 (웹 .instagram 그라데이션) — 타이틀 옆. 탭하면 인스타 열기.
Widget _instaIcon(VoidCallback onTap) => BounceTap(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: const LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [
              Color(0xFFFEDA75),
              Color(0xFFFA7E1E),
              Color(0xFFD62976),
              Color(0xFF962FBF),
              Color(0xFF4F5BD5),
            ],
          ),
        ),
        child: const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
      ),
    );

// 컴팩트 액션 알약 (웹 .action-buttons .btn): flex로 한 줄에 여러 개.
Widget _actionPill(String label, VoidCallback onTap,
    {required Color bg, required Color fg}) {
  return Expanded(
    child: BounceTap(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      ),
    ),
  );
}

Widget _sheet(List<Widget> children) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );

// 소유자 수정/삭제 — 웹처럼 풀폭 스택(수정=노랑, 삭제=흰 아웃라인).
Widget _modifyRow({required VoidCallback onEdit, required VoidCallback onDelete}) =>
    Column(children: [
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          width: double.infinity,
          child: BounceTap(
            child: ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, size: 18),
              label: Text(t('edit')),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(t('delete')),
          ),
        ),
      ),
    ]);

// coords가 있으면 그 위치, 없으면 서울 — 폼 지도피커 초기 중심.
NLatLng _centerOf(double? lat, double? lng) => (lat != null && lng != null)
    ? NLatLng(lat, lng)
    : const NLatLng(37.5559, 127.0838);

// 삭제 확인 → 삭제 → 패널 닫기(close) → onChanged. context=호출측(다이얼로그·스낵바).
Future<void> _confirmDelete(
  BuildContext context,
  Future<void> Function()? onChanged,
  VoidCallback close,
  Future<void> Function() doDelete,
) async {
  final ok = await showDialog<bool>(
    context: context,
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
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t('err_delete')}: $e')));
    }
    return;
  }
  close();
  await onChanged?.call();
}

// 동호회 급구(is_urgent) 올리기/내리기 — 소유자 전용. update merge로 나머지 보존.
Widget _urgentToggle(
  Club c,
  BuildContext context,
  Future<void> Function()? onChanged,
  VoidCallback close,
) {
  Future<void> apply(bool urgent, String msg) async {
    try {
      await DataRepository().updateClub(
          c.id, {'is_urgent': urgent, 'urgent_msg': urgent ? msg : ''});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${t('err_generic')}: $e')));
      }
      return;
    }
    close();
    await onChanged?.call();
  }

  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white),
        onPressed: () async {
          if (c.isUrgent) {
            await apply(false, '');
          } else {
            final msg = await _promptText(context,
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

// 상세 시트: 웹 .bottom-sheet처럼 비(非)모달로 띄운다 — OverlayEntry로 화면 바닥에만 깔고
// (딤·배리어 없음) 위쪽 지도는 그대로 조작 가능. content는 close 콜백을 받아 빌드한다
// (수정/삭제/급구 토글이 패널을 닫을 때 사용). 한 번에 하나만 — 새로 열면 기존 패널 교체.
OverlayEntry? _activeDetailEntry;

void _showDetailSheet(
  BuildContext context,
  List<Widget> Function(VoidCallback close) content,
) {
  _activeDetailEntry?.remove();
  _activeDetailEntry = null;
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  void close() {
    if (identical(_activeDetailEntry, entry)) _activeDetailEntry = null;
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) =>
        MapDetailPanel(onClose: close, child: _sheet(content(close))),
  );
  _activeDetailEntry = entry;
  overlay.insert(entry);
}

void showSpotDetail(
  BuildContext context,
  PickupSpot s, {
  String? currentUid,
  bool isAdmin = false,
  Future<void> Function()? onChanged,
}) {
  Track.event('view_pickup', {'id': s.id});
  final where = [s.venueName, s.address].where((e) => e != null && e.isNotEmpty).join(' · ');
  // 수정/삭제: 소유자 OR 관리자(모더레이션). Firestore 규칙도 동일 조건.
  final canModify =
      (currentUid != null && s.ownerUid != null && s.ownerUid == currentUid) ||
          isAdmin;
  final spotEvents = (s.scheduleRaw != null && s.scheduleRaw!.isNotEmpty)
      ? eventsFromRaw(s.scheduleRaw)
      : eventsFromText(s.schedule ?? s.scheduleText);
  _showDetailSheet(context, (close) => [
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
        _ScheduleMorph(
          summaryText: spotEvents.isNotEmpty
              ? scheduleSummary(spotEvents)
              : (((s.schedule ?? s.scheduleText) != null &&
                      (s.schedule ?? s.scheduleText)!.isNotEmpty)
                  ? i18nSchedule(s.schedule ?? s.scheduleText)
                  : null),
          full: ScheduleTimetable(events: spotEvents, accent: NurungjiColors.teal),
        ),
        if (where.isNotEmpty) _addressRow(context, where, s.address ?? where),
        if (s.feeInfo != null && s.feeInfo!.isNotEmpty) _infoRow('💰', i18nPrice(s.feeInfo)),
        if (s.instaReel != null && s.instaReel!.isNotEmpty)
          InstaEmbed(url: s.instaReel!),
        if (s.contactLink != null && s.contactLink!.isNotEmpty)
          _primaryBtn(t('chat_join'), () {
            Track.event('pickup_contact', {'id': s.id, 'sport': s.sport});
            _open(s.contactLink);
          }),
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
              close();
              final ok = await showPickupFormSheet(
                context,
                editing: s,
                initialCenter: _centerOf(s.lat, s.lng),
              );
              if (ok == true) await onChanged?.call();
            },
            onDelete: () => _confirmDelete(context, onChanged, close,
                () => DataRepository().deletePickup(s.id)),
          ),
      ]);
}

void showClubDetail(
  BuildContext context,
  Club c, {
  String? currentUid,
  bool isAdmin = false,
  Future<void> Function()? onChanged,
}) {
  Track.event('view_club', {'club_id': c.id, 'club_name': c.name});
  final tags = (c.target ?? '')
      .split(RegExp(r'[,\s]+'))
      .where((e) => e.isNotEmpty)
      .toList();
  // 수정/삭제: 소유자 OR 관리자(문서 02 §7, 규칙도 동일).
  final canModify = (currentUid != null &&
          c.registeredBy != null &&
          c.registeredBy == currentUid) ||
      isAdmin;
  // 일정 이벤트(요약·그리드 공용으로 1회 파싱)
  final clubEvents = (c.scheduleRaw != null && c.scheduleRaw!.isNotEmpty)
      ? eventsFromRaw(c.scheduleRaw)
      : eventsFromText(c.schedule);
  void shareClub() => showShareMenu(
        context,
        url: ShareService.clubUrl(c.id),
        shareTitle: c.name,
        onStory: () => shareStoryCard(context, StoryCardData.fromClub(c)),
      );
  Future<void> copyAddr() async {
    await Clipboard.setData(ClipboardData(text: c.address ?? ''));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('address_copied'))));
    }
  }

  // 웹 클럽 상세 순서: 급구→타이틀→일정→태그→가격→주소→액션줄→임베드→소유자
  _showDetailSheet(context, (close) => [
        // 1. 급구 배너 (맨 위, 컴팩트)
        if (c.isUrgent && c.urgentMsg != null && c.urgentMsg!.isNotEmpty)
          _banner(t('urgent'), c.urgentMsg!),
        // 2. 타이틀: ✓ + 이름 + 인스타 아이콘 + 🍱 북마크
        Row(children: [
          if (c.isVerified)
            const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.verified, color: Color(0xFF1DA1F2), size: 22)),
          Expanded(child: Text(c.name, style: _titleStyle)),
          if (c.insta != null && c.insta!.isNotEmpty)
            _instaIcon(() => _open('https://instagram.com/${c.insta}')),
          if (currentUid != null)
            _BookmarkButton(uid: currentUid, teamId: c.id),
        ]),
        const SizedBox(height: 4),
        // 3. 일정 morph (타이틀 바로 아래)
        _ScheduleMorph(
          summaryText: clubEvents.isNotEmpty
              ? scheduleSummary(clubEvents)
              : ((c.schedule != null && c.schedule!.isNotEmpty)
                  ? i18nSchedule(c.schedule)
                  : null),
          full: ScheduleTimetable(
              events: clubEvents, accent: NurungjiColors.yellow),
        ),
        // 4. 태그 + 🏠 홈페이지(인라인)
        if (tags.isNotEmpty || (c.link != null && c.link!.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...tags.map((tag) => _chip(i18nTarget(tag),
                    NurungjiColors.chipBg, NurungjiColors.chipFg)),
                if (c.link != null && c.link!.isNotEmpty)
                  _outlineBtn(t('home_btn'), () => _open(c.link)),
              ],
            ),
          ),
        // 5. 가격
        if (c.price != null && c.price!.isNotEmpty)
          _infoRow('💰', i18nPrice(c.price)),
        // 6. 주소 텍스트(유지)
        if (c.address != null && c.address!.isNotEmpty)
          _infoRow('📍', c.address!),
        // 7. 액션 줄: 주소복사 / 길찾기 / 공유 (컴팩트 3)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(children: [
            if (c.address != null && c.address!.isNotEmpty) ...[
              _actionPill(t('copy_address'), copyAddr,
                  bg: const Color(0xFFECEFF1), fg: const Color(0xFF455A64)),
              const SizedBox(width: 8),
            ],
            if (c.lat != null && c.lng != null) ...[
              _actionPill(
                  t('directions_btn'),
                  () => _open(
                      'https://map.kakao.com/link/to/${c.name},${c.lat},${c.lng}'),
                  bg: NurungjiColors.yellow,
                  fg: NurungjiColors.dark),
              const SizedBox(width: 8),
            ],
            _actionPill(t('share_link'), shareClub,
                bg: const Color(0xFFECEFF1), fg: const Color(0xFF455A64)),
          ]),
        ),
        // 8. 인스타 임베드
        if (c.instaReel != null && c.instaReel!.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 14),
              child: InstaEmbed(url: c.instaReel!)),
        // 9. 소유자: 인증 / 급구(빨강) / 수정·삭제(풀폭)
        if (canModify && !c.isVerified) _verifyBtn(c, context),
        if (canModify) _urgentToggle(c, context, onChanged, close),
        if (canModify)
          _modifyRow(
            onEdit: () async {
              close();
              final ok = await showClubFormSheet(
                context,
                editing: c,
                initialCenter: _centerOf(c.lat, c.lng),
              );
              if (ok == true) await onChanged?.call();
            },
            onDelete: () => _confirmDelete(context, onChanged, close,
                () => DataRepository().deleteClub(c.id)),
          ),
      ]);
}
