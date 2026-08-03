// pickup_level_label_test.dart — 레벨 라벨/설명 헬퍼.
// 라벨 매핑이 4곳(상세·목록·폼·스토리카드)에 흩어져 있던 걸 i18n.dart 로 모았으므로,
// 새 레벨이 어느 화면에서 빠지지 않는지 여기서 지킨다.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/services/pickup_filter.dart';

void main() {
  group('pickupLevelLabel', () {
    test('모든 레벨 값이 고유한 라벨을 가진다 (누락 시 any 로 뭉개지지 않는다)', () {
      final labels = pickupLevelOptions.map(pickupLevelLabel).toSet();
      expect(labels.length, pickupLevelOptions.length);
      expect(labels.contains(pickupLevelLabel('any')), isFalse);
    });

    test('모르는 값·null 은 누구나 환영으로 폴백', () {
      expect(pickupLevelLabel(null), pickupLevelLabel('any'));
      expect(pickupLevelLabel('bogus'), pickupLevelLabel('any'));
    });
  });

  group('pickupLevelDesc', () {
    test('모든 레벨에 설명이 있고 서로 다르다', () {
      final descs = pickupLevelOptions.map(pickupLevelDesc).toList();
      expect(descs.any((d) => d.isEmpty), isFalse);
      expect(descs.toSet().length, descs.length);
    });

    test('모르는 값은 any 설명으로 폴백', () {
      expect(pickupLevelDesc('bogus'), pickupLevelDesc('any'));
    });
  });
}
