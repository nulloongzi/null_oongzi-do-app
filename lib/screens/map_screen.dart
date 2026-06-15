// map_screen.dart — 네이티브 네이버지도(flutter_naver_map) + Firestore 마커
// kakao_map_plugin(웹뷰) → flutter_naver_map(네이티브)로 전환: 패닝 부드러움 + 한국 데이터.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';
import '../services/analytics.dart';
import '../services/data_repository.dart';
import '../services/club_filter.dart';
import '../services/deep_link_service.dart';
import '../services/profile_service.dart';
import '../services/i18n.dart';
import '../theme.dart';
import 'detail_sheet.dart';
import 'pickup_form_screen.dart';
import 'club_form_screen.dart';
import 'lunchbox_screen.dart';
import 'profile_screen.dart';
import '../widgets/bounce_tap.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/glass_surface.dart';
import '../widgets/insta_embed.dart';
import '../widgets/pickup_list_panel.dart';

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
  bool _pickupListView = false; // 픽업: 지도/목록 토글
  bool _isAdmin = false; // 관리자(픽업 모더레이션 삭제)
  final _search = TextEditingController(); // 상단 검색바 (동호회=필터키워드 / 픽업=목록검색)
  final _deepLinks = DeepLinkService();
  NOverlayImage? _clusterIcon; // 클러스터 노란 원 (런타임 생성)
  _ReelPeek? _reelPeek; // 마커 롱프레스 → 블러+릴스 미리보기(인스타 피드 꾹 누르기 느낌)

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

  // 픽업: English-OK + 검색어(제목/장소/주소) 필터.
  List<PickupSpot> _visibleSpots() {
    final kw = _search.text.trim().toLowerCase();
    return _spots.where((s) {
      if (_pkEnglishOnly && !s.englishOk) return false;
      if (kw.isEmpty) return true;
      final hay =
          '${s.title} ${s.venueName ?? ''} ${s.address ?? ''}'.toLowerCase();
      return hay.contains(kw);
    }).toList();
  }

  // 📍 내 위치로 이동(추적 follow). 권한 거부 시 무시.
  Future<void> _moveToMe() async {
    try {
      final st = await Permission.location.request();
      if (st.isGranted) {
        _controller?.setLocationTrackingMode(NLocationTrackingMode.follow);
      }
    } catch (_) {}
  }

  // 도시락/프로필: 웹 오버레이처럼 화면 중앙 다이얼로그로.
  void _openLunchbox() => showLunchboxDialog(context);

  void _openProfile() => showProfileDialog(context);

  // 딥링크(?club=/?spot=) → 탭 전환 + 상세 오픈. 메모리에 없으면 단건 조회.
  Future<void> _handleDeepLink(DeepLink d) async {
    if (!mounted) return;
    Track.event('deep_link_open', d.kind == 'club' ? {'club_id': d.id} : {'spot_id': d.id});
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
        showClubDetail(context, c,
            currentUid: _repo.currentUid, isAdmin: _isAdmin, onChanged: _load);
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
        showSpotDetail(context, s,
            currentUid: _repo.currentUid, isAdmin: _isAdmin, onChanged: _load);
      }
    }
  }

  Future<void> _load() async {
    try {
      final results =
          await Future.wait([_repo.loadClubs(), _repo.loadPickups()]);
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
      if (mounted) setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // 웹과 동일한 마커 이미지(assets/markers). 원본 224x294 → 32x42로 표시.
  static final _clubIcon =
      NOverlayImage.fromAssetImage('assets/markers/marker_yellow.png');
  static final _pickupIcon =
      NOverlayImage.fromAssetImage('assets/markers/marker_red.png');
  static const _markerSize = Size(38, 48); // 기본 핀(라벨 없음) — 약간 키움
  static const _labelSize = Size(170, 76); // 이름 알약 포함 마커
  // 라벨 on/off 데드밴드(히스테리시스): 경계 근처 미세 줌이 표시를 깜빡이며 토글하지 않도록.
  static const _labelZoomShow = 12.2; // 이 줌 이상 → 이름 알약 켜기
  static const _labelZoomHide = 11.8; // 이 줌 미만 → 끄기 (사이 구간은 현 상태 유지)
  static const _focusZoom = 15.0; // 마커 탭 시 확대 축척
  bool _showLabels = false; // 현재 줌이 임계 이상? (스테이지3=알약 표시)

  // 라벨 토글을 clear+add 없이 in-place(setIcon/setSize)로 적용하기 위한 보관.
  Map<String, NMarker> _markersById = {};
  List<_MarkerSpec> _lastSpecs = const [];
  Timer? _labelFadeTimer;

  // 마커 라벨 아이콘 캐시(이름·상태별 1회 렌더) + 핀 에셋 프리캐시(미로드 시 핀이 빈칸으로 캡처되는 것 방지)
  final Map<String, NOverlayImage> _labelIconCache = {};
  Future<void>? _prewarm;
  Future<void> _ensurePrewarm() {
    return _prewarm ??= () async {
      try {
        await precacheImage(
            const AssetImage('assets/markers/marker_yellow.png'), context);
        await precacheImage(
            const AssetImage('assets/markers/marker_red.png'), context);
      } catch (_) {}
    }();
  }

  // 핀 위에 이름 알약(흰 배경 + 인증 배지) — 웹 마커 라벨. fromWidget 1회 렌더 후 캐시.
  Future<NOverlayImage?> _labeledIcon(String name,
      {required bool red, required bool urgent, required bool verified}) async {
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: urgent
                            ? const Color(0xFFE53935)
                            : const Color(0x22000000),
                        width: urgent ? 1.5 : 1),
                    boxShadow: [
                      const BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 3,
                          offset: Offset(0, 1)),
                      // 급구: 붉은 글로우로 시선 끌기
                      if (urgent)
                        BoxShadow(
                            color: const Color(0xFFE53935).withValues(alpha: 0.55),
                            blurRadius: 8,
                            spreadRadius: 1),
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
                          child: Icon(Icons.verified,
                              color: Color(0xFF1DA1F2), size: 14),
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

  NOverlayCaption _caption(String text, {bool urgent = false}) => NOverlayCaption(
        text: urgent ? '🔥 $text' : text,
        textSize: 13,
        color: urgent ? const Color(0xFFD32F2F) : NurungjiColors.dark,
        haloColor: Colors.white,
      );

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
            boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2))],
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
    final pivotY =
        (((topChrome + sheetTopInMap) / 2) / mapH).clamp(0.18, 0.5).toDouble();
    // 정해진 축척으로 확대(현재가 더 크면 유지 — 줌아웃 방지)
    double z = _focusZoom;
    try {
      final cam = await c.getCameraPosition();
      if (cam.zoom > z) z = cam.zoom;
    } catch (_) {}
    try {
      final update =
          NCameraUpdate.scrollAndZoomTo(target: NLatLng(lat, lng), zoom: z)
            ..setPivot(NPoint(0.5, pivotY));
      await c.updateCamera(update);
    } catch (_) {
      try {
        await c.updateCamera(
            NCameraUpdate.scrollAndZoomTo(target: NLatLng(lat, lng), zoom: z));
      } catch (_) {}
    }
  }

  // 마커/티커 탭 → 핀을 보이는 영역 중앙으로 이동 + 상세 시트 오픈.
  Future<void> _focusAndShowClub(Club club) async {
    await _centerOnPin(club.lat, club.lng);
    if (!mounted) return;
    showClubDetail(context, club,
        currentUid: _repo.currentUid, isAdmin: _isAdmin, onChanged: _load);
  }

  Future<void> _focusAndShowSpot(PickupSpot spot) async {
    await _centerOnPin(spot.lat, spot.lng);
    if (!mounted) return;
    showSpotDetail(context, spot,
        currentUid: _repo.currentUid, isAdmin: _isAdmin, onChanged: _load);
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
    final mpp = 156543.03392 *
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
    setState(() => _reelPeek = _ReelPeek(title: title!, reel: reel!, urgent: urgent));
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _refreshMarkers({bool fade = false}) async {
    final c = _controller;
    if (c == null) return;
    // 1) 표시할 항목 수집(클럽/스팟 공통 스펙)
    final items = <_MarkerSpec>[];
    if (_tab == 'clubs') {
      for (final club in _clubs.where(_filter.matches)) {
        if (club.lat == null || club.lng == null) continue;
        final urgent = club.isUrgent && (club.urgentMsg?.isNotEmpty ?? false);
        items.add(_MarkerSpec(
          id: 'c_${club.id}',
          pos: NLatLng(club.lat!, club.lng!),
          name: club.name,
          red: urgent,
          urgent: urgent,
          verified: club.isVerified,
          clusterable: !urgent, // 급구: 클러스터 제외(항상 표시)
          onTap: () => _focusAndShowClub(club),
        ));
      }
    } else {
      for (final spot in _visibleSpots()) {
        if (spot.lat == null || spot.lng == null) continue;
        items.add(_MarkerSpec(
          id: 's_${spot.id}',
          pos: NLatLng(spot.lat!, spot.lng!),
          name: spot.title,
          red: true,
          urgent: false,
          verified: false,
          clusterable: true,
          onTap: () => _focusAndShowSpot(spot),
        ));
      }
    }

    // 2) 이름 알약 아이콘을 병렬로 빌드(순차 await 제거 → 줌 인 시 끊김 완화). 캐시 히트는 즉시.
    final icons = _showLabels
        ? await Future.wait(items.map((s) => _labeledIcon(s.name,
            red: s.red, urgent: s.urgent, verified: s.verified)))
        : const <NOverlayImage?>[];
    if (!mounted || _controller == null) return;

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
            id: s.id, position: s.pos, icon: icon ?? fallback, size: size);
        cm.setOnTapListener((NClusterableMarker o) => s.onTap());
        m = cm;
      } else {
        final nm = NMarker(
            id: s.id, position: s.pos, icon: icon ?? fallback, size: size);
        nm.setOnTapListener((NMarker o) => s.onTap());
        m = nm;
      }
      markers.add(m);
      overlays.add(m);
    }

    // 4) 아이콘 빌드를 끝낸 뒤에 clear+add → 사라졌다 뜨는 끊김 최소화
    await c.clearOverlays();
    if (overlays.isNotEmpty) await c.addOverlayAll(overlays);

    // 라벨 in-place 토글용으로 현재 마커/스펙 보관(인덱스 정렬됨).
    _lastSpecs = items;
    _markersById = {
      for (var i = 0; i < items.length; i++) items[i].id: markers[i]
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
    final icons = _showLabels
        ? await Future.wait(specs.map((s) => _labeledIcon(s.name,
            red: s.red, urgent: s.urgent, verified: s.verified)))
        : const <NOverlayImage?>[];
    if (!mounted) return;
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
    setState(() => _tab = t);
    Track.event('switch_tab', {'tab': t});
    _refreshMarkers();
  }

  // ＋등록: 활성 탭에 따라 픽업/동호회 폼. 등록 성공 시 데이터 재로딩→마커 갱신.
  Future<void> _openRegister() async {
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
    if (_tab != 'clubs' || _filter.isEmpty) return;
    final pts = <NLatLng>[];
    for (final club in _clubs.where(_filter.matches)) {
      if (club.lat != null && club.lng != null) {
        pts.add(NLatLng(club.lat!, club.lng!));
      }
    }
    if (pts.isEmpty) return;
    try {
      final bounds = NLatLngBounds.from(pts);
      _controller?.updateCamera(
          NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(64)));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  if (_clusterIcon != null) clusterMarker.setIcon(_clusterIcon!);
                  clusterMarker.setIsFlat(true);
                  clusterMarker.setCaption(NOverlayCaption(
                    text: info.size.toString(),
                    textSize: 15,
                    color: NurungjiColors.dark,
                    haloColor: NurungjiColors.yellow,
                  ));
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
              Positioned(top: 70, left: 15, right: 15, child: _urgentTicker()),
            if (_tab == 'pickup')
              Positioned(
                  top: 70, left: 0, right: 0, child: Center(child: _pickupToggle())),
            // 동호회/픽업 탭 — 위 컨텍스트바가 있으면 122, 없으면 70.
            Positioned(
                top: (_tab == 'pickup' || (_tab == 'clubs' && _hasUrgent))
                    ? 122
                    : 70,
                left: 0,
                right: 0,
                child: Center(child: _tabPill())),
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
                    onTap: (s) => showSpotDetail(context, s,
                        currentUid: _repo.currentUid, isAdmin: _isAdmin, onChanged: _load),
                  ),
                ),
              ),
            // 플로팅 FAB (design §2.4): 좌(도시락/프로필) · 우(등록/내위치)
            // 픽업 목록뷰에선 패널과 겹치므로 숨김.
            if (!(_tab == 'pickup' && _pickupListView)) ...[
              Positioned(
                  left: 15, bottom: 95, child: _fab('🍱', _openLunchbox)),
              Positioned(left: 15, bottom: 30, child: _fab('🍚', _openProfile)),
              Positioned(
                  right: 15,
                  bottom: 95,
                  child: _fab('📝', _openRegister,
                      bg: const Color(0xF2FAC710))), // 등록 = 브랜드 옐로
              Positioned(right: 15, bottom: 30, child: _fab('📍', _moveToMe)),
            ],
            if (_error != null)
              Positioned(bottom: 20, left: 90, right: 90, child: _errorBox()),
            // 상세 패널(비모달) — Stack의 일부라 상세에서 띄우는 모달(공유 등)이 그 위에 뜸.
            ValueListenableBuilder<Widget?>(
              valueListenable: detailPanel,
              builder: (_, panel, __) => panel ?? const SizedBox.shrink(),
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
    );
  }

  // 플로팅 글래스 FAB (이모지) — 누르면 spring 축소.
  Widget _fab(String emoji, VoidCallback onTap, {Color? bg, double size = 52}) {
    return BounceTap(
      onTap: onTap,
      child: GlassSurface(
        radius: BorderRadius.circular(size / 2),
        color: bg ?? const Color(0xD9FFFFFF),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
              child: Text(emoji, style: TextStyle(fontSize: size * 0.46))),
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
      child: Row(children: [
        const Icon(Icons.search, size: 20, color: NurungjiColors.brown),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: _onSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: t('search_ph'),
            ),
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: NurungjiColors.dark),
          ),
        ),
        TextButton(
          onPressed: toggleLang,
          style: TextButton.styleFrom(
              minimumSize: const Size(34, 40),
              padding: const EdgeInsets.symmetric(horizontal: 4)),
          child: Text(isKo ? 'EN' : '한',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: NurungjiColors.brown)),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (isClubs)
          Stack(alignment: Alignment.center, children: [
            IconButton(
              onPressed: _openFilter,
              icon: Icon(Icons.tune,
                  color: _filter.isEmpty ? NurungjiColors.brown : NurungjiColors.urgent),
              tooltip: t('search_filter'),
            ),
            if (!_filter.isEmpty)
              const Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(radius: 4, backgroundColor: NurungjiColors.urgent),
              ),
          ])
        else
          IconButton(
            onPressed: () {
              setState(() => _pkEnglishOnly = !_pkEnglishOnly);
              _refreshMarkers();
            },
            icon: Icon(Icons.language,
                color: _pkEnglishOnly ? NurungjiColors.teal : NurungjiColors.brown),
            tooltip: t('english_only'),
          ),
      ]),
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _tabBtn('🏐 ${t('clubs')}', 'clubs'),
        const SizedBox(width: 4),
        _tabBtn('📍 ${t('pickup')}', 'pickup'),
      ]),
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
        child: Text(label,
            style: TextStyle(
                fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                color: NurungjiColors.dark)),
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _seg('🗺 ${t('map_view')}', !_pickupListView,
            () => setState(() => _pickupListView = false)),
        _seg('☰ ${t('list_view')}', _pickupListView,
            () => setState(() => _pickupListView = true)),
      ]),
    );
  }

  Widget _seg(String label, bool on, VoidCallback onTap) {
    return BounceTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
            color: on ? NurungjiColors.yellow : Colors.transparent,
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                color: NurungjiColors.dark,
                fontSize: 13)),
      ),
    );
  }

  Widget _errorBox() => Material(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('${t('data_load_err')}: $_error',
              style: TextStyle(color: Colors.red.shade900, fontSize: 12)),
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
            child: Row(children: [
              const SizedBox(width: 12),
              const Text('🔥', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 1), end: Offset.zero)
                        .animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Text(
                    '[${c.name}] ${c.urgentMsg}',
                    key: ValueKey('${c.id}_$_i'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: NurungjiColors.dark),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ]),
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
  const _ReelPeek(
      {required this.title, required this.reel, required this.urgent});
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
                      color: Colors.black.withValues(alpha: 0.42 * v)),
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
                color: Color(0x55000000), blurRadius: 30, offset: Offset(0, 12)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더: 이름(+급구 불꽃) · 닫기
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 2),
              child: Row(children: [
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
                        color: NurungjiColors.dark),
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 20),
                  color: NurungjiColors.brown,
                ),
              ]),
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
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
