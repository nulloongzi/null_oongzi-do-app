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
import 'login_screen.dart';
import 'pickup_form_screen.dart';

const _titleStyle = TextStyle(
  fontSize: 20.5,
  fontWeight: FontWeight.w800,
  color: NurungjiColors.dark,
);

String _sportLabel(String? s) =>
    s == '6s' ? t('sport_6s') : (s == '9s' ? t('sport_9s') : t('sport_mixed'));
String _levelLabel(String? l) => pickupLevelLabel(l);

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
  child: Text(
    text,
    style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 11.5),
  ),
);

// 급구/이번주 배너 — 웹처럼 컴팩트(작은 크림-오렌지). 텍스트 크기 명시.
Widget _banner(String badge, String text) => Container(
  width: double.infinity,
  margin: const EdgeInsets.only(top: 8, bottom: 12),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
  decoration: BoxDecoration(
    color: const Color(0xFFFFF3E0),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: NurungjiColors.urgent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          badge,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: Colors.white,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            height: 1.3,
            color: NurungjiColors.dark,
          ),
        ),
      ),
    ],
  ),
);

Widget _infoRow(String icon, String text) => Padding(
  padding: const EdgeInsets.only(top: 12),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(icon, style: const TextStyle(fontSize: 17)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15.5,
            color: NurungjiColors.dark,
            height: 1.4,
          ),
        ),
      ),
    ],
  ),
);

// 📍 주소 행 + 복사 알약 (웹 #sheetAddressVal + #btnCopy). display=표시값, copyText=복사값.
Widget _addressRow(BuildContext context, String display, String copyText) =>
    Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📍', style: TextStyle(fontSize: 17)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              display,
              style: const TextStyle(
                fontSize: 15.5,
                color: NurungjiColors.dark,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _outlineBtn(t('copy_address'), () async {
            await Clipboard.setData(ClipboardData(text: copyText));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(t('address_copied'))));
            }
          }),
        ],
      ),
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
        builder: (_, r, _) => AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOut,
          crossFadeState: r >= 0.5
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: summary,
          secondChild: full,
        ),
      ),
    );
  }
}

// 펼치기 전(peek)엔 숨기고, 위로 펼치면(ratio>=0.5) 펼쳐지듯 나타나는 영역.
// 릴스 임베드·소유자 버튼(급구/수정/삭제)에 사용 — peek에선 주소복사/길찾기/공유까지만 보이게.
class _ExpandReveal extends StatelessWidget {
  final Widget child;
  const _ExpandReveal({required this.child});

  @override
  Widget build(BuildContext context) {
    final scope = DetailPanelScope.of(context);
    if (scope == null) return child; // 패널 밖이면 그냥 표시
    return ValueListenableBuilder<double>(
      valueListenable: scope.expand,
      builder: (_, r, _) => AnimatedSize(
        duration: const Duration(milliseconds: 220),
        alignment: Alignment.topCenter,
        curve: Curves.easeOut,
        child: r >= 0.5
            ? child
            : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }
}

/// 시딩 항목(공개 인스타 정보로 모은 크루) 출처 고지 + 수정/삭제 요청 통로.
/// 수신처는 Play Console 연락처와 동일한 지원 메일.
class _CuratedNote extends StatelessWidget {
  static const _email = 'paulyoo999@gmail.com';
  final PickupSpot spot;
  const _CuratedNote({required this.spot});

  Future<void> _request() async {
    final body = StringBuffer()
      ..writeln(t('pk_takedown_body'))
      ..writeln()
      ..writeln('- ${spot.title}')
      ..writeln('- id: ${spot.id}');
    if (spot.insta != null && spot.insta!.isNotEmpty) {
      body.writeln('- @${spot.insta}');
    }
    final uri = Uri(
      scheme: 'mailto',
      path: _email,
      query: Uri(
        queryParameters: {
          'subject': t('pk_takedown_subject'),
          'body': body.toString(),
        },
      ).query,
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: NurungjiColors.chipBg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('pk_curated_note'),
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: NurungjiColors.brown,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _request,
          child: Text(
            t('pk_curated_takedown'),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1565C0),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    ),
  );
}

// 릴스 섹션: 첫 릴스는 항상 표시(피로감↓), 2개 이상이면 '더 보기' 드롭다운으로 나머지.
class _ReelsSection extends StatefulWidget {
  final List<String> reels;
  const _ReelsSection({required this.reels});

  @override
  State<_ReelsSection> createState() => _ReelsSectionState();
}

class _ReelsSectionState extends State<_ReelsSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final reels = widget.reels;
    if (reels.isEmpty) return const SizedBox.shrink();
    final more = reels.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LazyReel(url: reels.first), // 포스터 카드 → 탭하면 인라인 재생(스크롤 매끄럽게)
        if (more > 0)
          BounceTap(
            onTap: () => setState(() => _open = !_open),
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(vertical: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: NurungjiColors.chipBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _open
                        ? t('reels_hide')
                        : '${t('reels_more_label')} ($more)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: NurungjiColors.chipFg,
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: NurungjiColors.chipFg,
                  ),
                ],
              ),
            ),
          ),
        if (_open)
          for (final u in reels.skip(1)) _LazyReel(url: u),
      ],
    );
  }
}

// 릴스 지연 로딩: 기본은 가벼운 포스터 카드만 → 탭하면 그때 InstaEmbed(WebView) 인라인 생성.
// 스크롤 경로에서 플랫폼뷰(WebView)를 걷어내 버벅임 제거(자동재생 대신 탭재생).
class _LazyReel extends StatefulWidget {
  final String url;
  const _LazyReel({required this.url});

  @override
  State<_LazyReel> createState() => _LazyReelState();
}

class _LazyReelState extends State<_LazyReel> {
  bool _play = false;

  @override
  Widget build(BuildContext context) {
    if (_play) return InstaEmbed(url: widget.url); // 탭 후에만 실제 임베드
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: BounceTap(
        onTap: () => setState(() => _play = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x1A000000)),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
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
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('insta_reel_title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: NurungjiColors.dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t('reel_tap_play'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: NurungjiColors.brown,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_circle_outline,
                size: 20,
                color: NurungjiColors.brown,
              ),
            ],
          ),
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
  bool _busy = false; // 토글 처리 중(더블탭 중복 방지)

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
    if (_on == null || _busy) return;
    _busy = true;
    final cur = _on!;
    setState(() => _on = !cur); // 낙관적 업데이트
    final err = cur
        ? await _svc.removeBookmark(widget.uid, widget.teamId)
        : await _svc.addBookmark(widget.uid, widget.teamId);
    _busy = false;
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
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
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
        child: Text(
          label,
          style: const TextStyle(
            color: NurungjiColors.chipFg,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
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

// 홈페이지 집 아이콘 — 타이틀 옆(인스타·북마크와 한 줄). 탭하면 홈/링크 열기.
Widget _homeIcon(VoidCallback onTap) => BounceTap(
  onTap: onTap,
  child: Container(
    margin: const EdgeInsets.only(left: 6),
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: NurungjiColors.chipBg,
      borderRadius: BorderRadius.circular(7),
    ),
    child: const Icon(
      Icons.home_rounded,
      size: 15,
      color: NurungjiColors.brown,
    ),
  ),
);

// 컴팩트 액션 알약 (웹 .action-buttons .btn): flex로 한 줄에 여러 개.
Widget _actionPill(
  String label,
  VoidCallback onTap, {
  required Color bg,
  required Color fg,
}) {
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
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
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
Widget _modifyRow({
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) => Column(
  children: [
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
  ],
);

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
          child: Text(t('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dctx, true),
          child: Text(t('delete'), style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await doDelete();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${t('err_delete')}: $e')));
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
      await DataRepository().updateClub(c.id, {
        'is_urgent': urgent,
        'urgent_msg': urgent ? msg : '',
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${t('err_generic')}: $e')));
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
          foregroundColor: Colors.white,
        ),
        onPressed: () async {
          if (c.isUrgent) {
            await apply(false, '');
          } else {
            final msg = await _promptText(
              context,
              title: t('urgent_on'),
              hint: t('urgent_msg_hint'),
            );
            if (msg != null && msg.trim().isNotEmpty) {
              await apply(true, msg.trim());
            }
          }
        },
        icon: Icon(
          c.isUrgent ? Icons.notifications_off : Icons.campaign,
          size: 18,
        ),
        label: Text(c.isUrgent ? t('urgent_off') : t('urgent_on')),
      ),
    ),
  );
}

// 인증 신청/상태 영역(웹 verifyStatusArea 대응) — 소유자 & 미인증일 때만.
// 최신 요청 조회: 이력 없음→신청 버튼 / 심사 중→안내 / 거절→사유+재신청.
class _VerificationSection extends StatefulWidget {
  final Club club;
  const _VerificationSection({required this.club});

  @override
  State<_VerificationSection> createState() => _VerificationSectionState();
}

class _VerificationSectionState extends State<_VerificationSection> {
  ({String status, String? reason})? _req;

  @override
  void initState() {
    super.initState();
    VerificationService().latestRequest(widget.club.id).then((r) {
      if (mounted && r != null) setState(() => _req = r);
    });
  }

  Future<void> _apply() async {
    final err = await VerificationService().submit(
      clubId: widget.club.id,
      clubName: widget.club.name,
    );
    if (err == 'cancelled' || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(err ?? t('verify_done'))));
    if (err == null) setState(() => _req = (status: 'pending', reason: null));
  }

  Widget _applyBtn(String label) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: _apply,
      icon: const Icon(Icons.verified_outlined, size: 18),
      label: Text(label),
    ),
  );

  // 좌측 색 보더 안내 박스(웹 pending/rejected 박스 톤)
  Widget _noticeBox(Color border, Color bg, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      border: Border(left: BorderSide(color: border, width: 3)),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final r = _req;
    final Widget body;
    if (r != null && r.status == 'pending') {
      body = _noticeBox(
        const Color(0xFF2196F3),
        const Color(0x1A2196F3),
        Text(
          t('vf_pending'),
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: Color(0xFF1565C0),
          ),
        ),
      );
    } else if (r != null && r.status == 'rejected') {
      body = Column(
        children: [
          _noticeBox(
            const Color(0xFFF44336),
            const Color(0x14F44336),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('vf_rejected'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD32F2F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${t('vf_reason')}${r.reason ?? t('vf_no_reason')}',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF555555),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _applyBtn(t('vf_reapply')),
        ],
      );
    } else {
      body = _applyBtn(t('verify_btn')); // 이력 없음(또는 조회 실패 폴백)
    }
    return Padding(padding: const EdgeInsets.only(top: 12), child: body);
  }
}

Future<String?> _promptText(
  BuildContext ctx, {
  required String title,
  required String hint,
}) {
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
          onPressed: () => Navigator.pop(dctx),
          child: Text(t('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dctx, ctrl.text),
          child: Text(t('confirm')),
        ),
      ],
    ),
  ).whenComplete(ctrl.dispose);
}

// 상세 패널: OverlayEntry(모든 라우트 위) 대신 MapScreen Stack에서 렌더되도록 notifier로
// 전달한다 → 상세에서 띄우는 공유/삭제확인/스토리카드 등 모달이 패널보다 위에 나타남.
// 비모달(지도 조작 가능)은 MapDetailPanel(Align)이 그대로 유지. 한 번에 하나만.
final ValueNotifier<Widget?> detailPanel = ValueNotifier<Widget?>(null);

void _showDetailSheet(
  BuildContext context,
  List<Widget> Function(VoidCallback close) content,
) {
  void close() => detailPanel.value = null;
  detailPanel.value = MapDetailPanel(
    key: UniqueKey(), // 새로 열 때마다 드래그/높이 상태 초기화
    onClose: close,
    child: _sheet(content(close)),
  );
}

void showSpotDetail(
  BuildContext context,
  PickupSpot s, {
  String? currentUid,
  bool isAdmin = false,
  Future<void> Function()? onChanged,
}) {
  Track.event('view_pickup', {'id': s.id});
  // 장소가 유동적인 크루는 체육관·주소가 비어 있다 → 지역 칩으로 대체 표시.
  final where = [
    s.venueName,
    s.address,
  ].where((e) => e != null && e.isNotEmpty).join(' · ');
  final whereLabel = where.isNotEmpty
      ? where
      : ((s.region != null && s.region!.isNotEmpty)
            ? i18nRegion(s.region!)
            : '');
  // 수정/삭제: 소유자 OR 관리자(모더레이션). Firestore 규칙도 동일 조건.
  final canModify =
      (currentUid != null && s.ownerUid != null && s.ownerUid == currentUid) ||
      isAdmin;
  final spotEvents = (s.scheduleRaw != null && s.scheduleRaw!.isNotEmpty)
      ? eventsFromRaw(s.scheduleRaw)
      : eventsFromText(s.schedule ?? s.scheduleText);
  _showDetailSheet(
    context,
    (close) => [
      Text(s.title, style: _titleStyle),
      const SizedBox(height: 12),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _chip(
            _sportLabel(s.sport),
            NurungjiColors.yellow,
            NurungjiColors.dark,
          ),
          _chip(
            _levelLabel(s.level),
            NurungjiColors.chipBg,
            NurungjiColors.chipFg,
          ),
          if (s.beginnerFriendly)
            _chip(
              t('beginner_ok'),
              const Color(0xFFE7F6E7),
              const Color(0xFF2E7D32),
            ),
          if (s.englishOk)
            _chip(
              t('english_ok'),
              const Color(0xFFE6F0FB),
              const Color(0xFF1565C0),
            ),
        ],
      ),
      if (s.thisWeek != null && s.thisWeek!.isNotEmpty)
        _banner(t('this_week'), s.thisWeek!),
      _ScheduleMorph(
        summaryText: spotEvents.isNotEmpty
            ? scheduleSummary(spotEvents)
            : (((s.schedule ?? s.scheduleText) != null &&
                      (s.schedule ?? s.scheduleText)!.isNotEmpty)
                  ? i18nSchedule(s.schedule ?? s.scheduleText)
                  : null),
        full: ScheduleTimetable(
          events: spotEvents,
          accent: NurungjiColors.teal,
        ),
      ),
      // 일정 메모(비정기): 구조화 일정이 있어 요약에 안 쓰였을 때 별도 행(웹 동일)
      if ((s.schedule ?? '').isNotEmpty && (s.scheduleText ?? '').isNotEmpty)
        _infoRow('🗓', s.scheduleText!),
      // 주소가 있으면 복사/길찾기가 붙은 주소 행, 지역만 있으면 단순 정보 행.
      if (where.isNotEmpty)
        _addressRow(context, where, s.address ?? where)
      else if (whereLabel.isNotEmpty)
        _infoRow('📍', whereLabel),
      if (s.feeInfo != null && s.feeInfo!.isNotEmpty)
        _infoRow('💰', i18nPrice(s.feeInfo)),
      // 인스타 핸들 — 단톡 링크가 없는 크루의 실질적인 "들어가는 문"
      if (s.insta != null && s.insta!.isNotEmpty)
        _primaryBtn('📷 @${s.insta}', () {
          Track.event('pickup_contact', {
            'id': s.id,
            'type': 'insta',
            'sport': s.sport,
          });
          // NSM 전용 이벤트 — 웹 pickup-detail.js와 동일 스키마
          Track.event('contact_click', {
            'channel': 'instagram',
            'id': s.id,
            'source': 'pickup',
          });
          _open('https://instagram.com/${s.insta}');
        }),
      if (s.contactLink != null && s.contactLink!.isNotEmpty)
        _primaryBtn(t('chat_join'), () {
          Track.event('pickup_contact', {
            'id': s.id,
            'type': 'link',
            'sport': s.sport,
          });
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
      // 추가 안내(notes) — 웹 픽업 상세 메모 행 (폼 저장값 표시 누락 보완)
      if (s.notes != null && s.notes!.isNotEmpty) _infoRow('📝', s.notes!),
      // 시딩 항목: 크루 본인이 올린 게 아니라 owner_uid가 관리자다.
      // 이 고지+요청 링크가 유일한 옵트아웃 경로라 반드시 노출한다.
      if (s.source == 'curated') _CuratedNote(spot: s),
      // 펼쳐야 보이는 영역: 릴스 + 소유자 수정/삭제
      _ExpandReveal(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (s.instaReels.isNotEmpty) _ReelsSection(reels: s.instaReels),
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
                onDelete: () => _confirmDelete(
                  context,
                  onChanged,
                  close,
                  () => DataRepository().deletePickup(s.id),
                ),
              ),
          ],
        ),
      ),
    ],
  );
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
  final canModify =
      (currentUid != null &&
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('address_copied'))));
    }
  }

  // 웹 클럽 상세 순서: 급구→타이틀→일정→태그→가격→주소→액션줄→임베드→소유자
  _showDetailSheet(
    context,
    (close) => [
      // 1. 급구 배너 (맨 위, 컴팩트)
      if (c.isUrgent && c.urgentMsg != null && c.urgentMsg!.isNotEmpty)
        _banner(t('urgent'), c.urgentMsg!),
      // 2. 타이틀: ✓ + 이름 + 인스타 아이콘 + 🍱 북마크
      Row(
        children: [
          if (c.isVerified)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.verified, color: Color(0xFF1DA1F2), size: 22),
            ),
          Expanded(child: Text(c.name, style: _titleStyle)),
          if (c.insta != null && c.insta!.isNotEmpty)
            _instaIcon(() {
              Track.event('club_contact', {'type': 'insta', 'club_id': c.id});
              // NSM 전용 이벤트 — 웹 club-detail.js와 동일 스키마로 병행 발화
              Track.event('contact_click', {
                'channel': 'instagram',
                'club_id': c.id,
                'source': 'club',
              });
              _open('https://instagram.com/${c.insta}');
            }),
          if (c.link != null && c.link!.isNotEmpty)
            _homeIcon(() {
              Track.event('club_contact', {'type': 'link', 'club_id': c.id});
              _open(c.link);
            }),
          if (currentUid != null)
            _BookmarkButton(uid: currentUid, teamId: c.id)
          else
            // 게스트: 흐린 🍱 → 탭하면 로그인 유도(웹은 localStorage 폴백, 앱은 로그인 우선)
            BounceTap(
              onTap: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(t('login_required'))));
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Opacity(
                  opacity: 0.32,
                  child: Text('🍱', style: TextStyle(fontSize: 24)),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 4),
      // 3. 일정 morph (타이틀 바로 아래)
      _ScheduleMorph(
        summaryText: clubEvents.isNotEmpty
            ? scheduleSummary(clubEvents)
            : ((c.schedule != null && c.schedule!.isNotEmpty)
                  ? i18nSchedule(c.schedule)
                  : null),
        full: ScheduleTimetable(
          events: clubEvents,
          accent: NurungjiColors.yellow,
        ),
      ),
      // 4. 모집 키워드 — 해시태그 느낌(#)
      if (tags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags
                .map(
                  (tag) => _chip(
                    '#${i18nTarget(tag)}',
                    NurungjiColors.chipBg,
                    NurungjiColors.chipFg,
                  ),
                )
                .toList(),
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
        child: Row(
          children: [
            if (c.address != null && c.address!.isNotEmpty) ...[
              _actionPill(
                t('copy_address'),
                copyAddr,
                bg: const Color(0xFFECEFF1),
                fg: const Color(0xFF455A64),
              ),
              const SizedBox(width: 8),
            ],
            if (c.lat != null && c.lng != null) ...[
              _actionPill(
                t('directions_btn'),
                () {
                  Track.event('club_contact', {
                    'type': 'directions',
                    'club_id': c.id,
                  });
                  // NSM(주당 길찾기 클릭) 전용 이벤트 — 웹과 동일 스키마
                  Track.event('get_directions', {
                    'club_id': c.id,
                    'source': 'club',
                  });
                  _open(
                    'https://map.kakao.com/link/to/${c.name},${c.lat},${c.lng}',
                  );
                },
                bg: NurungjiColors.yellow,
                fg: NurungjiColors.dark,
              ),
              const SizedBox(width: 8),
            ],
            _actionPill(
              t('share_link'),
              shareClub,
              bg: const Color(0xFFECEFF1),
              fg: const Color(0xFF455A64),
            ),
          ],
        ),
      ),
      // 8~9. 펼쳐야 보이는 영역: 릴스 임베드 + 소유자(인증/급구/수정·삭제)
      _ExpandReveal(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (c.instaReels.isNotEmpty) _ReelsSection(reels: c.instaReels),
            if (canModify && !c.isVerified) _VerificationSection(club: c),
            // 급구는 인증팀만(웹 정책 통일 · A10)
            if (canModify && c.isVerified)
              _urgentToggle(c, context, onChanged, close),
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
                onDelete: () => _confirmDelete(
                  context,
                  onChanged,
                  close,
                  () => DataRepository().deleteClub(c.id),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
