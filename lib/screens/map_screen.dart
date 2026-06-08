// map_screen.dart — 네이티브 네이버지도(flutter_naver_map) + Firestore 마커
// kakao_map_plugin(웹뷰) → flutter_naver_map(네이티브)로 전환: 패닝 부드러움 + 한국 데이터.
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
import '../widgets/pickup_list_panel.dart';

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

  // 도시락/프로필: 풀스크린 라우트 대신 지도 위 모달 시트(웹 오버레이 동작 대응).
  void _openLunchbox() => showLunchboxSheet(context);

  void _openProfile() => showProfileSheet(context);

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
  static const _labelZoomThreshold = 13.5; // 이 줌 이상에서만 이름 알약 노출
  bool _showLabels = false; // 현재 줌이 임계 이상? (스테이지3=알약 표시)

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

  // 줌 변경 후: 임계 넘나들면 이름 알약 표시여부 전환 + 마커 재렌더(아이콘 캐시로 빠름).
  void _onCameraIdle() async {
    final cam = await _controller?.getCameraPosition();
    if (cam == null || !mounted) return;
    final show = cam.zoom >= _labelZoomThreshold;
    if (show != _showLabels) {
      _showLabels = show;
      _refreshMarkers();
    }
  }

  Future<void> _refreshMarkers() async {
    final c = _controller;
    if (c == null) return;
    await c.clearOverlays();
    final overlays = <NAddableOverlay>{};
    if (_tab == 'clubs') {
      for (final club in _clubs.where(_filter.matches)) {
        if (club.lat == null || club.lng == null) continue;
        final pos = NLatLng(club.lat!, club.lng!);
        final urgent = club.isUrgent && (club.urgentMsg?.isNotEmpty ?? false);
        // 줌 임계 이상일 때만 이름 알약 노출(중간 줌=핀만). 인증팀은 배지 포함.
        final icon = _showLabels
            ? await _labeledIcon(club.name,
                red: urgent, urgent: urgent, verified: club.isVerified)
            : null;
        if (urgent) {
          // 급구: 클러스터 제외(항상 표시) + 빨강 라벨
          final m = NMarker(
            id: 'c_${club.id}',
            position: pos,
            icon: icon ?? _pickupIcon,
            size: icon != null ? _labelSize : _markerSize,
          );
          m.setOnTapListener((NMarker o) => showClubDetail(context, club,
              currentUid: _repo.currentUid, isAdmin: _isAdmin, onChanged: _load));
          overlays.add(m);
        } else {
          final m = NClusterableMarker(
            id: 'c_${club.id}',
            position: pos,
            icon: icon ?? _clubIcon,
            size: icon != null ? _labelSize : _markerSize,
          );
          m.setOnTapListener((NClusterableMarker o) => showClubDetail(context, club,
              currentUid: _repo.currentUid, isAdmin: _isAdmin, onChanged: _load));
          overlays.add(m);
        }
      }
    } else {
      final spots = _visibleSpots();
      for (final spot in spots) {
        if (spot.lat == null || spot.lng == null) continue;
        final icon = _showLabels
            ? await _labeledIcon(spot.title,
                red: true, urgent: false, verified: false)
            : null;
        final m = NClusterableMarker(
          id: 's_${spot.id}',
          position: NLatLng(spot.lat!, spot.lng!),
          icon: icon ?? _pickupIcon,
          size: icon != null ? _labelSize : _markerSize,
        );
        m.setOnTapListener((NClusterableMarker o) => showSpotDetail(context, spot,
            currentUid: _repo.currentUid, isAdmin: _isAdmin, onChanged: _load));
        overlays.add(m);
      }
    }
    if (overlays.isNotEmpty) await c.addOverlayAll(overlays);
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
            ),
            // 검색바 (design §2.1)
            Positioned(top: 12, left: 15, right: 15, child: _searchBar()),
            // 탭 pill (design §2.2) — 검색바 아래 가운데
            Positioned(
                top: 70, left: 0, right: 0, child: Center(child: _tabPill())),
            // 급구 티커(동호회) / 지도·목록 토글(픽업) — design §2.3
            if (_tab == 'clubs')
              Positioned(top: 122, left: 15, right: 15, child: _urgentTicker()),
            if (_tab == 'pickup')
              Positioned(
                  top: 122, left: 0, right: 0, child: Center(child: _pickupToggle())),
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
  Widget _tabPill() {
    return GlassSurface(
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _tabBtn('🏐 ${t('clubs')} ${_clubs.length}', 'clubs'),
        const SizedBox(width: 4),
        _tabBtn('📍 ${t('pickup')} ${_spots.length}', 'pickup'),
      ]),
    );
  }


  Widget _tabBtn(String label, String key) {
    final on = _tab == key;
    return BounceTap(
      onTap: () => _onTab(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? NurungjiColors.yellow : NurungjiColors.chipBg,
          borderRadius: BorderRadius.circular(12),
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
    return GlassSurface(
      color: const Color(0xD9FFFBF0), // 크림-오렌지 0.85
      blur: 10,
      radius: BorderRadius.circular(12),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: urgent.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (_, i) {
            final c = urgent[i];
            return Center(
              child: GestureDetector(
                onTap: () => showClubDetail(context, c,
                    currentUid: _repo.currentUid, isAdmin: _isAdmin, onChanged: _load),
                child: Text('🔥 ${c.name} · ${c.urgentMsg}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: NurungjiColors.dark)),
              ),
            );
          },
        ),
      ),
    );
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
