// map_screen.dart — 네이티브 네이버지도(flutter_naver_map) + Firestore 마커
// kakao_map_plugin(웹뷰) → flutter_naver_map(네이티브)로 전환: 패닝 부드러움 + 한국 데이터.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';
import '../services/data_repository.dart';
import '../services/club_filter.dart';
import '../theme.dart';
import 'detail_sheet.dart';
import 'pickup_form_screen.dart';
import 'club_form_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _refreshMarkers() async {
    final c = _controller;
    if (c == null) return;
    await c.clearOverlays();
    final overlays = <NAddableOverlay>{};
    if (_tab == 'clubs') {
      for (final club in _clubs.where(_filter.matches)) {
        if (club.lat == null || club.lng == null) continue;
        final m = NMarker(
          id: 'c_${club.id}',
          position: NLatLng(club.lat!, club.lng!),
          icon: _clubIcon,
          size: _markerSize,
        );
        m.setOnTapListener((NMarker overlay) => showClubDetail(
              context,
              club,
              currentUid: _repo.currentUid,
              onChanged: _load,
            ));
        overlays.add(m);
      }
    } else {
      final spots = _pkEnglishOnly ? _spots.where((s) => s.englishOk) : _spots;
      for (final spot in spots) {
        if (spot.lat == null || spot.lng == null) continue;
        final m = NMarker(
          id: 's_${spot.id}',
          position: NLatLng(spot.lat!, spot.lng!),
          icon: _pickupIcon,
          size: _markerSize,
        );
        m.setOnTapListener((NMarker overlay) => showSpotDetail(
              context,
              spot,
              currentUid: _repo.currentUid,
              onChanged: _load,
            ));
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

  Future<void> _signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRegister,
        backgroundColor: NurungjiColors.yellow,
        foregroundColor: NurungjiColors.dark,
        icon: const Icon(Icons.add),
        label: const Text('등록', style: TextStyle(fontWeight: FontWeight.w800)),
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
              onMapReady: (controller) {
                _controller = controller;
                _refreshMarkers();
              },
            ),
            Positioned(top: 10, left: 10, right: 10, child: _topBar()),
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
            _tabBtn('🏐 동호회 ${_clubs.length}', 'clubs'),
            const SizedBox(width: 6),
            _tabBtn('📍 픽업 ${_spots.length}', 'pickup'),
            const Spacer(),
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
                tooltip: '검색·필터',
              )
            else
              IconButton(
                onPressed: () {
                  setState(() => _pkEnglishOnly = !_pkEnglishOnly);
                  _refreshMarkers();
                },
                icon: Icon(Icons.language,
                    color: _pkEnglishOnly ? NurungjiColors.teal : null),
                tooltip: 'English OK만',
              ),
            IconButton(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                tooltip: '로그아웃'),
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

  Widget _errorBox() => Material(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('데이터 로드 오류: $_error',
              style: TextStyle(color: Colors.red.shade900, fontSize: 12)),
        ),
      );
}
