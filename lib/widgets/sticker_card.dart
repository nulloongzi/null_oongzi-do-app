// sticker_card.dart — 릴스 프레임: 9:16(1080×1920) 투명 PNG. 아래엔 진짜 상세 시트가 올라온 듯한
// 바텀시트, 오른쪽 위엔 누룽지도 로고만. 지도 앱 바텀시트에 인증샷을 합성하던 유행에서 착안했다.
// 시트는 화면 너비 꽉, 아래는 프레임 끝까지(둥근 건 위 모서리뿐), 내용은 프레임 아래로 잘려 나간다.
// 유입 장치(QR·링크·문구)는 넣지 않는다 — 시트와 로고만 보고 궁금하게 만드는 노출용.
// 모양은 접힌 상세 시트(map_detail_panel · detail_sheet)를 3배(360dp → 1080)로 옮겼다.
// 앱 전용(릴스는 폰에서 만든다). 규격은 웹 레포 docs/design-system.md §7-6.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';
import '../services/i18n.dart';
import '../services/schedule_parse.dart';
import '../services/target_parse.dart' show targetTagParts;
import '../theme.dart';
import 'share_card_kit.dart';
import 'story_card.dart';

class FrameBanner {
  final String badge;
  final String desc;
  final String msg;
  const FrameBanner(this.badge, this.desc, this.msg);
}

class FrameAction {
  final String label;
  final Color bg, fg;
  const FrameAction(this.label, this.bg, this.fg);
}

const _grayBtnBg = Color(0xFFECEFF1), _grayBtnFg = Color(0xFF455A64);

class StickerData {
  final String title;
  final bool verified;
  final bool insta, home;
  final FrameBanner? urgent; // 제목 위 (급구 · 픽업 이번주)
  final FrameBanner? recruit; // 일정 아래 (식구 모집)
  final String schedule; // 요약 한 줄 "토요일 PM 1:00 ~ PM 5:00"
  final List<String> tags;
  final String fee;
  final String address;
  final List<FrameAction> actions;

  const StickerData({
    required this.title,
    this.verified = false,
    this.insta = false,
    this.home = false,
    this.urgent,
    this.recruit,
    this.schedule = '',
    this.tags = const [],
    this.fee = '',
    this.address = '',
    this.actions = const [],
  });

  static List<FrameAction> _actions(String? address, double? lat) => [
    if ((address ?? '').isNotEmpty)
      FrameAction(stripEmoji(t('copy_address')), _grayBtnBg, _grayBtnFg),
    if (lat != null)
      FrameAction(
        stripEmoji(t('directions_btn')),
        NurungjiColors.yellow,
        NurungjiColors.dark,
      ),
    FrameAction(stripEmoji(t('share_link')), _grayBtnBg, _grayBtnFg),
  ];

  static String _summary(List? raw, String? text) {
    final ev = (raw != null && raw.isNotEmpty)
        ? eventsFromRaw(raw)
        : eventsFromText(text);
    return ev.isNotEmpty
        ? scheduleSummary(ev)
        : stripEmoji(i18nSchedule(text ?? ''));
  }

  factory StickerData.fromClub(Club c) {
    final parts = targetTagParts(c.target);
    return StickerData(
      title: c.name.isEmpty ? t('card_title_fallback') : c.name,
      verified: c.isVerified,
      insta: (c.insta ?? '').isNotEmpty,
      home: (c.link ?? '').isNotEmpty,
      urgent: c.urgentActive
          ? FrameBanner(
              stripEmoji(t('urgent')),
              t('ug_badge_desc'),
              stripEmoji(c.urgentMsg),
            )
          : null,
      recruit: c.recruitingActive
          ? FrameBanner(
              stripEmoji(t('rc_badge')),
              t('rc_badge_desc'),
              stripEmoji(c.recruitMsg),
            )
          : null,
      schedule: _summary(c.scheduleRaw, c.schedule),
      tags: [...parts.words.map((w) => '#${i18nTarget(w)}'), ...parts.notes],
      fee: stripEmoji(i18nPrice(c.price)),
      address: c.address ?? '',
      actions: _actions(c.address, c.lat),
    );
  }

  factory StickerData.fromSpot(PickupSpot s) {
    final week = stripEmoji(s.thisWeek);
    return StickerData(
      title: s.title,
      insta: (s.insta ?? '').isNotEmpty,
      urgent: week.isNotEmpty ? FrameBanner(t('this_week'), '', week) : null,
      schedule: _summary(s.scheduleRaw, s.schedule ?? s.scheduleText),
      tags: [for (final x in StoryCardData.fromSpot(s).tags) x.text],
      fee: stripEmoji(i18nPrice(s.feeInfo)),
      address: s.address ?? '',
      actions: _actions(s.address, s.lat),
    );
  }
}

// ── 규격 (design-system §7-6) ──────────────────────────────────────
const frameW = 1080.0, frameH = 1920.0;
// 시트 윗단 = 1920 × 0.64. 앱 접힌 시트(화면 42%)에서 손잡이·펼침 힌트 자리만큼 낮췄다 —
// 프레임에선 끌어 올릴 수 없으니 둘 다 뺀다. 보이는 내용(제목·일정·띠…)은 그대로.
const frameTop = 1229.0;
// 시트 안 숫자는 dp × 3 으로 적고, 그릴 때 _k 로 줄여 dp × 2.625 가 되게 한다.
// 1080px 폰은 대개 너비 411dp(밀도 2.625) — ×3(360dp 폰)으로 그리면 실제 캡처보다 글자가 15% 컸다.
const _k = 2.625 / 3;
const _vw = frameW / _k, _vh = frameH / _k; // 줄이기 전 좌표계의 프레임 크기
const _r = 84.0; // 시트 위 모서리 (28dp)
const _pad = 66.0; // 시트 안 좌우 여백 (22dp)
const _iw = _vw - _pad * 2;
const _urgentBg = Color(0xFFFFF3E0), _recruitBg = Color(0xFFE8F5E9);
const _recruitInk = Color(0xFF2E7D32);

// ── 시트 아이콘 (캔버스 안 이모지 금지 — 앱 캔버스에선 □로 깨진다) ──
void _verified(Canvas c, double cx, double cy, double r) {
  final p = Paint()..color = const Color(0xFF1DA1F2);
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    c.drawCircle(
      Offset(cx + math.cos(a) * r * 0.62, cy + math.sin(a) * r * 0.62),
      r * 0.38,
      p,
    );
  }
  c.drawCircle(Offset(cx, cy), r * 0.8, p);
  c.drawPath(
    Path()
      ..moveTo(cx - r * 0.38, cy + r * 0.02)
      ..lineTo(cx - r * 0.1, cy + r * 0.3)
      ..lineTo(cx + r * 0.42, cy - r * 0.28),
    cardStroke(Colors.white, r * 0.2),
  );
}

void _insta(Canvas c, double x, double y, double s) {
  c.drawRRect(
    cardRRect(x, y, s, s, s * 0.29),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(x, y + s),
        Offset(x + s, y),
        const [
          Color(0xFFFEDA75),
          Color(0xFFFA7E1E),
          Color(0xFFD62976),
          Color(0xFF962FBF),
          Color(0xFF4F5BD5),
        ],
        const [0, 0.25, 0.5, 0.75, 1],
      ),
  );
  final st = cardStroke(Colors.white, s * 0.07);
  c.drawRRect(
    cardRRect(x + s * 0.24, y + s * 0.3, s * 0.52, s * 0.42, s * 0.08),
    st,
  );
  c.drawCircle(Offset(x + s / 2, y + s * 0.51), s * 0.11, st);
}

void _home(Canvas c, double x, double y, double s) {
  c.drawRRect(
    cardRRect(x, y, s, s, s * 0.29),
    Paint()..color = NurungjiColors.chipBg,
  );
  final p = Paint()..color = NurungjiColors.brown;
  c.drawPath(
    Path()
      ..moveTo(x + s * 0.5, y + s * 0.22)
      ..lineTo(x + s * 0.8, y + s * 0.5)
      ..lineTo(x + s * 0.2, y + s * 0.5)
      ..close(),
    p,
  );
  c.drawRect(Rect.fromLTWH(x + s * 0.28, y + s * 0.48, s * 0.44, s * 0.3), p);
  c.drawRect(
    Rect.fromLTWH(x + s * 0.44, y + s * 0.6, s * 0.12, s * 0.18),
    Paint()..color = NurungjiColors.chipBg,
  );
}

void _bento(Canvas c, double x, double y, double s) {
  final h = s * 0.8, top = y + (s - h) / 2;
  c.drawRRect(
    cardRRect(x, top, s, h, s * 0.14),
    Paint()..color = const Color(0xFF5D4037),
  );
  final p = s * 0.08, iw = s - p * 2, ih = h - p * 2, gx = x + p, gy = top + p;
  void box(double bx, double by, double bw, double bh, Color col) =>
      c.drawRRect(cardRRect(bx, by, bw, bh, s * 0.05), Paint()..color = col);
  box(gx, gy, iw * 0.48, ih, const Color(0xFFFFFDF8));
  box(gx + iw * 0.54, gy, iw * 0.46, ih * 0.46, const Color(0xFFE57373));
  box(
    gx + iw * 0.54,
    gy + ih * 0.54,
    iw * 0.2,
    ih * 0.46,
    const Color(0xFF81C784),
  );
  box(
    gx + iw * 0.8,
    gy + ih * 0.54,
    iw * 0.2,
    ih * 0.46,
    const Color(0xFFFFD54F),
  );
}

/// 배지 알약 + 설명·문구 상자. 반환: 상자 높이.
double _banner(
  Canvas c,
  double x,
  double y,
  double w,
  FrameBanner b,
  Color bg,
  Color badgeBg,
) {
  final bst = cardStyle(33, FontWeight.w800, Colors.white);
  final bw = cardMeasure(b.badge, bst) + 48;
  const bh = 58.0;
  final cx = x + 36 + bw + 24, cw = w - (cx - x) - 36;
  final dst = cardStyle(36, FontWeight.w500, NurungjiColors.brown);
  final mst = cardStyle(40.5, FontWeight.w700, NurungjiColors.dark);
  final desc = b.desc.isEmpty ? <String>[] : cardWrapWords(b.desc, dst, cw, 2);
  final msg = b.msg.isEmpty ? <String>[] : cardWrapWords(b.msg, mst, cw, 2);
  final colH =
      desc.length * 47.0 +
      (desc.isNotEmpty && msg.isNotEmpty ? 6 : 0) +
      msg.length * 53.0;
  final inner = math.max(bh, colH);
  c.drawRRect(cardRRect(x, y, w, 54 + inner, 36), Paint()..color = bg);
  final by = y + 27 + (inner - bh) / 2;
  c.drawRRect(cardRRect(x + 36, by, bw, bh, bh / 2), Paint()..color = badgeBg);
  cardText(c, b.badge, bst, x + 60, by + bh / 2 + 1, middle: true);
  var ty = y + 27 + (inner - colH) / 2;
  for (final l in desc) {
    cardText(c, l, dst, cx, ty + 4);
    ty += 47;
  }
  if (desc.isNotEmpty && msg.isNotEmpty) ty += 6;
  for (final l in msg) {
    cardText(c, l, mst, cx, ty + 4);
    ty += 53;
  }
  return 54 + inner;
}

typedef _Ico = void Function(Canvas, double, double, double, Color);

/// 아이콘 + 글 줄(일정 · 회비 · 주소). 반환: 줄 높이.
double _row(Canvas c, double x, double y, double w, _Ico icon, String text) {
  final st = cardStyle(46.5, FontWeight.w400, NurungjiColors.dark);
  final lines = cardWrapWords(text, st, w - 81, 2);
  icon(c, x, y + 8, 51, NurungjiColors.brown);
  for (var i = 0; i < lines.length; i++) {
    cardText(c, lines[i], st, x + 81, y + 6 + i * 65);
  }
  return lines.length * 65.0;
}

/// 각 칸 윗단 y (테스트용).
class FrameLayout {
  final double title;
  final double? urgent, schedule, recruit, tags, fee, address, actions;
  final Rect logo;
  const FrameLayout({
    required this.title,
    required this.logo,
    this.urgent,
    this.schedule,
    this.recruit,
    this.tags,
    this.fee,
    this.address,
    this.actions,
  });
}

/// 시트를 그린다. 프레임 밖(1920 아래)으로 넘친 건 이미지 크기에서 잘린다 — 접힌 시트 그대로.
FrameLayout paintFrame(Canvas c, StickerData d, ui.Image? logo) {
  const x = _pad, top = frameTop / _k;
  c.save();
  c.scale(_k);
  // 시트 판: 위 모서리만 둥글고 아래는 프레임 끝까지
  final sheet = RRect.fromRectAndCorners(
    const Rect.fromLTWH(0, top, _vw, _vh - top),
    topLeft: const Radius.circular(_r),
    topRight: const Radius.circular(_r),
  );
  c.drawRRect(
    sheet.shift(const Offset(0, -18)),
    Paint()
      ..color = const Color.fromRGBO(93, 64, 55, 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42),
  );
  c.drawRRect(sheet, Paint()..color = Colors.white);
  var y = top + 72; // 위 여백 24dp

  double? urgentY, schedY, recruitY, tagsY, feeY, addrY, actY;
  if (d.urgent != null) {
    y += 24;
    urgentY = y;
    y +=
        _banner(c, x, y, _iw, d.urgent!, _urgentBg, NurungjiColors.urgentInk) +
        36;
  }
  // 제목 줄: 인증 배지 · 이름 · 인스타 · 홈 · 도시락
  final titleY = y;
  final icons = <void Function(Canvas, double, double, double)>[
    if (d.insta) _insta,
    if (d.home) _home,
    _bento,
  ];
  final iconsW = icons.length * (72.0 + 18);
  final nx = x + (d.verified ? 84 : 0);
  final tst = cardStyle(61.5, FontWeight.w800, NurungjiColors.dark);
  final name = cardWrapWords(d.title, tst, _iw - (nx - x) - iconsW, 2);
  final rowH = math.max(72.0, name.length * 74.0);
  if (d.verified) _verified(c, x + 33, y + math.min(rowH, 74) / 2, 33);
  for (var i = 0; i < name.length; i++) {
    cardText(c, name[i], tst, nx, y + i * 74 + 6);
  }
  var ix = _vw - _pad - 72;
  final iy = y + (rowH - 72) / 2;
  for (final ico in icons.reversed) {
    ico(c, ix, iy, 72);
    ix -= 72 + 18;
  }
  y += rowH + 12;

  if (d.schedule.isNotEmpty) {
    y += 36;
    schedY = y;
    y += _row(c, x, y, _iw, cardIcoCal, d.schedule);
  }
  if (d.recruit != null) {
    y += 30;
    recruitY = y;
    y += _banner(c, x, y, _iw, d.recruit!, _recruitBg, _recruitInk);
  }
  if (d.tags.isNotEmpty) {
    y += 36;
    tagsY = y;
    final st = cardStyle(34.5, FontWeight.w600, NurungjiColors.chipFg);
    var cx = 0.0, cy = 0.0;
    for (final tg in d.tags) {
      final w = math.min(_iw, cardMeasure(tg, st) + 54);
      if (cx + w > _iw && cx > 0) {
        cx = 0;
        cy += 71 + 18;
      }
      c.drawRRect(
        cardRRect(x + cx, y + cy, w, 71, 27),
        Paint()..color = NurungjiColors.chipBg,
      );
      cardText(
        c,
        cardWrapLines(tg, st, w - 54, 1).firstOrNull ?? '',
        st,
        x + cx + 27,
        y + cy + 36,
        middle: true,
      );
      cx += w + 18;
    }
    y += cy + 71;
  }
  if (d.fee.isNotEmpty) {
    y += 36;
    feeY = y;
    y += _row(c, x, y, _iw, cardIcoWon, d.fee);
  }
  if (d.address.isNotEmpty) {
    y += 36;
    addrY = y;
    y += _row(c, x, y, _iw, cardIcoPin, d.address);
  }
  if (d.actions.isNotEmpty) {
    y += 36;
    actY = y;
    final n = d.actions.length;
    final aw = (_iw - (n - 1) * 24) / n;
    for (var i = 0; i < n; i++) {
      final a = d.actions[i];
      final ax = x + i * (aw + 24);
      c.drawRRect(cardRRect(ax, y, aw, 113, 36), Paint()..color = a.bg);
      final st = cardStyle(39, FontWeight.w700, a.fg);
      cardText(
        c,
        cardWrapLines(a.label, st, aw - 30, 1).firstOrNull ?? '',
        st,
        ax + aw / 2,
        y + 57,
        align: TextAlign.center,
        middle: true,
      );
    }
  }
  c.restore();

  // 오른쪽 위 로고 알약 — 이름표 하나뿐. 인스타 상단 UI(진행 바·프로필 줄) 아래.
  final brand = t('brand');
  final bst = cardStyle(30, FontWeight.w800, ShareCard.ink);
  final pw = 10 + 48 + 12 + cardMeasure(brand, bst) + 26;
  const ph = 68.0, py = 250.0;
  final px = frameW - 64 - pw;
  cardPill(c, px, py, pw, ph);
  final center = Offset(px + 10 + 24, py + ph / 2);
  if (logo != null) {
    cardLogoCircle(c, logo, center, 24);
  } else {
    cardVolley(c, center.dx, center.dy, 17, ShareCard.yellow);
  }
  cardText(c, brand, bst, px + 10 + 48 + 12, py + ph / 2 + 1, middle: true);

  double? k(double? v) => v == null ? null : v * _k; // 프레임 좌표로
  return FrameLayout(
    title: titleY * _k,
    urgent: k(urgentY),
    schedule: k(schedY),
    recruit: k(recruitY),
    tags: k(tagsY),
    fee: k(feeY),
    address: k(addrY),
    actions: k(actY),
    logo: Rect.fromLTWH(px, py, pw, ph),
  );
}

/// 배치만 계산(테스트용) — 버려지는 캔버스에 그린다.
FrameLayout stickerLayout(StickerData d) =>
    paintFrame(Canvas(ui.PictureRecorder()), d, null);

/// 9:16 투명 프레임 PNG (1080×1920).
Future<Uint8List?> renderStickerPng(StickerData d) async {
  final logo = await loadBrandLogo();
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, const Rect.fromLTWH(0, 0, frameW, frameH));
  c.clipRect(const Rect.fromLTWH(0, 0, frameW, frameH));
  paintFrame(c, d, logo);
  final img = await rec.endRecording().toImage(frameW.round(), frameH.round());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}
