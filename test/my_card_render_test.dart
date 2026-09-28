// 내 카드(공유 이미지) 렌더 테스트 — 골든 대신 '구조 검사'.
// 이 카드는 Canvas에 좌표를 직접 계산해 그리므로 깨지는 방식이 정해져 있다:
//   · 레이아웃 산술이 음수/NaN이 되어 paint가 throw
//   · 블록 합이 세로 예산을 넘어 QR 스텁을 덮음  ← 실제로 한 번 그렇게 됐다
// 처음엔 픽셀 프로브로 확인했는데 그 좌표가 QR 모듈 위에 떨어져 헛짚었다.
// 침범은 좌표로 따지는 게 맞다 → layout()을 직접 본다.
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/schedule_parse.dart';
import 'package:nulloongzido/widgets/diet_grid.dart' show DietTeam;
import 'package:nulloongzido/widgets/my_card.dart';
import 'package:nulloongzido/widgets/share_card_kit.dart';

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
  test('규격: 스토리형 9:16(1080×1920) / 피드형 3:4(1080×1440)', () async {
    final story = await _render(_data(feed: false));
    expect(story.width, 1080);
    expect(story.height, 1920);
    // 피드형은 3:4 — 인스타 피드·그리드가 3:4를 그대로 보여준다(2025~).
    final feed = await _render(_data(feed: true));
    expect(feed.width, 1080);
    expect(feed.height, 1440);
  });

  test('블록이 QR 스텁을 침범하지 않는다 (찜 0~5개, 두 규격)', () async {
    for (final feed in [true, false]) {
      for (var filled = 0; filled <= 5; filled++) {
        final p = MyCardPainter(_data(feed: feed, filled: filled));
        expect(
          p.layout().bottom,
          lessThanOrEqualTo(p.stubTop - ShareCard.gap + 0.01),
          reason: 'feed=$feed filled=$filled: 마지막 블록이 스텁까지 내려왔다',
        );
      }
    }
  });

  test('빈 띠가 없다: 본문은 스텁 바로 위까지, 그 위는 밥색 필드', () async {
    for (final feed in [true, false]) {
      final l = MyCardPainter(_data(feed: feed)).layout();
      // 본문 아래끝이 스텁 절취선 - gap 에 붙는다 (크림 띠가 남지 않는다)
      expect(l.bottom, closeTo(l.stubTop - ShareCard.gap, 0.01));
      // 필드는 맨 위부터 본문 카드 윗단을 overlap 만큼 넘어 내려온다
      expect(l.fieldH, closeTo(l.bento.top + ShareCard.overlap, 0.01));
      // 머리글·QR은 안전영역 안
      expect(l.identity.top, greaterThanOrEqualTo(l.fmt.top));
    }
  });

  test('피드형: 신원 → 도시락통 → 식단표 순으로 겹치지 않게', () async {
    final l = MyCardPainter(_data(feed: true, filled: 5)).layout();
    expect(l.diet, isNot(Rect.zero));
    expect(l.bento.top, greaterThanOrEqualTo(l.identity.bottom));
    expect(l.diet.top, greaterThanOrEqualTo(l.bento.bottom));
    expect(l.diet.width, l.bento.width); // 둘 다 본문 폭
    expect(l.diet.height, greaterThanOrEqualTo(320)); // 식단표 최소 높이
  });

  test('스토리형: 식단표 없이 도시락통만, 가운데 정렬', () async {
    final l = MyCardPainter(_data(feed: false, filled: 5)).layout();
    expect(l.diet, Rect.zero);
    expect(l.bento.center.dx, closeTo(540, 0.5));
    expect(l.bento.height, inInclusiveRange(440, 760));
  });

  test('찜 0개 / 일정 0개여도 죽지 않는다', () async {
    for (final feed in [true, false]) {
      final img = await _render(
        _data(feed: feed, filled: 0, withSchedule: false),
      );
      expect(img.width, 1080);
    }
  });

  test('밥이름이 아주 길어도(축소 + 말줄임) 레이아웃이 버틴다', () async {
    for (final feed in [true, false]) {
      final data = _data(feed: feed, filled: 5, nickname: '아주아주긴밥이름' * 6);
      final p = MyCardPainter(data);
      expect(
        p.layout().bottom,
        lessThanOrEqualTo(p.stubTop - ShareCard.gap + 0.01),
        reason: 'feed=$feed',
      );
      expect((await _render(data)).width, 1080);
    }
  });

  group('밥친구 포함 (4단계)', () {
    List<MyCardFriend> friends(int n) => [
      for (var i = 0; i < n; i++)
        MyCardFriend(
          name: '밥친구$i',
          color: const Color(0xFFF8BBD0),
          tier: (i % 3) + 1,
          n: i + 1,
        ),
    ];
    MyCardData withFriends(bool feed, int n) => MyCardData(
      nickname: '현미밥-a3k',
      riceType: '현미밥',
      bgColor: const Color(0xFFFFF9C4),
      joined: '가입 2026.7.1',
      mainTeam: '잠실 배구회',
      slots: _data(feed: feed, filled: 3).slots,
      diet: _data(feed: feed, filled: 3).diet,
      url: 'https://do.nulloongzi.com/',
      feed: feed,
      friends: friends(n),
    );

    test('밥친구 없으면 friends 자리가 없다', () {
      for (final feed in [true, false]) {
        expect(MyCardPainter(withFriends(feed, 0)).layout().friends, Rect.zero);
      }
    });

    for (final feed in [false, true]) {
      test('${feed ? '피드' : '스토리'}: 1~6명 — 스텁을 덮지 않고 신원이 머리글 아래', () {
        for (var n = 1; n <= 6; n++) {
          final p = MyCardPainter(withFriends(feed, n));
          final l = p.layout();
          expect(l.friends, isNot(Rect.zero), reason: '$n명');
          expect(
            l.bottom,
            lessThanOrEqualTo(p.stubTop - ShareCard.gap + 0.01),
            reason: 'feed=$feed n=$n',
          );
          expect(
            l.identity.top,
            greaterThanOrEqualTo(l.fmt.top + ShareCard.headerH + 24 - 0.01),
            reason: 'feed=$feed n=$n: 신원이 머리글에 붙는다',
          );
        }
      });
    }

    test('스토리: 밥친구 칸은 도시락통 아래(264), 도시락통은 320 이상', () {
      final l = MyCardPainter(withFriends(false, 4)).layout();
      final l0 = MyCardPainter(withFriends(false, 0)).layout();
      expect(l.friends.height, 264);
      expect(l.friends.top, closeTo(l.bento.bottom + ShareCard.gap, 0.01));
      expect(l.friends.bottom, closeTo(l.stubTop - ShareCard.gap, 0.01));
      expect(l.bento.height, greaterThanOrEqualTo(320));
      expect(l.bento.height, lessThan(l0.bento.height));
      expect(l.identity.bottom, lessThanOrEqualTo(l.bento.top - 24 + 0.01));
    });

    test('피드: 얼굴 묶음은 신원 줄 오른쪽 안, 식단표·도시락통은 그대로', () {
      final l = MyCardPainter(withFriends(true, 3)).layout();
      final l0 = MyCardPainter(withFriends(true, 0)).layout();
      expect(l.friends.width, 72 + 48 * 2);
      expect(l.friends.right, closeTo(l.identity.right, 0.01));
      expect(l.friends.top, greaterThanOrEqualTo(l.identity.top - 0.01));
      expect(l.friends.bottom, lessThanOrEqualTo(l.identity.bottom + 0.01));
      expect(l.diet, l0.diet);
      expect(l.bento, l0.bento);
    });

    test('5명 이상은 4명까지만 자리를 잡는다', () {
      expect(
        MyCardPainter(withFriends(true, 7)).layout().friends.width,
        72 + 48 * 3,
      );
    });

    test('그리기: 누룽지(conic) 포함 두 규격이 죽지 않는다', () async {
      for (final feed in [true, false]) {
        expect((await _render(withFriends(feed, 4))).width, 1080);
      }
    });
  });
}
