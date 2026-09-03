// map_screen.dart — 네이티브 네이버지도(flutter_naver_map) + Firestore 마커
// kakao_map_plugin(웹뷰) → flutter_naver_map(네이티브)로 전환: 패닝 부드러움 + 한국 데이터.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';
import '../services/analytics.dart';
import '../services/data_repository.dart';
import '../services/club_filter.dart';
import '../services/deep_link_service.dart';
import '../services/profile_service.dart';
import '../services/i18n.dart';
import '../services/pickup_filter.dart';
import '../services/region_match.dart';
import '../services/share_service.dart';
import '../services/story_share.dart';
import '../services/lunchbox_service.dart';
import '../theme.dart';
import 'detail_sheet.dart';
import 'login_screen.dart';
import 'pickup_form_screen.dart';
import 'club_form_screen.dart';
import 'lunchbox_screen.dart';
import 'profile_screen.dart';
import 'share_image_screen.dart';
import '../widgets/bounce_tap.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/glass_surface.dart';
import '../widgets/insta_embed.dart';
import '../widgets/map_detail_panel.dart';
import '../widgets/pickup_list_panel.dart';
import '../widgets/share_menu.dart';
import '../widgets/story_card.dart';

// 마커 1건 스펙(클럽/스팟 공통) — 아이콘 병렬 빌드 후 마커를 한 번에 생성하기 위한 중간 표현.
class _MarkerSpec {
  final String id;
  final NLatLng pos;
  final String name;
  final bool red; // 빨강 핀(급구/스팟)
  final bool urgent;
  final bool verified;
  final bool clusterable; // 급구 클럽=false(항상 표시), 그 외=true
  final VoidCallback onTap;
  const _MarkerSpec({
    required this.id,
    required this.pos,
    required this.name,
    required this.red,
    required this.urgent,
    required this.verified,
    required this.clusterable,
    required this.onTap,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

/// 마케팅 자산 자동 캡처 빌드 플래그(`--dart-define=CAPTURE_MODE=true`).
/// 켜져 있을 때만 `?capture=` 딥링크가 화면을 결정적으로 이동한다(일반 릴리즈엔 무영향).
const bool kCaptureMode = bool.fromEnvironment('CAPTURE_MODE');

/// GPU 없는 CI 에뮬(SwiftShader)용 완화 플래그.
/// 고배율 타일이 오지 않고 카메라 이동 중 렌더가 깨져, 축척을 낮추고 fitBounds 를
/// 건너뛴다. **로컬/실기기(진짜 GPU)에서는 켜지 않는다** — 앱의 실제 동작 그대로가
/// 더 좋은 그림이고, 그게 홍보 영상에 맞다.
const bool kCaptureLowGpu = bool.fromEnvironment('CAPTURE_LOW_GPU');

class _MapScreenState extends State<MapScreen> {
  NaverMapController? _controller;
  final _repo = DataRepository();
  List<Club> _clubs = [];
  List<PickupSpot> _spots = [];
  String _tab = 'clubs'; // 'clubs' | 'pickup'
  bool _loading = true;
  String? _error;
  ClubFilter _filter = const ClubFilter(); // 동호회 필터/검색
  bool _pkEnglishOnly = false; // 픽업: English OK만
  String _pkRegion = ''; // 픽업: 지역 칩. '' = 전체
  String _pkLevel = ''; // 픽업: 레벨. '' = 전체
  // 픽업: 지도/목록 토글. **기본은 목록** — 장소가 유동적인 크루는 좌표가 없어
  // 지도에 마커가 안 뜬다. 지도를 기본으로 두면 그런 크루가 첫 화면에서
  // 존재하지 않는 것처럼 보인다(안내 배너로만 알 수 있음).
  bool _pickupListView = true;
  bool _isAdmin = false; // 관리자(픽업 모더레이션 삭제)
  final _search = TextEditingController(); // 상단 검색바 (동호회=필터키워드 / 픽업=목록검색)
  final _deepLinks = DeepLinkService();
  NOverlayImage? _clusterIcon; // 클러스터 노란 원 (런타임 생성)
  _ReelPeek? _reelPeek; // 마커 롱프레스 → 블러+릴스 미리보기(인스타 피드 꾹 누르기 느낌)
  DateTime? _lastBackPress; // 뒤로가기 2번 종료 판정

  @override
  void initState() {
    super.initState();
    _load();
    _deepLinks.start(_handleDeepLink);
    // 첫 로그인 시 밥이름 프로필 생성 (조용히, 실패 무시)
    final uid = _repo.currentUid;
    if (uid != null) {
      ProfileService().ensureProfile(uid).then((_) {}, onError: (_) {});
    }
  }

  @override
  void dispose() {
    detailPanel.value = null; // 화면 떠날 때 잔존 패널 정리
    _labelFadeTimer?.cancel();
    _search.dispose();
    _deepLinks.dispose();
    super.dispose();
  }

  // 상단 검색: 동호회=필터 키워드 + 결과맞춤 / 픽업=목록·마커 재필터.
  void _onSearch(String v) {
    if (_tab == 'clubs') {
      setState(() => _filter = _filter.copyWith(keyword: v));
      _refreshMarkers();
      _fitToFilter();
    } else {
      setState(() {});
      _refreshMarkers();
    }
  }

  // 픽업: 지역 + English-OK + 검색어(제목/장소/주소/인스타) 필터.
  // 순수 로직은 pickup_filter.dart — 웹 js/pickup-filter.js 와 같은 규칙이라 공유 링크가 재현된다.
  List<PickupSpot> _visibleSpots() => filterPickupSpots(
    _spots,
    region: _pkRegion,
    level: _pkLevel,
    englishOnly: _pkEnglishOnly,
    keyword: _search.text,
  );

  /// 현재 필터에서 좌표가 없어 지도에 못 뜨는 크루 수(목록에는 있음).
  int get _spotsOffMap =>
      _visibleSpots().where((s) => s.lat == null || s.lng == null).length;

  // 📍 내 위치로 이동(추적 follow). 권한 거부 시 무시.
  Future<void> _moveToMe() async {
    try {
      final st = await Permission.location.request();
      if (st.isGranted) {
        _controller?.setLocationTrackingMode(NLocationTrackingMode.follow);
      }
    } catch (_) {}
  }

  // 게스트 모드(A1): 로그인 필요한 액션 앞 공통 가드 — 로그인 화면 push 후 상태 갱신.
  Future<bool> _ensureLogin() async {
    if (_repo.currentUid != null) return true;
    _snack(t('login_required'));
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (!mounted || _repo.currentUid == null) return false;
    // 세션 중 로그인 → 관리자 상태 갱신
    _repo
        .isAdmin()
        .then((v) {
          if (mounted && v != _isAdmin) setState(() => _isAdmin = v);
        })
        .catchError((_) {});
    return true;
  }

  // 도시락/프로필: 풀스크린 라우트 대신 지도 위 모달 시트(웹 오버레이 동작 대응).
  Future<void> _openLunchbox() async {
    if (!await _ensureLogin() || !mounted) return;
    showLunchboxSheet(context);
  }

  Future<void> _openProfile() async {
    if (!await _ensureLogin() || !mounted) return;
    showProfileSheet(context);
  }

  // 딥링크(?club=/?spot=) → 탭 전환 + 상세 오픈. 메모리에 없으면 단건 조회.
  Future<void> _handleDeepLink(DeepLink d) async {
    if (!mounted) return;
    if (d.kind == 'capture') {
      if (kCaptureMode) _runCapture(d.id, d.lang);
      return;
    }
    Track.event(
      'deep_link_open',
      d.kind == 'club' ? {'club_id': d.id} : {'spot_id': d.id},
    );
    if (d.kind == 'club') {
      Club? c;
      for (final x in _clubs) {
        if (x.id == d.id) {
          c = x;
          break;
        }
      }
      c ??= await _repo.getClub(d.id);
      if (c != null && mounted) {
        setState(() => _tab = 'clubs');
        _refreshMarkers();
        showClubDetail(
          context,
          c,
          currentUid: _repo.currentUid,
          isAdmin: _isAdmin,
          onChanged: _load,
        );
      }
    } else {
      PickupSpot? s;
      for (final x in _spots) {
        if (x.id == d.id) {
          s = x;
          break;
        }
      }
      s ??= await _repo.getSpot(d.id);
      if (s != null && mounted) {
        setState(() => _tab = 'pickup');
        _refreshMarkers();
        showSpotDetail(
          context,
          s,
          currentUid: _repo.currentUid,
          isAdmin: _isAdmin,
          onChanged: _load,
        );
      }
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.loadClubs(),
        _repo.loadPickups(),
      ]);
      if (!mounted) return;
      setState(() {
        _clubs = results[0] as List<Club>;
        _spots = results[1] as List<PickupSpot>;
        _loading = false;
      });
      _refreshMarkers();
      // 관리자 여부(픽업 모더레이션 삭제 권한) — 비동기, 실패 무시.
      _repo.isAdmin().then((v) {
        if (mounted && v != _isAdmin) setState(() => _isAdmin = v);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  // 웹과 동일한 마커 이미지(assets/markers). 원본 224x294 → 32x42로 표시.
  static final _clubIcon = NOverlayImage.fromAssetImage(
    'assets/markers/marker_yellow.png',
  );
  static final _pickupIcon = NOverlayImage.fromAssetImage(
    'assets/markers/marker_red.png',
  );
  static const _markerSize = Size(38, 48); // 기본 핀(라벨 없음) — 약간 키움
  static const _labelSize = Size(170, 76); // 이름 알약 포함 마커
  // 라벨 on/off 데드밴드(히스테리시스): 경계 근처 미세 줌이 표시를 깜빡이며 토글하지 않도록.
  static const _labelZoomShow = 12.2; // 이 줌 이상 → 이름 알약 켜기
  static const _labelZoomHide = 11.8; // 이 줌 미만 → 끄기 (사이 구간은 현 상태 유지)
  static const _focusZoom = 15.0; // 마커 탭 시 확대 축척
  static const _captureFocusZoom = 12.5; // 저사양 캡처용(타일이 실제로 렌더되는 축척)
  // fitBounds 를 쓸 최소 경계 크기(위경도 도). 이보다 좁으면 최대 축척까지 확대돼
  // 타일 없는 빈 화면이 되므로 고정 축척으로 중심 이동한다. 0.01도 ≈ 1.1km.
  static const _minFitSpanDeg = 0.01;
  // 이전 카메라의 축척을 물려받을 상한. 이게 없으면 한 번 과확대된 상태가
  // 이후 모든 이동에 계속 전파된다(줌아웃 방지 규칙 때문).
  static const _maxInheritZoom = 16.0;
  bool _showLabels = false; // 현재 줌이 임계 이상? (스테이지3=알약 표시)

  // 라벨 토글을 clear+add 없이 in-place(setIcon/setSize)로 적용하기 위한 보관.
  Map<String, NMarker> _markersById = {};
  List<_MarkerSpec> _lastSpecs = const [];
  Timer? _labelFadeTimer;
  int _markerGen = 0; // 마커 새로고침 세대 토큰(동시 호출 재진입 가드)

  // 마커 라벨 아이콘 캐시(이름·상태별 1회 렌더) + 핀 에셋 프리캐시(미로드 시 핀이 빈칸으로 캡처되는 것 방지)
  final Map<String, NOverlayImage> _labelIconCache = {};
  Future<void>? _prewarm;
  Future<void> _ensurePrewarm() {
    return _prewarm ??= () async {
      try {
        await precacheImage(
          const AssetImage('assets/markers/marker_yellow.png'),
          context,
        );
        if (!mounted) return; // await 사이 화면 이탈 시 context 사용 금지
        await precacheImage(
          const AssetImage('assets/markers/marker_red.png'),
          context,
        );
      } catch (_) {}
    }();
  }

  // 핀 위에 이름 알약(흰 배경 + 인증 배지) — 웹 마커 라벨. fromWidget 1회 렌더 후 캐시.
  Future<NOverlayImage?> _labeledIcon(
    String name, {
    required bool red,
    required bool urgent,
    required bool verified,
  }) async {
    final key =
        '${red ? "r" : "y"}|${urgent ? "u" : "n"}|${verified ? "v" : ""}|$name';
    final hit = _labelIconCache[key];
    if (hit != null) return hit;
    await _ensurePrewarm();
    if (!mounted) return null;
    try {
      final img = await NOverlayImage.fromWidget(
        size: _labelSize,
        context: context,
        widget: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: _labelSize.width,
            height: _labelSize.height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: urgent
                          ? const Color(0xFFE53935)
                          : const Color(0x22000000),
                      width: urgent ? 1.5 : 1,
                    ),
                    boxShadow: [
                      const BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                      // 급구: 붉은 글로우로 시선 끌기
                      if (urgent)
                        BoxShadow(
                          color: const Color(
                            0xFFE53935,
                          ).withValues(alpha: 0.55),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          urgent ? '🔥 $name' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: urgent
                                ? const Color(0xFFD32F2F)
                                : NurungjiColors.dark,
                          ),
                        ),
                      ),
                      if (verified)
                        const Padding(
                          padding: EdgeInsets.only(left: 3),
                          child: Icon(
                            Icons.verified,
                            color: Color(0xFF1DA1F2),
                            size: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Image.asset(
                  red
                      ? 'assets/markers/marker_red.png'
                      : 'assets/markers/marker_yellow.png',
                  width: 34,
                  height: 44,
                ),
              ],
            ),
          ),
        ),
      );
      _labelIconCache[key] = img;
      return img;
    } catch (_) {
      return null;
    }
  }

  // 클러스터용 노란 원 아이콘 1회 생성
  Future<void> _ensureClusterIcon() async {
    if (_clusterIcon != null || !mounted) return;
    try {
      _clusterIcon = await NOverlayImage.fromWidget(
        widget: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: NurungjiColors.yellow,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        size: const Size(46, 46),
        context: context,
      );
    } catch (_) {}
  }

  // 위치 권한 + 내 위치 오버레이 (locationButtonEnable 버튼이 동작하도록)
  Future<void> _enableMyLocation() async {
    try {
      final status = await Permission.location.request();
      if (status.isGranted) {
        _controller?.setLocationTrackingMode(NLocationTrackingMode.noFollow);
      }
    } catch (_) {}
  }

  // 핀을 '시트 위 보이는 영역'의 중앙(화면 상단 ~30%)에 오도록 카메라 이동.
  // pivot으로 타깃 latlng를 화면 비율 위치에 배치(시트 peek가 하단 ~42% 가림 보정).
  Future<void> _centerOnPin(double? lat, double? lng) async {
    final c = _controller;
    if (c == null || lat == null || lng == null) return;
    // 상단(검색·티커·탭)과 하단 시트가 가리는 부분을 빼고 '보이는 지도'의 중앙에 핀 배치.
    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    final mapTop = mq.padding.top;
    final mapH = h - mapTop - mq.padding.bottom;
    const topChrome = 172.0; // 검색바+티커+탭(대략, SafeArea 기준 px)
    final sheetTopInMap = h * 0.58 - mapTop; // 시트 peek(42%) 윗변
    final pivotY = (((topChrome + sheetTopInMap) / 2) / mapH)
        .clamp(0.18, 0.5)
        .toDouble();
    // 정해진 축척으로 확대(현재가 더 크면 유지 — 줌아웃 방지)
    // 캡처 빌드는 줌을 낮춘다: GPU 없는 CI 에뮬(SwiftShader)에서 고배율 타일이
    // 20초를 기다려도 안 와 지도가 연녹색 민무늬로 찍혔다(#32 04·05).
    double z = kCaptureLowGpu ? _captureFocusZoom : _focusZoom;
    try {
      final cam = await c.getCameraPosition();
      // 현재가 더 크면 유지하되, 비정상적으로 과확대된(타일 없는) 축척까지
      // 물려받지는 않는다 — 그러면 빈 지도가 다음 화면으로 계속 번진다.
      if (cam.zoom > z && cam.zoom <= _maxInheritZoom) z = cam.zoom;
    } catch (_) {}
    try {
      final update = NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(lat, lng),
        zoom: z,
      )..setPivot(NPoint(0.5, pivotY));
      await c.updateCamera(update);
    } catch (_) {
      try {
        await c.updateCamera(
          NCameraUpdate.scrollAndZoomTo(target: NLatLng(lat, lng), zoom: z),
        );
      } catch (_) {}
    }
  }

  // 마커/티커 탭 → 핀을 보이는 영역 중앙으로 이동 + 상세 시트 오픈.
  Future<void> _focusAndShowClub(Club club) async {
    await _centerOnPin(club.lat, club.lng);
    if (!mounted) return;
    showClubDetail(
      context,
      club,
      currentUid: _repo.currentUid,
      isAdmin: _isAdmin,
      onChanged: _load,
    );
  }

  /// 캡처 디렉터(kCaptureMode 전용). CI가 `?capture=<cmd>&lang=ko` 딥링크로 각 화면을
  /// **결정적으로** 연다 — 좌표/마커 위치에 비의존. 화면당 1회 콜드 실행을 가정.
  Future<void> _runCapture(String cmd, String? lang) async {
    if (lang == 'ko' || lang == 'en') appLang.value = lang!;
    // 데이터 로드 대기(최대 ~21s) + 타일/마커 안정 여유
    for (var i = 0; i < 70 && _clubs.isEmpty && mounted; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // 스틸 캡처(st_*)는 **리셋하지 않고** 델타만 적용한다.
    // 모션그래픽은 '오버레이 없는 배경'과 '오버레이 있는 화면' 두 장의 차이로
    // 시트 레이어와 좌표를 얻는데, 매 스텝 콜드 리셋을 하면 지도 카메라가 달라져
    // 두 장의 배경이 어긋나고 합성이 즉시 티가 난다. 따라서 st_* 는 같은 세션에서
    // 순차 딥링크(-S 없이)로 호출되며 카메라를 건드리지 않는다.
    if (cmd.startsWith('st_')) {
      await _runStill(cmd);
      return;
    }

    // 잔존 시트/다이얼로그(이전 캡처의 상세·공유 등) 정리 → 매 캡처를 깨끗한 지도에서 시작.
    Navigator.of(context).popUntil((r) => r.isFirst);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // 예쁜 상세용 클럽 선택: 급구(빨간 배지) → 검증됨 → 첫 클럽.
    Club? pick() {
      if (_clubs.isEmpty) return null;
      for (final c in _clubs) {
        if (c.isUrgent && (c.urgentMsg?.isNotEmpty ?? false)) return c;
      }
      for (final c in _clubs) {
        if (c.isVerified) return c;
      }
      return _clubs.first;
    }

    switch (cmd) {
      case 'map':
        break; // 지도만(언어만 적용)
      case 'filter':
        await _openFilter();
        break;
      case 'pickup':
        // 목록 뷰로 — 지도만 찍으면 '픽업'인지 스토어에서 알아볼 수 없다.
        setState(() {
          _tab = 'pickup';
          _pickupListView = true;
        });
        _refreshMarkers();
        break;
      case 'login':
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        );
        break;
      case 'detail':
        final c = pick();
        if (c != null) await _focusAndShowClub(c);
        break;
      case 'share':
        final c = pick();
        if (c != null) {
          await _focusAndShowClub(c);
          await Future<void>.delayed(const Duration(milliseconds: 900));
          if (mounted) {
            showShareMenu(
              context,
              url: ShareService.clubUrl(c.id),
              shareTitle: c.name,
              onStory: () => shareStoryCard(context, StoryCardData.fromClub(c)),
            );
          }
        }
        break;
      case 'story':
        // shareStoryCard()는 '링크 스티커' 1회 안내 다이얼로그부터 띄운다 — 스토어용으로는
        // 안내문이 아니라 카드 자체가 보여야 하므로 공유 이미지 미리보기 화면을 연다.
        // 도시락이 비면 카드가 휑하므로 일정 있는 팀 3개까지 시드(캡처 빌드 전용).
        try {
          final uid = await _repo.ensureUid();
          final lb = LunchboxService();
          var seeded = 0;
          for (final c in _clubs) {
            if (seeded >= 3) break;
            final hasSched =
                (c.schedule ?? '').isNotEmpty ||
                (c.scheduleRaw?.isNotEmpty ?? false);
            if (!hasSched) continue;
            await lb.addBookmark(uid, c.id);
            seeded++;
          }
        } catch (_) {}
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const ShareImageScreen()),
        );
        break;
      case 'lunchbox':
        // 로그인 게이트 우회(익명) + 데모 찜 1건 시드 → 빈 화면 방지.
        try {
          final uid = await _repo.ensureUid();
          final c = pick();
          if (c != null) await LunchboxService().addBookmark(uid, c.id);
        } catch (_) {}
        if (mounted) showLunchboxSheet(context);
        break;
      case 'profile':
        try {
          await _repo.ensureUid();
        } catch (_) {}
        if (mounted) showProfileSheet(context);
        break;

      // ── 흐름(flow): 여러 기능을 한 테이크로 이어서 시연 ──────────────
      // 낱개 화면 캡처와 달리 앱 안에서 연속 전환하므로(콜드 재시작 없음)
      // 전환이 Flutter 내비게이션 속도(~0.3s)로 끝난다. 홍보 영상용.
      // 체류시간은 편집에서 자막·TTS를 얹을 여유를 두고 넉넉히 잡았다.
      case 'flow_discover':
        await _flowDiscover();
        break;
      case 'flow_save':
        await _flowSave(pick());
        break;
      case 'flow_share':
        await _flowShare();
        break;
    }
  }

  // ── 스틸 캡처 상태 머신(모션그래픽용) ────────────────────────────
  // 에뮬레이터 실시간 녹화는 GPU 없는 CI(SwiftShader)에서 렉·타일 로딩 때문에
  // 마케팅 품질이 안 나온다. 대신 **정확한 UI 상태 스틸**을 찍고, 그 사이를
  // 앱의 실제 전환(바텀시트 슬라이드 등)으로 이어 붙여 영상을 만든다.
  // 여기서는 그 스틸 상태들을 결정적으로 만들어 준다.

  /// 스틸 세트에서 쓰는 고정 필터(찾기 스토리: 서울·성인).
  // 요일까지 걸면 결과가 1팀으로 줄어 지도에 핀 하나만 남는다 — 시연 영상에서
  // "필터로 좁혔더니 지도가 비었다"로 보인다. 지역·대상만 걸어 여러 팀이 남게 한다.
  static const _stillPreset = ClubFilter(regions: {'서울'}, targets: {'성인'});

  /// 스틸 전용 대상 클럽 — 프리셋에 걸리는 팀 우선, 없으면 급구→검증→첫 팀.
  Club? _stillClub() {
    if (_clubs.isEmpty) return null;
    for (final c in _clubs) {
      if (_stillPreset.matches(c)) return c;
    }
    for (final c in _clubs) {
      if (c.isUrgent && (c.urgentMsg?.isNotEmpty ?? false)) return c;
    }
    return _clubs.first;
  }

  /// 캡처용: 현재 화면에 떠 있는 바텀시트/상세패널의 **정확한 상단 y(디바이스 px)**.
  ///
  /// 스크린샷만으로 시트 상단을 추정하려 했으나 신뢰할 수 없었다(검증됨):
  ///  · 스크림이 화면 전체를 덮어 '차이가 생기는 첫 행'은 항상 0 이 된다.
  ///  · 밝기 프로파일도 시트 내부의 어두운 행(라벨·구분선) 때문에 튄다.
  ///  · 상세 패널은 아예 비모달이라 스크림이 없어 규칙이 또 다르다.
  /// 앱은 정확한 값을 알고 있으므로 그대로 내준다. 시트 파일은 건드리지 않고
  /// 렌더 트리에서 BottomSheet(머티리얼 공개 위젯)/MapDetailPanel 을 찾는다.
  int? _overlayTopPx() {
    // 모달 바텀시트(필터·공유)는 렌더박스가 곧 시트다.
    double? sheet;
    void visit(Element el) {
      if (el.widget is BottomSheet) {
        final ro = el.renderObject;
        if (ro is RenderBox && ro.attached && ro.hasSize) {
          final dy = ro.localToGlobal(Offset.zero).dy;
          if (sheet == null || dy < sheet!) sheet = dy;
        }
      }
      el.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);

    // 상세 패널은 화면을 채우는 Align 안에 있어 렌더박스 상단이 항상 0 이다
    // (#32에서 128 로 잡혀 detail·share 좌표가 뭉개진 원인) → 패널이 직접
    // 알려주는 detailPanelTop 을 쓴다. 모달이 위에 있으면 모달이 우선.
    final panel = detailPanelTop.value;
    final top = sheet ?? (panel >= 0 ? panel : null);
    if (top == null) return null;
    final dpr = View.of(context).devicePixelRatio;
    return (top * dpr).round();
  }

  /// 스틸 상태가 안정된 뒤 좌표를 로그로 남긴다(run_capture.sh 가 logcat 에서 수거).
  void _dumpRect(String cmd) {
    final top = _overlayTopPx();
    debugPrint('CAPTURE_RECT cmd=$cmd sheetTopPx=${top ?? -1}');
  }

  Future<void> _closeOverlays() async {
    if (!mounted) return;
    // 상세 패널은 Navigator 라우트가 아니라 detailPanel notifier 로 MapScreen Stack
    // 에서 렌더된다(상세 위에 공유·삭제확인 모달이 뜨도록 한 설계) → popUntil 로는
    // 닫히지 않는다. 캡처 #28에서 '배경만' 스틸에 상세 시트가 남아 배경 쌍이
    // 오염된 원인이 이것. notifier 를 먼저 비우고 라우트를 정리한다.
    detailPanel.value = null;
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  /// st_* 상태 적용. 지도 카메라는 st_club_bg 에서 한 번만 움직이고,
  /// 이후 오버레이 상태들은 카메라를 건드리지 않아 배경이 픽셀 단위로 같다.
  Future<void> _runStill(String cmd) async {
    await _applyStill(cmd);
    // 레이아웃이 안정된 뒤 오버레이 좌표를 남긴다.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    _dumpRect(cmd);
  }

  Future<void> _applyStill(String cmd) async {
    switch (cmd) {
      // ── 찾기 ──────────────────────────────────────────────
      case 'st_map': // 지도 기본(필터 없음)
        await _closeOverlays();
        if (!mounted) return;
        setState(() {
          _filter = const ClubFilter();
          _search.text = '';
        });
        await _refreshMarkers();
        break;

      case 'st_filter_open': // 필터 시트(미선택)
        unawaited(showFilterSheet(context, const ClubFilter()));
        break;

      case 'st_filter_set': // 같은 시트, 칩 3개 선택된 상태
        await _closeOverlays();
        if (!mounted) return;
        unawaited(showFilterSheet(context, _stillPreset));
        break;

      case 'st_map_filtered': // 필터 적용된 지도
        await _closeOverlays();
        if (!mounted) return;
        setState(() {
          _filter = _stillPreset;
          _search.text = '';
        });
        await _refreshMarkers();
        _fitToFilter();
        break;

      case 'st_club_bg': // 대상 클럽으로 카메라 이동 — 시트 없음(배경 쌍)
        await _closeOverlays();
        final c = _stillClub();
        if (c != null) await _centerOnPin(c.lat, c.lng);
        break;

      case 'st_club_sheet': // 같은 카메라에 상세 시트만 얹기
        final c2 = _stillClub();
        if (c2 != null && mounted) {
          showClubDetail(
            context,
            c2,
            currentUid: _repo.currentUid,
            isAdmin: _isAdmin,
            onChanged: _load,
          );
        }
        break;

      // ── 담고 관리 ─────────────────────────────────────────
      case 'st_lunchbox_bg': // 오버레이만 걷어냄(카메라 유지)
        await _closeOverlays();
        // 도시락이 비면 화면이 휑하므로 일정 있는 팀을 시드(캡처 빌드 전용).
        try {
          final uid = await _repo.ensureUid();
          final lb = LunchboxService();
          var n = 0;
          final target = _stillClub();
          if (target != null) {
            await lb.addBookmark(uid, target.id);
            n++;
          }
          for (final x in _clubs) {
            if (n >= 4) break;
            if (target != null && x.id == target.id) continue;
            final hasSched =
                (x.schedule ?? '').isNotEmpty ||
                (x.scheduleRaw?.isNotEmpty ?? false);
            if (!hasSched) continue;
            await lb.addBookmark(uid, x.id);
            n++;
          }
        } catch (_) {}
        break;

      case 'st_lunchbox': // 도시락 모달
        if (mounted) showLunchboxSheet(context);
        break;

      case 'st_lunchbox_diet': // 도시락 모달 + 식단표 펼침
        await _closeOverlays();
        if (mounted) showLunchboxSheet(context, openDiet: true);
        break;

      // ── 자랑하기 ──────────────────────────────────────────
      case 'st_profile_bg':
        await _closeOverlays();
        try {
          await _repo.ensureUid();
        } catch (_) {}
        break;

      case 'st_profile': // 밥이름 카드
        if (mounted) showProfileSheet(context);
        break;

      case 'st_namecard': // 네임카드(도시락+시간표+QR)
        await _closeOverlays();
        if (!mounted) return;
        unawaited(
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const ShareImageScreen()),
          ),
        );
        break;

      case 'st_share_bg': // 상세 시트만(공유 메뉴 없음) — 배경 쌍
        await _closeOverlays();
        final c3 = _stillClub();
        if (c3 != null && mounted) {
          showClubDetail(
            context,
            c3,
            currentUid: _repo.currentUid,
            isAdmin: _isAdmin,
            onChanged: _load,
          );
        }
        break;

      case 'st_share': // 상세 + 공유 메뉴
        final c4 = _stillClub();
        if (c4 != null && mounted) {
          showShareMenu(
            context,
            url: ShareService.clubUrl(c4.id),
            shareTitle: c4.name,
            onStory: () => shareStoryCard(context, StoryCardData.fromClub(c4)),
          );
        }
        break;
    }
  }

  /// 캡처 흐름 공용: n초 대기(위젯이 사라졌으면 중단).
  Future<bool> _hold(double sec) async {
    await Future<void>.delayed(Duration(milliseconds: (sec * 1000).round()));
    return mounted;
  }

  /// 열려 있는 시트/화면을 닫아 지도로 복귀.
  Future<void> _backToMap() async {
    if (!mounted) return;
    // 상세 패널은 라우트가 아니라 notifier 렌더 → popUntil 로 안 닫힌다(_closeOverlays 주석).
    detailPanel.value = null;
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    await _hold(0.6);
  }

  /// ① 찾기: 지도 → 필터(서울·화·성인) → 결과 → 클럽 상세 → 연락
  Future<void> _flowDiscover() async {
    await _hold(2.5); // 지도 전경(전국 마커·클러스터)
    if (!mounted) return;

    // 필터 시트를 '이미 선택된' 상태로 띄운다 — 좌표 탭 없이 칩 선택이 보인다.
    // 스틸 세트와 같은 프리셋을 쓴다: 여기만 요일까지 걸려 있어 결과가 1팀으로
    // 줄었고, 스틸 영상과 녹화 영상의 내용이 서로 달라 비교가 안 됐다.
    const preset = _stillPreset;
    final sheet = showFilterSheet(context, preset);
    await _hold(4); // 지역·대상 칩을 읽을 시간
    if (!mounted) return;
    Navigator.of(context).pop(preset); // '적용하기' 상당
    final applied = await sheet;
    if (!mounted) return;
    if (applied != null) {
      setState(() {
        _filter = applied;
        _search.text = applied.keyword;
      });
      await _refreshMarkers();
      _fitToFilter();
    }
    if (!await _hold(3)) return; // 좁혀진 결과 지도

    // 결과 중 한 팀을 열어 일정·회비·위치를 보여준다.
    final c = _clubs.where(_filter.matches).isNotEmpty
        ? _clubs.firstWhere(_filter.matches)
        : (_clubs.isNotEmpty ? _clubs.first : null);
    if (c == null) return;
    await _focusAndShowClub(c);
    if (!await _hold(4)) return; // 상세: 일정·회비·주소·버튼

    // 필터 원복(다음 캡처 오염 방지)
    await _backToMap();
    if (!mounted) return;
    setState(() {
      _filter = const ClubFilter();
      _search.text = '';
    });
    await _refreshMarkers();
  }

  /// ② 담고 관리: 클럽 상세 → 도시락 찜 → 도시락(반찬칸) → 식단표
  Future<void> _flowSave(Club? c) async {
    if (c == null) return;
    await _focusAndShowClub(c);
    if (!await _hold(3)) return; // 상세에서 시작

    // 찜(도시락 담기) — 실제 저장까지 수행해 도시락이 비지 않게.
    try {
      final uid = await _repo.ensureUid();
      final lb = LunchboxService();
      await lb.addBookmark(uid, c.id);
      var seeded = 1;
      for (final x in _clubs) {
        if (seeded >= 4) break;
        if (x.id == c.id) continue;
        final hasSched =
            (x.schedule ?? '').isNotEmpty ||
            (x.scheduleRaw?.isNotEmpty ?? false);
        if (!hasSched) continue;
        await lb.addBookmark(uid, x.id);
        seeded++;
      }
    } catch (_) {}
    if (!await _hold(1.5)) return;

    await _backToMap();
    if (!mounted) return;
    showLunchboxSheet(context);
    if (!await _hold(6)) return; // 반찬칸 그리드 + 식단표 버튼까지 읽을 시간
    await _backToMap();
  }

  /// ③ 자랑하기: 밥이름 프로필 → 네임카드(도시락+시간표+QR) → 공유
  Future<void> _flowShare() async {
    try {
      await _repo.ensureUid();
    } catch (_) {}
    if (!mounted) return;
    showProfileSheet(context);
    if (!await _hold(3.5)) return; // 밥이름 카드·스탬프

    await _backToMap();
    if (!mounted) return;
    // 네임카드(피드형/스토리형 전환 + 이미지로 공유·저장)
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const ShareImageScreen()),
      ),
    );
    if (!await _hold(6)) return;

    await _backToMap();
    if (!mounted) return;
    // 클럽 공유 메뉴(인스타 스토리·카톡·링크)
    final c = _clubs.isNotEmpty ? _clubs.first : null;
    if (c == null) return;
    await _focusAndShowClub(c);
    await _hold(2);
    if (!mounted) return;
    showShareMenu(
      context,
      url: ShareService.clubUrl(c.id),
      shareTitle: c.name,
      onStory: () => shareStoryCard(context, StoryCardData.fromClub(c)),
    );
    await _hold(4);
  }

  Future<void> _focusAndShowSpot(PickupSpot spot) async {
    await _centerOnPin(spot.lat, spot.lng);
    if (!mounted) return;
    showSpotDetail(
      context,
      spot,
      currentUid: _repo.currentUid,
      isAdmin: _isAdmin,
      onChanged: _load,
    );
  }

  // 줌 변경 후: 데드밴드(히스테리시스)로 라벨 on/off 결정 → 넘나들면 in-place로 아이콘만 교체.
  void _onCameraIdle() async {
    final cam = await _controller?.getCameraPosition();
    if (cam == null || !mounted) return;
    final z = cam.zoom;
    final bool show;
    if (z >= _labelZoomShow) {
      show = true;
    } else if (z < _labelZoomHide) {
      show = false;
    } else {
      show = _showLabels; // 경계 사이 → 현 상태 유지(미세 줌 thrash 방지)
    }
    if (show != _showLabels) {
      _showLabels = show;
      _applyLabelState(); // clear+add 없이 setIcon/setSize로 교체 + 페이드
    }
  }

  // 두 좌표 간 근사 거리(m) — 작은 범위라 equirectangular 근사로 충분(haversine 불필요).
  static double _approxMeters(NLatLng a, NLatLng b) {
    const r = 6378137.0; // 지구 반경
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final mLat = (a.latitude + b.latitude) / 2 * math.pi / 180;
    final x = dLng * math.cos(mLat);
    return math.sqrt(dLat * dLat + x * x) * r;
  }

  // 마커 롱프레스(인스타 피드 '꾹 누르기'): 누른 지점 근처 가장 가까운 마커를 찾아
  // 릴스가 있으면 배경 블러 + 릴스 크게 미리보기. flutter_naver_map은 마커별 롱프레스
  // 콜백이 없어 지도 onMapLongTapped + 최근접 마커로 우회(핀을 정확히 누를 필요 없음).
  Future<void> _onMapLongTapped(NPoint point, NLatLng latLng) async {
    final c = _controller;
    if (c == null) return;
    double zoom = 14;
    try {
      final cam = await c.getCameraPosition();
      zoom = cam.zoom;
    } catch (_) {}
    if (!mounted) return;
    // 화면상 ~52px 반경 안에서만 인식 → 줌 기준 m/px로 환산해 거리 임계로 사용(줌 무관).
    final mpp =
        156543.03392 *
        math.cos(latLng.latitude * math.pi / 180) /
        math.pow(2, zoom);
    final thresholdM = 52 * mpp;

    String? title;
    String? reel;
    bool urgent = false;
    double best = double.infinity;
    if (_tab == 'clubs') {
      for (final club in _clubs.where(_filter.matches)) {
        if (club.lat == null || club.lng == null) continue;
        final d = _approxMeters(latLng, NLatLng(club.lat!, club.lng!));
        if (d < best) {
          best = d;
          title = club.name;
          reel = club.instaReels.isNotEmpty ? club.instaReels.first : null;
          urgent = club.isUrgent && (club.urgentMsg?.isNotEmpty ?? false);
        }
      }
    } else {
      for (final spot in _visibleSpots()) {
        if (spot.lat == null || spot.lng == null) continue;
        final d = _approxMeters(latLng, NLatLng(spot.lat!, spot.lng!));
        if (d < best) {
          best = d;
          title = spot.title;
          reel = spot.instaReels.isNotEmpty ? spot.instaReels.first : null;
          urgent = false;
        }
      }
    }
    if (title == null || best > thresholdM) return; // 근처에 마커 없음
    if (reel == null) {
      _snack(t('reel_peek_none'));
      return;
    }
    Track.event('reel_peek', {'tab': _tab});
    setState(
      () => _reelPeek = _ReelPeek(title: title!, reel: reel!, urgent: urgent),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _refreshMarkers({bool fade = false}) async {
    final c = _controller;
    if (c == null) return;
    final gen = ++_markerGen; // 동시 새로고침 시 최신만 반영(재진입 가드)
    // 1) 표시할 항목 수집(클럽/스팟 공통 스펙)
    final items = <_MarkerSpec>[];
    if (_tab == 'clubs') {
      for (final club in _clubs.where(_filter.matches)) {
        if (club.lat == null || club.lng == null) continue;
        final urgent = club.isUrgent && (club.urgentMsg?.isNotEmpty ?? false);
        items.add(
          _MarkerSpec(
            id: 'c_${club.id}',
            pos: NLatLng(club.lat!, club.lng!),
            name: club.name,
            red: urgent,
            urgent: urgent,
            verified: club.isVerified,
            clusterable: !urgent, // 급구: 클러스터 제외(항상 표시)
            onTap: () => _focusAndShowClub(club),
          ),
        );
      }
    } else {
      for (final spot in _visibleSpots()) {
        if (spot.lat == null || spot.lng == null) continue;
        items.add(
          _MarkerSpec(
            id: 's_${spot.id}',
            pos: NLatLng(spot.lat!, spot.lng!),
            name: spot.title,
            red: true,
            urgent: false,
            verified: false,
            clusterable: true,
            onTap: () => _focusAndShowSpot(spot),
          ),
        );
      }
    }

    // 2) 이름 알약 아이콘을 병렬로 빌드(순차 await 제거 → 줌 인 시 끊김 완화). 캐시 히트는 즉시.
    final icons = _showLabels
        ? await Future.wait(
            items.map(
              (s) => _labeledIcon(
                s.name,
                red: s.red,
                urgent: s.urgent,
                verified: s.verified,
              ),
            ),
          )
        : const <NOverlayImage?>[];
    if (gen != _markerGen || !mounted || _controller == null) return;

    // 3) 마커 생성(급구 클럽=비클러스터, 그 외=클러스터러블)
    final markers = <NMarker>[];
    final overlays = <NAddableOverlay>{};
    for (var i = 0; i < items.length; i++) {
      final s = items[i];
      final icon = _showLabels ? icons[i] : null;
      final size = icon != null ? _labelSize : _markerSize;
      final fallback = s.red ? _pickupIcon : _clubIcon;
      final NMarker m;
      if (s.clusterable) {
        final cm = NClusterableMarker(
          id: s.id,
          position: s.pos,
          icon: icon ?? fallback,
          size: size,
        );
        cm.setOnTapListener((NClusterableMarker o) => s.onTap());
        m = cm;
      } else {
        final nm = NMarker(
          id: s.id,
          position: s.pos,
          icon: icon ?? fallback,
          size: size,
        );
        nm.setOnTapListener((NMarker o) => s.onTap());
        m = nm;
      }
      markers.add(m);
      overlays.add(m);
    }

    // 4) 아이콘 빌드를 끝낸 뒤에 clear+add → 사라졌다 뜨는 끊김 최소화
    await c.clearOverlays();
    if (overlays.isNotEmpty) await c.addOverlayAll(overlays);
    if (gen != _markerGen) return; // 더 새 새로고침 진행 중 → 보관/페이드 생략(그쪽이 덮어씀)

    // 라벨 in-place 토글용으로 현재 마커/스펙 보관(인덱스 정렬됨).
    _lastSpecs = items;
    _markersById = {
      for (var i = 0; i < items.length; i++) items[i].id: markers[i],
    };

    // 5) 라벨 전환(줌) 시: 네이티브 마커 alpha 0→1 페이드 인(팝업 대신 부드러운 등장)
    if (fade && markers.isNotEmpty) _fadeInMarkers(markers);
  }

  // 라벨 on/off를 clear+add 없이 적용: 보관된 기존 마커의 아이콘·크기만 교체 후 페이드.
  // (보관된 마커가 없으면 풀 리프레시로 폴백)
  Future<void> _applyLabelState() async {
    final specs = _lastSpecs;
    if (specs.isEmpty || _markersById.isEmpty) {
      return _refreshMarkers(fade: true);
    }
    final gen = _markerGen; // 적용 도중 풀 리프레시가 끼어들면 양보(재진입 가드)
    final icons = _showLabels
        ? await Future.wait(
            specs.map(
              (s) => _labeledIcon(
                s.name,
                red: s.red,
                urgent: s.urgent,
                verified: s.verified,
              ),
            ),
          )
        : const <NOverlayImage?>[];
    if (gen != _markerGen || !mounted) return;
    final updated = <NMarker>[];
    for (var i = 0; i < specs.length; i++) {
      final m = _markersById[specs[i].id];
      if (m == null) continue;
      final icon = _showLabels ? icons[i] : null;
      final fallback = specs[i].red ? _pickupIcon : _clubIcon;
      try {
        m.setIcon(icon ?? fallback);
        m.setSize(icon != null ? _labelSize : _markerSize);
      } catch (_) {}
      updated.add(m);
    }
    if (updated.isNotEmpty) _fadeInMarkers(updated);
  }

  // 마커 등장 페이드: alpha 0→1 짧은 트윈. 채널콜 폭주 방지를 위해 스텝 제한 + 가드.
  void _fadeInMarkers(List<NMarker> markers) {
    _labelFadeTimer?.cancel(); // 이전 페이드 진행 중이면 취소(겹침 방지)
    for (final m in markers) {
      try {
        m.setAlpha(0.0);
      } catch (_) {}
    }
    const steps = 6;
    var i = 0;
    _labelFadeTimer = Timer.periodic(const Duration(milliseconds: 36), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      i++;
      final v = (i / steps).clamp(0.0, 1.0);
      for (final m in markers) {
        try {
          m.setAlpha(v);
        } catch (_) {}
      }
      if (i >= steps) timer.cancel();
    });
  }

  void _onTab(String t) {
    if (_tab == t) return;
    setState(() {
      _tab = t;
      _reelPeek = null; // 탭 전환: 이전 탭의 오버레이 정리
    });
    detailPanel.value = null; // 이전 탭 항목의 상세 패널 닫기
    Track.event('switch_tab', {'tab': t});
    _refreshMarkers();
  }

  // ＋등록: 활성 탭에 따라 픽업/동호회 폼. 등록 성공 시 데이터 재로딩→마커 갱신.
  Future<void> _openRegister() async {
    // 클럽 등록은 로그인 필수(웹과 동일). 픽업은 무로그인(익명) 허용.
    // 측정 파리티(웹 registration_login_gate): 미로그인 상태로 등록 시도한 신호
    if (_tab != 'pickup' && _repo.currentUid == null) {
      Track.event('registration_login_gate');
    }
    if (_tab != 'pickup' && (!await _ensureLogin() || !mounted)) return;
    // 현재 지도 중심을 피커 초기 위치로 (없으면 폼 기본값 사용)
    final cam = await _controller?.getCameraPosition();
    if (!mounted) return;
    final center = cam?.target ?? const NLatLng(37.5559, 127.0838);
    // 풀스크린 라우트 대신 지도 위 모달 시트(웹 등록 팝업 동작 대응).
    final created = await (_tab == 'pickup'
        ? showPickupFormSheet(context, initialCenter: center)
        : showClubFormSheet(context, initialCenter: center));
    if (created == true) await _load();
  }

  // 동호회 필터 시트 열기 → 적용 시 마커 갱신 + 화면 맞춤
  Future<void> _openFilter() async {
    final result = await showFilterSheet(context, _filter);
    if (result != null) {
      setState(() {
        _filter = result;
        _search.text = result.keyword; // 시트의 키워드 ↔ 상단 검색바 동기화
      });
      await _refreshMarkers();
      _fitToFilter();
    }
  }

  // 필터/검색 활성 시 결과가 다 보이게 카메라 맞춤 (웹 map.setBounds 대응)
  void _fitToFilter() {
    // 캡처: 카메라를 옮기면 (a) 고배율 타일이 안 오고 (b) '필터 적용' 스틸의 배경이
    // 지도 스틸과 달라져 디졸브가 어색해진다. 같은 화면에서 마커만 줄어드는 게 낫다.
    if (kCaptureLowGpu) return;
    if (_tab != 'clubs' || _filter.isEmpty) return;
    final pts = <NLatLng>[];
    for (final club in _clubs.where(_filter.matches)) {
      if (club.lat != null && club.lng != null) {
        pts.add(NLatLng(club.lat!, club.lng!));
      }
    }
    if (pts.isEmpty) return;
    try {
      // 결과가 1곳이거나 아주 좁게 모여 있으면 fitBounds 가 최대 축척까지 확대한다.
      // 그 배율에는 타일이 없어 지도가 통째로 빈 연녹색이 된다(축척 2m). 필터를
      // 좁힐수록 지도가 사라지는 셈이라 실사용에서도 버그다 → 고정 축척으로 대체.
      double minLat = pts.first.latitude, maxLat = minLat;
      double minLng = pts.first.longitude, maxLng = minLng;
      for (final p in pts) {
        minLat = math.min(minLat, p.latitude);
        maxLat = math.max(maxLat, p.latitude);
        minLng = math.min(minLng, p.longitude);
        maxLng = math.max(maxLng, p.longitude);
      }
      final span = math.max(maxLat - minLat, maxLng - minLng);
      if (span < _minFitSpanDeg) {
        _controller?.updateCamera(
          NCameraUpdate.scrollAndZoomTo(
            target: NLatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
            zoom: _focusZoom,
          ),
        );
        return;
      }
      final bounds = NLatLngBounds.from(pts);
      _controller?.updateCamera(
        NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(64)),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // 시스템 뒤로가기: 인앱 오버레이(릴스 피크 → 상세 패널)를 먼저 닫고, 없을 때만 앱 종료.
    // (상세 패널·피크는 route가 아닌 Stack 오버레이라 처리 없인 back이 곧장 앱을 종료함)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_reelPeek != null) {
          setState(() => _reelPeek = null);
        } else if (detailPanel.value != null) {
          detailPanel.value = null;
        } else {
          // 실수 종료 방지: 2초 안에 한 번 더 눌러야 종료
          final now = DateTime.now();
          if (_lastBackPress != null &&
              now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
            SystemNavigator.pop();
          } else {
            _lastBackPress = now;
            _snack(t('back_exit_hint'));
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // 키보드에 지도(플랫폼뷰) 리사이즈 방지
        body: SafeArea(
          child: Stack(
            children: [
              NaverMap(
                options: const NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: NLatLng(37.5559, 127.0838),
                    zoom: 10.5,
                  ),
                  locationButtonEnable: false, // 커스텀 📍 FAB 사용
                ),
                clusterOptions: NaverMapClusteringOptions(
                  clusterMarkerBuilder: (info, clusterMarker) {
                    if (_clusterIcon != null) {
                      clusterMarker.setIcon(_clusterIcon);
                    }
                    clusterMarker.setIsFlat(true);
                    clusterMarker.setCaption(
                      NOverlayCaption(
                        text: info.size.toString(),
                        textSize: 15,
                        color: NurungjiColors.dark,
                        haloColor: NurungjiColors.yellow,
                      ),
                    );
                  },
                ),
                onMapReady: (controller) async {
                  _controller = controller;
                  await _ensureClusterIcon();
                  await _enableMyLocation();
                  _refreshMarkers();
                },
                // 줌이 임계를 넘나들면 이름 알약 표시/숨김 전환(스테이지 2↔3)
                onCameraIdle: _onCameraIdle,
                // 마커 꾹 누르기 → 배경 블러 + 릴스 미리보기(인스타 피드 느낌)
                onMapLongTapped: _onMapLongTapped,
              ),
              // 검색바 (design §2.1)
              Positioned(top: 12, left: 15, right: 15, child: _searchBar()),
              // 급구 티커(동호회) / 지도·목록 토글(픽업) — 검색바 바로 아래(우선 노출)
              if (_tab == 'clubs' && _hasUrgent)
                Positioned(
                  top: 70,
                  left: 15,
                  right: 15,
                  child: _urgentTicker(),
                ),
              if (_tab == 'pickup')
                Positioned(
                  top: 70,
                  left: 0,
                  right: 0,
                  child: Center(child: _pickupToggle()),
                ),
              // 지도 뷰에서 좌표 없는 크루는 마커가 없다 → 목록으로 유도(없으면 존재를 모른다).
              if (_tab == 'pickup' && !_pickupListView && _spotsOffMap > 0)
                Positioned(
                  top: 210,
                  left: 24,
                  right: 24,
                  child: Center(child: _offMapHint(_spotsOffMap)),
                ),
              // 동호회/픽업 탭 — 위 컨텍스트바가 있으면 122, 없으면 70.
              Positioned(
                top: (_tab == 'pickup' || (_tab == 'clubs' && _hasUrgent))
                    ? 122
                    : 70,
                left: 0,
                right: 0,
                child: Center(child: _tabPill()),
              ),
              if (_tab == 'pickup' && _pickupListView)
                Positioned(
                  top: 166,
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: GlassSurface(
                    color: const Color(0xF5FFFFFF), // 흰 0.96
                    blur: 10,
                    child: PickupListPanel(
                      spots: _visibleSpots(),
                      onTap: (s) => showSpotDetail(
                        context,
                        s,
                        currentUid: _repo.currentUid,
                        isAdmin: _isAdmin,
                        onChanged: _load,
                      ),
                      onInstaTap: _openSpotInsta,
                    ),
                  ),
                ),
              // 플로팅 FAB (design §2.4): 좌(도시락/프로필) · 우(등록/내위치)
              // 픽업 목록뷰에선 패널과 겹치므로 숨김.
              if (!(_tab == 'pickup' && _pickupListView)) ...[
                Positioned(
                  left: 15,
                  bottom: 95,
                  child: _fab('🍱', t('fab_lunchbox'), _openLunchbox),
                ),
                Positioned(
                  left: 15,
                  bottom: 30,
                  child: _fab('🍚', t('fab_profile'), _openProfile),
                ),
                Positioned(
                  right: 15,
                  bottom: 95,
                  child: _fab(
                    '📝',
                    t('fab_register'),
                    _openRegister,
                    bg: const Color(0xF2FAC710),
                  ),
                ), // 등록 = 브랜드 옐로
                Positioned(
                  right: 15,
                  bottom: 30,
                  child: _fab('📍', t('fab_my_location'), _moveToMe),
                ),
              ],
              if (_error != null)
                Positioned(bottom: 20, left: 90, right: 90, child: _errorBox()),
              // 상세 패널(비모달) — Stack의 일부라 상세에서 띄우는 모달(공유 등)이 그 위에 뜸.
              ValueListenableBuilder<Widget?>(
                valueListenable: detailPanel,
                builder: (_, panel, _) => panel ?? const SizedBox.shrink(),
              ),
              // 마커 롱프레스 릴스 미리보기(최상단) — 배경 블러 + 릴스 크게.
              if (_reelPeek != null)
                Positioned.fill(
                  child: _ReelPeekOverlay(
                    data: _reelPeek!,
                    onClose: () => setState(() => _reelPeek = null),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 플로팅 글래스 FAB (이모지) — 누르면 spring 축소.
  Widget _fab(
    String emoji,
    String label,
    VoidCallback onTap, {
    Color? bg,
    double size = 52,
  }) {
    return Semantics(
      button: true,
      label: label, // 이모지 전용 FAB → 스크린리더용 라벨
      child: BounceTap(
        onTap: onTap,
        child: GlassSurface(
          radius: BorderRadius.circular(size / 2),
          color: bg ?? const Color(0xD9FFFFFF),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Text(emoji, style: TextStyle(fontSize: size * 0.46)),
            ),
          ),
        ),
      ),
    );
  }

  // 상단 검색바: 🔎 + 입력 + EN토글 + (동호회)필터 / (픽업)English-OK.
  Widget _searchBar() {
    final isClubs = _tab == 'clubs';
    return GlassSurface(
      radius: BorderRadius.circular(20),
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: NurungjiColors.brown),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              // 바깥(지도·마커·버튼) 탭 시 포커스 해제 → 키보드 내려가고,
              // 다른 기능 다녀와도 키보드가 다시 올라오지 않음.
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              // 키보드 검색(돋보기) 버튼 → 키보드 닫기(검색은 입력 즉시 반영됨)
              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                isDense: true,
                filled: false, // 전역 테마의 흰색 fill 제거 — 글래스 톤과 색 얼룩 방지
                border: InputBorder.none,
                hintText: t(_tab == 'pickup' ? 'pk_search_ph' : 'search_ph'),
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: NurungjiColors.dark,
              ),
            ),
          ),
          TextButton(
            onPressed: toggleLang,
            style: TextButton.styleFrom(
              minimumSize: const Size(34, 40),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: Text(
              isKo ? 'EN' : '한',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: NurungjiColors.brown,
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (isClubs)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  onPressed: _openFilter,
                  icon: Icon(
                    Icons.tune,
                    color: _filter.isEmpty
                        ? NurungjiColors.brown
                        : NurungjiColors.urgent,
                  ),
                  tooltip: t('search_filter'),
                ),
                if (!_filter.isEmpty)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      radius: 4,
                      backgroundColor: NurungjiColors.urgent,
                    ),
                  ),
              ],
            )
          else
            IconButton(
              onPressed: () {
                setState(() => _pkEnglishOnly = !_pkEnglishOnly);
                _refreshMarkers();
              },
              icon: Icon(
                Icons.language,
                color: _pkEnglishOnly
                    ? NurungjiColors.teal
                    : NurungjiColors.brown,
              ),
              tooltip: t('english_only'),
            ),
        ],
      ),
    );
  }

  // 탭 pill (동호회 | 픽업) — 글래스.
  // 급구(메시지 있는) 동호회가 하나라도 있는지 — 상단 티커/탭 배치에 사용.
  bool get _hasUrgent =>
      _clubs.any((c) => c.isUrgent && (c.urgentMsg?.isNotEmpty ?? false));

  // 동호회/픽업 — 큰 알약 안에 작은 알약 둘(숫자 없음).
  Widget _tabPill() {
    return GlassSurface(
      radius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tabBtn('🏐 ${t('clubs')}', 'clubs'),
          const SizedBox(width: 4),
          _tabBtn('📍 ${t('pickup')}', 'pickup'),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, String key) {
    final on = _tab == key;
    return BounceTap(
      onTap: () => _onTab(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: on ? NurungjiColors.yellow : NurungjiColors.chipBg,
          borderRadius: BorderRadius.circular(18), // 작은 알약
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: on ? FontWeight.w800 : FontWeight.w600,
            color: NurungjiColors.dark,
          ),
        ),
      ),
    );
  }

  // 급구 티커 (verified 무관, is_urgent+메시지 있는 클럽). 탭 → 상세.
  Widget _urgentTicker() {
    final urgent = _clubs
        .where((c) => c.isUrgent && (c.urgentMsg?.isNotEmpty ?? false))
        .toList();
    if (urgent.isEmpty) return const SizedBox.shrink();
    // 롤링 티커: 여러 급구 팀을 일정 간격으로 위로 굴려 보여줌. 탭 → 핀 이동 + 상세.
    return _UrgentTicker(clubs: urgent, onTap: _focusAndShowClub);
  }

  // 픽업 탭: 지도/목록 토글 알약
  Widget _pickupToggle() {
    return GlassSurface(
      radius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(
            '🗺 ${t('map_view')}',
            !_pickupListView,
            () => setState(() => _pickupListView = false),
          ),
          _seg(
            '☰ ${t('list_view')}',
            _pickupListView,
            () => setState(() => _pickupListView = true),
          ),
          _regionMenu(),
          _levelMenu(),
          // 현재 필터 목록을 링크 하나로 — 외국인 DM 대응의 핵심 동선.
          BounceTap(
            onTap: _sharePickupList,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Icon(
                Icons.ios_share,
                size: 18,
                color: NurungjiColors.brown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 지역 선택 — 칩 8개를 상단 바에 다 못 넣어 팝업 메뉴로.
  Widget _regionMenu() {
    return PopupMenuButton<String>(
      tooltip: t('filter_region'),
      onSelected: (v) {
        setState(() => _pkRegion = v);
        _refreshMarkers();
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: '', child: Text(t('pk_region_all'))),
        ...regionOptionsAll.map(
          (r) => PopupMenuItem(value: r, child: Text(i18nRegion(r))),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _pkRegion.isEmpty ? t('pk_region_all') : i18nRegion(_pkRegion),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _pkRegion.isEmpty
                    ? NurungjiColors.brown
                    : NurungjiColors.teal,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: NurungjiColors.brown),
          ],
        ),
      ),
    );
  }

  // 목록에서 인스타 핸들 탭 → 상세를 거치지 않고 바로 인스타로.
  Future<void> _openSpotInsta(PickupSpot s) async {
    final handle = s.insta;
    if (handle == null || handle.isEmpty) return;
    Track.event('pickup_contact', {
      'id': s.id,
      'type': 'insta',
      'sport': s.sport,
    });
    final u = Uri.parse('https://instagram.com/$handle');
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  // 좌표 없는 크루 안내 — 탭하면 목록 뷰로 전환.
  Widget _offMapHint(int n) => BounceTap(
    onTap: () => setState(() => _pickupListView = true),
    child: GlassSurface(
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        t('pk_no_map_hint').replaceAll('{n}', '$n'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: NurungjiColors.brown,
        ),
      ),
    ),
  );

  // 레벨 선택 — 외국인에게 "나 초보인데 가도 되나"가 핵심 질문이라 지역 다음으로 중요.
  Widget _levelMenu() {
    String label(String l) => l.isEmpty ? t('pk_level_all') : t('lv_$l');
    return PopupMenuButton<String>(
      tooltip: t('filter_level'),
      onSelected: (v) {
        setState(() => _pkLevel = v);
        _refreshMarkers();
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: '', child: Text(t('pk_level_all'))),
        // 필터에도 설명을 붙인다 — 목록을 보는 사람(특히 외국인)이 기준을 알아야 고른다.
        ...pickupLevelOptions.map(
          (l) => PopupMenuItem(
            value: l,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t('lv_$l')),
                Text(
                  pickupLevelDesc(l),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: NurungjiColors.brown,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label(_pkLevel),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _pkLevel.isEmpty
                    ? NurungjiColors.brown
                    : NurungjiColors.teal,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: NurungjiColors.brown,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePickupList() async {
    final url = ShareService.pickupListUrl(
      region: _pkRegion,
      level: _pkLevel,
      englishOnly: _pkEnglishOnly,
    );
    Track.event('share', {
      'type': 'pickup_list',
      'region': _pkRegion,
      'level': _pkLevel,
      'english': _pkEnglishOnly,
    });
    await ShareService.osShare(url);
  }

  Widget _seg(String label, bool on, VoidCallback onTap) {
    return BounceTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: on ? NurungjiColors.yellow : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: on ? FontWeight.w800 : FontWeight.w600,
            color: NurungjiColors.dark,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _errorBox() => Material(
    color: Colors.red.shade50,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        '${t('data_load_err')}: $_error',
        style: TextStyle(color: Colors.red.shade900, fontSize: 12),
      ),
    ),
  );
}

// 상단 급구 롤링 티커: 여러 급구 팀을 4초마다 위로 굴려 노출. 탭 → 핀 이동 + 상세.
class _UrgentTicker extends StatefulWidget {
  final List<Club> clubs;
  final void Function(Club) onTap;
  const _UrgentTicker({required this.clubs, required this.onTap});

  @override
  State<_UrgentTicker> createState() => _UrgentTickerState();
}

class _UrgentTickerState extends State<_UrgentTicker> {
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    // 캡처 빌드에선 배너를 고정한다. 4초마다 문구가 바뀌면 스틸마다 상단 배너가
    // 달라져(예: [GVT] → [피터팬]) 스틸을 이어 붙일 때 배너가 깜빡이고,
    // 그 순간 합성 티가 난다. 캡처는 항상 첫 항목으로 고정.
    if (kCaptureMode) return;
    if (widget.clubs.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        setState(() => _i = (_i + 1) % widget.clubs.length);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _UrgentTicker old) {
    super.didUpdateWidget(old);
    if (_i >= widget.clubs.length) _i = 0;
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clubs.isEmpty) return const SizedBox.shrink();
    final c = widget.clubs[_i % widget.clubs.length];
    return GlassSurface(
      color: const Color(0xD9FFFBF0), // 크림-오렌지 0.85
      blur: 10,
      radius: BorderRadius.circular(12),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onTap(c),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Text(
                      '[${c.name}] ${c.urgentMsg}',
                      key: ValueKey('${c.id}_$_i'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: NurungjiColors.dark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 마커 롱프레스 릴스 미리보기 데이터(제목·릴스 URL·급구여부).
class _ReelPeek {
  final String title;
  final String reel;
  final bool urgent;
  const _ReelPeek({
    required this.title,
    required this.reel,
    required this.urgent,
  });
}

// 배경 블러 + 릴스 크게 — 인스타 피드 '꾹 누르면 릴스' 느낌. 바깥 탭/✕ → 닫힘.
// 진입 시 스크림(블러+딤)만 애니메이션(웹뷰는 플랫폼뷰라 Transform/Opacity 미적용).
class _ReelPeekOverlay extends StatefulWidget {
  final _ReelPeek data;
  final VoidCallback onClose;
  const _ReelPeekOverlay({required this.data, required this.onClose});

  @override
  State<_ReelPeekOverlay> createState() => _ReelPeekOverlayState();
}

class _ReelPeekOverlayState extends State<_ReelPeekOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..forward();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      // 카드는 1회만 빌드(웹뷰 재생성 방지) — 스크림만 프레임마다 갱신.
      child: Center(child: _card(context, widget.data)),
      builder: (_, child) {
        final v = Curves.easeOut.transform(_ac.value);
        return Stack(
          children: [
            // 블러 + 어둡게 스크림 — 탭하면 닫힘. (네이티브 맵은 플랫폼뷰라
            // 일부 기기에서 blur 미반영 가능 → 딤으로 항상 초점 보장)
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18 * v, sigmaY: 18 * v),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.42 * v),
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, _ReelPeek d) {
    final maxH = MediaQuery.of(context).size.height * 0.76;
    return GestureDetector(
      onTap: () {}, // 카드 내부 탭은 닫힘으로 전파하지 않음
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 22),
        constraints: BoxConstraints(maxHeight: maxH, maxWidth: 460),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더: 이름(+급구 불꽃) · 닫기
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 2),
              child: Row(
                children: [
                  if (d.urgent)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Text('🔥', style: TextStyle(fontSize: 16)),
                    ),
                  Expanded(
                    child: Text(
                      d.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: NurungjiColors.dark,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 20),
                    color: NurungjiColors.brown,
                  ),
                ],
              ),
            ),
            // 릴스 임베드(탭하면 인라인/인스타 재생)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
                child: InstaEmbed(url: d.reel),
              ),
            ),
            // 닫기/재생 힌트
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 10),
              child: Text(
                t('reel_peek_hint'),
                style: const TextStyle(
                  fontSize: 12,
                  color: NurungjiColors.brown,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
