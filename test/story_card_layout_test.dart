// 팀·픽업 공유 카드 배치 테스트 — 웹 tests/spot-story-card.test.js '공유 카드 규격' 과 같은 불변식.
// 카드는 좌표를 직접 계산해 그리므로 깨지는 방식이 정해져 있다: 긴 내용이 QR 스텁을
// 덮거나(2026-09 이전 실제 버그), 짧은 내용 아래로 빈 띠가 남는다. 둘 다 좌표로 본다.
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/widgets/share_card_kit.dart';
import 'package:nulloongzido/widgets/story_card.dart';

final _long = StoryCardData(
  title: '가' * 120,
  url: 'https://do.nulloongzi.com/?spot=x',
  tags: [
    for (var i = 0; i < 12; i++)
      StoryTag(
        '태그$i 가나다라마바사',
        const Color(0xFFF0ECE2),
        const Color(0xFF6D6258),
      ),
  ],
  thisWeek: '나' * 300,
  schedule: '다' * 300,
  fee: '라' * 300,
  venue: '마' * 100,
  address: '서울 송파구 ${'바' * 200}',
);

const _short = StoryCardData(
  title: '짧은 팀',
  url: 'https://do.nulloongzi.com/?club=z',
);

Future<ui.Image> _render(StoryCardData d, CardFormat f) async {
  final p = StoryCardPainter(d, format: f);
  final rec = ui.PictureRecorder();
  p.paint(Canvas(rec), p.canvasSize);
  return rec.endRecording().toImage(1080, p.canvasSize.height.round());
}

void main() {
  test('규격: 스토리 9:16(1080×1920) · 피드 3:4(1080×1440)', () async {
    expect((await _render(_short, CardFormat.story)).height, 1920);
    final feed = await _render(_short, CardFormat.feed);
    expect(feed.width / feed.height, 3 / 4);
  });

  for (final f in CardFormat.values) {
    test('${f.name}: 아주 긴 내용도 정보 카드가 QR 스텁을 덮지 않는다', () async {
      final l = spotCardLayout(_long, f);
      expect(
        l.card.bottom,
        lessThanOrEqualTo(l.stubTop - ShareCard.gap + 0.01),
      );
      expect(
        l.card.top,
        greaterThanOrEqualTo(l.headerY + ShareCard.headerH + 120 - 0.01),
      );
      expect((await _render(_long, f)).width, 1080);
    });

    test('${f.name}: 짧은 내용이면 지도가 남는 세로를 먹는다 (빈 띠 없음)', () {
      final l = spotCardLayout(_short, f);
      expect(l.card.bottom, closeTo(l.stubTop - ShareCard.gap, 0.01));
      expect(l.map.top, 0);
      expect(l.map.bottom, closeTo(l.card.top + ShareCard.overlap, 0.01));
    });

    test('${f.name}: QR 타일은 아래 안전영역 안에 있다', () {
      final fmt = ShareCard.of(f);
      final qrBottom = ShareCard.stubTop(fmt) + ShareCard.stubPad + fmt.qr + 20;
      expect(qrBottom, lessThanOrEqualTo(fmt.h - fmt.bottom + 0.01));
    });
  }

  test('캔버스 문구에서 이모지를 뺀다 (앱 캔버스에선 □로 깨진다)', () {
    expect(stripEmoji('🌱 초보환영'), '초보환영');
    expect(stripEmoji('🌐 English OK'), 'English OK');
    expect(stripEmoji('반찬1 🍳'), '반찬1');
  });
}
