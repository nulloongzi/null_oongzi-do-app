import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
// 안드로이드 전용 기능을 위해 import
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '누룽지도',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFAC710)),
        useMaterial3: true,
      ),
      home: const MapScreen(),
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

  @override
  void initState() {
    super.initState();
    _requestPermission();

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
            // Stack을 사용하여 로딩바를 웹뷰 위에 배치
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
            ],
          ),
        ),
      ),
    );
  }
}
