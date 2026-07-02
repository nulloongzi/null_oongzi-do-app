// profile_screen.dart — 내 프로필(밥이름 카드). 웹 renderProfileCard/editNickname 포팅.
// 웹처럼 화면 중앙 팝업 모달(딤 blur + slideUp 스프링)로 표시.
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/club.dart';
import '../models/profile.dart';
import '../services/data_repository.dart';
import '../services/i18n.dart';
import '../services/lunchbox_service.dart';
import '../services/profile_service.dart';
import '../theme.dart';
import '../widgets/bounce_tap.dart';
import 'share_image_screen.dart';

/// 내 정보 팝업: 웹 프로필 오버레이 대응 — 화면 중앙 카드 모달(딤 blur + 스프링 등장).
Future<void> showProfileSheet(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false, // 딤·blur·바깥탭을 _ProfileModal에서 직접 처리
    barrierLabel: 'profile',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, a1, a2) => const _ProfileModal(),
    transitionBuilder: (ctx, anim, sec, child) =>
        FadeTransition(opacity: anim, child: child), // 오버레이 fadeIn
  );
}

// 중앙 모달: 배경 blur+갈색 딤(바깥 탭 닫기) + 스프링으로 떠오르는 카드.
class _ProfileModal extends StatelessWidget {
  const _ProfileModal();

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
              child: Container(color: const Color(0x595D4037)), // 웹 rgba(93,64,55,.35)
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
                child: const SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: ProfileScreen(),
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
    final newName = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(t('change_nickname')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 30,
          decoration: InputDecoration(hintText: t('nickname_hint')),
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
    ctrl.dispose(); // 다이얼로그 종료 후 컨트롤러 정리(누수 방지)
    if (newName == null) return;
    final n = newName.trim();
    if (n.isEmpty || n == p.fullNickname) return;
    if (n.contains('-')) {
      _snack(t('nickname_hyphen'));
      return;
    }
    try {
      if (await _svc.isDuplicate(n)) {
        _snack(t('nickname_dup'));
        return;
      }
      await _svc.rename(uid, n);
      if (mounted) {
        setState(() => _profile = Profile(
            fullNickname: n,
            nickname: p.nickname,
            color: p.color,
            createdAt: p.createdAt));
      }
      _snack(t('nickname_done'));
    } catch (e) {
      _snack('${t('err_generic')}: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pop(context); // AuthGate가 로그인 화면으로 전환
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
                color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
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
          BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 6)),
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
                      child: Text(p.fullNickname,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: NurungjiColors.dark)),
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
                    child: Text(joined,
                        style: const TextStyle(
                            color: NurungjiColors.brown, fontSize: 13)),
                  ),
                Container(
                  width: 90,
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  color: const Color(0x338D6E63), // 옅은 구분선(웹 .pc-divider)
                ),
                // 메인 팀 뱃지(웹 .pc-main-team)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        color: NurungjiColors.dark),
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
                              builder: (_) => const ShareImageScreen())),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 누룽지 워터마크(밥 종류) — 좌상단 옅게(웹 .pc-rice-type)
          Positioned(
            top: 0,
            left: 0,
            child: Text(p.nickname,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0x4D5D4037))),
          ),
        ],
      ),
    );
  }
}
