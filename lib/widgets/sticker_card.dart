// sticker_card.dart — 릴스 스티커: 팀 정보를 상세 시트처럼 생긴 카드 한 장으로, 바깥은 투명.
// 릴스·스토리 편집기에서 '스티커/사진'으로 영상 위에 얹는 용도 — 예전엔 운영자가 시트를
// 캡처해서 누끼를 땄다. 높이는 내용만큼(고정 규격 없음).
// 웹 js/share.js generateSticker 와 같은 숫자(docs/design-system.md §7-6, 웹 레포).
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';
import '../services/i18n.dart';
import '../services/schedule_parse.dart';
import '../services/share_service.dart';
import 'share_card_kit.dart';
import 'story_card.dart';

class StickerSlot {
  final String day; // '화·목' · '토요일' · 'Sat'
  final String time; // 'PM 7:00~PM 10:00'
  const StickerSlot(this.day, this.time);
}

class StickerBanner {
  final bool urgent; // 급구(주황) · 아니면 모집·이번주(노랑)
  final String badge;
  final String msg;
  const StickerBanner(this.badge, this.msg, {this.urgent = false});
}

class StickerData {
  final String title;
  final String url;
  final bool verified;
  final List<StoryTag> tags;
  final StickerBanner? banner;
  final List<StickerSlot> slots;
  final String schedule; // 타일로 못 그렸을 때 달력 줄에 쓰는 원문
  final String? fee;
  final String region;

  const StickerData({
    required this.title,
    required this.url,
    this.verified = false,
    this.tags = const [],
    this.banner,
    this.slots = const [],
    this.schedule = '',
    this.fee,
    this.region = '',
  });

  factory StickerData.fromClub(Club c) {
    final base = StoryCardData.fromClub(c);
    StickerBanner? banner;
    final urgentMsg = stripEmoji(c.urgentMsg);
    if (c.urgentActive && urgentMsg.isNotEmpty) {
      banner = StickerBanner(t('sticker_urgent'), urgentMsg, urgent: true);
    } else if (c.recruitingActive) {
      final m = stripEmoji(c.recruitMsg);
      banner = StickerBanner(
        stripEmoji(t('rc_badge')),
        m.isNotEmpty ? m : t('rc_badge_desc'),
      );
    }
    return StickerData(
      title: base.title,
      url: base.url,
      verified: base.verified,
      tags: base.tags,
      banner: banner,
      slots: stickerSlots(c.schedule),
      schedule: base.schedule ?? '',
      fee: base.fee,
      region: _region(c.address),
    );
  }

  factory StickerData.fromSpot(PickupSpot s) {
    final base = StoryCardData.fromSpot(s);
    final raw = (s.schedule != null && s.schedule!.isNotEmpty)
        ? s.schedule
        : s.scheduleText;
    final week = stripEmoji(s.thisWeek);
    return StickerData(
      title: base.title,
      url: base.url,
      tags: base.tags,
      banner: week.isNotEmpty ? StickerBanner(t('this_week'), week) : null,
      slots: stickerSlots(raw),
      schedule: base.schedule ?? '',
      fee: base.fee,
      region: _region(s.address),
    );
  }
}

/// 주소 앞 두 마디 ("서울 송파구 올림픽로 25" → "서울 송파구"). 웹 storyRegion.
String _region(String? address) {
  final p = (address ?? '').trim().split(RegExp(r'\s+'));
  return p.where((x) => x.isNotEmpty).take(2).join(' ');
}

/// 일정 글 → 요일 묶음 타일. 같은 시간인 요일은 한 장('화·목').
/// 못 읽거나 4장을 넘으면 [] — 그땐 달력 줄 하나로 원문을 쓴다. 웹 stickerSlots.
List<StickerSlot> stickerSlots(String? text) {
  // 웹 parseScheduleText 처럼 한 요일엔 마지막 시간 하나만 남긴다.
  final byDay = <String, SchedEvent>{};
  for (final e in eventsFromText(text)) {
    byDay[e.day] = e;
  }
  final order = <String>[];
  final days = <String, List<String>>{};
  for (final d in scheduleDays) {
    final e = byDay[d];
    if (e == null) continue;
    final time = '${time12(e.start)}~${time12(e.end)}';
    if (!days.containsKey(time)) order.add(time);
    days.putIfAbsent(time, () => []).add(d);
  }
  if (order.isEmpty || order.length > 4) return const [];
  return [
    for (final time in order)
      StickerSlot(
        days[time]!.map(i18nDay).join('·') +
            (isKo && days[time]!.length == 1 ? '요일' : ''),
        time,
      ),
  ];
}

// ── 규격 (웹 STICKER 와 같다) ───────────────────────────────────
const _edge = 48.0; // 카드 바깥 투명 여백(그림자 자리)
const _pad = 56.0; // 카드 안 좌우 여백 → 본문 폭 872
const _cw = ShareCard.w - _edge * 2;
const _iw = _cw - _pad * 2;
const _titleFs = 64.0, _titleLh = 76.0;
const _chipH = 56.0, _chipFs = 30.0, _chipPad = 24.0, _chipGap = 12.0;
const _slotH = 132.0, _slotGap = 20.0;
const _rowIcon = 36.0, _rowFs = 32.0, _rowLh = 44.0, _rowGap = 14.0;
const _qr = 132.0;
const _slotDay = Color(0xFFB7791F);

class _Tone {
  final Color bg, line, ink, badge, badgeInk;
  const _Tone(this.bg, this.line, this.ink, this.badge, this.badgeInk);
}

const _urgentTone = _Tone(
  Color(0xFFFFF3E0),
  Color(0xFFFFCC80),
  Color(0xFFBF360C),
  Color(0xFFBF360C),
  Colors.white,
);
const _recruitTone = _Tone(
  Color(0xFFFFFBE6),
  Color(0x99FAC710), // 노랑 60%
  ShareCard.dark,
  ShareCard.yellow,
  ShareCard.ink,
);

class _Chip {
  final StoryTag tag;
  final double x, w;
  final int row;
  const _Chip(this.tag, this.x, this.row, this.w);
}

class StickerRow {
  final String icon;
  final List<String> lines;
  final double h;
  const StickerRow(this.icon, this.lines, this.h);
}

/// 측정 결과. 테스트가 높이·줄 수를 본다.
class StickerLayout {
  final double h;
  final List<String> title;
  final int chipCount;
  final List<StickerRow> rows;
  const StickerLayout(this.h, this.title, this.chipCount, this.rows);
}

/// 측정과 그리기를 한 함수로 — 같은 값으로 높이를 재고 그린다. [c] 가 null 이면 높이만.
StickerLayout _paint(Canvas? c, StickerData d, ui.Image? logo) {
  const x = _edge + _pad;
  var y = _edge + 24; // 손잡이
  c?.drawRRect(
    cardRRect((ShareCard.w - 112) / 2, y, 112, 12, 6),
    Paint()..color = ShareCard.hair,
  );
  y += 12 + 40;

  final b = d.banner;
  if (b != null) {
    final tone = b.urgent ? _urgentTone : _recruitTone;
    final msgSt = cardStyle(36, FontWeight.w800, tone.ink);
    final msgLines = cardWrapLines(b.msg, msgSt, _iw - 56, 2);
    final bh = 24 + 44 + 14 + msgLines.length * 46 + 22.0;
    if (c != null) {
      final rr = cardRRect(x, y, _iw, bh, 24);
      c.drawRRect(rr, Paint()..color = tone.bg);
      c.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = tone.line,
      );
      final bst = cardStyle(26, FontWeight.w800, tone.badgeInk);
      final bw = cardMeasure(b.badge, bst) + 36;
      c.drawRRect(
        cardRRect(x + 28, y + 24, bw, 44, 22),
        Paint()..color = tone.badge,
      );
      cardText(c, b.badge, bst, x + 46, y + 24 + 23, middle: true);
      for (var i = 0; i < msgLines.length; i++) {
        cardText(c, msgLines[i], msgSt, x + 28, y + 24 + 44 + 14 + i * 46);
      }
    }
    y += bh + 32;
  }

  final titleSt = cardStyle(_titleFs, FontWeight.w800, ShareCard.ink);
  final title = cardWrapLines(
    d.title.isEmpty ? t('card_title_fallback') : d.title,
    titleSt,
    _iw - (d.verified ? 64 : 0),
    2,
  );
  if (c != null) {
    for (var i = 0; i < title.length; i++) {
      cardText(c, title[i], titleSt, x, y + i * _titleLh + 4);
      if (i == 0 && d.verified) {
        cardCheckBadge(
          c,
          x + cardMeasure(title[0], titleSt) + 36,
          y + _titleLh / 2,
          24,
        );
      }
    }
  }
  y += title.length * _titleLh;

  // 대상 칩: 최대 두 줄, 넘치는 칩은 뺀다
  final chipSt = cardStyle(_chipFs, FontWeight.w700, ShareCard.ink);
  final chips = <_Chip>[];
  var cx = 0.0;
  var row = 0;
  for (final tag in d.tags) {
    final w = math.min(_iw, cardMeasure(tag.text, chipSt) + _chipPad * 2);
    if (cx + w > _iw && cx > 0) {
      row++;
      cx = 0;
    }
    if (row >= 2) break;
    chips.add(_Chip(tag, cx, row, w));
    cx += w + _chipGap;
  }
  final chipRows = chips.isEmpty ? 0 : chips.last.row + 1;
  if (chipRows > 0) {
    y += 20;
    if (c != null) {
      for (final ch in chips) {
        final cy = y + ch.row * (_chipH + _chipGap);
        c.drawRRect(
          cardRRect(x + ch.x, cy, ch.w, _chipH, _chipH / 2),
          Paint()..color = ch.tag.bg,
        );
        final st = cardStyle(_chipFs, FontWeight.w700, ch.tag.fg);
        cardText(
          c,
          cardWrapLines(ch.tag.text, st, ch.w - _chipPad * 2, 1).firstOrNull ??
              '',
          st,
          x + ch.x + _chipPad,
          cy + _chipH / 2 + 1,
          middle: true,
        );
      }
    }
    y += chipRows * _chipH + (chipRows - 1) * _chipGap;
  }

  // 시간 타일: 노란 테두리 칸(예전 캡처 스티커에서 가장 눈에 띄던 부분). 두 칸씩.
  if (d.slots.isNotEmpty) {
    y += 28;
    const sw = (_iw - _slotGap) / 2;
    if (c != null) {
      for (var i = 0; i < d.slots.length; i++) {
        final s = d.slots[i];
        final sx = x + (i % 2) * (sw + _slotGap);
        final sy = y + (i ~/ 2) * (_slotH + _slotGap);
        final rr = cardRRect(sx, sy, sw, _slotH, 28);
        c.drawRRect(rr, Paint()..color = Colors.white);
        c.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = ShareCard.yellow,
        );
        final dst = cardStyle(28, FontWeight.w800, _slotDay);
        cardText(
          c,
          cardWrapLines(s.day, dst, sw - 40, 1).firstOrNull ?? '',
          dst,
          sx + sw / 2,
          sy + 22,
          align: TextAlign.center,
        );
        var fs = 40.0;
        while (fs > 30 &&
            cardMeasure(s.time, cardStyle(fs, FontWeight.w800, ShareCard.ink)) >
                sw - 40) {
          fs -= 2;
        }
        final tst = cardStyle(fs, FontWeight.w800, ShareCard.ink);
        cardText(
          c,
          cardWrapLines(s.time, tst, sw - 40, 1).firstOrNull ?? '',
          tst,
          sx + sw / 2,
          sy + 64,
          align: TextAlign.center,
        );
      }
    }
    y += (d.slots.length / 2).ceil() * (_slotH + _slotGap) - _slotGap;
  }

  // 정보 줄: (일정을 타일로 못 그렸을 때만) 달력 · 회비 · 지역
  final defs = [
    if (d.slots.isEmpty && d.schedule.isNotEmpty) ('cal', d.schedule),
    if ((d.fee ?? '').isNotEmpty) ('won', d.fee!),
    if (d.region.isNotEmpty) ('pin', d.region),
  ];
  final rowSt = cardStyle(_rowFs, FontWeight.w600, ShareCard.dark);
  final rows = [
    for (final (icon, text) in defs)
      () {
        final ln = cardWrapLines(text, rowSt, _iw - _rowIcon - 20, 2);
        return StickerRow(icon, ln, math.max(_rowIcon, ln.length * _rowLh));
      }(),
  ];
  if (rows.isNotEmpty) {
    y += 28;
    for (var k = 0; k < rows.length; k++) {
      final r = rows[k];
      if (k > 0) y += _rowGap;
      if (c != null) {
        final ico = switch (r.icon) {
          'cal' => cardIcoCal,
          'won' => cardIcoWon,
          _ => cardIcoPin,
        };
        ico(c, x, y + (_rowLh - _rowIcon) / 2, _rowIcon, ShareCard.brown);
        for (var i = 0; i < r.lines.length; i++) {
          cardText(
            c,
            r.lines[i],
            rowSt,
            x + _rowIcon + 20,
            y + _rowLh / 2 + i * _rowLh,
            middle: true,
          );
        }
      }
      y += r.h;
    }
  }

  // 꼬리: 헤어라인 + 로고·워드마크·안내 + QR(영상엔 링크가 안 걸린다 — QR 이 유일한 길)
  y += 36;
  c?.drawRect(Rect.fromLTWH(x, y, _iw, 2), Paint()..color = ShareCard.hair);
  y += 2 + 28;
  if (c != null) {
    cardQr(
      c,
      ShareService.withUtm(d.url, 'reel_sticker'),
      x + _iw - _qr,
      y,
      _qr,
    );
    final by = y + (_qr - 104) / 2; // 로고 줄 56 + 안내 줄 = 104
    final center = Offset(x + 28, by + 28);
    if (logo != null) {
      cardLogoCircle(c, logo, center, 28);
    } else {
      cardVolley(c, center.dx, center.dy, 20, ShareCard.yellow);
    }
    cardText(
      c,
      t('brand'),
      cardStyle(30, FontWeight.w800, ShareCard.ink),
      x + 72,
      by + 29,
      middle: true,
    );
    final capSt = cardStyle(24, FontWeight.w600, ShareCard.brown);
    cardText(
      c,
      cardWrapLines(
            t('sticker_foot_qr'),
            capSt,
            _iw - _qr - 32,
            1,
          ).firstOrNull ??
          '',
      capSt,
      x,
      by + 86,
      middle: true,
    );
  }
  y += _qr + 48;
  return StickerLayout(y + _edge, title, chips.length, rows);
}

/// 스티커 높이·배치만 계산(테스트용).
StickerLayout stickerLayout(StickerData d) => _paint(null, d, null);

/// 투명 스티커 PNG. 폭 1080, 높이는 내용만큼.
Future<Uint8List?> renderStickerPng(StickerData d) async {
  final logo = await loadBrandLogo();
  final h = stickerLayout(d).h;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  // 카드 판 — 바깥은 칠하지 않는다(투명)
  final card = cardRRect(_edge, _edge, _cw, h - _edge * 2, 48);
  cardShadow(c, Path()..addRRect(card));
  c.drawRRect(card, Paint()..color = ShareCard.card);
  _paint(c, d, logo);
  final img = await rec.endRecording().toImage(ShareCard.w.round(), h.round());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}
