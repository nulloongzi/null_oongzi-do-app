// map_screen.dart — P3 카카오 지도 + P2 Firestore 마커 (동호회/픽업)
// 지도가 안 떠도(카카오 도메인 등록 이슈 등) 상단 카운트로 Firestore 로드는 확인 가능.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';
import '../services/data_repository.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  KakaoMapController? _controller;
  final _repo = DataRepository();
  List<Club> _clubs = [];
  List<PickupSpot> _spots = [];
  String _tab = 'clubs'; // 'clubs' | 'pickup'
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_repo.loadClubs(), _repo.loadPickups()]);
      if (!mounted) return;
      setState(() {
        _clubs = results[0] as List<Club>;
        _spots = results[1] as List<PickupSpot>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // 웹앱과 동일한 마커 이미지(GitHub Pages 호스팅) — 동호회=노랑, 픽업=빨강
  static const _clubPin =
      'https://nulloongzi.github.io/null_oongzi-do/marker_yellow.png';
  static const _pickupPin =
      'https://nulloongzi.github.io/null_oongzi-do/marker_red.png';

  List<Marker> _buildMarkers() {
    final list = <Marker>[];
    if (_tab == 'clubs') {
      for (final c in _clubs) {
        if (c.lat == null || c.lng == null) continue;
        list.add(Marker(
            markerId: 'c_${c.id}',
            latLng: LatLng(c.lat!, c.lng!),
            markerImageSrc: _clubPin,
            width: 33,
            height: 43));
      }
    } else {
      for (final s in _spots) {
        if (s.lat == null || s.lng == null) continue;
        list.add(Marker(
            markerId: 's_${s.id}',
            latLng: LatLng(s.lat!, s.lng!),
            markerImageSrc: _pickupPin,
            width: 33,
            height: 43));
      }
    }
    return list;
  }

  void _onMarkerTap(String markerId) {
    if (markerId.startsWith('c_')) {
      final id = markerId.substring(2);
      Club? c;
      for (final e in _clubs) {
        if (e.id == id) {
          c = e;
          break;
        }
      }
      if (c == null) return;
      _showSheet(c.name, [
        if (c.target != null) '🏷 ${c.target}',
        if (c.schedule != null) '🗓 ${c.schedule}',
        if (c.price != null) '💰 ${c.price}',
        if (c.address != null) '📍 ${c.address}',
      ]);
    } else if (markerId.startsWith('s_')) {
      final id = markerId.substring(2);
      PickupSpot? s;
      for (final e in _spots) {
        if (e.id == id) {
          s = e;
          break;
        }
      }
      if (s == null) return;
      _showSheet(s.title, [
        if (s.thisWeek != null) '🔥 ${s.thisWeek}',
        if (s.schedule != null) '🗓 ${s.schedule}',
        if (s.feeInfo != null) '💰 ${s.feeInfo}',
        if ((s.venueName ?? s.address) != null) '📍 ${s.venueName ?? s.address}',
      ]);
    }
  }

  void _showSheet(String title, List<String> lines) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...lines.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(l, style: const TextStyle(fontSize: 15.5)),
                )),
            const SizedBox(height: 6),
            const Text('상세·공유·등록은 다음 단계(P4~)에서 이식 예정',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
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
      body: SafeArea(
        child: Stack(
          children: [
            KakaoMap(
              onMapCreated: (controller) => _controller = controller,
              onMarkerTap: (markerId, latLng, zoomLevel) => _onMarkerTap(markerId),
              markers: _buildMarkers(),
              center: LatLng(37.5559, 127.0838),
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
      onTap: () => setState(() => _tab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFFAC710) : const Color(0xFFF0ECE2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                color: const Color(0xFF4E342E))),
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
