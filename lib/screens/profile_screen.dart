// profile_screen.dart — 내 프로필(밥이름 카드). 웹 renderProfileCard/editNickname 포팅.
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/club.dart';
import '../models/profile.dart';
import '../services/data_repository.dart';
import '../services/i18n.dart';
import '../services/lunchbox_service.dart';
import '../services/profile_service.dart';
import '../services/share_service.dart';
import '../services/story_share.dart';
import '../theme.dart';
import '../widgets/app_sheet.dart';

/// 내 정보 팝업: 웹 프로필 오버레이처럼 화면 중앙에 뜨는 다이얼로그(명함).
Future<void> showProfileDialog(BuildContext context) =>
    showAppDialog<void>(context, child: const ProfileScreen());

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _svc = ProfileService();
  final _repo = DataRepository();
  final _lb = LunchboxService();
  final _cardKey = GlobalKey(); // 🎁 포장하기: 네임카드 본체만 캡처
  Profile? _profile;
  String? _mainTeam; // 🏆 대표 팀 = 도시락 첫 칸
  bool _loading = true;
  bool _wrapping = false;
  String? _uid;

  // 🎁 포장하기: .profile-card 본체만 RepaintBoundary로 캡처 → 인스타 스토리 공유
  // (상세시트의 인스타 공유와 동일 경로 재사용). Dim 처리된 지도는 캡처에 포함 안 됨.
  Future<void> _wrapShare() async {
    setState(() => _wrapping = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      if (!mounted) return;
      await shareImagePngToInstagramStory(
        context,
        bytes.buffer.asUint8List(),
        url: ShareService.siteBase,
      );
    } catch (e) {
      _snack('${t('err_share')}: $e');
    } finally {
      if (mounted) setState(() => _wrapping = false);
    }
  }

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
      await _loadMainTeam(uid);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // 대표 팀: 도시락 첫 번째로 채워진 칸의 팀 이름(클럽 또는 커스텀).
  Future<void> _loadMainTeam(String uid) async {
    try {
      final results = await Future.wait([_repo.loadClubs(), _lb.load(uid)]);
      final clubs = results[0] as List<Club>;
      final data = results[1] as LunchboxData;
      final id = data.bookmarks.firstWhere((e) => e != null, orElse: () => null);
      if (id == null) return;
      String? name;
      if (data.customTeams.containsKey(id)) {
        final m = data.customTeams[id];
        name = (m is Map ? m['name'] : null) as String?;
      } else {
        for (final c in clubs) {
          if (c.id == id) {
            name = c.name;
            break;
          }
        }
      }
      if (name != null && mounted) setState(() => _mainTeam = name);
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(t('profile_title')),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_profile != null)
                RepaintBoundary(key: _cardKey, child: _card(_profile!)),
              const SizedBox(height: 20),
              // 풋터: 좌 로그아웃(회색) · 우 🎁 포장하기(브라운, Primary) — 웹 profileContent 풋터.
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout,
                          size: 18, color: Color(0xFF555555)),
                      label: Text(t('logout')),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE0E0E0),
                          foregroundColor: const Color(0xFF555555),
                          elevation: 0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _wrapping ? null : _wrapShare,
                      icon: _wrapping
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.card_giftcard, size: 18),
                      label: Text(t('wrap_share')),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: NurungjiColors.brown,
                          foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(Profile p) {
    final joined = _joinedLabel(p);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.bgColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Stack(
        children: [
          // 좌상단 워터마크: 밥 종류(등급/원산지 느낌).
          if (p.nickname.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              child: Text(
                p.nickname,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFBCAAA4)),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              const Text('🍚', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 8),
              // 닉네임 + 🥢 인라인 수정
              Row(
                children: [
                  Flexible(
                    child: Text(p.fullNickname,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: NurungjiColors.dark)),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _rename,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0x33FFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🥢', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
              if (joined.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(joined,
                      style: const TextStyle(color: NurungjiColors.brown)),
                ),
              if (_mainTeam != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 8,
                            offset: Offset(0, 3)),
                      ],
                    ),
                    child: Text('🏆 $_mainTeam',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: NurungjiColors.dark)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
