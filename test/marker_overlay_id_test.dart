// 지도 마커 오버레이 id — 새로고침 세대마다 달라야 한다.
// flutter_naver_map(1.4.4) 클러스터러는 지운 마커를 나중에 id 로 정리한다. 같은 id 로 다시 올리면
// 그 정리가 새 마커까지 지워, 필터 적용 → 초기화 적용 뒤 화면의 마커가 전부 사라졌다.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/screens/map_screen.dart';

void main() {
  test('같은 항목도 세대가 다르면 다른 오버레이 id', () {
    expect(markerOverlayId('c_abc', 1), isNot(markerOverlayId('c_abc', 2)));
  });

  test('같은 세대 안에선 항목마다 다르다', () {
    expect(markerOverlayId('c_a', 3), isNot(markerOverlayId('c_b', 3)));
    expect(markerOverlayId('c_a', 3), isNot(markerOverlayId('s_a', 3)));
  });
}
