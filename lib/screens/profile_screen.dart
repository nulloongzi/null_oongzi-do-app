// profile_screen.dart — 내 프로필(밥이름 카드). 웹 renderProfileCard/editNickname 포팅.
// 웹처럼 화면 중앙 팝업 모달(딤 blur + slideUp 스프링)로 표시.
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../services/deep_link_service.dart' show kCaptureMode;
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/profile.dart';
import '../services/analytics.dart';
import '../services/data_repository.dart';
import '../services/friends_service.dart';
import '../services/i18n.dart';
import '../services/lunchbox_service.dart';
import '../services/profile_service.dart';
import '../services/social_auth_service.dart';
import '../theme.dart';
import '../widgets/bounce_tap.dart';
import '../widgets/friends_page.dart';
import '../widgets/provider_stamp.dart';
import 'share_image_screen.dart';

/// 내 정보 팝업: 웹 프로필 오버레이 대응 — 화면 중앙 카드 모달(딤 blur + 스프링 등장).
/// 옆으로 넘기면 둘째 장이 밥친구다. [initialPage] 1 + [inviteCode] 는 초대 링크(?invite=) 착지.
Future<void> showProfileSheet(
  BuildContext context, {
  int initialPage = 0,
  String? inviteCode,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false, // 딤·blur·바깥탭을 _ProfileModal에서 직접 처리
    barrierLabel: 'profile',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, a1, a2) =>
        _ProfileModal(initialPage: initialPage, inviteCode: inviteCode),
    transitionBuilder: (ctx, anim, sec, child) =>
        FadeTransition(opacity: anim, child: child), // 오버레이 fadeIn
  );
}

// 중앙 모달: 배경 blur+갈색 딤(바깥 탭 닫기) + 스프링으로 떠오르는 카드.
class _ProfileModal extends StatelessWidget {
  final int initialPage;
  final String? inviteCode;
  const _ProfileModal({this.initialPage = 0, this.inviteCode});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(), // 바깥 탭 닫기
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                color: const Color(0x595D4037),
              ), // 웹 rgba(93,64,55,.35)
            ),
          ),
        ),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutBack, // 통통 스프링(웹 slideUp)
            builder: (ctx, v, child) => Transform.translate(
              offset: Offset(0, (1 - v) * 40),
              child: Transform.scale(scale: 0.95 + 0.05 * v, child: child),
            ),
            child: GestureDetector(
              onTap: () {}, // 카드 탭 흡수(닫기 방지)
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 360,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: ProfilePager(
                  initialPage: initialPage,
                  inviteCode: inviteCode,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _svc = ProfileService();
  Profile? _profile;
  bool _loading = true;
  String? _uid;
  ({String name, bool isCustom})? _mainTeam; // 대표팀(첫 찜팀)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _uid = uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final p = await _svc.ensureProfile(uid);
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
    await _loadMainTeam(uid);
    if (mounted) setState(() => _loading = false);
  }

  // 대표팀 = 도시락 첫 찜팀(bookmarks[0]). 커스텀이면 🍙, 클럽이면 🏆.
  Future<void> _loadMainTeam(String uid) async {
    try {
      final lb = await LunchboxService().load(uid);
      String? firstId;
      for (final b in lb.bookmarks) {
        if (b != null) {
          firstId = b;
          break;
        }
      }
      if (firstId == null) return; // 찜한 팀 없음
      final custom = lb.customTeams[firstId];
      if (custom is Map && custom['name'] is String) {
        _mainTeam = (name: custom['name'] as String, isCustom: true);
        return;
      }
      final clubs = await DataRepository().loadClubs();
      for (final c in clubs) {
        if (c.id == firstId) {
          _mainTeam = (name: c.name, isCustom: false);
          return;
        }
      }
    } catch (_) {}
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _rename() async {
    final p = _profile;
    final uid = _uid;
    if (p == null || uid == null) return;
    final ctrl = TextEditingController(text: p.fullNickname);
    // 검사는 팝업 안에서 한다 — 틀리면 닫지 않고 칸 바로 아래에 알린다(웹 nzPrompt validate 와 같음)
    final newName = await showDialog<String>(
      context: context,
      builder: (dctx) {
        String? error;
        var busy = false;
        return StatefulBuilder(
          builder: (dctx, setLocal) {
            Future<void> submit() async {
              if (busy) return;
              final n = ctrl.text.trim();
              String? err;
              if (n.isEmpty) {
                err = t('nick_empty');
              } else if (n.contains('-')) {
                err = t('nickname_hyphen');
              } else if (n != p.fullNickname) {
                setLocal(() => busy = true);
                try {
                  if (isReservedNickname(n) &&
                      !await _svc.canUseReservedNickname(uid)) {
                    err = t('nickname_reserved');
                  } else if (await _svc.isDuplicate(n)) {
                    err = t('nickname_dup');
                  }
                } catch (e) {
                  debugPrint('rename check: $e');
                  err = t('nick_change_error');
                }
                if (!dctx.mounted) return;
                setLocal(() => busy = false);
              }
              if (err != null) {
                setLocal(() => error = err);
                return;
              }
              Navigator.pop(dctx, n);
            }

            return AlertDialog(
              title: Text(t('change_nickname')),
              content: TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 30,
                onChanged: (_) {
                  if (error != null) setLocal(() => error = null);
                },
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  hintText: t('nickname_hint'),
                  errorText: error,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dctx),
                  child: Text(t('cancel')),
                ),
                TextButton(
                  onPressed: busy ? null : submit,
                  child: Text(t('nick_btn')),
                ),
              ],
            );
          },
        );
      },
    );
    ctrl.dispose(); // 다이얼로그 종료 후 컨트롤러 정리(누수 방지)
    if (newName == null || newName == p.fullNickname) return;
    try {
      await _svc.rename(uid, newName);
      if (mounted) {
        setState(
          () => _profile = Profile(
            fullNickname: newName,
            nickname: p.nickname,
            color: p.color,
            createdAt: p.createdAt,
          ),
        );
      }
      _snack(t('nickname_done'));
    } catch (e) {
      debugPrint('rename: $e');
      _snack(t('nick_change_error'));
    }
  }

  Future<void> _signOut() async {
    // 실수 방지 확인(웹 au_logout_confirm 대응)
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        content: Text(t('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(t('logout')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await SocialAuthService.signOutProviders(); // 카카오/네이버 세션도 정리
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pop(context); // 게스트로 지도 복귀
  }

  // 회원 탈퇴(웹 auth.js deleteMyAccount 와 같은 흐름): 확인 → 서버가 지움 → 카카오 연결 끊기·
  // 네이버 토큰 삭제 → 로그아웃 → 게스트로 지도 복귀.
  bool _deleting = false;
  Future<void> _deleteAccount() async {
    if (_deleting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(t('acct_delete_title')),
        content: Text(t('acct_delete_body')),
        actions: [
          TextButton(
            autofocus: true, // 위험한 작업은 '취소'에 먼저(웹 nzConfirm danger 와 같음)
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(t('cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: NurungjiColors.urgentInk,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(t('acct_delete_btn')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    _snack(t('acct_deleting'));
    try {
      await ProfileService.deleteMyAccount();
    } catch (e) {
      debugPrint('deleteMyAccount: $e');
      if (mounted) setState(() => _deleting = false);
      _snack(t('acct_delete_err'));
      return;
    }
    Track.event('account_delete');
    try {
      await GoogleSignIn().disconnect();
    } catch (_) {}
    await SocialAuthService.unlinkProvidersAfterDeletion();
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    _snack(t('acct_deleted'));
    if (mounted) Navigator.pop(context); // 게스트로 지도 복귀
  }

  String _joinedLabel(Profile p) => p.createdAt == null
      ? ''
      : '${t('joined')} ${p.createdAt!.year}.${p.createdAt!.month}.${p.createdAt!.day}';

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_profile != null)
            // 웹 profile-card 그대로: 카드 하나(푸터 버튼 포함)만 중앙에.
            _card(_profile!),
        ],
      ),
    );
  }

  // 웹 .btn-logout/.pc-share-btn 톤의 알약 버튼(눌림 scale .95).
  Widget _footerBtn({
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return BounceTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x145D4037),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }

  Widget _card(Profile p) {
    final joined = _joinedLabel(p);
    final mt = _mainTeam;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: p.bgColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x225D4037),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 크기 결정용 본문(중앙 정렬)
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 닉네임 + 🥢 편집(웹 .pc-header / .pc-edit-btn)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        p.fullNickname,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: NurungjiColors.dark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    BounceTap(
                      onTap: _rename,
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0x99FFFFFF),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x0D000000)),
                        ),
                        child: const Text('🥢', style: TextStyle(fontSize: 15)),
                      ),
                    ),
                  ],
                ),
                if (joined.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      joined,
                      style: const TextStyle(
                        color: NurungjiColors.brown,
                        fontSize: 13,
                      ),
                    ),
                  ),
                Container(
                  width: 90,
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  color: const Color(0x338D6E63), // 옅은 구분선(웹 .pc-divider)
                ),
                // 메인 팀 뱃지(웹 .pc-main-team)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xB3FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Text(
                    mt == null
                        ? t('no_saved_team')
                        : '${mt.isCustom ? '🍙' : '🏆'} ${mt.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: NurungjiColors.dark,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                // 푸터(웹 .pc-footer): [로그아웃 | 🎁 포장하기] 나란히
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _footerBtn(
                      label: t('logout'),
                      bg: const Color(0x99D7CCC8), // 웹 .btn-logout
                      fg: NurungjiColors.dark,
                      onTap: _signOut,
                    ),
                    const SizedBox(width: 12),
                    _footerBtn(
                      label: t('share_wrap'), // 🎁 포장하기
                      bg: NurungjiColors.brown, // 웹 .pc-share-btn
                      fg: Colors.white,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ShareImageScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                // 회원 탈퇴 입구(웹 .pc-delete-link) — 눈에 띄지 않게, 그러나 찾을 수 있게
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _deleting ? null : _deleteAccount,
                    style: TextButton.styleFrom(
                      foregroundColor: NurungjiColors.dark.withValues(
                        alpha: 0.55,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    child: Text(t('acct_delete')),
                  ),
                ),
              ],
            ),
          ),
          // 좌상단 워터마크: 로그인 수단 스탬프(이스터에그) + 밥 종류(웹 .pc-provider-mark/.pc-rice-type)
          Positioned(
            top: 0,
            left: 0,
            child: Row(
              children: [
                ProviderStamp(
                  provider: SocialAuthService.detectProviderOf(
                    FirebaseAuth.instance.currentUser,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  p.nickname,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0x4D5D4037),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 🍚 팝업 두 장: 내 카드 ↔ 밥친구 (웹 js/friends.js 와 같은 동작) ─────────
// 위의 도트 두 개가 두 장을 알려주고, 받은 신청을 아직 안 봤으면 둘째 점이 커지고 빛난다.
// 두 장의 높이가 달라서, 팝업 높이는 보고 있는 장에 맞춘다(넘기는 동안은 두 높이 사이를 보간).
// 로그아웃·익명이면 둘째 장 없이 지금처럼 카드 한 장.
/// 캡처 시연: 'page:0|1'(장 넘기기) 'scroll:end|top'(지금 장을 끝까지·맨 위로). '#n' 꼬리 허용.
final ValueNotifier<String> profileDemo = ValueNotifier<String>('');

class ProfilePager extends StatefulWidget {
  final int initialPage;
  final String? inviteCode;
  final double maxHeight;
  const ProfilePager({
    super.key,
    this.initialPage = 0,
    this.inviteCode,
    required this.maxHeight,
  });

  @override
  State<ProfilePager> createState() => _ProfilePagerState();
}

class _ProfilePagerState extends State<ProfilePager> {
  late final PageController _pc = PageController(
    initialPage: widget.initialPage,
  );
  final _heights = <double>[320, 320];
  final _scrolls = [ScrollController(), ScrollController()]; // 장마다(시연에서 내릴 때)
  late double _page = widget.initialPage.toDouble();
  static const _dotsH = 28.0;
  static const _pad = EdgeInsets.symmetric(horizontal: 20, vertical: 8);

  @override
  void initState() {
    super.initState();
    _pc.addListener(() {
      final p = _pc.page ?? _page;
      if (p != _page) setState(() => _page = p);
    });
    if (widget.initialPage == 1) _onFriendsShown();
    if (kCaptureMode) profileDemo.addListener(_onDemo);
  }

  void _onDemo() {
    if (!mounted) return;
    final c = profileDemo.value.split('#').first;
    if (c.startsWith('page:')) {
      final i = int.tryParse(c.substring(5)) ?? 0;
      if (_pc.hasClients) {
        _pc.animateToPage(
          i,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }
    } else if (c.startsWith('scroll:')) {
      final sc = _scrolls[_page.round().clamp(0, 1)];
      if (!sc.hasClients) return;
      sc.animateTo(
        c == 'scroll:end' ? sc.position.maxScrollExtent : 0,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    profileDemo.removeListener(_onDemo);
    for (final s in _scrolls) {
      s.dispose();
    }
    _pc.dispose();
    super.dispose();
  }

  void _onFriendsShown() {
    FriendsHub.instance.markSeen();
    Track.event('friends_open');
  }

  void _setHeight(int i, double h) {
    if (!mounted || (_heights[i] - h).abs() < 0.5) return;
    setState(() => _heights[i] = h);
  }

  Widget _pageOf(int i, Widget child) => SingleChildScrollView(
    controller: _scrolls[i],
    padding: _pad,
    child: _MeasureSize(
      onSize: (s) => _setHeight(i, s.height + _pad.vertical),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FriendState>(
      valueListenable: FriendsHub.instance.state,
      builder: (ctx, st, _) {
        if (st.uid == null) {
          return const SingleChildScrollView(
            padding: _pad,
            child: ProfileScreen(),
          );
        }
        final lo = _page.floor().clamp(0, 1), hi = _page.ceil().clamp(0, 1);
        final h = (_heights[lo] + (_heights[hi] - _heights[lo]) * (_page - lo))
            .clamp(120.0, widget.maxHeight - _dotsH);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _dotsH,
              child: ValueListenableBuilder<bool>(
                valueListenable: FriendsHub.instance.hasUnseen,
                builder: (ctx, unseen, _) => _Dots(
                  page: _page,
                  signal: unseen,
                  onTap: (i) => _pc.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: h,
              child: PageView(
                controller: _pc,
                onPageChanged: (i) {
                  if (i == 1) _onFriendsShown();
                },
                children: [
                  _pageOf(0, const ProfileScreen()),
                  _pageOf(1, FriendsPage(initialCode: widget.inviteCode)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Dots extends StatelessWidget {
  final double page;
  final bool signal; // 받은 신청을 아직 못 봄 → 둘째 점이 커지고 빛난다
  final void Function(int) onTap;
  const _Dots({required this.page, required this.signal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cur = page.round();
    Widget dot(int i) {
      final on = cur == i;
      final sig = i == 1 && !on && signal;
      return Semantics(
        button: true,
        selected: on,
        label: t(i == 0 ? 'fr_page_card' : 'fr_page_friends'),
        child: GestureDetector(
          onTap: () => onTap(i),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: on ? 22 : (sig ? 13 : 8),
              height: sig ? 13 : 8,
              decoration: BoxDecoration(
                color: sig
                    ? NurungjiColors.yellow
                    : (on ? const Color(0xFFFFF8E1) : const Color(0x99FFF8E1)),
                borderRadius: BorderRadius.circular(999),
                boxShadow: sig
                    ? const [
                        BoxShadow(color: Color(0x59FAC710), spreadRadius: 3),
                        BoxShadow(color: Color(0xE6FAC710), blurRadius: 14),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [dot(0), dot(1)],
    );
  }
}

/// 자식의 실제 크기를 알려준다 — 팝업 높이를 보고 있는 장에 맞추려고.
class _MeasureSize extends SingleChildRenderObjectWidget {
  final void Function(Size) onSize;
  const _MeasureSize({required this.onSize, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _MeasureBox(onSize);

  @override
  void updateRenderObject(BuildContext context, _MeasureBox renderObject) {
    renderObject.onSize = onSize;
  }
}

class _MeasureBox extends RenderProxyBox {
  _MeasureBox(this.onSize);
  void Function(Size) onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size != _last) {
      _last = size;
      final s = size;
      WidgetsBinding.instance.addPostFrameCallback((_) => onSize(s));
    }
  }
}
