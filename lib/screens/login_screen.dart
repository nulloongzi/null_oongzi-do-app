// login_screen.dart — 네이티브 구글/카카오/네이버/이메일 로그인.
// 웹 auth.js + social-auth.js 대응: 소셜 로그인은 제공자 SDK → CF 커스텀 토큰.
// 진행 중에는 제공자별 반투명 테마 레이어(AuthLoadingLayer)로 상태를 보여준다 —
// 카카오/네이버는 즉시, 구글/이메일은 800ms 이상 걸릴 때만(빠른 로그인 번쩍임 방지).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/analytics.dart';
import '../services/i18n.dart';
import '../services/profile_service.dart';
import '../services/social_auth_service.dart';
import '../widgets/auth_loading_layer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  String? _error;
  String _lastProvider = ''; // 지난 로그인 수단 → 해당 버튼에 칩 표시

  // 진행 표시 상태: null이면 유휴. 오버레이는 _overlayVisible일 때만 그린다.
  AuthLoadingTheme? _busyTheme;
  bool _overlayVisible = false;
  Timer? _delayTimer;

  bool get _busy => _busyTheme != null;

  // Firebase '웹 클라이언트 ID'(google-services.json oauth_client type=3).
  // Android에서 Firebase용 idToken을 받으려면 serverClientId로 이 값을 넘겨야 함.
  static const _webClientId =
      '1024551952678-memm6flqg5t62tu24jti0rsegt9jigfr.apps.googleusercontent.com';

  @override
  void initState() {
    super.initState();
    SocialAuthService.lastProvider().then((p) {
      if (mounted && p.isNotEmpty) setState(() => _lastProvider = p);
    });
  }

  // 진행 표시 시작. delayMs > 0이면 그 시간 안에 끝나는 로그인엔 오버레이가 아예 안 뜬다.
  void _startBusy(AuthLoadingTheme theme, {int delayMs = 0}) {
    _delayTimer?.cancel();
    setState(() {
      _busyTheme = theme;
      _error = null;
      _overlayVisible = delayMs <= 0;
    });
    if (delayMs > 0) {
      _delayTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted && _busyTheme != null) {
          setState(() => _overlayVisible = true);
        }
      });
    }
  }

  void _endBusy() {
    _delayTimer?.cancel();
    _delayTimer = null;
    if (mounted) {
      setState(() {
        _busyTheme = null;
        _overlayVisible = false;
      });
    }
  }

  Future<void> _googleSignIn() async {
    _startBusy(AuthLoadingTheme.google, delayMs: 800);
    try {
      final gsi = GoogleSignIn(serverClientId: _webClientId);
      final account = await gsi.signIn();
      if (account == null) {
        _endBusy(); // 사용자가 취소
        return;
      }
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await SocialAuthService.rememberProvider('google');
      Track.event('login', {'method': 'google'});
      await _afterLogin();
    } catch (e) {
      if (mounted) setState(() => _error = t('login_google_fail'));
    } finally {
      _endBusy();
    }
  }

  Future<void> _kakaoSignIn() async {
    _startBusy(AuthLoadingTheme.kakao);
    try {
      await SocialAuthService().loginWithKakao();
      Track.event('login', {'method': 'kakao'});
      await _afterLogin();
    } on SocialAuthCancelled {
      // 사용자가 취소 — 에러 문구 없이 조용히 복귀
    } catch (e) {
      if (mounted) setState(() => _error = t('login_kakao_fail'));
    } finally {
      _endBusy();
    }
  }

  Future<void> _naverSignIn() async {
    _startBusy(AuthLoadingTheme.naver);
    try {
      await SocialAuthService().loginWithNaver();
      Track.event('login', {'method': 'naver'});
      await _afterLogin();
    } on SocialAuthCancelled {
      // 사용자가 취소
    } catch (e) {
      if (mounted) setState(() => _error = t('login_naver_fail'));
    } finally {
      _endBusy();
    }
  }

  Future<void> _emailAuth({required bool signUp}) async {
    // 누룽지도 계정 지연 시 이스터에그: 노란 습기(스팀) 레이어
    _startBusy(AuthLoadingTheme.rice, delayMs: 800);
    try {
      final email = _email.text.trim();
      final pw = _pw.text;
      if (signUp) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: pw,
        );
        Track.event('sign_up', {'method': 'email'});
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: pw,
        );
        Track.event('login', {'method': 'email'});
      }
      await _afterLogin();
    } on FirebaseAuthException catch (_) {
      if (mounted) setState(() => _error = t('login_err'));
    } catch (_) {
      if (mounted) setState(() => _error = t('login_err'));
    } finally {
      _endBusy();
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
    _delayTimer?.cancel();
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  // 소셜 로그인 버튼 (웹 .btn-google-login 대응). 지난 수단이면 "지난번에 사용" 칩.
  Widget _providerBtn({
    required String providerKey,
    required Widget icon,
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    final isLast = _lastProvider == providerKey;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (isLast)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x1F000000),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  t('login_last_used'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🍚', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 8),
                    Text(
                      t('brand'),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4E342E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t('login_subtitle'),
                      style: const TextStyle(color: Color(0xFF8D6E63)),
                    ),
                    const SizedBox(height: 28),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    _providerBtn(
                      providerKey: 'google',
                      icon: const Icon(Icons.account_circle, size: 20),
                      label: t('login_google'),
                      bg: Colors.white,
                      fg: const Color(0xFF4E342E),
                      onTap: _googleSignIn,
                    ),
                    const SizedBox(height: 8),
                    _providerBtn(
                      providerKey: 'kakao',
                      icon: const Text('💬', style: TextStyle(fontSize: 16)),
                      label: t('login_kakao'),
                      bg: const Color(0xFFFEE500),
                      fg: const Color(0xFF191600),
                      onTap: _kakaoSignIn,
                    ),
                    // 네이버: client secret 설정 전엔 버튼 숨김 (웹 hideUnconfigured 대응)
                    if (kNaverLoginConfigured) ...[
                      const SizedBox(height: 8),
                      _providerBtn(
                        providerKey: 'naver',
                        icon: const Text(
                          'N',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        label: t('login_naver'),
                        bg: const Color(0xFF03C75A),
                        fg: Colors.white,
                        onTap: _naverSignIn,
                      ),
                    ],
                    const SizedBox(height: 22),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: t('email'),
                        filled: true,
                        fillColor: Colors.white,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pw,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: t('password'),
                        filled: true,
                        fillColor: Colors.white,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _busy
                                ? null
                                : () => _emailAuth(signUp: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFAC710),
                              foregroundColor: const Color(0xFF4E342E),
                            ),
                            child: Text(t('sign_in')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _emailAuth(signUp: true),
                            child: Text(t('sign_up')),
                          ),
                        ),
                      ],
                    ),
                    // 게스트 모드: 로그인 없이 계속 둘러보기(push로 열렸을 때만)
                    if (Navigator.of(context).canPop())
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: Text(
                            t('login_later'),
                            style: const TextStyle(color: Color(0xFF8D6E63)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // 진행 안내: 반투명 테마 레이어 (지도/로그인 화면이 비쳐 보임)
          if (_overlayVisible && _busyTheme != null)
            AuthLoadingLayer(theme: _busyTheme!, onCancel: _endBusy),
        ],
      ),
    );
  }
}
