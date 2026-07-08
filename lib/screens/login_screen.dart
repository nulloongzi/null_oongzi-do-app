// login_screen.dart — 네이티브 구글/이메일 로그인 (웹뷰 OAuth 차단 탈출)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/analytics.dart';
import '../services/i18n.dart';
import '../services/profile_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  String? _error;

  // Firebase '웹 클라이언트 ID'(google-services.json oauth_client type=3).
  // Android에서 Firebase용 idToken을 받으려면 serverClientId로 이 값을 넘겨야 함.
  static const _webClientId =
      '1024551952678-memm6flqg5t62tu24jti0rsegt9jigfr.apps.googleusercontent.com';

  Future<void> _googleSignIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final gsi = GoogleSignIn(serverClientId: _webClientId);
      final account = await gsi.signIn();
      if (account == null) {
        setState(() => _busy = false); // 사용자가 취소
        return;
      }
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      Track.event('login', {'method': 'google'});
      await _afterLogin();
    } catch (e) {
      setState(() => _error = t('login_google_fail'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _emailAuth({required bool signUp}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final pw = _pw.text;
      if (signUp) {
        await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: pw);
        Track.event('sign_up', {'method': 'email'});
      } else {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: pw);
        Track.event('login', {'method': 'email'});
      }
      await _afterLogin();
    } on FirebaseAuthException catch (_) {
      setState(() => _error = t('login_err'));
    } catch (_) {
      setState(() => _error = t('login_err'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // 로그인 성공 공통: 밥이름 프로필 보장(조용히) 후, push로 열렸으면 지도로 복귀.
  Future<void> _afterLogin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await ProfileService().ensureProfile(uid);
      } catch (_) {}
    }
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🍚', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text(t('brand'),
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4E342E))),
                const SizedBox(height: 6),
                Text(t('login_subtitle'),
                    style: const TextStyle(color: Color(0xFF8D6E63))),
                const SizedBox(height: 28),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _googleSignIn,
                    icon: const Icon(Icons.account_circle),
                    label: Text(t('login_google')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4E342E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                      labelText: t('email'),
                      filled: true,
                      fillColor: Colors.white,
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _pw,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: t('password'),
                      filled: true,
                      fillColor: Colors.white,
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy ? null : () => _emailAuth(signUp: false),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFAC710),
                            foregroundColor: const Color(0xFF4E342E)),
                        child: Text(t('sign_in')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _emailAuth(signUp: true),
                        child: Text(t('sign_up')),
                      ),
                    ),
                  ],
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 18),
                    child: CircularProgressIndicator(),
                  ),
                // 게스트 모드: 로그인 없이 계속 둘러보기(push로 열렸을 때만)
                if (Navigator.of(context).canPop())
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: TextButton(
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(false),
                      child: Text(t('login_later'),
                          style: const TextStyle(color: Color(0xFF8D6E63))),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
