// share_card_kit.dart — 공유 카드 공용 키트. 팀·픽업 카드(story_card.dart)와
// 내 카드(my_card.dart)가 같은 규격·토큰·머리글·스텁을 쓴다.
//
// 웹 js/share.js 의 '공유 카드 키트'를 그대로 옮겼다. 숫자는 docs/design-system.md §7 과
// 같아야 한다 — 한쪽만 바꾸면 같은 카드가 플랫폼마다 달라진다.
//
// 캔버스 안에는 이모지를 쓰지 않는다: dart:ui Canvas 에서 이모지는 □(tofu)로 깨진다.
// 아이콘은 여기 벡터로 그리고, 칩·라벨 문구는 [stripEmoji] 로 이모지를 뺀다.
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/i18n.dart';
import '../services/share_service.dart';

/// 공유 카드 규격.
enum CardFormat { story, feed }

class CardFmt {
  final double h; // 캔버스 높이 (폭은 항상 1080)
  final double top; // 위 안전영역 — 글·로고는 이 안쪽에
  final double bottom; // 아래 안전영역 — QR은 이 위에
  final double qr; // QR 한 변
  const CardFmt(this.h, this.top, this.bottom, this.qr);
}

class ShareCard {
  static const w = 1080.0;
  static const m = 80.0; // 좌우 여백 → 본문 폭 920
  static const bodyW = w - m * 2;

  // 스토리: 위는 프로필·진행바, 아래는 답장바가 덮는다(인스타 UI) → 글·QR은 250 안쪽에.
  // 그 띠를 비워두지 않는다 — 위는 히어로(지도·밥색), 아래는 티켓 스텁이 채운다.
  static const story = CardFmt(1920, 250, 250, 172);
  // 피드 3:4: 인스타 피드·그리드가 3:4를 그대로 보여준다(2025~). 덮는 UI가 없다.
  static const feed = CardFmt(1440, 72, 72, 148);
  static CardFmt of(CardFormat f) => f == CardFormat.feed ? feed : story;

  static const headerH = 64.0; // 머리글 알약 높이
  static const overlap = 72.0; // 본문 카드가 히어로 아랫단을 덮는 깊이
  static const gap = 32.0; // 블록 사이
  static const stubPad = 36.0; // 스텁 절취선 ↔ QR 타일

  /// 스텁 윗단(절취선) y. QR 타일 아래끝이 아래 안전선에 닿게 놓는다.
  static double stubTop(CardFmt f) => f.h - f.bottom - (stubPad + f.qr + 20);

  static const cream = Color(0xFFFBF3E2);
  static const card = Color(0xFFFFFDF8);
  static const ink = Color(0xFF3D2C22);
  static const dark = Color(0xFF4E342E);
  static const brown = Color(0xFF8D6E63);
  static const sub = Color(0xFFA99A8C);
  static const yellow = Color(0xFFFAC710);
  static const teal = Color(0xFF12A89E);
  static const hair = Color(0x478D6E63); // rgba(141,110,99,.28)
  static const qrInk = Color(0xFF1C140D);
}

// ── 글자 ─────────────────────────────────────────────────────────

TextStyle cardStyle(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: 'Pretendard',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1.2,
);

TextPainter _tp(String text, TextStyle st) => TextPainter(
  text: TextSpan(text: text, style: st),
  textDirection: TextDirection.ltr,
  maxLines: 1,
)..layout();

double cardMeasure(String text, TextStyle st) => _tp(text, st).width;

/// 한 줄 텍스트. [align] 기준으로 x 를 해석하고, [middle] 이면 y 가 글줄 가운데.
/// 아니면 y 가 글자 네모(em box) 윗단 — 웹 캔버스 textBaseline='top' 과 같은 자리.
void cardText(
  Canvas c,
  String text,
  TextStyle st,
  double x,
  double y, {
  TextAlign align = TextAlign.left,
  bool middle = false,
}) {
  if (text.isEmpty) return;
  final tp = _tp(text, st);
  final dx = align == TextAlign.center
      ? x - tp.width / 2
      : (align == TextAlign.right ? x - tp.width : x);
  final fs = st.fontSize ?? 14;
  final dy = middle ? y - tp.height / 2 : y - (tp.height - fs) / 2;
  tp.paint(c, Offset(dx, dy));
}

/// 글자 단위 줄바꿈 + 넘치면 … (웹 storyWrapLines 와 같은 규칙).
List<String> cardWrapLines(
  String? text,
  TextStyle st,
  double maxW,
  int maxLines,
) {
  final chars = (text ?? '').characters.toList();
  final lines = <String>[];
  var cur = '';
  var truncated = false;
  for (final ch in chars) {
    if (cur.isNotEmpty && cardMeasure(cur + ch, st) > maxW) {
      lines.add(cur);
      cur = ch;
      if (lines.length == maxLines) {
        truncated = true;
        break;
      }
    } else {
      cur += ch;
    }
  }
  if (!truncated && cur.isNotEmpty && lines.length < maxLines) lines.add(cur);
  if (truncated && lines.isNotEmpty) {
    var last = lines.last;
    while (last.isNotEmpty && cardMeasure('$last…', st) > maxW) {
      final cs = last.characters.toList()..removeLast();
      last = cs.join();
    }
    lines[lines.length - 1] = '$last…';
  }
  return lines;
}

/// 한 줄 말줄임.
String cardEllip(String text, TextStyle st, double maxW) {
  if (cardMeasure(text, st) <= maxW) return text;
  var cs = text.characters.toList();
  while (cs.length > 1 && cardMeasure('${cs.join()}…', st) > maxW) {
    cs = cs..removeLast();
  }
  return '${cs.join()}…';
}

/// 공백이 있으면 단어 경계 우선으로 접는다(웹 my-card.js wrapWords).
/// 없으면(붙여 쓴 한글) 글자 단위 — "월요 리시브반"이 "월요 리 / 시브반"이 되지 않게.
List<String> cardWrapWords(
  String text,
  TextStyle st,
  double maxW,
  int maxLines,
) {
  final words = text.split(' ');
  if (words.length < 2) return cardWrapLines(text, st, maxW, maxLines);
  final lines = <String>[];
  var cur = '';
  for (final w in words) {
    final cand = cur.isEmpty ? w : '$cur $w';
    if (cardMeasure(cand, st) <= maxW) {
      cur = cand;
      continue;
    }
    if (cur.isNotEmpty) lines.add(cur);
    cur = w;
    if (lines.length >= maxLines) break;
  }
  if (cur.isNotEmpty && lines.length < maxLines) lines.add(cur);
  final out = lines.length > maxLines ? lines.sublist(0, maxLines) : lines;
  if (out.isNotEmpty) out[out.length - 1] = cardEllip(out.last, st, maxW);
  return out;
}

/// 폭에 맞을 때까지 글자를 줄인다(밥이름은 말줄임보다 축소가 낫다). 맞춘 크기를 돌려준다.
double cardFit(
  String text,
  double maxW,
  double size,
  double min,
  FontWeight w,
) {
  for (var s = size; s > min; s -= 2) {
    if (cardMeasure(text, cardStyle(s, w, ShareCard.ink)) <= maxW) return s;
  }
  return min;
}

final _emoji = RegExp(
  r'(?:[\u{1F000}-\u{1FAFF}]|[\u{2600}-\u{27BF}]|\u{FE0F}|\u{200D})',
  unicode: true,
);

/// 이모지를 뺀다 — 캔버스 안에서는 □로 깨진다. (웹 storyStripEmoji 와 같은 범위)
String stripEmoji(String? s) =>
    (s ?? '').replaceAll(_emoji, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();

// ── 도형 ─────────────────────────────────────────────────────────

RRect cardRRect(double x, double y, double w, double h, double r) =>
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

/// 그림자 두 단계만 쓴다 — 카드(큰 것)와 알약·QR 타일(작은 것).
/// 웹 shadowBlur(≈2σ) 32/16, offsetY 8/4, 알파 .15/.12 와 같은 값.
void cardShadow(Canvas c, Path p, {bool small = false}) {
  c.drawPath(
    p.shift(Offset(0, small ? 4 : 8)),
    Paint()
      ..color = Color.fromRGBO(93, 64, 55, small ? 0.12 : 0.15)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, small ? 8 : 16),
  );
}

void cardBackground(Canvas c, double h) {
  c.drawRect(
    Rect.fromLTWH(0, 0, ShareCard.w, h),
    Paint()..color = ShareCard.cream,
  );
}

/// 알약 하나(흰 바탕 + 작은 그림자). 머리글·지역·역 표시가 같은 모양을 쓴다.
void cardPill(Canvas c, double x, double y, double w, double h) {
  final rr = cardRRect(x, y, w, h, h / 2);
  cardShadow(c, Path()..addRRect(rr), small: true);
  c.drawRRect(rr, Paint()..color = Colors.white);
}

/// 흰 판(본문 카드). 모서리 28 + 큰 그림자.
void cardPanel(Canvas c, Rect r, {Color color = ShareCard.card}) {
  final rr = RRect.fromRectAndRadius(r, const Radius.circular(28));
  cardShadow(c, Path()..addRRect(rr));
  c.drawRRect(rr, Paint()..color = color);
}

/// 로고를 원 안에 그린다.
void cardLogoCircle(Canvas c, ui.Image logo, Offset center, double r) {
  c.save();
  c.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));
  c.drawImageRect(
    logo,
    Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
    Rect.fromCircle(center: center, radius: r),
    Paint()..filterQuality = FilterQuality.high,
  );
  c.restore();
}

/// 머리글: 흰 알약 안에 로고 44 + 워드마크 30/800. 히어로(지도·밥색) 위에 얹혀도 읽힌다.
/// [right]: 같은 줄 오른쪽 끝 알약(지역 등, 선택).
void cardHeader(Canvas c, double y, ui.Image? logo, {String? right}) {
  const h = ShareCard.headerH, m = ShareCard.m;
  final brand = t('brand');
  final st = cardStyle(30, FontWeight.w800, ShareCard.ink);
  final w = 10 + 44 + 14 + cardMeasure(brand, st) + 26;
  cardPill(c, m, y, w, h);
  final center = Offset(m + 10 + 22, y + h / 2);
  if (logo != null) {
    cardLogoCircle(c, logo, center, 22);
  } else {
    cardVolley(c, center.dx, center.dy, 15, ShareCard.yellow);
  }
  cardText(c, brand, st, m + 10 + 44 + 14, y + h / 2 + 1, middle: true);
  if (right != null && right.isNotEmpty) {
    final rst = cardStyle(28, FontWeight.w700, ShareCard.ink);
    final maxW = ShareCard.w - m * 2 - w - 24;
    final txt = cardWrapLines(right, rst, maxW - 80, 1).firstOrNull ?? '';
    final rw = cardMeasure(txt, rst) + 80, rx = ShareCard.w - m - rw;
    cardPill(c, rx, y, rw, h);
    cardIcoPin(c, rx + 20, y + 17, 30, ShareCard.brown);
    cardText(c, txt, rst, rx + 58, y + h / 2 + 1, middle: true);
  }
}

/// 스텁 푸터: 전폭 패널 + 절취선(양끝 반원 홈 + 점선) + QR 타일 + SCAN · CTA · URL.
/// 스토리는 링크가 안 걸리는 매체라 QR이 유일한 유입 경로 — 표 한 장을 떼어 가는 은유.
void cardStub(Canvas c, CardFmt fmt, String url, String cta) {
  const m = ShareCard.m, w = ShareCard.w;
  final q = fmt.qr, top = ShareCard.stubTop(fmt);
  final panel = Rect.fromLTWH(0, top, w, fmt.h - top);
  c.drawRect(
    panel.shift(const Offset(0, -4)),
    Paint()
      ..color = const Color.fromRGBO(93, 64, 55, 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
  );
  c.drawRect(panel, Paint()..color = ShareCard.card);
  // 홈: 배경색 반원으로 파낸다
  final notch = Paint()..color = ShareCard.cream;
  c.drawCircle(Offset(0, top), 22, notch);
  c.drawCircle(Offset(w, top), 22, notch);
  final dash = Paint()
    ..color = ShareCard.hair
    ..strokeWidth = 3;
  for (var x = 40.0; x < w - 40; x += 26) {
    c.drawLine(Offset(x, top), Offset(math.min(x + 14, w - 40), top), dash);
  }

  final tileY = top + ShareCard.stubPad;
  final tile = cardRRect(m, tileY, q + 20, q + 20, 18);
  cardShadow(c, Path()..addRRect(tile), small: true);
  c.drawRRect(tile, Paint()..color = Colors.white);
  // QR 로 들어온 사람을 따로 센다(포장하기·팀 카드 = 떠나는 사람이 건네주는 물건). 인쇄 글자는 원래 url.
  cardQr(c, ShareService.withUtm(url, 'card_qr'), m + 10, tileY + 10, q);

  final tx = m + q + 20 + 40, tw = w - m - tx;
  final ctaSt = cardStyle(34, FontWeight.w800, ShareCard.ink);
  final ctaLines = cardWrapLines(cta, ctaSt, tw, 2);
  final blockH = 30 + ctaLines.length * 42 + 8 + 30; // SCAN + CTA + URL
  var y = tileY + (q + 20 - blockH) / 2;
  cardText(c, 'S C A N', cardStyle(22, FontWeight.w700, ShareCard.sub), tx, y);
  y += 30;
  for (final l in ctaLines) {
    cardText(c, l, ctaSt, tx, y);
    y += 42;
  }
  y += 8;
  final urlSt = cardStyle(26, FontWeight.w500, ShareCard.brown);
  final shown = url
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceFirst(RegExp(r'/$'), '');
  cardText(
    c,
    cardWrapLines(shown, urlSt, tw, 1).firstOrNull ?? '',
    urlSt,
    tx,
    y,
  );
}

/// QR. 웹 qrcode-generator 처럼 둘레에 4모듈 여백(quiet zone)을 두고 그린다 —
/// QrPainter 는 여백 없이 꽉 채워서, 그대로 두면 앱 QR만 한 치수 크게 보였다.
void cardQr(Canvas c, String url, double x, double y, double size) {
  try {
    final v = QrValidator.validate(
      data: url,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
    final code = v.qrCode;
    if (!v.isValid || code == null) return;
    final cell = size / (code.moduleCount + 8);
    final qr = QrPainter.withQr(
      qr: code,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: ShareCard.qrInk,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: ShareCard.qrInk,
      ),
    );
    c.save();
    c.translate(x + cell * 4, y + cell * 4);
    qr.paint(c, Size.square(cell * code.moduleCount));
    c.restore();
  } catch (_) {}
}

// ── 벡터 아이콘 (웹과 같은 획) ───────────────────────────────────

Paint cardStroke(Color c, double lw) => Paint()
  ..style = PaintingStyle.stroke
  ..color = c
  ..strokeWidth = lw
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

void cardVolley(Canvas c, double cx, double cy, double r, Color col) {
  final p = cardStroke(col, r * 0.14);
  c.drawCircle(Offset(cx, cy), r, p);
  // 웹 ctx.arc(x, y, r, a0, a1) 와 같은 호: 시작각 a0, 시계 방향 a1-a0
  void arc(double x, double y, double a0, double a1) => c.drawArc(
    Rect.fromCircle(center: Offset(x, y), radius: r * 1.1),
    a0,
    a1 - a0,
    false,
    p,
  );
  arc(cx - r * 0.2, cy - r * 0.1, -0.5, 0.7);
  arc(cx + r * 0.5, cy + r * 0.6, 3.3, 4.4);
  arc(cx - r * 0.4, cy + r * 0.7, 1.5, 2.6);
}

void cardIcoCal(Canvas c, double x, double y, double s, Color col) {
  final p = cardStroke(col, s * 0.08);
  c.drawRRect(
    cardRRect(x + s * 0.1, y + s * 0.16, s * 0.8, s * 0.72, s * 0.13),
    p,
  );
  c.drawLine(
    Offset(x + s * 0.1, y + s * 0.36),
    Offset(x + s * 0.9, y + s * 0.36),
    p,
  );
  c.drawLine(
    Offset(x + s * 0.32, y + s * 0.06),
    Offset(x + s * 0.32, y + s * 0.24),
    p,
  );
  c.drawLine(
    Offset(x + s * 0.68, y + s * 0.06),
    Offset(x + s * 0.68, y + s * 0.24),
    p,
  );
}

void cardIcoWon(Canvas c, double x, double y, double s, Color col) {
  final p = cardStroke(col, s * 0.08);
  c.drawCircle(Offset(x + s / 2, y + s / 2), s * 0.4, p);
  // ₩ 를 선으로: W 한 획 + 가로줄 (글꼴에 기대지 않는다)
  c.drawPath(
    Path()
      ..moveTo(x + s * 0.3, y + s * 0.32)
      ..lineTo(x + s * 0.39, y + s * 0.68)
      ..lineTo(x + s * 0.5, y + s * 0.42)
      ..lineTo(x + s * 0.61, y + s * 0.68)
      ..lineTo(x + s * 0.7, y + s * 0.32),
    p,
  );
  c.drawLine(
    Offset(x + s * 0.28, y + s * 0.47),
    Offset(x + s * 0.72, y + s * 0.47),
    p,
  );
}

void cardIcoPin(Canvas c, double x, double y, double s, Color col) {
  final p = cardStroke(col, s * 0.08);
  final cx = x + s / 2, cy = y + s * 0.4, r = s * 0.28;
  // 웹: arc(0.85π → 0.15π, 반시계 아님=시계) 후 꼭짓점으로
  final path = Path()
    ..addArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      math.pi * 0.85,
      math.pi * 1.3,
    )
    ..lineTo(cx, y + s * 0.9)
    ..close();
  c.drawPath(path, p);
  c.drawCircle(Offset(cx, cy), s * 0.11, p);
}

void cardIcoSub(Canvas c, double x, double y, double s, Color col) {
  final p = cardStroke(col, s * 0.08);
  c.drawRRect(
    cardRRect(x + s * 0.18, y + s * 0.12, s * 0.64, s * 0.6, s * 0.16),
    p,
  );
  c.drawLine(
    Offset(x + s * 0.18, y + s * 0.44),
    Offset(x + s * 0.82, y + s * 0.44),
    p,
  );
  final dot = Paint()..color = col;
  c.drawCircle(Offset(x + s * 0.34, y + s * 0.58), s * 0.05, dot);
  c.drawCircle(Offset(x + s * 0.66, y + s * 0.58), s * 0.05, dot);
  c.drawLine(
    Offset(x + s * 0.3, y + s * 0.74),
    Offset(x + s * 0.22, y + s * 0.9),
    p,
  );
  c.drawLine(
    Offset(x + s * 0.7, y + s * 0.74),
    Offset(x + s * 0.78, y + s * 0.9),
    p,
  );
}

void cardCheckBadge(Canvas c, double cx, double cy, double r) {
  c.drawCircle(Offset(cx, cy), r, Paint()..color = ShareCard.teal);
  c.drawPath(
    Path()
      ..moveTo(cx - r * 0.45, cy)
      ..lineTo(cx - r * 0.13, cy + r * 0.36)
      ..lineTo(cx + r * 0.5, cy - r * 0.36),
    cardStroke(Colors.white, r * 0.23),
  );
}
