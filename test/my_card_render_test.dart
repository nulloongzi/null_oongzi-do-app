// 내 카드(포장하기) 렌더 테스트 — 골든 대신 '구조 검사'.
// 이 카드는 Canvas에 좌표를 직접 계산해 그리므로 깨지는 방식이 정해져 있다:
//   · 레이아웃 산술이 음수/NaN이 되어 paint가 throw
//   · 블록 합이 세로 예산을 넘어 QR 스텁을 덮음  ← 실제로 한 번 그렇게 됐다
//   · 신원이 머리글 위로 밀리거나 도시락통이 최소치 아래로 눌림
// 침범은 좌표로 따진다 → layout()을 직접 본다. 웹 tests/my-card.test.js 와 같은 불변식.
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/rice_dex.dart';
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
  MyCardMode mode = MyCardMode.card,
  int filled = 3,
  bool withSchedule = true,
  String nickname = '현미밥-a3k',
  String rice = '현미밥',
  List<String> friends = const [],
  bool team = true,
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
            events: [
              SchedEvent(scheduleDays[i + 1], 19 + i * 0.5, 21.5 + i * 0.5),
            ],
          ),
        );
      }
    } else {
      slots.add(const MyCardSlot());
    }
  }
  return MyCardData(
    nickname: nickname,
    riceType: rice,
    bgColor: const Color(0xFFFFF9C4),
    joined: '가입일: 2026.7.1',
    mainTeam: team && filled > 0 ? '스파이크클럽 0' : null,
    slots: slots,
    diet: diet,
    url: 'https://do.nulloongzi.com/',
    mode: mode,
    dex: RiceDex.build(rice, friends),
  );
}

void main() {
  test('규격: 네임카드·식단표 둘 다 9:16(1080×1920)', () async {
    for (final m in MyCardMode.values) {
      final img = await _render(_data(mode: m));
      expect(img.width, 1080, reason: m.name);
      expect(img.height, 1920, reason: m.name);
    }
  });

  test('블록이 QR 스텁을 침범하지 않는다 (찜 0~5개, 두 장)', () async {
    for (final m in MyCardMode.values) {
      for (var filled = 0; filled <= 5; filled++) {
        final p = MyCardPainter(_data(mode: m, filled: filled));
        expect(
          p.layout().bottom,
          lessThanOrEqualTo(p.stubTop - ShareCard.gap + 0.01),
          reason: '${m.name} filled=$filled: 마지막 블록이 스텁까지 내려왔다',
        );
      }
    }
  });

  test('네임카드: 신원 → 도시락통 → 밥도감, 밥도감은 스텁 바로 위', () async {
    for (final d in [
      _data(),
      _data(rice: '누룽지', nickname: '누룽지', team: false),
      _data(filled: 5, friends: ['백미밥', '흑미밥', '밥아저씨']),
    ]) {
      final l = MyCardPainter(d).layout();
      final headBot = l.fmt.top + ShareCard.headerH;
      expect(l.diet, Rect.zero);
      expect(l.identity.top, greaterThanOrEqualTo(headBot + 16 - 0.01));
      expect(l.identity.bottom, lessThanOrEqualTo(l.bento.top - 16 + 0.01));
      expect(l.bento.height, inInclusiveRange(280, 760));
      expect(l.bento.bottom + ShareCard.gap, closeTo(l.dex.top, 0.01));
      expect(l.dex.bottom, closeTo(l.stubTop - ShareCard.gap, 0.01));
      // 필드는 맨 위부터 본문 카드 윗단을 overlap 만큼 넘어 내려온다
      expect(l.fieldH, closeTo(l.bento.top + ShareCard.overlap, 0.01));
    }
  });

  test('네임카드: 도감 밖 닉네임은 번호·한 줄이 빠진 만큼 도시락통이 커진다', () {
    final a = MyCardPainter(_data()).layout();
    final b = MyCardPainter(_data(rice: '누룽지', nickname: '누룽지')).layout();
    expect(b.identity.height, lessThan(a.identity.height));
    expect(b.bento.height, greaterThanOrEqualTo(a.bento.height));
  });

  test('식단표: 신원 아래 시간표가 스텁 위까지, 도시락통·밥도감 없음', () {
    final l = MyCardPainter(_data(mode: MyCardMode.diet)).layout();
    expect(l.bento, Rect.zero);
    expect(l.dex, Rect.zero);
    expect(l.diet.top, greaterThanOrEqualTo(l.identity.bottom + 24));
    expect(l.diet.bottom, closeTo(l.stubTop - ShareCard.gap, 0.01));
    expect(l.diet.height, greaterThanOrEqualTo(600));
  });

  test('찜 0개 / 일정 0개 / 밥친구 24종이어도 죽지 않는다', () async {
    final many = [for (final it in RiceDex.list.take(24)) it.name];
    for (final m in MyCardMode.values) {
      for (final d in [
        _data(mode: m, filled: 0, withSchedule: false),
        _data(mode: m, friends: many),
      ]) {
        final img = await _render(d);
        expect(img.width, 1080);
      }
    }
  });

  test('밥이름이 아주 길어도(축소 + 말줄임) 레이아웃이 버틴다', () async {
    for (final m in MyCardMode.values) {
      final data = _data(mode: m, filled: 5, nickname: '아주아주긴밥이름' * 6);
      final p = MyCardPainter(data);
      expect(
        p.layout().bottom,
        lessThanOrEqualTo(p.stubTop - ShareCard.gap + 0.01),
        reason: m.name,
      );
      final img = await _render(data);
      expect(img.width, 1080);
    }
  });

  group('식단표 헤드라인 (웹 myCardDietSummary 와 같은 규칙)', () {
    DietTeam team(int slot, String name, List<SchedEvent> ev) =>
        DietTeam(name: name, isCustom: false, slotIdx: slot, events: ev);

    test('요일 + 시간대 성향, 횟수·시간, 범례는 도시락 칸 순서', () {
      final s = dietSummary([
        team(1, '강동 화요반', [SchedEvent('화', 20, 22)]),
        team(0, '잠실 배구회', [SchedEvent('목', 19, 22), SchedEvent('토', 14, 17)]),
      ]);
      expect(s.head, contains('저녁형'));
      expect(s.head.split(' ').first.split('·').length, 3);
      expect(s.sub, contains('3'));
      expect(s.sub, contains('8'));
      expect([for (final l in s.legend) l.slot], [0, 1]);
    });

    test('5일 이상은 "주 N일", 낮이 많으면 낮형, 일정 없으면 기본 제목', () {
      final s = dietSummary([
        team(0, 'A', [
          for (final d in scheduleDays.take(5)) SchedEvent(d, 13, 14.5),
        ]),
      ]);
      expect(s.head, contains('5'));
      expect(s.head, contains('낮형'));
      expect(s.sub, contains('7.5'));
      final e = dietSummary(const []);
      expect(e.sub, isEmpty);
      expect(e.legend, isEmpty);
    });
  });
}
