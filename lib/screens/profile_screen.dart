// profile_screen.dart — 내 프로필(밥이름 카드). 웹 renderProfileCard/editNickname 포팅.
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
import '../widgets/app_sheet.dart';
import 'lunchbox_screen.dart';
import 'share_image_screen.dart';

/// 내 정보 팝업: 풀스크린 라우트 대신 지도 위로 뜨는 모달 바텀시트(웹 프로필 오버레이 대응).
Future<void> showProfileSheet(BuildContext context) =>
    showAppSheet<void>(context, child: const ProfileScreen());

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _svc = ProfileService();
  final _repo = DataRepository();
  final _lb = LunchboxService();
  Profile? _profile;
  String? _mainTeam; // 🏆 대표 팀 = 도시락 첫 칸
  bool _loading = true;
  String? _uid;

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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
              if (_profile != null) _card(_profile!),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                // 도시락도 시트로 (이 시트 위에 스택). 풀스크린 전환 제거.
                onPressed: () => showLunchboxSheet(context),
                icon: const Icon(Icons.lunch_dining, size: 18),
                label: Text(t('my_lunchbox')),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                // 🎁 포장하기: 네임카드를 이미지로 캡처해 공유.
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ShareImageScreen())),
                icon: const Icon(Icons.card_giftcard, size: 18),
                label: Text(t('wrap_share')),
                style: ElevatedButton.styleFrom(
                    backgroundColor: NurungjiColors.brown,
                    foregroundColor: Colors.white),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, size: 18, color: Colors.red),
                label: Text(t('logout'),
                    style: const TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red)),
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
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: NurungjiColors.dark.withValues(alpha: 0.3)),
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
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x22000000)),
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
