// 릴스 스티커 — 웹 tests/spot-story-card.test.js '릴스 스티커' 와 같은 불변식.
// 배경은 투명, 높이는 내용만큼, 같은 시간 요일은 한 타일, 못 읽는 일정은 달력 줄.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/widgets/sticker_card.dart';
import 'package:nulloongzido/widgets/story_card.dart';

void main() {
  setUp(() => appLang.value = 'ko');

  test('같은 시간 요일은 한 타일로 묶는다', () {
    final s = stickerSlots('화 19:00~22:00 / 목 19:00~22:00 / 토 13:00~17:00');
    expect(
      [for (final x in s) '${x.day} ${x.time}'],
      ['화·목 PM 7:00~PM 10:00', '토요일 PM 1:00~PM 5:00'],
    );
  });

  test('못 읽거나 묶음이 4개를 넘으면 타일 없음 → 달력 줄', () {
    const many =
        '월 1:00~2:00 / 화 3:00~4:00 / 수 5:00~6:00 / 목 7:00~8:00 / 금 9:00~10:00';
    for (final sched in [many, '매주 금요일 저녁']) {
      expect(stickerSlots(sched), isEmpty);
      final l = stickerLayout(
        StickerData(title: 'X', url: 'u', schedule: sched),
      );
      expect(l.rows.first.icon, 'cal');
    }
  });

  test('높이는 내용만큼 — 띠·타일이 있으면 더 길다', () {
    final full = stickerLayout(
      StickerData(
        title: 'GVT',
        url: 'https://do.nulloongzi.com/?club=a',
        verified: true,
        banner: const StickerBanner('식구 모집', '남자부 모집중!! 게스트 환영!!'),
        tags: const [
          StoryTag('성인', Color(0xFFF0ECE2), Color(0xFF6D6258)),
          StoryTag('대학생', Color(0xFFF0ECE2), Color(0xFF6D6258)),
        ],
        slots: stickerSlots('토 13:00~17:00'),
        fee: '월 3만원',
        region: '경기 구리시',
      ),
    ).h;
    final bare = stickerLayout(
      const StickerData(title: 'X', url: 'https://do.nulloongzi.com/?club=b'),
    ).h;
    expect(full, greaterThan(bare + 300));
  });

  test('PNG 는 폭 1080 · 모서리 밖은 투명', () async {
    final png = await renderStickerPng(
      StickerData(
        title: 'GVT',
        url: 'https://do.nulloongzi.com/?club=a',
        slots: stickerSlots('토 13:00~17:00'),
      ),
    );
    expect(png, isNotNull);
    // PNG IHDR: 폭(16..19) · 색 형식(25) = 6(RGBA)
    final w = (png![16] << 24) | (png[17] << 16) | (png[18] << 8) | png[19];
    expect(w, 1080);
    expect(png[25], 6);
  });
}
