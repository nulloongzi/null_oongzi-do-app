// map_picker.dart — 전체화면 네이버지도 + 중앙 핀. 확인 시 지도 중심 좌표 반환.
// 반환: (lat, lng) record 또는 null(취소). registration.js startMapPicker 대체.
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../services/i18n.dart';
import '../theme.dart';

class MapPickerScreen extends StatefulWidget {
  final NLatLng initial;
  const MapPickerScreen({super.key, required this.initial});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  NaverMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('map_pick_title'))),
      body: Stack(
        alignment: Alignment.center,
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition:
                  NCameraPosition(target: widget.initial, zoom: 15),
            ),
            onMapReady: (c) => _controller = c,
          ),
          // 중앙 고정 핀 (지도를 움직여 핀을 원하는 위치에)
          const IgnorePointer(
            child: Padding(
              padding: EdgeInsets.only(bottom: 44),
              child: Icon(Icons.location_on,
                  size: 50, color: NurungjiColors.teal),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: ElevatedButton(
              onPressed: () async {
                final pos = await _controller?.getCameraPosition();
                if (pos != null && context.mounted) {
                  Navigator.pop(
                      context, (pos.target.latitude, pos.target.longitude));
                }
              },
              child: Text(t('map_pick_set')),
            ),
          ),
        ],
      ),
    );
  }
}
