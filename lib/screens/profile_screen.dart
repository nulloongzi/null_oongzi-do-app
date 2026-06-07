// profile_screen.dart — 내 프로필(밥이름 카드). 웹 renderProfileCard/editNickname 포팅.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/profile.dart';
import '../services/i18n.dart';
import '../services/profile_service.dart';
import '../theme.dart';
import 'lunchbox_screen.dart';
import 'share_image_screen.dart';

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
    if (mounted) setState(() => _loading = false);
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
    return Scaffold(
      appBar: AppBar(title: Text(t('profile_title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_profile != null) _card(_profile!),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LunchboxScreen())),
                    icon: const Icon(Icons.lunch_dining, size: 18),
                    label: Text(t('my_lunchbox')),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ShareImageScreen())),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: Text(t('share_image_btn_profile')),
                  ),
                  const SizedBox(height: 10),
                  if (_profile != null)
                    OutlinedButton.icon(
                      onPressed: _rename,
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(t('change_nickname')),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🍚', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          Text(p.fullNickname,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: NurungjiColors.dark)),
          if (joined.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(joined,
                  style: const TextStyle(color: NurungjiColors.brown)),
            ),
        ],
      ),
    );
  }
}
