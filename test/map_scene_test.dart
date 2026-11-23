// 지도 장면 — 무엇을 어느 층에 그릴지(services/map_scene.dart). 폰 없이 확인한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/models/club.dart';
import 'package:nulloongzido/models/pickup_spot.dart';
import 'package:nulloongzido/services/club_filter.dart';
import 'package:nulloongzido/services/map_scene.dart';

final _now = DateTime(2026, 11, 4, 12);

Club _club(
  String id, {
  String address = '서울 송파구',
  bool urgent = false,
  double? lat = 37.5,
}) => Club(
  id: id,
  name: '팀$id',
  address: address,
  lat: lat,
  lng: 127.0,
  isUrgent: urgent,
  urgentMsg: urgent ? '2명' : null,
  urgentUntil: urgent ? _now.add(const Duration(days: 1)) : null,
);

void main() {
  test('급구 팀은 신호 층, 나머지는 발견 층. 좌표 없는 팀은 뺀다', () {
    final s = clubScene(
      [_club('a'), _club('b', urgent: true), _club('c', lat: null)],
      const ClubFilter(),
      now: _now,
    );
    expect(s.discovery.map((m) => m.id), ['c_a']);
    expect(s.signal.map((m) => m.id), ['c_b']);
    expect(s.signal.single.red, isTrue);
  });

  test('필터는 두 층 모두에 적용된다', () {
    final s = clubScene(
      [
        _club('a'),
        _club('b', urgent: true, address: '부산 해운대구'),
        _club('c', urgent: true),
      ],
      const ClubFilter(regions: {'서울'}),
      now: _now,
    );
    expect(s.discovery.map((m) => m.id), ['c_a']);
    expect(s.signal.map((m) => m.id), ['c_c']);
  });

  test('발견 층 열쇠: 같은 팀이면 같고, 팀이 바뀌면 다르다', () {
    final a = clubScene([_club('a')], const ClubFilter(), now: _now);
    final b = clubScene([_club('a')], const ClubFilter(), now: _now);
    final c = clubScene(
      [_club('a'), _club('z')],
      const ClubFilter(),
      now: _now,
    );
    expect(a.discoveryKey, b.discoveryKey);
    expect(a.discoveryKey, isNot(c.discoveryKey));
  });

  test('픽업은 모두 발견 층 빨강 핀', () {
    final s = spotScene([
      PickupSpot(
        id: 'p',
        title: '픽업',
        sport: '6s',
        level: 'any',
        lat: 37.5,
        lng: 127,
      ),
    ]);
    expect(s.discovery.single.id, 's_p');
    expect(s.discovery.single.red, isTrue);
    expect(s.signal, isEmpty);
  });
}
