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

  @override
  void initState() {
    super.initState();
    
    // [1] 앱 시작 시 위치 권한 요청
    _requestPermission();

    // [2] 웹뷰 컨트롤러 설정
    final WebViewController controller = WebViewController();
    
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            // 외부 링크(카카오맵, 인스타 등) 처리
            if (request.url.contains('map.kakao.com') || 
                request.url.contains('instagram.com') || 
                request.url.startsWith('kakaomap:') ||
                request.url.startsWith('intent:') ||
                request.url.startsWith('tel:') ||
                request.url.startsWith('mailto:')) {
              
              if (await canLaunchUrl(Uri.parse(request.url))) {
                await launchUrl(Uri.parse(request.url), mode: LaunchMode.externalApplication);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://nulloongzi.github.io/null_oongzi-do/'));

    // [3] 안드로이드 WebView 위치 권한 허용
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setGeolocationPermissionsPromptCallbacks(
        // [수정 포인트] 타입을 생략하여(origin) 호환성 문제 해결
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
      // 뒤로가기 제스처 처리
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
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}