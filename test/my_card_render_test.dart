// 내 카드(공유 이미지) 렌더 테스트 — 골든 대신 '구조 검사'.
// 이 카드는 Canvas에 좌표를 직접 계산해 그리므로 깨지는 방식이 정해져 있다:
//   · 레이아웃 산술이 음수/NaN이 되어 paint가 throw
//   · 블록 합이 세로 예산을 넘어 푸터(QR)를 덮음  ← 실제로 한 번 그렇게 됐다
// 처음엔 픽셀 프로브로 확인했는데 그 좌표가 QR 모듈 위에 떨어져 헛짚었다.
// 침범은 좌표로 따지는 게 맞다 → layout()을 직접 본다.
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/schedule_parse.dart';
import 'package:nulloongzido/widgets/diet_grid.dart' show DietTeam;
import 'package:nulloongzido/widgets/my_card.dart';

Future<ui.Image> _render(MyCardData data) async {
  final painter = MyCardPainter(data);
  final size = painter.canvasSize;
  final rec = ui.PictureRecorder();
  painter.paint(Canvas(rec), size);
  return rec.endRecording().toImage(size.width.round(), size.height.round());
}

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
    riceType: '백미밥',
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
  test('규격: 스토리형 9:16(1080×1920) / 피드형 4:5(1080×1350)', () async {
    final story = await _render(_data(feed: false));
    expect(story.width, 1080);
    expect(story.height, 1920);
    // 피드형은 인스타 피드 제 규격 4:5 — 9:16로 내면 피드에서 잘린다.
    final feed = await _render(_data(feed: true));
    expect(feed.width, 1080);
    expect(feed.height, 1350);
  });

  test('블록이 푸터(QR/CTA)를 침범하지 않는다 (찜 0~5개, 두 규격)', () async {
    for (final feed in [true, false]) {
      for (var filled = 0; filled <= 5; filled++) {
        final p = MyCardPainter(_data(feed: feed, filled: filled));
        expect(
          p.layout().bottom,
          lessThanOrEqualTo(p.footTop),
          reason: 'feed=$feed filled=$filled: 마지막 블록이 푸터까지 내려왔다',
        );
      }
    }
  });

  test('피드형: 도시락통은 왼쪽, 시간표는 오른쪽에 겹치지 않게', () async {
    final l = MyCardPainter(_data(feed: true, filled: 5)).layout();
    expect(l.diet, isNot(Rect.zero));
    expect(l.box.right, lessThanOrEqualTo(l.diet.left));
    expect(l.box.top, l.diet.top);
    expect(l.box.height, l.diet.height);
    expect(l.box.top, greaterThanOrEqualTo(l.hero.bottom));
  });

  test('스토리형: 시간표 없이 도시락통만, 가운데 정렬', () async {
    final l = MyCardPainter(_data(feed: false, filled: 5)).layout();
    expect(l.diet, Rect.zero);
    expect(l.box.center.dx, closeTo(540, 0.5));
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
      final data = _data(feed: feed, filled: 5, nickname: '아주아주긴밥이름' * 6);
      final p = MyCardPainter(data);
      expect(
        p.layout().bottom,
        lessThanOrEqualTo(p.footTop),
        reason: 'feed=$feed',
      );
      expect((await _render(data)).width, 1080);
    }
  });
}
