// map_picker.dart — 전체화면 네이버지도 + 중앙 핀. 확인 시 지도 중심 좌표 반환.
// 반환: (lat, lng) record 또는 null(취소). registration.js startMapPicker 대체.
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../services/deep_link_service.dart' show kCaptureMode;
import '../services/i18n.dart';
import '../theme.dart';

/// 캡처 시연용: '이 위치로'를 밖에서 누른다(값이 바뀌면 확정).
/// 시연은 손으로 버튼을 못 누르므로, 사용자가 누를 때와 **같은 코드 경로**를 탄다.
final ValueNotifier<int> mapPickerDemoConfirm = ValueNotifier<int>(0);

class MapPickerScreen extends StatefulWidget {
  final NLatLng initial;
  const MapPickerScreen({super.key, required this.initial});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  NaverMapController? _controller;

  @override
  void initState() {
    super.initState();
    if (kCaptureMode) mapPickerDemoConfirm.addListener(_confirm);
  }

  @override
  void dispose() {
    mapPickerDemoConfirm.removeListener(_confirm);
    super.dispose();
  }

  // 버튼과 시연이 공유하는 확정 경로.
  Future<void> _confirm() async {
    final pos = await _controller?.getCameraPosition();
    if (pos != null && mounted) {
      Navigator.pop(context, (pos.target.latitude, pos.target.longitude));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('map_pick_title'))),
      body: Stack(
        alignment: Alignment.center,
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: widget.initial,
                zoom: 15,
              ),
            ),
            onMapReady: (c) => _controller = c,
          ),
          // 중앙 고정 핀 (지도를 움직여 핀을 원하는 위치에)
          const IgnorePointer(
            child: Padding(
              padding: EdgeInsets.only(bottom: 44),
              child: Icon(
                Icons.location_on,
                size: 50,
                color: NurungjiColors.teal,
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: ElevatedButton(
              onPressed: _confirm,
              child: Text(t('map_pick_set')),
            ),
          ),
        ],
      ),
    );
  }
}
