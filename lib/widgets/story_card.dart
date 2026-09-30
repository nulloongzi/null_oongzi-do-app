// story_card.dart — 팀·픽업 공유 카드. 스토리 9:16(1080×1920) · 피드 3:4(1080×1440).
// 웹 js/share.js generateStoryCard 와 같은 규격·배치(docs/design-system.md §7).
// dart:ui Canvas로 직접 그려 PNG로 내보낸다(위젯 트리/RepaintBoundary 불필요·결정적).
// 머리글·스텁(QR)·아이콘·글자 규칙은 share_card_kit.dart 를 내 카드와 함께 쓴다.
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/club.dart';
import '../models/pickup_spot.dart';
import '../services/i18n.dart';
import '../services/target_parse.dart' show targetTagParts;
import '../services/share_service.dart';
import 'share_card_kit.dart';

class StoryTag {
  final String text;
  final Color bg;
  final Color fg;
  const StoryTag(this.text, this.bg, this.fg);
}

class StoryCardData {
  final String title;
  final String url;
  final bool verified;
  final Color accent;
  final String icon; // 핀 안 이모지
  final List<StoryTag> tags;
  final String? thisWeek;
  final String thisWeekBadge;
  final String? schedule;
  final String? fee;
  final String? venue;
  final String? address;
  final double? lat;
  final double? lng;
  final String? station; // 가까운 지하철역 라벨 (enrich)

  const StoryCardData({
    required this.title,
    required this.url,
    this.verified = false,
    this.accent = const Color(0xFF13A89E),
    this.icon = '🏐',
    this.tags = const [],
    this.thisWeek,
    this.thisWeekBadge = '이번주',
    this.schedule,
    this.fee,
    this.venue,
    this.address,
    this.lat,
    this.lng,
    this.station,
  });

  StoryCardData copyWith({String? station}) => StoryCardData(
    title: title,
    url: url,
    verified: verified,
    accent: accent,
    icon: icon,
    tags: tags,
    thisWeek: thisWeek,
    thisWeekBadge: thisWeekBadge,
    schedule: schedule,
    fee: fee,
    venue: venue,
    address: address,
    lat: lat,
    lng: lng,
    station: station ?? this.station,
  );

  factory StoryCardData.fromSpot(PickupSpot s) {
    final sportL = t(
      s.sport == '6s'
          ? 'sport_6s'
          : (s.sport == '9s' ? 'sport_9s' : 'sport_mixed'),
    );
    final levelL = pickupLevelLabel(s.level);
    final tags = <StoryTag>[
      StoryTag(
        stripEmoji(sportL),
        const Color(0xFFFAC710),
        const Color(0xFF4E342E),
      ),
      StoryTag(
        stripEmoji(levelL),
        const Color(0xFFF0ECE2),
        const Color(0xFF6D6258),
      ),
    ];
    if (s.beginnerFriendly) {
      tags.add(
        StoryTag(
          stripEmoji(t('beginner_ok')),
          const Color(0xFFE7F6E7),
          const Color(0xFF2E7D32),
        ),
      );
    }
    if (s.englishOk) {
      tags.add(
        StoryTag(
          stripEmoji(t('english_ok')),
          const Color(0xFFE6F0FB),
          const Color(0xFF1565C0),
        ),
      );
    }
    return StoryCardData(
      title: s.title,
      url: ShareService.spotUrl(s.id),
      accent: const Color(0xFF13A89E),
      tags: tags,
      thisWeek: s.thisWeek,
      thisWeekBadge: t('this_week'),
      schedule: i18nSchedule(
        (s.schedule != null && s.schedule!.isNotEmpty)
            ? s.schedule
            : s.scheduleText,
      ),
      fee: i18nPrice(s.feeInfo),
      venue: s.venueName,
      address: s.address,
      lat: s.lat,
      lng: s.lng,
    );
  }

  factory StoryCardData.fromClub(Club c) {
    // 단어는 하나씩, 괄호 안 메모는 한 덩어리(쪼개지 않는다) — 웹 storyClubData 와 같은 규칙
    final parts = targetTagParts(c.target);
    final tgt = [...parts.words.map(i18nTarget), ...parts.notes];
    final tags = <StoryTag>[];
    for (var i = 0; i < tgt.length && i < 4; i++) {
      tags.add(
        StoryTag(tgt[i], const Color(0xFFF0ECE2), const Color(0xFF6D6258)),
      );
    }
    return StoryCardData(
      title: c.name,
      url: ShareService.clubUrl(c.id),
      verified: c.isVerified,
      accent: const Color(0xFFFAC710),
      tags: tags,
      schedule: i18nSchedule(c.schedule),
      fee: i18nPrice(c.price),
      venue: '',
      address: c.address,
      lat: c.lat,
      lng: c.lng,
    );
  }
}

/// 카드를 PNG 바이트로 렌더. 스토리 9:16(1080×1920) / 피드 3:4(1080×1440).
/// 번들 Pretendard 사용으로 한글 tofu 방지.
Future<Uint8List?> renderStoryCardPng(
  StoryCardData data, {
  CardFormat format = CardFormat.story,
}) async {
  // Pretendard는 pubspec fonts로 번들 → 앱 시작 시 등록되어 즉시 사용 가능.
  final logo = await loadBrandLogo();
  final painter = StoryCardPainter(data, logo: logo, format: format);
  final size = painter.canvasSize;
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final pic = recorder.endRecording();
  final img = await pic.toImage(size.width.round(), size.height.round());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

/// 브랜드 로고 비트맵. 팀·픽업 카드·내 카드가 같은 로고를 쓴다.
Future<ui.Image?> loadBrandLogo() async {
  try {
    final bd = await rootBundle.load('assets/logo-512.png');
    final codec = await ui.instantiateImageCodec(bd.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

// ── 배치 ─────────────────────────────────────────────────────────
// 구조: 전폭 지도(히어로, 탄력) / 정보 카드(지도 아랫단을 덮음) / 티켓 스텁(QR).
// 웹 js/share.js spotLayout 과 같은 규칙 — 지도가 남는 세로를 흡수한다. 고정 좌표로
// 두면 짧은 팀은 아래가 비고, 긴 픽업은 정보 카드가 QR을 덮었다(2026-09 이전 버그).

/// 지도 최소 높이(맨 위 ~ 정보 카드 윗단): 머리글 + 핀이 들어갈 자리.
const _mapMin = {CardFormat.story: 640.0, CardFormat.feed: 440.0};

/// 정보가 넘치면 이 순서로 줄 수를 줄인다. QR을 덮는 것보다 말줄임이 낫다.
const _budgets = [
  (title: 2, week: 2, row: 2, chips: 3),
  (title: 2, week: 1, row: 1, chips: 2),
  (title: 1, week: 1, row: 1, chips: 1),
];

const _pad = 48.0, _titleFs = 60.0, _titleLh = 70.0;
const _chipH = 52.0, _chipFs = 28.0, _chipPad = 22.0, _chipGap = 12.0;
const _rowIcon = 36.0, _rowFs = 32.0, _rowLh = 44.0, _rowGap = 14.0;

class SpotChip {
  final StoryTag tag;
  final double x, w;
  final int row;
  const SpotChip(this.tag, this.x, this.row, this.w);
}

class SpotRow {
  final String icon;
  final List<String> lines;
  final double h;
  const SpotRow(this.icon, this.lines, this.h);
}

/// 정보 카드 내용 측정. 그리기와 같은 값을 쓴다.
class SpotInfo {
  final double h;
  final List<String> title;
  final List<SpotChip> chips;
  final int chipRows;
  final String? weekBadge;
  final List<String> weekLines;
  final double weekH;
  final List<SpotRow> rows;
  const SpotInfo._(
    this.h,
    this.title,
    this.chips,
    this.chipRows,
    this.weekBadge,
    this.weekLines,
    this.weekH,
    this.rows,
  );
}

const _iw = ShareCard.bodyW - _pad * 2;

SpotInfo _measureInfo(
  StoryCardData d,
  ({int title, int week, int row, int chips}) b,
) {
  final title = cardWrapLines(
    d.title.isEmpty ? t('card_title_fallback') : d.title,
    cardStyle(_titleFs, FontWeight.w800, ShareCard.ink),
    _iw - (d.verified ? 60 : 0),
    b.title,
  );
  var h = title.length * _titleLh;

  final chipSt = cardStyle(_chipFs, FontWeight.w700, ShareCard.ink);
  final chips = <SpotChip>[];
  var cx = 0.0;
  var row = 0;
  for (final tag in d.tags) {
    final w = math.min(_iw, cardMeasure(tag.text, chipSt) + _chipPad * 2);
    if (cx + w > _iw && cx > 0) {
      row++;
      cx = 0;
    }
    if (row >= b.chips) {
      row = b.chips - 1; // 넘치는 칩은 뺀다
      break;
    }
    chips.add(SpotChip(tag, cx, row, w));
    cx += w + _chipGap;
  }
  final chipRows = chips.isEmpty ? 0 : row + 1;
  if (chipRows > 0) h += 20 + chipRows * _chipH + (chipRows - 1) * _chipGap;

  String? badge;
  var weekLines = const <String>[];
  var weekH = 0.0;
  if ((d.thisWeek ?? '').isNotEmpty) {
    badge = d.thisWeekBadge;
    weekLines = cardWrapLines(
      d.thisWeek,
      cardStyle(30, FontWeight.w700, ShareCard.ink),
      _iw - 40,
      b.week,
    );
    weekH = 20 + 40 + 12 + weekLines.length * 40 + 20;
    h += 24 + weekH;
  }

  final venue = d.venue ?? '';
  final addr = d.address ?? '';
  final defs = [
    ('cal', d.schedule),
    ('won', d.fee),
    (
      'pin',
      venue.isNotEmpty ? (addr.isNotEmpty ? '$venue · $addr' : venue) : addr,
    ),
  ];
  final rowSt = cardStyle(_rowFs, FontWeight.w500, ShareCard.dark);
  final rows = <SpotRow>[];
  for (final (icon, text) in defs) {
    if (text == null || text.isEmpty) continue;
    final ln = cardWrapLines(text, rowSt, _iw - _rowIcon - 20, b.row);
    rows.add(SpotRow(icon, ln, math.max(_rowIcon, ln.length * _rowLh)));
  }
  if (rows.isNotEmpty) {
    h += 24;
    for (var i = 0; i < rows.length; i++) {
      h += rows[i].h + (i > 0 ? _rowGap : 0);
    }
  }
  return SpotInfo._(
    h + _pad * 2,
    title,
    chips,
    chipRows,
    badge,
    weekLines,
    weekH,
    rows,
  );
}

/// 배치 결과. 테스트가 좌표로 겹침(정보 카드 ↔ QR 스텁)을 검증한다.
class SpotCardLayout {
  final CardFmt fmt;
  final double headerY;
  final double stubTop;
  final Rect map; // 전폭, y=0
  final Rect card; // 정보 카드
  final SpotInfo info;
  const SpotCardLayout(
    this.fmt,
    this.headerY,
    this.stubTop,
    this.map,
    this.card,
    this.info,
  );
}

SpotCardLayout spotCardLayout(StoryCardData d, CardFormat format) {
  final fmt = ShareCard.of(format);
  final stubTop = ShareCard.stubTop(fmt);
  final cardBot = stubTop - ShareCard.gap;
  late SpotInfo info;
  var cardY = 0.0;
  for (final b in _budgets) {
    info = _measureInfo(d, b);
    cardY = cardBot - info.h;
    if (cardY >= _mapMin[format]! - ShareCard.overlap) break;
  }
  // 가장 빠듯한 예산으로도 모자라면 지도를 더 줄인다 — QR을 덮지 않는 게 먼저다.
  // 머리글 아래 핀 자리(120)는 남긴다.
  cardY = math.max(cardY, fmt.top + ShareCard.headerH + 120);
  return SpotCardLayout(
    fmt,
    fmt.top,
    stubTop,
    Rect.fromLTWH(0, 0, ShareCard.w, cardY + ShareCard.overlap),
    Rect.fromLTWH(ShareCard.m, cardY, ShareCard.bodyW, info.h),
    info,
  );
}

/// 주소 → 지역 라벨 ("서울 송파구 올림픽로 25" → "서울 송파구"). 웹 storyRegion.
String _region(String? address) {
  final p = (address ?? '').trim().split(RegExp(r'\s+'));
  return p.where((x) => x.isNotEmpty).take(2).join(' ');
}

class StoryCardPainter extends CustomPainter {
  final StoryCardData data;
  final ui.Image? logo;
  final CardFormat format;
  StoryCardPainter(this.data, {this.logo, this.format = CardFormat.story});

  Size get canvasSize => Size(ShareCard.w, ShareCard.of(format).h);

  @override
  void paint(Canvas canvas, Size size) {
    // 미리보기(작은 위젯)와 내보내기가 같은 좌표계를 쓰도록 스케일.
    if (size.width != ShareCard.w) canvas.scale(size.width / ShareCard.w);
    final l = spotCardLayout(data, format);
    cardBackground(canvas, l.fmt.h);
    _map(canvas, l);
    cardHeader(canvas, l.headerY, logo, right: _region(data.address));
    _info(canvas, l);
    cardStub(canvas, l.fmt, data.url, t('card_cta'));
  }

  // 전폭 일러스트 지도. 좌표로 시드를 잡아 장소마다 고유하고 안정적이다(웹과 같은 난수열).
  // 요소는 560 높이 한 벌 기준으로 그리고, 더 크면 한 벌을 아래로 이어 붙인다.
  void _map(Canvas c, SpotCardLayout l) {
    final w = l.map.width, h = l.map.height;
    c.save();
    c.clipRect(l.map);
    c.drawRect(l.map, Paint()..color = const Color(0xFFF7EDD6));
    var seed =
        ((((data.lat ?? 37.55) * 1e4).round() * 73856093) ^
                (((data.lng ?? 126.98) * 1e4).round() * 19349663))
            .abs() %
        2147483647;
    if (seed == 0) seed = 12345;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    const tile = 560.0;
    const blocks = [
      [0.06, 0.12, 130.0, 92.0],
      [0.28, 0.08, 104.0, 82.0],
      [0.08, 0.42, 112.0, 74.0],
      [0.3, 0.46, 118.0, 88.0],
      [0.55, 0.12, 92.0, 80.0],
      [0.56, 0.52, 104.0, 74.0],
      [0.82, 0.64, 118.0, 84.0],
      [0.14, 0.74, 98.0, 70.0],
      [0.66, 0.84, 110.0, 76.0],
    ];
    for (var ty = 0.0; ty < h; ty += tile) {
      final flip = (ty / tile).round() % 2 == 1;
      final ox = flip ? w * 0.18 : 0.0;
      c.save();
      c.translate((w * 0.78 + ox) % w, ty + tile * 0.3);
      c.rotate(0.3);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 340, height: 260),
        Paint()..color = const Color(0xFFDBE4BF),
      );
      c.restore();
      for (var i = 0; i < 4; i++) {
        c.drawCircle(
          Offset((w * 0.72 + ox) % w + i * 34, ty + tile * 0.24 + (i % 2) * 30),
          11,
          Paint()..color = const Color(0xFFC3D29A),
        );
      }
      for (final b in blocks) {
        final col = rnd() > 0.5
            ? const Color(0xFFECDFBB)
            : const Color(0xFFE6D6AC);
        final bx = (w * b[0] + ox) % w + (rnd() - 0.5) * 24;
        final by = ty + tile * b[1] + (rnd() - 0.5) * 18;
        c.drawRRect(cardRRect(bx, by, b[2], b[3], 10), Paint()..color = col);
      }
    }
    // 물길: 지도 아랫단(정보 카드 뒤)으로 흘러 나간다
    c.drawPath(
      Path()
        ..moveTo(0, h * 0.78)
        ..cubicTo(w * 0.28, h * 0.7, w * 0.34, h * 0.92, w * 0.62, h * 0.88)
        ..lineTo(w * 0.62, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFFD7E6E4),
    );
    final roadY = h * 0.55;
    final road = Path()
      ..moveTo(-20, roadY + 40)
      ..cubicTo(w * 0.35, roadY - 30, w * 0.5, roadY + 70, w + 20, roadY - 20);
    final roadPaint = cardStroke(const Color(0xFFFDF8EC), 32);
    c.drawPath(road, roadPaint);
    c.drawPath(
      Path()
        ..moveTo(w * 0.42, -20)
        ..cubicTo(w * 0.47, h * 0.4, w * 0.38, h * 0.6, w * 0.44, h + 20),
      roadPaint,
    );
    // 센터라인 점선
    final dash = cardStroke(const Color(0xFFE8CF94), 4);
    for (final m in road.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 34) {
        c.drawPath(m.extractPath(d, math.min(d + 16, m.length)), dash);
      }
    }
    // 아랫단을 크림으로 녹여 정보 카드와 이어지게
    c.drawRect(
      Rect.fromLTWH(0, h - 200, w, 200),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, h - 200), Offset(0, h), const [
          Color(0x00FBF3E2),
          Color(0xFFFBF3E2),
        ]),
    );
    c.restore();

    // 핀: 머리글 아래 ~ 정보 카드 윗단 사이 가운데. 아래 알약(가까운 역·장소)은 자리가 날 때만.
    final visTop = l.headerY + ShareCard.headerH, visBot = l.card.top;
    final station = (data.station ?? '').isNotEmpty;
    final geo = station ? data.station! : (data.venue ?? '');
    final geoH = geo.isNotEmpty && visBot - visTop > 360 ? 56.0 + 28 : 0.0;
    final px = w / 2, py = visTop + (visBot - visTop - geoH) / 2 - 20;
    const pr = 52.0;
    c.drawOval(
      Rect.fromCenter(center: Offset(px, py + 82), width: 80, height: 24),
      Paint()..color = const Color.fromRGBO(93, 64, 55, 0.14),
    );
    final pin = Path()
      ..moveTo(px - 30, py + 14)
      ..lineTo(px + 30, py + 14)
      ..lineTo(px, py + 80)
      ..close()
      ..addOval(Rect.fromCircle(center: Offset(px, py), radius: pr));
    cardShadow(c, pin);
    c.drawPath(pin, Paint()..color = data.accent);
    c.drawCircle(Offset(px, py), 34, Paint()..color = Colors.white);
    cardVolley(c, px, py, 22, data.accent);
    if (geoH > 0) {
      final st = cardStyle(28, FontWeight.w700, ShareCard.ink);
      final gw = math.min(ShareCard.bodyW, cardMeasure(geo, st) + 80);
      final gx = (w - gw) / 2, gy = visBot - 28 - 56;
      cardPill(c, gx, gy, gw, 56);
      (station ? cardIcoSub : cardIcoPin)(c, gx + 20, gy + 13, 30, data.accent);
      cardText(
        c,
        cardWrapLines(geo, st, gw - 80, 1).firstOrNull ?? '',
        st,
        gx + 60,
        gy + 29,
        middle: true,
      );
    }
  }

  void _info(Canvas c, SpotCardLayout l) {
    final r = l.card, info = l.info;
    final ix = r.left + _pad;
    cardPanel(c, r);
    var y = r.top + _pad;
    final titleSt = cardStyle(_titleFs, FontWeight.w800, ShareCard.ink);
    for (var i = 0; i < info.title.length; i++) {
      cardText(c, info.title[i], titleSt, ix, y + 2);
      if (i == 0 && data.verified) {
        cardCheckBadge(
          c,
          ix + cardMeasure(info.title[0], titleSt) + 34,
          y + _titleLh / 2,
          22,
        );
      }
      y += _titleLh;
    }
    if (info.chipRows > 0) {
      y += 20;
      for (final ch in info.chips) {
        final cx = ix + ch.x, cy = y + ch.row * (_chipH + _chipGap);
        c.drawRRect(
          cardRRect(cx, cy, ch.w, _chipH, _chipH / 2),
          Paint()..color = ch.tag.bg,
        );
        final st = cardStyle(_chipFs, FontWeight.w700, ch.tag.fg);
        cardText(
          c,
          cardWrapLines(ch.tag.text, st, ch.w - _chipPad * 2, 1).firstOrNull ??
              '',
          st,
          cx + _chipPad,
          cy + _chipH / 2 + 1,
          middle: true,
        );
      }
      y += info.chipRows * _chipH + (info.chipRows - 1) * _chipGap;
    }
    if (info.weekBadge != null) {
      y += 24;
      c.drawRRect(
        cardRRect(ix, y, _iw, info.weekH, 18),
        Paint()..color = const Color(0x38FAC710), // rgba(250,199,16,.22)
      );
      final bst = cardStyle(24, FontWeight.w800, ShareCard.ink);
      final bw = cardMeasure(info.weekBadge!, bst) + 32;
      c.drawRRect(
        cardRRect(ix + 20, y + 20, bw, 40, 20),
        Paint()..color = ShareCard.yellow,
      );
      cardText(c, info.weekBadge!, bst, ix + 36, y + 41, middle: true);
      final wst = cardStyle(30, FontWeight.w700, ShareCard.ink);
      for (var i = 0; i < info.weekLines.length; i++) {
        cardText(c, info.weekLines[i], wst, ix + 20, y + 72 + i * 40);
      }
      y += info.weekH;
    }
    if (info.rows.isNotEmpty) {
      y += 24;
      final st = cardStyle(_rowFs, FontWeight.w500, ShareCard.dark);
      for (var k = 0; k < info.rows.length; k++) {
        final row = info.rows[k];
        if (k > 0) y += _rowGap;
        final ico = switch (row.icon) {
          'cal' => cardIcoCal,
          'won' => cardIcoWon,
          _ => cardIcoPin,
        };
        ico(c, ix, y + (_rowLh - _rowIcon) / 2, _rowIcon, ShareCard.brown);
        for (var i = 0; i < row.lines.length; i++) {
          cardText(
            c,
            row.lines[i],
            st,
            ix + _rowIcon + 20,
            y + _rowLh / 2 + i * _rowLh,
            middle: true,
          );
        }
        y += row.h;
      }
    }
  }

  @override
  bool shouldRepaint(covariant StoryCardPainter old) =>
      old.data != data || old.logo != logo || old.format != format;
}
