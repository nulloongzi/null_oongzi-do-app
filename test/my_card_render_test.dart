// 내 카드(공유 이미지) 렌더 테스트 — 골든 대신 '구조 검사'.
// 이 카드는 Canvas에 좌표를 직접 계산해 그리므로 깨지는 방식이 정해져 있다:
//   · 레이아웃 산술이 음수/NaN이 되어 paint가 throw
//   · 블록 합이 세로 예산을 넘어 푸터(QR)를 덮음  ← 실제로 한 번 그렇게 됐다
// 그 둘을 픽셀 샘플링으로 잡는다. 문구·폰트에 의존하는 골든과 달리 카피가 바뀌어도 안 깨진다.
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/schedule_parse.dart';
import 'package:nulloongzido/widgets/diet_grid.dart' show DietTeam;
import 'package:nulloongzido/widgets/my_card.dart';

const _w = 1080, _h = 1920;

Future<ui.Image> _render(MyCardData data) async {
  final rec = ui.PictureRecorder();
  MyCardPainter(data).paint(Canvas(rec), const Size(1080, 1920));
  return rec.endRecording().toImage(_w, _h);
}

/// (x, y) 픽셀을 0xRRGGBB 정수로. Color API 변화에 안 흔들리게 바이트를 직접 읽는다.
Future<int> _rgb(ui.Image img, int x, int y) async {
  final bd = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final i = (y * _w + x) * 4;
  return (bd.getUint8(i) << 16) |
      (bd.getUint8(i + 1) << 8) |
      bd.getUint8(i + 2);
}

const _cream = 0xFBF3E2;

MyCardData _data({
  required bool feed,
  int filled = 3,
  bool withSchedule = true,
  String nickname = '백미밥-a3z',
}) {
  final slots = <MyCardSlot>[];
  final diet = <DietTeam>[];
  for (var i = 0; i < 5; i++) {
    if (i < filled) {
      slots.add(MyCardSlot(name: '스파이크클럽 $i', isCustom: i == 2));
      if (withSchedule) {
        diet.add(
          DietTeam(
            name: '스파이크클럽 $i',
            isCustom: i == 2,
            slotIdx: i,
            events: [SchedEvent('월', 19 + i * 0.5, 21.5 + i * 0.5)],
          ),
        );
      }
    } else {
      slots.add(const MyCardSlot());
    }
  }
  return MyCardData(
    nickname: nickname,
    bgColor: const Color(0xFFFFF9C4),
    joined: '가입 2026.7.1',
    mainTeam: filled > 0 ? '스파이크클럽 0' : null,
    slots: slots,
    diet: diet,
    url: 'https://nulloongzi.github.io/null_oongzi-do/',
    feed: feed,
  );
}

void main() {
  test('1080×1920으로 렌더된다', () async {
    for (final feed in [true, false]) {
      final img = await _render(_data(feed: feed));
      expect(img.width, 1080);
      expect(img.height, 1920);
    }
  });

  test('푸터 QR 흰 판을 위 블록이 덮지 않는다 (찜 0~5개, 두 모드 모두)', () async {
    // QR 흰 판 = (68,1458)~(282,1672). (76,1490)은 판 안쪽·QR 모듈 바깥의 여백.
    for (final feed in [true, false]) {
      for (var filled = 0; filled <= 5; filled++) {
        final img = await _render(_data(feed: feed, filled: filled));
        expect(
          await _rgb(img, 76, 1490),
          0xFFFFFF,
          reason: 'feed=$feed filled=$filled: 블록이 푸터까지 내려왔다',
        );
      }
    }
  });

  test('히어로 네임카드가 배경과 구분된다', () async {
    final img = await _render(_data(feed: false));
    expect(await _rgb(img, 200, 300), isNot(_cream));
  });

  test('찜 0개 / 일정 0개여도 죽지 않는다', () async {
    for (final feed in [true, false]) {
      final img = await _render(
        _data(feed: feed, filled: 0, withSchedule: false),
      );
      expect(img.width, 1080);
    }
  });

  test('밥이름이 아주 길어도(2줄 말줄임) 레이아웃이 버틴다', () async {
    for (final feed in [true, false]) {
      final img = await _render(
        _data(feed: feed, filled: 5, nickname: '아주아주긴밥이름' * 6),
      );
      expect(await _rgb(img, 76, 1490), 0xFFFFFF);
    }
  });
}
