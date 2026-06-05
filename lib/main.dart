import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
// 안드로이드 전용 기능을 위해 import
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:appinio_social_share/appinio_social_share.dart';

// ── 인스타 스토리 공유용 Facebook(Meta) App ID ──
// developers.facebook.com 에서 발급한 뒤, 아래 값과 함께
//   android/app/src/main/res/values/strings.xml 의 facebook_app_id,
//   ios/Runner/Info.plist 의 FacebookAppID / CFBundleURLSchemes(fb<APPID>)
// 를 같은 값으로 교체해야 한다.
// placeholder('000000000000000') 상태면 앱은 정상 동작하되, 스토리 스티커
// '탭 → 딥링크'(attributionURL)만 비활성이다. (handoff §1.2)
const String kFacebookAppId = '000000000000000';

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
  final AppinioSocialShare _socialShare = AppinioSocialShare();

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
      // 웹(share.js)이 인스타 스토리 카드를 넘기는 통로. 셸 안에서만 켜진다.
      ..addJavaScriptChannel(
        'NativeShare',
        onMessageReceived: (JavaScriptMessage message) {
          _handleNativeShare(message.message);
        },
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

  // 웹(share.js)에서 보낸 인스타 스토리 공유 요청 처리.
  // 계약 JSON: { type:'ig_story', stickerImage:'data:image/png;base64,…',
  //             contentUrl:'…?spot=ID', topColor:'#fff8e1', bottomColor:'#fac710' }
  Future<void> _handleNativeShare(String raw) async {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['type'] != 'ig_story') return;

      // 1) base64 dataURL → 임시 PNG 파일 (앱 캐시 디렉터리)
      final sticker = (data['stickerImage'] as String?) ?? '';
      final comma = sticker.indexOf(',');
      final b64 = comma >= 0 ? sticker.substring(comma + 1) : sticker;
      if (b64.isEmpty) return;
      final bytes = base64Decode(b64);
      final dir = await getTemporaryDirectory();
      final file = await File(
        '${dir.path}/story_${DateTime.now().millisecondsSinceEpoch}.png',
      ).writeAsBytes(bytes);

      // 2) 인스타 스토리 공유: 스티커 + 배경색 + 탭 시 attributionURL(=?spot= 딥링크)
      final topColor = (data['topColor'] as String?) ?? '#FFFFFF';
      final bottomColor = (data['bottomColor'] as String?) ?? '#FFFFFF';
      final contentUrl = data['contentUrl'] as String?;

      if (Platform.isAndroid) {
        await _socialShare.android.shareToInstagramStory(
          kFacebookAppId,
          stickerImage: file.path,
          backgroundTopColor: topColor,
          backgroundBottomColor: bottomColor,
          attributionURL: contentUrl,
        );
      } else if (Platform.isIOS) {
        await _socialShare.iOS.shareToInstagramStory(
          kFacebookAppId,
          stickerImage: file.path,
          backgroundTopColor: topColor,
          backgroundBottomColor: bottomColor,
          attributionURL: contentUrl,
        );
      }
    } catch (e) {
      debugPrint('NativeShare(ig_story) 처리 실패: $e');
    }
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
