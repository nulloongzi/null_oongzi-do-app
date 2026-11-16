// map_marker_layers.dart — 지도 마커를 올리고 지우는 유일한 곳. 장면(services/map_scene.dart)을
// 받아 두 층에 반영한다. 화면(map_screen)은 장면을 만들어 apply 만 부른다.
//
// 지켜야 하는 것(flutter_naver_map 1.4.4 의 묶음 기능 때문):
//  1. 묶음에 들어간 핀(발견 층)은 올린 뒤 **손대지 않는다.** 묶음 기능이 핀을 풀 때마다
//     처음 받은 설정으로 새로 만들어서, 나중에 바꾼 아이콘·투명도는 되돌아간다.
//     → 이름표 단계가 바뀌어도 발견 층은 통째로 다시 그린다(아이콘은 캐시라 싸다).
//  2. 발견 층 id 는 그릴 때마다 새로(세대 번호). 묶음 기능은 지운 핀을 나중에 **id 로** 정리해서,
//     같은 id 로 다시 올린 새 핀까지 지웠다(필터 적용 → 초기화 적용 뒤 마커가 전부 사라진 버그).
//  3. 그리기는 한 번에 하나, 밀린 요청은 최신 하나만. 겹쳐 돌면 지우기·올리기 순서가 엉켜
//     핀이 두 벌 남거나 이름표가 옛 줌 기준으로 남았다.
// 급구(신호 층)는 묶음 밖의 보통 핀이라 제자리 교체가 안전하다 — 바뀐 것만 고친다.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, Size;
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../services/club_admin.dart' show kAreaCircleRadius;
import '../services/map_scene.dart';

/// 지도 오버레이 id = 핀 id + 그린 세대. 세대마다 달라야 한다(위 2번).
@visibleForTesting
String markerOverlayId(String specId, int gen) => '$specId#$gen';

/// 지도에 오버레이를 올리고 지우는 최소 동작. 테스트는 가짜로 바꿔 끼운다.
abstract class MarkerSink {
  Future<void> clearClusterable();
  Future<void> addAll(Set<NAddableOverlay> overlays);
  Future<void> delete(NOverlayInfo info);
}

class NaverMarkerSink implements MarkerSink {
  final NaverMapController controller;
  NaverMarkerSink(this.controller);

  @override
  Future<void> clearClusterable() =>
      controller.clearOverlays(type: NOverlayType.clusterableMarker);

  @override
  Future<void> addAll(Set<NAddableOverlay> overlays) =>
      controller.addOverlayAll(overlays);

  @override
  Future<void> delete(NOverlayInfo info) => controller.deleteOverlay(info);
}

/// 핀 아이콘. [labeled] 면 이름표 붙은 아이콘(없으면 null → 기본 핀).
typedef MarkerIconFor = Future<NOverlayImage?> Function(MarkerSpec spec);

class _Request {
  final MapScene scene;
  final bool labels; // 일반 핀 이름표 단계
  final bool urgentLabels; // 급구 핀 이름표 단계
  final bool fade;
  const _Request(this.scene, this.labels, this.urgentLabels, this.fade);
}

class _SignalPin {
  final NMarker marker;
  final NCircleOverlay? circle;
  final String look; // 데이터 그림(MarkerSpec.look)
  bool labeled;
  _SignalPin(this.marker, this.circle, this.look, this.labeled);
}

class MapMarkerLayers {
  final MarkerIconFor labeledIcon;
  final NOverlayImage Function(MarkerSpec spec) baseIcon;
  final void Function(MarkerSpec spec) onTap;
  final Size labelSize;
  final Size markerSize;

  MapMarkerLayers({
    required this.labeledIcon,
    required this.baseIcon,
    required this.onTap,
    required this.labelSize,
    required this.markerSize,
  });

  MarkerSink? _sink;
  _Request? _next; // 밀린 요청(최신 하나)
  final List<Completer<void>> _waiting = [];
  bool _busy = false;
  bool _disposed = false;

  int _gen = 0; // 발견 층 세대
  String? _discoveryKey; // 지금 올라간 발견 층(이름표 단계 포함)
  List<NOverlayInfo> _discoveryCircles = const [];
  final Map<String, _SignalPin> _signal = {};
  Timer? _fadeTimer;
  List<NAddableOverlay> _fading = const [];

  @visibleForTesting
  int get generation => _gen;

  /// 지도가 준비되면 붙인다. 붙기 전에 온 마지막 요청을 이때 그린다.
  void attach(MarkerSink sink) {
    _sink = sink;
    _pump();
  }

  void dispose() {
    _disposed = true;
    _fadeTimer?.cancel();
  }

  /// 장면을 지도에 반영한다. 돌려준 Future 는 이 요청(또는 그 뒤의 더 새 요청)이 지도에
  /// 다 올라간 뒤 끝난다 — 그다음에 카메라를 옮겨야 순서가 꼬이지 않는다.
  /// 지도가 아직 없으면 요청만 기억하고 바로 끝난다(붙을 때 그린다).
  Future<void> apply(
    MapScene scene, {
    required bool labels,
    required bool urgentLabels,
    bool fade = false,
  }) {
    _next = _Request(scene, labels, urgentLabels, fade);
    if (_sink == null) return Future.value();
    final done = Completer<void>();
    _waiting.add(done);
    _pump();
    return done.future;
  }

  Future<void> _pump() async {
    if (_busy || _sink == null) return;
    _busy = true;
    try {
      while (_next != null && !_disposed) {
        final r = _next!;
        _next = null;
        final done = List.of(_waiting);
        _waiting.clear();
        try {
          await _applyNow(_sink!, r);
        } catch (e) {
          debugPrint('map markers: $e');
          _discoveryKey = null; // 다음 요청에서 발견 층을 다시 그리게
        }
        for (final c in done) {
          c.complete();
        }
      }
    } finally {
      _busy = false;
      for (final c in _waiting) {
        c.complete(); // dispose 로 멈춘 경우 기다리는 쪽을 풀어 준다
      }
      _waiting.clear();
    }
  }

  Future<void> _applyNow(MarkerSink sink, _Request r) async {
    await _applyDiscovery(sink, r);
    await _applySignal(sink, r);
  }

  // ── 발견 층: 바뀌었으면 통째로 다시 ─────────────────────────────
  Future<void> _applyDiscovery(MarkerSink sink, _Request r) async {
    final key = '${r.labels}\n${r.scene.discoveryKey}';
    if (key == _discoveryKey) return;
    final specs = r.scene.discovery;
    final icons = await Future.wait(
      specs.map(
        (s) => r.labels ? labeledIcon(s) : Future<NOverlayImage?>.value(),
      ),
    );
    final gen = ++_gen;
    final markers = <NClusterableMarker>[];
    final circles = <NCircleOverlay>[];
    for (var i = 0; i < specs.length; i++) {
      final s = specs[i];
      final icon = icons[i];
      final id = markerOverlayId(s.id, gen);
      final m = NClusterableMarker(
        id: id,
        position: NLatLng(s.lat, s.lng),
        icon: icon ?? baseIcon(s),
        size: icon != null ? labelSize : markerSize,
      );
      m.setOnTapListener((_) => onTap(s));
      markers.add(m);
      if (s.areaOnly) circles.add(_areaCircle('area_$id', s));
    }
    await sink.clearClusterable();
    // 범위 원은 묶음 밖 보통 오버레이 — 하나씩 지워도 늦은 정리가 없다
    await Future.wait(_discoveryCircles.map(sink.delete));
    await sink.addAll({...markers, ...circles});
    _discoveryCircles = [for (final c in circles) c.info];
    _discoveryKey = key;
    if (r.fade && markers.isNotEmpty) _fadeIn(markers);
  }

  // ── 신호 층(급구): 바뀐 것만 ─────────────────────────────────
  Future<void> _applySignal(MarkerSink sink, _Request r) async {
    final want = {for (final s in r.scene.signal) s.id: s};
    // 빠진 핀
    for (final id in _signal.keys.toList()) {
      final old = _signal[id]!;
      final s = want[id];
      if (s != null && s.look == old.look) continue;
      _signal.remove(id);
      await sink.delete(old.marker.info);
      if (old.circle != null) await sink.delete(old.circle!.info);
    }
    // 새 핀 · 이름표 단계만 바뀐 핀
    final add = <NAddableOverlay>{};
    for (final s in r.scene.signal) {
      final icon = r.urgentLabels ? await labeledIcon(s) : null;
      final cur = _signal[s.id];
      if (cur != null) {
        if (cur.labeled != r.urgentLabels) {
          cur.marker.setIcon(icon ?? baseIcon(s));
          cur.marker.setSize(icon != null ? labelSize : markerSize);
          cur.labeled = r.urgentLabels;
        }
        continue;
      }
      final m = NMarker(
        id: s.id,
        position: NLatLng(s.lat, s.lng),
        icon: icon ?? baseIcon(s),
        size: icon != null ? labelSize : markerSize,
      );
      m.setOnTapListener((_) => onTap(s));
      final circle = s.areaOnly ? _areaCircle('area_${s.id}', s) : null;
      _signal[s.id] = _SignalPin(m, circle, s.look, r.urgentLabels);
      add.add(m);
      if (circle != null) add.add(circle);
    }
    if (add.isNotEmpty) await sink.addAll(add);
  }

  // 대략 위치 팀: 핀 아래 범위 원 — "이 점은 정확한 좌표가 아니다"를 눈으로 알린다.
  // 좌표 자체는 저장 시점에 이미 뭉개져 있다(가리는 장치가 아니라 알리는 표시).
  NCircleOverlay _areaCircle(String id, MarkerSpec s) => NCircleOverlay(
    id: id,
    center: NLatLng(s.lat, s.lng),
    radius: kAreaCircleRadius,
    color: const Color(0x26FFC107),
    outlineColor: const Color(0x99FFA000),
    outlineWidth: 2,
  );

  // 이름표 단계가 바뀌어 새로 그린 핀: 투명도 0→1 짧은 페이드(툭 나타나지 않게).
  // 앞 페이드가 끝나기 전에 새로 시작하면 앞 핀들을 1로 마저 올려 둔다(흐린 채 멈추지 않게).
  // 묶음 기능이 도중에 핀을 새로 만들어도 처음 설정(투명도 1)이라 안 보이는 일은 없다.
  void _fadeIn(List<NAddableOverlay> overlays) {
    _fadeTimer?.cancel();
    for (final o in _fading) {
      _alpha(o, 1);
    }
    _fading = overlays;
    for (final o in overlays) {
      _alpha(o, 0);
    }
    const steps = 6;
    var i = 0;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 36), (t) {
      if (_disposed) {
        t.cancel();
        return;
      }
      i++;
      final v = (i / steps).clamp(0.0, 1.0);
      for (final o in overlays) {
        _alpha(o, v);
      }
      if (i >= steps) {
        t.cancel();
        _fading = const [];
      }
    });
  }

  static void _alpha(NAddableOverlay o, double v) {
    try {
      if (o is NMarker) o.setAlpha(v);
    } catch (_) {}
  }
}
