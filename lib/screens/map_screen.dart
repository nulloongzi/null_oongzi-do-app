// map_screen.dart — 네이티브 네이버지도(flutter_naver_map) + Firestore 마커
// kakao_map_plugin(웹뷰) → flutter_naver_map(네이티브)로 전환: 패닝 부드러움 + 한국 데이터.
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';
import '../services/data_repository.dart';
import '../services/club_filter.dart';
import '../services/deep_link_service.dart';
import '../services/profile_service.dart';
import '../services/i18n.dart';
import '../theme.dart';
import 'detail_sheet.dart';
import 'pickup_form_screen.dart';
import 'club_form_screen.dart';
import 'profile_screen.dart';
import '../widgets/filter_sheet.dart';

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
    _deepLinks.dispose();
    super.dispose();
  }

  // 딥링크(?club=/?spot=) → 탭 전환 + 상세 오픈. 메모리에 없으면 단건 조회.
  Future<void> _handleDeepLink(DeepLink d) async {
    if (!mounted) return;
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
            currentUid: _repo.currentUid, onChanged: _load);
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
            currentUid: _repo.currentUid, onChanged: _load);
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
  static const _markerSize = Size(32, 42);

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
        if (urgent) {
          // 급구: 클러스터 제외(항상 표시) + 빨강 + 항상 캡션
          final m = NMarker(
            id: 'c_${club.id}',
            position: pos,
            icon: _pickupIcon,
            size: _markerSize,
            caption: _caption(club.name, urgent: true),
          );
          m.setOnTapListener((NMarker o) => showClubDetail(context, club,
              currentUid: _repo.currentUid, onChanged: _load));
          overlays.add(m);
        } else {
          final m = NClusterableMarker(
            id: 'c_${club.id}',
            position: pos,
            icon: _clubIcon,
            size: _markerSize,
            caption: _caption(club.name),
            isHideCollidedCaptions: true,
          );
          m.setOnTapListener((NClusterableMarker o) => showClubDetail(context, club,
              currentUid: _repo.currentUid, onChanged: _load));
          overlays.add(m);
        }
      }
    } else {
      final spots = _pkEnglishOnly ? _spots.where((s) => s.englishOk) : _spots;
      for (final spot in spots) {
        if (spot.lat == null || spot.lng == null) continue;
        final m = NClusterableMarker(
          id: 's_${spot.id}',
          position: NLatLng(spot.lat!, spot.lng!),
          icon: _pickupIcon,
          size: _markerSize,
          caption: _caption(spot.title),
          isHideCollidedCaptions: true,
        );
        m.setOnTapListener((NClusterableMarker o) => showSpotDetail(context, spot,
            currentUid: _repo.currentUid, onChanged: _load));
        overlays.add(m);
      }
    }
    if (overlays.isNotEmpty) await c.addOverlayAll(overlays);
  }

  void _onTab(String t) {
    setState(() => _tab = t);
    _refreshMarkers();
  }

  // ＋등록: 활성 탭에 따라 픽업/동호회 폼. 등록 성공 시 데이터 재로딩→마커 갱신.
  Future<void> _openRegister() async {
    // 현재 지도 중심을 피커 초기 위치로 (없으면 폼 기본값 사용)
    final cam = await _controller?.getCameraPosition();
    if (!mounted) return;
    final center = cam?.target ?? const NLatLng(37.5559, 127.0838);
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _tab == 'pickup'
            ? PickupFormScreen(initialCenter: center)
            : ClubFormScreen(initialCenter: center),
      ),
    );
    if (created == true) await _load();
  }

  // 동호회 필터 시트 열기 → 적용 시 마커 갱신
  Future<void> _openFilter() async {
    final result = await showFilterSheet(context, _filter);
    if (result != null) {
      setState(() => _filter = result);
      _refreshMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRegister,
        backgroundColor: NurungjiColors.yellow,
        foregroundColor: NurungjiColors.dark,
        icon: const Icon(Icons.add),
        label: Text(t('add'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            NaverMap(
              options: const NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: NLatLng(37.5559, 127.0838),
                  zoom: 10.5,
                ),
                locationButtonEnable: true,
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
            ),
            Positioned(top: 10, left: 10, right: 10, child: _topBar()),
            if (_tab == 'clubs')
              Positioned(top: 66, left: 10, right: 10, child: _urgentTicker()),
            if (_error != null)
              Positioned(bottom: 20, left: 20, right: 20, child: _errorBox()),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            _tabBtn('🏐 ${t('clubs')} ${_clubs.length}', 'clubs'),
            const SizedBox(width: 6),
            _tabBtn('📍 ${t('pickup')} ${_spots.length}', 'pickup'),
            const Spacer(),
            TextButton(
              onPressed: toggleLang,
              style: TextButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 6)),
              child: Text(isKo ? 'EN' : '한',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: NurungjiColors.dark)),
            ),
            if (_loading)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            if (_tab == 'clubs')
              IconButton(
                onPressed: _openFilter,
                icon: Icon(Icons.tune,
                    color: _filter.isEmpty ? null : NurungjiColors.teal),
                tooltip: t('search_filter'),
              )
            else
              IconButton(
                onPressed: () {
                  setState(() => _pkEnglishOnly = !_pkEnglishOnly);
                  _refreshMarkers();
                },
                icon: Icon(Icons.language,
                    color: _pkEnglishOnly ? NurungjiColors.teal : null),
                tooltip: t('english_only'),
              ),
            IconButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen())),
                icon: const Icon(Icons.account_circle),
                tooltip: t('my_profile')),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(String label, String key) {
    final on = _tab == key;
    return GestureDetector(
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
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFFFFF3E0),
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
                    currentUid: _repo.currentUid, onChanged: _load),
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
