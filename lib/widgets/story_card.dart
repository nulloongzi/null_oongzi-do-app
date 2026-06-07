// story_card.dart — 9:16 인스타 스토리 카드 (1080×1920). 웹 share.js generateStoryCard 포팅.
// dart:ui Canvas로 직접 그려 PNG로 내보낸다(위젯 트리/RepaintBoundary 불필요·결정적).
// C 미감: 따뜻한 누룽지 그라데이션+밥알 텍스처 + 일러스트 지도패널(핀) + 정보카드 + QR + CTA.
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';
import '../services/share_service.dart';

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
  });

  factory StoryCardData.fromSpot(PickupSpot s) {
    final sportL =
        s.sport == '6s' ? '6인제' : (s.sport == '9s' ? '9인제' : '혼성·자유');
    final levelL =
        const {'beginner': '입문', 'intermediate': '중급', 'advanced': '고급'}[s.level] ??
            '레벨무관';
    final tags = <StoryTag>[
      StoryTag(sportL, const Color(0xFFFAC710), const Color(0xFF4E342E)),
      StoryTag(levelL, const Color(0xFFF0ECE2), const Color(0xFF6D6258)),
    ];
    if (s.beginnerFriendly) {
      tags.add(const StoryTag('🌱 초보환영', Color(0xFFE7F6E7), Color(0xFF2E7D32)));
    }
    if (s.englishOk) {
      tags.add(const StoryTag('🌐 English OK', Color(0xFFE6F0FB), Color(0xFF1565C0)));
    }
    return StoryCardData(
      title: s.title,
      url: ShareService.spotUrl(s.id),
      accent: const Color(0xFF13A89E),
      tags: tags,
      thisWeek: s.thisWeek,
      schedule: (s.schedule != null && s.schedule!.isNotEmpty)
          ? s.schedule
          : s.scheduleText,
      fee: s.feeInfo,
      venue: s.venueName,
      address: s.address,
    );
  }

  factory StoryCardData.fromClub(Club c) {
    final tgt = (c.target ?? '')
        .split(RegExp(r'[,\s]+'))
        .where((x) => x.isNotEmpty)
        .toList();
    final tags = <StoryTag>[];
    for (var i = 0; i < tgt.length && i < 4; i++) {
      tags.add(StoryTag(tgt[i], const Color(0xFFF0ECE2), const Color(0xFF6D6258)));
    }
    return StoryCardData(
      title: c.name,
      url: ShareService.clubUrl(c.id),
      verified: c.isVerified,
      accent: const Color(0xFFFAC710),
      tags: tags,
      schedule: c.schedule,
      fee: c.price,
      venue: '',
      address: c.address,
    );
  }
}

/// 카드를 1080×1920 PNG 바이트로 렌더. 한글 폰트 선로딩으로 tofu 방지.
Future<Uint8List?> renderStoryCardPng(StoryCardData data) async {
  try {
    await GoogleFonts.pendingFonts([GoogleFonts.notoSansKr()]);
  } catch (_) {}
  final logo = await _loadLogo();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  StoryCardPainter(data, logo: logo).paint(canvas, const Size(1080, 1920));
  final pic = recorder.endRecording();
  final img = await pic.toImage(1080, 1920);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

Future<ui.Image?> _loadLogo() async {
  try {
    final bd = await rootBundle.load('assets/nulloongzido logo_without bg.png');
    final codec = await ui.instantiateImageCodec(bd.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

class StoryCardPainter extends CustomPainter {
  final StoryCardData data;
  final ui.Image? logo;
  StoryCardPainter(this.data, {this.logo});

  static const _dark = Color(0xFF4E342E);
  static const _brown = Color(0xFF8D6E63);
  static const _yellow = Color(0xFFFAC710);

  TextStyle _st(double size, FontWeight w, Color c) =>
      GoogleFonts.notoSansKr(fontSize: size, fontWeight: w, color: c, height: 1.1);

  TextPainter _tp(String text, TextStyle style,
      {double maxWidth = double.infinity, int maxLines = 1}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    return tp;
  }

  void _rrect(Canvas c, Rect r, double radius, Paint p) =>
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), p);

  void _shadow(Canvas c, Rect r, double radius,
      {double blur = 20, double dy = 14, Color color = const Color(0x2E5D4037)}) {
    c.drawRRect(
      RRect.fromRectAndRadius(r.translate(0, dy), Radius.circular(radius)),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    const w = 1080.0, h = 1920.0, pad = 80.0;
    final accent = data.accent;

    // ── 배경: 누룽지 그라데이션 + 밥알 텍스처 ──
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(0, h),
          const [Color(0xFFFFF7E3), Color(0xFFFFE9B8), Color(0xFFF7D27E)],
          const [0.0, 0.5, 1.0],
        ),
    );
    var seed = 1234567;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    const specks = [Color(0x33D8A441), Color(0x29B47832), Color(0x38FFFFFF)];
    for (var sp = 0; sp < 520; sp++) {
      canvas.drawCircle(Offset(rnd() * w, rnd() * h), 1.5 + rnd() * 4,
          Paint()..color = specks[sp % specks.length]);
    }

    // ── 상단 브랜드 (로고 + 누룽지도) ──
    final brandTp = _tp('누룽지도', _st(58, FontWeight.w900, _dark));
    const logoSize = 92.0, gap = 26.0;
    final totalW = (logo != null ? logoSize + gap : 0) + brandTp.width;
    var gx = (w - totalW) / 2;
    const gy = 96.0;
    if (logo != null) {
      final dst = Rect.fromLTWH(gx, gy, logoSize, logoSize);
      canvas.save();
      canvas.clipPath(Path()..addOval(dst));
      canvas.drawImageRect(
        logo!,
        Rect.fromLTWH(0, 0, logo!.width.toDouble(), logo!.height.toDouble()),
        dst,
        Paint(),
      );
      canvas.restore();
      gx += logoSize + gap;
    }
    brandTp.paint(canvas, Offset(gx, gy + logoSize / 2 - brandTp.height / 2));

    // ── 위치 패널 (일러스트 지도 + 핀) ──
    const mpX = pad, mpY = 250.0, mpW = w - pad * 2, mpH = 540.0;
    final panel = const Rect.fromLTWH(mpX, mpY, mpW, mpH);
    _shadow(canvas, panel, 44, blur: 18, dy: 16);
    _rrect(canvas, panel, 44, Paint()..color = const Color(0xFFFFFAF0));
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(panel, const Radius.circular(44)));
    var bseed = 99;
    double brnd() {
      bseed = (bseed * 1103515245 + 12345) & 0x7fffffff;
      return bseed / 0x7fffffff;
    }

    for (double bx = mpX + 10; bx < mpX + mpW - 30; bx += 150) {
      for (double by = mpY + 10; by < mpY + mpH - 70; by += 120) {
        final col =
            brnd() > 0.5 ? const Color(0xFFF1E3BF) : const Color(0xFFEFE6CF);
        _rrect(
            canvas,
            Rect.fromLTWH(
                bx + brnd() * 18, by + brnd() * 14, 84 + brnd() * 46, 60 + brnd() * 34),
            12,
            Paint()..color = col);
      }
    }
    // 하천 느낌
    final river = Path()
      ..moveTo(mpX, mpY + mpH - 60)
      ..cubicTo(mpX + mpW * 0.3, mpY + mpH - 100, mpX + mpW * 0.6, mpY + mpH - 20,
          mpX + mpW, mpY + mpH - 70)
      ..lineTo(mpX + mpW, mpY + mpH)
      ..lineTo(mpX, mpY + mpH)
      ..close();
    canvas.drawPath(river, Paint()..color = const Color(0x7396C8DC));
    canvas.restore();

    // 핀
    final pinX = mpX + mpW / 2;
    const headY = mpY + 178.0, rPin = 66.0;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(pinX, headY + 104), width: 92, height: 28),
        Paint()..color = const Color(0x1A000000));
    final pinPaint = Paint()..color = accent;
    canvas.drawPath(
        Path()
          ..moveTo(pinX - 36, headY + 22)
          ..lineTo(pinX + 36, headY + 22)
          ..lineTo(pinX, headY + 100)
          ..close(),
        pinPaint);
    canvas.drawCircle(Offset(pinX, headY), rPin, pinPaint);
    canvas.drawCircle(Offset(pinX, headY), 42, Paint()..color = Colors.white);
    final iconTp = _tp(data.icon, _st(44, FontWeight.w400, _dark));
    iconTp.paint(
        canvas, Offset(pinX - iconTp.width / 2, headY - iconTp.height / 2));

    // 지역 라벨 + 위치 칩
    final region = _region(data.address);
    if (region.isNotEmpty) {
      final rt = _tp('📍 $region', _st(26, FontWeight.w700, _brown));
      rt.paint(canvas, Offset(pinX - rt.width / 2, mpY + 34));
    }
    final chipText =
        (data.venue != null && data.venue!.isNotEmpty) ? data.venue! : region;
    if (chipText.isNotEmpty) {
      final ct = _tp(chipText, _st(34, FontWeight.w800, _dark));
      final chW = (ct.width + 56).clamp(0.0, mpW - 60);
      final chX = mpX + (mpW - chW) / 2;
      const chY = mpY + mpH - 94.0;
      _rrect(canvas, Rect.fromLTWH(chX, chY, chW, 64), 32,
          Paint()..color = Colors.white);
      ct.paint(canvas, Offset(mpX + mpW / 2 - ct.width / 2, chY + 32 - ct.height / 2));
    }

    // ── 정보 카드 ──
    const cardX = pad, cardY = 830.0, cardW = w - pad * 2, cardH = 670.0;
    final card = const Rect.fromLTWH(cardX, cardY, cardW, cardH);
    _shadow(canvas, card, 44, blur: 22, dy: 20);
    _rrect(canvas, card, 44, Paint()..color = Colors.white);
    const ix = cardX + 60, iw = cardW - 120;
    var y = cardY + 60;

    // 제목 (+인증)
    final titleTp = _tp(
      data.title.isEmpty ? '배구 모임' : data.title,
      _st(72, FontWeight.w800, _dark),
      maxWidth: iw - (data.verified ? 64 : 0),
      maxLines: 2,
    );
    titleTp.paint(canvas, Offset(ix, y));
    if (data.verified) {
      final lm = titleTp.computeLineMetrics();
      final firstW = lm.isNotEmpty ? lm.first.width : titleTp.width;
      _tp('✔', _st(46, FontWeight.w700, const Color(0xFF1DA1F2)))
          .paint(canvas, Offset(ix + firstW + 14, y + 10));
    }
    y += titleTp.height + 20;

    // 칩
    if (data.tags.isNotEmpty) {
      const chipH = 58.0, chipPad = 24.0, chipGap = 14.0;
      var cx = ix.toDouble();
      var cl = y;
      for (final t in data.tags) {
        final tt = _tp(t.text, _st(32, FontWeight.w700, t.fg));
        final cw = tt.width + chipPad * 2;
        if (cx + cw > ix + iw) {
          cx = ix.toDouble();
          cl += chipH + chipGap;
        }
        _rrect(canvas, Rect.fromLTWH(cx, cl, cw, chipH), chipH / 2,
            Paint()..color = t.bg);
        tt.paint(canvas, Offset(cx + chipPad, cl + chipH / 2 - tt.height / 2));
        cx += cw + chipGap;
      }
      y = cl + chipH + 32;
    }

    // 이번주 배너
    if (data.thisWeek != null && data.thisWeek!.isNotEmpty) {
      final twTp = _tp(data.thisWeek!, _st(34, FontWeight.w700, _dark),
          maxWidth: iw - 48, maxLines: 2);
      final bannerH = 84 + twTp.height + 18;
      _rrect(canvas, Rect.fromLTWH(ix, y, iw, bannerH), 20,
          Paint()..color = const Color(0x38FAC710));
      final badgeTp = _tp(data.thisWeekBadge, _st(28, FontWeight.w800, _dark));
      final badgeW = badgeTp.width + 32;
      _rrect(canvas, Rect.fromLTWH(ix + 22, y + 22, badgeW, 44), 22,
          Paint()..color = _yellow);
      badgeTp.paint(canvas, Offset(ix + 38, y + 44 - badgeTp.height / 2));
      twTp.paint(canvas, Offset(ix + 22, y + 84));
      y += bannerH + 30;
    }

    // 정보 행
    void infoRow(String icon, String? text, int maxLines) {
      if (text == null || text.isEmpty) return;
      final it = _tp(icon, _st(38, FontWeight.w600, _dark));
      it.paint(canvas, Offset(ix, y));
      final tt = _tp(text, _st(38, FontWeight.w600, _dark),
          maxWidth: iw - 62, maxLines: maxLines);
      tt.paint(canvas, Offset(ix + 62, y));
      y += (tt.height > it.height ? tt.height : it.height) + 14;
    }

    infoRow('🗓', data.schedule, 2);
    infoRow('💰', data.fee, 1);
    final place = (data.venue != null && data.venue!.isNotEmpty)
        ? (data.venue! +
            (data.address != null && data.address!.isNotEmpty
                ? ' · ${data.address}'
                : ''))
        : data.address;
    infoRow('📍', place, 2);

    // ── 푸터: QR + CTA ──
    const footY = 1545.0, footH = 300.0, qrSize = 250.0;
    const qrX = pad;
    const qrY = footY + (footH - qrSize) / 2;
    _shadow(canvas, Rect.fromLTWH(qrX - 16, qrY - 16, qrSize + 32, qrSize + 32), 24,
        blur: 12, dy: 8, color: const Color(0x1F000000));
    _rrect(canvas, Rect.fromLTWH(qrX - 16, qrY - 16, qrSize + 32, qrSize + 32), 24,
        Paint()..color = Colors.white);
    _drawQr(canvas, data.url, qrX, qrY, qrSize);

    final tx = qrX + qrSize + 56;
    final twf = w - pad - tx;
    final ctaTp = _tp('이 팀, 어때요? 지도에서 보기 👀',
        _st(48, FontWeight.w800, _dark),
        maxWidth: twf, maxLines: 2);
    ctaTp.paint(canvas, Offset(tx, footY + 60));
    final urlStr = data.url.replaceFirst(RegExp(r'^https?://'), '');
    _tp(urlStr, _st(28, FontWeight.w600, _brown), maxWidth: twf, maxLines: 2)
        .paint(canvas, Offset(tx, footY + 60 + ctaTp.height + 16));
  }

  void _drawQr(Canvas canvas, String url, double x, double y, double size) {
    try {
      final qr = QrPainter(
        data: url,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: true,
        eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square, color: Color(0xFF1C140D)),
        dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1C140D)),
      );
      canvas.save();
      canvas.translate(x, y);
      qr.paint(canvas, Size(size, size));
      canvas.restore();
    } catch (_) {}
  }

  String _region(String? address) {
    if (address == null) return '';
    final p = address.trim().split(RegExp(r'\s+'));
    return p.take(2).join(' ');
  }

  @override
  bool shouldRepaint(covariant StoryCardPainter old) => old.data != data;
}
