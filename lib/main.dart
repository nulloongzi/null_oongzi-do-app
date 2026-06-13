import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
// 안드로이드 전용 기능을 위해 import
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/clubs_repository.dart';
import 'services/lunchbox_repository.dart';
import 'state/lunchbox_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/lunchbox_fab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<ClubsRepository>(create: (_) => ClubsRepository()),
        Provider<LunchboxRepository>(create: (_) => LunchboxRepository()),
        ChangeNotifierProvider<LunchboxController>(
          create: (ctx) => LunchboxController(
            auth: ctx.read<AuthService>(),
            clubs: ctx.read<ClubsRepository>(),
            repo: ctx.read<LunchboxRepository>(),
          )..loadData(),
        ),
      ],
      child: MaterialApp(
        title: '누룽지도',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const MapScreen(),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0; // 로딩 상태 확인용 변수 추가
  StreamSubscription<dynamic>? _authSub;

  // 웹의 도시락 FAB 숨김 (네이티브 FAB와 중복 방지)
  static const _hideWebFabJs = '''
    (function(){
      var s = document.getElementById('nativeHideFab');
      if (!s) {
        s = document.createElement('style');
        s.id = 'nativeHideFab';
        s.innerHTML = '.fab-lunchbox{display:none !important;}';
        document.head.appendChild(s);
      }
    })();
  ''';

  @override
  void initState() {
    super.initState();
    _requestPermission();

    // 로그인 상태 변화 시 도시락 데이터 재로드
    final auth = context.read<AuthService>();
    _authSub = auth.authStateChanges().listen((_) {
      if (mounted) context.read<LunchboxController>().loadData();
    });

    final WebViewController controller = WebViewController();

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() {
              _loadingProgress = progress; // 로딩 진행률 업데이트
            });
          },
          onPageFinished: (_) {
            _controller.runJavaScript(_hideWebFabJs);
          },
          onNavigationRequest: (NavigationRequest request) async {
            // 기존 외부 링크 처리 로직 유지
            if (request.url.contains('map.kakao.com') ||
                request.url.contains('instagram.com') ||
                request.url.startsWith('kakaomap:') ||
                request.url.startsWith('intent:') ||
                request.url.startsWith('tel:') ||
                request.url.startsWith('mailto:')) {
              if (await canLaunchUrl(Uri.parse(request.url))) {
                await launchUrl(
                  Uri.parse(request.url),
                  mode: LaunchMode.externalApplication,
                );
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://nulloongzi.github.io/null_oongzi-do/'));

    // 안드로이드 특정 설정 유지
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setGeolocationPermissionsPromptCallbacks(
            onShowPrompt: (origin) async {
              return const GeolocationPermissionsResponse(
                allow: true,
                retain: false,
              );
            },
          );
    }

    _controller = controller;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // 권한 요청 함수
  Future<void> _requestPermission() async {
    await [Permission.location].request();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            // Stack을 사용하여 로딩바와 도시락 FAB를 웹뷰 위에 배치
            children: [
              WebViewWidget(controller: _controller),
              // 로딩이 진행 중일 때만 상단에 바 표시
              if (_loadingProgress < 100)
                LinearProgressIndicator(
                  value: _loadingProgress / 100.0,
                  backgroundColor: Colors.white,
                  color: const Color(0xFFFAC710), // 앱 메인 컬러
                  minHeight: 3,
                ),
              // 네이티브 도시락 FAB (웹 FAB와 같은 좌하단 위치)
              const Positioned(
                left: 15,
                bottom: 95,
                child: LunchboxFab(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
