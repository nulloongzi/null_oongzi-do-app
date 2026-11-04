// 지도 마커 층(widgets/map_marker_layers.dart) — 가짜 지도로 올리기·지우기 순서를 본다.
// 실제 지도 라이브러리의 묶음 기능은 지운 핀을 나중에 id 로 정리한다. 그래서 지켜야 할 것:
//  · 발견 층은 그릴 때마다 새 id (같은 id 를 다시 쓰면 새 핀이 지워졌다 — 필터 초기화 버그)
//  · 그리기는 한 번에 하나 (겹치면 핀이 두 벌 남았다)
//  · 이름표 단계가 바뀌면 발견 층은 다시 그리고, 급구는 제자리 교체

import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/map_scene.dart';
import 'package:nulloongzido/widgets/map_marker_layers.dart';
import 'package:flutter/material.dart' show Size;

/// 가짜 지도. 같은 오버레이를 두 번 올리면 터진다(실제 지도에선 두 벌이 보이는 상황).
class FakeSink implements MarkerSink {
  final live = <String, NAddableOverlay>{};
  final log = <String>[];
  Duration delay = Duration.zero;

  static String key(NOverlayInfo i) => '${i.type.name}:${i.id}';

  Iterable<String> get clusterIds => live.values
      .whereType<NClusterableMarker>()
      .map((m) => m.info.id.split('#').first);
  Iterable<String> get markerIds => live.values
      .where((o) => o is NMarker && o is! NClusterableMarker)
      .map((o) => o.info.id);

  @override
  Future<void> clearClusterable() async {
    await Future<void>.delayed(delay);
    live.removeWhere((_, o) => o is NClusterableMarker);
    log.add('clear');
  }

  @override
  Future<void> addAll(Set<NAddableOverlay> overlays) async {
    await Future<void>.delayed(delay);
    for (final o in overlays) {
      final k = key(o.info);
      if (live.containsKey(k)) throw StateError('두 번 올림: $k');
      live[k] = o;
    }
    log.add('add ${overlays.length}');
  }

  @override
  Future<void> delete(NOverlayInfo info) async {
    await Future<void>.delayed(delay);
    live.remove(key(info));
    log.add('delete ${info.id}');
  }
}

MarkerSpec _spec(String id, {bool urgent = false, bool area = false}) =>
    MarkerSpec(
      id: id,
      refId: id,
      isClub: true,
      lat: 37.5,
      lng: 127,
      name: id,
      red: urgent,
      urgent: urgent,
      verified: false,
      areaOnly: area,
    );

MapScene _scene(List<String> discovery, [List<String> signal = const []]) =>
    MapScene(
      [for (final d in discovery) _spec(d)],
      [for (final s in signal) _spec(s, urgent: true)],
    );

const _base = NOverlayImage.fromAssetImage('base');
const _label = NOverlayImage.fromAssetImage('label');

MapMarkerLayers _layers() => MapMarkerLayers(
  labeledIcon: (_) async => _label,
  baseIcon: (_) => _base,
  onTap: (_) {},
  labelSize: const Size(170, 76),
  markerSize: const Size(38, 48),
);

void main() {
  test('필터 → 초기화: 같은 팀도 다시 그릴 땐 새 id 로 올린다', () async {
    final sink = FakeSink();
    final l = _layers()..attach(sink);
    await l.apply(_scene(['c_a', 'c_b']), labels: false, urgentLabels: false);
    final first = sink.live.keys.toSet();
    await l.apply(_scene(['c_a']), labels: false, urgentLabels: false);
    await l.apply(_scene(['c_a', 'c_b']), labels: false, urgentLabels: false);
    expect(sink.clusterIds.toSet(), {'c_a', 'c_b'});
    expect(sink.live.keys.toSet().intersection(first), isEmpty);
  });

  test('연달아 불러도 한 번에 하나 — 핀이 두 벌 남지 않고 마지막 장면만 남는다', () async {
    final sink = FakeSink()..delay = const Duration(milliseconds: 5);
    final l = _layers()..attach(sink);
    final futures = [
      for (final q in [
        ['c_a'],
        ['c_a', 'c_b'],
        ['c_b'],
        ['c_a', 'c_c'],
      ])
        l.apply(_scene(q), labels: false, urgentLabels: false),
    ];
    await Future.wait(futures); // 두 번 올리면 FakeSink 가 터진다
    expect(sink.clusterIds.toList()..sort(), ['c_a', 'c_c']);
    // 첫 요청을 그리는 동안 쌓인 셋 중 마지막 하나만 그렸다
    expect(l.generation, 2);
  });

  test('같은 장면·같은 이름표 단계면 아무것도 안 한다', () async {
    final sink = FakeSink();
    final l = _layers()..attach(sink);
    await l.apply(_scene(['c_a'], ['c_u']), labels: false, urgentLabels: false);
    final n = sink.log.length;
    await l.apply(_scene(['c_a'], ['c_u']), labels: false, urgentLabels: false);
    expect(sink.log.length, n);
  });

  test('이름표 단계: 일반이 바뀌면 발견 층만 다시, 급구는 그대로', () async {
    final sink = FakeSink();
    final l = _layers()..attach(sink);
    await l.apply(_scene(['c_a'], ['c_u']), labels: false, urgentLabels: false);
    final urgent = sink.live['marker:c_u'];
    final gen = l.generation;
    await l.apply(_scene(['c_a'], ['c_u']), labels: true, urgentLabels: false);
    expect(l.generation, gen + 1);
    expect(identical(sink.live['marker:c_u'], urgent), isTrue);
  });

  test('이름표 단계: 급구만 바뀌면 급구 핀 제자리 교체, 발견 층은 그대로', () async {
    final sink = FakeSink();
    final l = _layers()..attach(sink);
    await l.apply(_scene(['c_a'], ['c_u']), labels: false, urgentLabels: false);
    final gen = l.generation;
    final urgent = sink.live['marker:c_u']! as NMarker;
    await l.apply(_scene(['c_a'], ['c_u']), labels: false, urgentLabels: true);
    expect(l.generation, gen);
    expect(identical(sink.live['marker:c_u'], urgent), isTrue);
    expect(urgent.icon, _label);
  });

  test('급구가 꺼진 팀은 신호 층에서 빠지고 발견 층으로 간다', () async {
    final sink = FakeSink();
    final l = _layers()..attach(sink);
    await l.apply(_scene(['c_a'], ['c_u']), labels: false, urgentLabels: false);
    await l.apply(_scene(['c_a', 'c_u']), labels: false, urgentLabels: false);
    expect(sink.markerIds, isEmpty);
    expect(sink.clusterIds.toSet(), {'c_a', 'c_u'});
  });

  test('대략 위치 범위 원도 층과 함께 바뀌고 남지 않는다', () async {
    final sink = FakeSink();
    final l = _layers()..attach(sink);
    final withArea = MapScene([_spec('c_a', area: true)], const []);
    await l.apply(withArea, labels: false, urgentLabels: false);
    await l.apply(withArea, labels: true, urgentLabels: false);
    final circles = sink.live.keys.where((k) => k.startsWith('circleOverlay'));
    expect(circles.length, 1);
    await l.apply(_scene([]), labels: true, urgentLabels: false);
    expect(sink.live, isEmpty);
  });

  test('지도가 붙기 전 요청은 기억했다가 붙을 때 마지막 것만 그린다', () async {
    final sink = FakeSink();
    final l = _layers();
    await l.apply(_scene(['c_a']), labels: false, urgentLabels: false);
    await l.apply(_scene(['c_b']), labels: false, urgentLabels: false);
    l.attach(sink);
    await pumpEventQueue();
    expect(sink.clusterIds.toList(), ['c_b']);
  });

  test('id 에 세대를 붙인다 — 세대가 다르면 다르다', () {
    expect(markerOverlayId('c_a', 1), isNot(markerOverlayId('c_a', 2)));
    expect(markerOverlayId('c_a', 1), isNot(markerOverlayId('s_a', 1)));
  });
}
