// story_card.dart — 9:16 인스타 스토리 카드 (1080×1920). 웹 share.js generateStoryCard 포팅.
// dart:ui Canvas로 직접 그려 PNG로 내보낸다(위젯 트리/RepaintBoundary 불필요·결정적).
// C 미감: 따뜻한 누룽지 그라데이션+밥알 텍스처 + 일러스트 지도패널(핀) + 정보카드 + QR + CTA.
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:qr_flutter/qr_flutter.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';
import '../services/i18n.dart';
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
    final levelL = t(
      const {
            'beginner': 'lv_beginner',
            'intermediate': 'lv_intermediate',
            'advanced': 'lv_advanced',
          }[s.level] ??
          'lv_any',
    );
    final tags = <StoryTag>[
      StoryTag(sportL, const Color(0xFFFAC710), const Color(0xFF4E342E)),
      StoryTag(levelL, const Color(0xFFF0ECE2), const Color(0xFF6D6258)),
    ];
    if (s.beginnerFriendly) {
      tags.add(
        StoryTag(
          t('beginner_ok'),
          const Color(0xFFE7F6E7),
          const Color(0xFF2E7D32),
        ),
      );
    }
    if (s.englishOk) {
      tags.add(
        StoryTag(
          t('english_ok'),
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
    final tgt = (c.target ?? '')
        .split(RegExp(r'[,\s]+'))
        .where((x) => x.isNotEmpty)
        .toList();
    final tags = <StoryTag>[];
    for (var i = 0; i < tgt.length && i < 4; i++) {
      tags.add(
        StoryTag(
          i18nTarget(tgt[i]),
          const Color(0xFFF0ECE2),
          const Color(0xFF6D6258),
        ),
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

/// 카드를 1080×1920 PNG 바이트로 렌더. 번들 Pretendard 사용으로 한글 tofu 방지.
Future<Uint8List?> renderStoryCardPng(StoryCardData data) async {
  // Pretendard는 pubspec fonts로 번들 → 앱 시작 시 등록되어 즉시 사용 가능
  // (google_fonts의 런타임 페치/pendingFonts 불필요).
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

  TextStyle _st(double size, FontWeight w, Color c) => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: size,
    fontWeight: w,
    color: c,
    height: 1.1,
  );

  TextPainter _tp(
    String text,
    TextStyle style, {
    double maxWidth = double.infinity,
    int maxLines = 1,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    return tp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const w = 1080.0, h = 1920.0, pad = 80.0;
    final accent = data.accent;
    const ink = Color(0xFF3D2C22), sub = Color(0xFFA99A8C);
    const cream = Color(0xFFFBF3E2), cardBg = Color(0xFFFFFDF8);
    final brand = '\uB204\uB8FD\uC9C0\uB3C4';

    // 배경: 절제된 크림 + 은은한 웜 비네트
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = cream);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(w / 2, h * 0.42),
          h * 0.7,
          const [Color(0x99FFFCF0), Color(0x80F0E2C4)],
          const [0.15, 1.0],
        ),
    );

    // 브랜드 헤더
    final wm = _tp(brand, _st(50, FontWeight.w800, ink));
    const tile = 64.0, tgap = 18.0;
    final total = tile + tgap + wm.width;
    final hsx = (w - total) / 2, hty = 118.0;
    _sh2(canvas, Rect.fromLTWH(hsx, hty, tile, tile), 18, 14, 6, 0.16);
    if (logo != null) {
      _rr2(canvas, hsx, hty, tile, tile, 18, Paint()..color = Colors.white);
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(hsx, hty, tile, tile),
          const Radius.circular(18),
        ),
      );
      canvas.drawImageRect(
        logo!,
        Rect.fromLTWH(0, 0, logo!.width.toDouble(), logo!.height.toDouble()),
        Rect.fromLTWH(hsx, hty, tile, tile),
        Paint(),
      );
      canvas.restore();
    } else {
      _rr2(canvas, hsx, hty, tile, tile, 18, Paint()..color = _yellow);
      _volley(canvas, hsx + tile / 2, hty + tile / 2, 20, Colors.white);
    }
    wm.paint(canvas, Offset(hsx + tile + tgap, hty + tile / 2 - wm.height / 2));

    // ===== 히어로: 에디토리얼 일러스트 지도 =====
    const mx = pad, my = 252.0, mw = w - pad * 2, mh = 560.0;
    _sh2(canvas, const Rect.fromLTWH(mx, my, mw, mh), 28, 36, 18, 0.15);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(mx, my, mw, mh),
        const Radius.circular(28),
      ),
    );
    canvas.drawRect(
      const Rect.fromLTWH(mx, my, mw, mh),
      Paint()..color = const Color(0xFFF7EDD6),
    );
    var mseed =
        ((((data.lat ?? 37.55) * 1e4).round() * 73856093) ^
                (((data.lng ?? 126.98) * 1e4).round() * 19349663))
            .abs() %
        2147483647;
    if (mseed == 0) mseed = 12345;
    double mr() {
      mseed = (mseed * 1103515245 + 12345) & 0x7fffffff;
      return mseed / 0x7fffffff;
    }

    // 공원 + 나무
    canvas.save();
    canvas.translate(mx + mw * 0.78, my + mh * 0.3);
    canvas.rotate(0.3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 300, height: 240),
      Paint()..color = const Color(0xFFDBE4BF),
    );
    canvas.restore();
    for (var tI = 0; tI < 4; tI++) {
      canvas.drawCircle(
        Offset(mx + mw * 0.72 + tI * 34, my + mh * 0.24 + (tI % 2) * 30),
        11,
        Paint()..color = const Color(0xFFC3D29A),
      );
    }
    // 물길
    final water = Path()
      ..moveTo(mx, my + mh * 0.72)
      ..cubicTo(
        mx + mw * 0.28,
        my + mh * 0.64,
        mx + mw * 0.34,
        my + mh * 0.9,
        mx + mw * 0.62,
        my + mh * 0.86,
      )
      ..lineTo(mx + mw * 0.62, my + mh)
      ..lineTo(mx, my + mh)
      ..close();
    canvas.drawPath(water, Paint()..color = const Color(0xFFD7E6E4));
    // 구획 블록
    const blocks = [
      [0.08, 0.12, 120.0, 88.0],
      [0.3, 0.1, 96.0, 78.0],
      [0.1, 0.4, 104.0, 70.0],
      [0.32, 0.44, 110.0, 84.0],
      [0.55, 0.14, 86.0, 76.0],
      [0.53, 0.5, 96.0, 70.0],
      [0.8, 0.62, 110.0, 80.0],
      [0.16, 0.7, 92.0, 66.0],
    ];
    for (var bI = 0; bI < blocks.length; bI++) {
      final b = blocks[bI];
      final col = mr() > 0.5
          ? const Color(0xFFECDFBB)
          : const Color(0xFFE6D6AC);
      _rr2(
        canvas,
        mx + mw * b[0] + (mr() - 0.5) * 20,
        my + mh * b[1] + (mr() - 0.5) * 16,
        b[2],
        b[3],
        10,
        Paint()..color = col,
      );
    }
    // 도로 + 점선 센터라인
    final roadA = Path()
      ..moveTo(mx - 20, my + mh * 0.58)
      ..cubicTo(
        mx + mw * 0.35,
        my + mh * 0.5,
        mx + mw * 0.5,
        my + mh * 0.66,
        mx + mw + 20,
        my + mh * 0.52,
      );
    final roadB = Path()
      ..moveTo(mx + mw * 0.42, my - 20)
      ..cubicTo(
        mx + mw * 0.46,
        my + mh * 0.4,
        mx + mw * 0.38,
        my + mh * 0.6,
        mx + mw * 0.44,
        my + mh + 20,
      );
    final roadPaint = _sp(const Color(0xFFFDF8EC), 30);
    canvas.drawPath(roadA, roadPaint);
    canvas.drawPath(roadB, roadPaint);
    canvas.drawPath(roadA, _dashed(const Color(0xFFE8CF94), 4, 16, 18));
    canvas.restore();

    // 지역 pill (상단)
    final region = _region(data.address);
    if (region.isNotEmpty) {
      final rt = _tp(region, _st(27, FontWeight.w700, ink));
      final rw = rt.width + 72;
      _sh2(
        canvas,
        Rect.fromLTWH(mx + (mw - rw) / 2, my + 24, rw, 54),
        27,
        8,
        4,
        0.12,
      );
      _rr2(
        canvas,
        mx + (mw - rw) / 2,
        my + 24,
        rw,
        54,
        27,
        Paint()..color = Colors.white,
      );
      _icoPin(canvas, mx + (mw - rw) / 2 + 18, my + 24 + 13, 28, _brown);
      rt.paint(
        canvas,
        Offset(mx + (mw - rw) / 2 + 52, my + 24 + 27 - rt.height / 2),
      );
    }

    // 핀 (중앙, 라인아트 배구공)
    final px = mx + mw / 2, py = my + mh * 0.48;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(px, py + 82), width: 80, height: 24),
      Paint()..color = const Color(0x24000000),
    );
    _sh2(
      canvas,
      Rect.fromCircle(center: Offset(px, py), radius: 52),
      52,
      16,
      8,
      0.22,
    );
    final pinPaint = Paint()..color = accent;
    canvas.drawPath(
      Path()
        ..moveTo(px - 30, py + 14)
        ..lineTo(px + 30, py + 14)
        ..lineTo(px, py + 80)
        ..close(),
      pinPaint,
    );
    canvas.drawCircle(Offset(px, py), 52, pinPaint);
    canvas.drawCircle(Offset(px, py), 34, Paint()..color = Colors.white);
    _volley(canvas, px, py, 22, accent);

    // 지오 힌트 pill (하단)
    String stTxt = '';
    bool stSub = false;
    if (data.station != null && data.station!.isNotEmpty) {
      stTxt = data.station!;
      stSub = true;
    } else if (data.venue != null && data.venue!.isNotEmpty) {
      stTxt = data.venue!;
    }
    if (stTxt.isNotEmpty) {
      final st = _tp(stTxt, _st(30, FontWeight.w700, ink), maxWidth: mw - 130);
      final sw = (st.width + 82).clamp(0.0, mw - 40);
      final ssx = mx + (mw - sw) / 2, ssy = my + mh - 82;
      _sh2(canvas, Rect.fromLTWH(ssx, ssy, sw, 60), 30, 10, 5, 0.16);
      _rr2(canvas, ssx, ssy, sw, 60, 30, Paint()..color = Colors.white);
      if (stSub) {
        _icoSub(canvas, ssx + 20, ssy + 15, 30, accent);
      } else {
        _icoPin(canvas, ssx + 20, ssy + 15, 30, accent);
      }
      st.paint(canvas, Offset(ssx + 58, ssy + 31 - st.height / 2));
    }

    // ===== 정보 카드 =====
    const cardX = pad, cardW = w - pad * 2, cpad = 56.0;
    const ix = cardX + cpad, iw = cardW - cpad * 2;
    final titleTp = _tp(
      data.title.isEmpty ? t('card_title_fallback') : data.title,
      _st(64, FontWeight.w800, ink),
      maxWidth: iw - (data.verified ? 66 : 0),
      maxLines: 2,
    );
    final titleH = titleTp.height;

    const chipH = 54.0, chipPad = 22.0, chipGap = 12.0;
    final chipTps = <TextPainter>[];
    final chipX = <double>[], chipRow = <int>[], chipW = <double>[];
    var ccx = 0.0;
    var crow = 0;
    for (final tg in data.tags) {
      final tp = _tp(tg.text, _st(30, FontWeight.w600, tg.fg));
      final cwd = tp.width + chipPad * 2;
      if (ccx + cwd > iw && ccx > 0) {
        crow++;
        ccx = 0;
      }
      chipTps.add(tp);
      chipX.add(ccx);
      chipRow.add(crow);
      chipW.add(cwd);
      ccx += cwd + chipGap;
    }
    final chipRows = data.tags.isEmpty ? 0 : crow + 1;
    final chipsH = chipRows > 0
        ? (chipRows * chipH + (chipRows - 1) * chipGap + 30)
        : 0.0;

    TextPainter? twTp;
    double bannerBodyH = 0, bannerH = 0;
    if (data.thisWeek != null && data.thisWeek!.isNotEmpty) {
      twTp = _tp(
        data.thisWeek!,
        _st(32, FontWeight.w700, ink),
        maxWidth: iw - 44,
        maxLines: 2,
      );
      bannerBodyH = 76 + twTp.height + 16;
      bannerH = bannerBodyH + 28;
    }

    final place = (data.venue != null && data.venue!.isNotEmpty)
        ? (data.venue! +
              ((data.address != null && data.address!.isNotEmpty)
                  ? ' \u00B7 ${data.address!}'
                  : ''))
        : data.address;
    final infoDefs = <List<dynamic>>[
      ['cal', data.schedule, 2],
      ['won', data.fee, 1],
      ['pin', place, 2],
    ];
    final infoTps = <TextPainter>[], infoIcon = <String>[];
    double infoH = 0;
    for (final d in infoDefs) {
      final txt = d[1] as String?;
      if (txt == null || txt.isEmpty) continue;
      final tp = _tp(
        txt,
        _st(36, FontWeight.w500, _dark),
        maxWidth: iw - 62,
        maxLines: d[2] as int,
      );
      infoTps.add(tp);
      infoIcon.add(d[0] as String);
      infoH += math.max(54.0, tp.height) + 18;
    }

    final contentH = titleH + chipsH + bannerH + infoH;
    final cardH = contentH + cpad * 2 - 6;
    const zoneTop = my + mh + 34, zoneBot = 1444.0;
    final cardY = (math.max(
      zoneTop,
      math.min(zoneBot - cardH, zoneTop + (zoneBot - zoneTop - cardH) / 2),
    )).roundToDouble();
    _sh2(canvas, Rect.fromLTWH(cardX, cardY, cardW, cardH), 28, 40, 20, 0.15);
    _rr2(canvas, cardX, cardY, cardW, cardH, 28, Paint()..color = cardBg);

    var y = cardY + cpad;
    titleTp.paint(canvas, Offset(ix, y));
    if (data.verified) {
      final lm = titleTp.computeLineMetrics();
      final fw = lm.isNotEmpty ? lm.first.width : titleTp.width;
      final ccX = ix + fw + 34, ccY = y + 34;
      canvas.drawCircle(
        Offset(ccX, ccY),
        22,
        Paint()..color = const Color(0xFF12A89E),
      );
      canvas.drawPath(
        Path()
          ..moveTo(ccX - 10, ccY)
          ..lineTo(ccX - 3, ccY + 8)
          ..lineTo(ccX + 11, ccY - 8),
        _sp(Colors.white, 5),
      );
    }
    y += titleTp.height + 8;

    if (chipRows > 0) {
      for (var i = 0; i < chipTps.length; i++) {
        final cxx = ix + chipX[i], cyy = y + chipRow[i] * (chipH + chipGap);
        _rr2(
          canvas,
          cxx,
          cyy,
          chipW[i],
          chipH,
          chipH / 2,
          Paint()..color = data.tags[i].bg,
        );
        chipTps[i].paint(
          canvas,
          Offset(cxx + chipPad, cyy + chipH / 2 - chipTps[i].height / 2),
        );
      }
      y += chipRows * chipH + (chipRows - 1) * chipGap + 30;
    }

    if (twTp != null) {
      _rr2(
        canvas,
        ix,
        y,
        iw,
        bannerBodyH,
        18,
        Paint()..color = const Color(0x38FAC710),
      );
      final badge = _tp(data.thisWeekBadge, _st(27, FontWeight.w800, ink));
      final badgeW = badge.width + 30;
      _rr2(canvas, ix + 22, y + 20, badgeW, 42, 21, Paint()..color = _yellow);
      badge.paint(canvas, Offset(ix + 22 + 15, y + 20 + 21 - badge.height / 2));
      twTp.paint(canvas, Offset(ix + 22, y + 76));
      y += bannerH;
    }

    for (var i = 0; i < infoTps.length; i++) {
      final ic = infoIcon[i];
      if (ic == 'cal') {
        _icoCal(canvas, ix, y - 2, 40, _brown);
      } else if (ic == 'won') {
        _icoWon(canvas, ix, y - 2, 40, _brown);
      } else {
        _icoPin(canvas, ix, y - 2, 40, _brown);
      }
      infoTps[i].paint(
        canvas,
        Offset(
          ix + 62,
          y +
              20 -
              infoTps[i].height / 2 +
              (infoTps[i].height > 46 ? infoTps[i].height / 2 - 23 : 0),
        ),
      );
      y += math.max(54.0, infoTps[i].height) + 18;
    }

    // ===== 푸터: QR + CTA =====
    const footH = 210.0, qrSize = 190.0, footY = 1670 - footH;
    const qrX = pad, qrY = footY + (footH - qrSize) / 2;
    _sh2(
      canvas,
      const Rect.fromLTWH(qrX - 12, qrY - 12, qrSize + 24, qrSize + 24),
      18,
      16,
      8,
      0.14,
    );
    _rr2(
      canvas,
      qrX - 12,
      qrY - 12,
      qrSize + 24,
      qrSize + 24,
      18,
      Paint()..color = Colors.white,
    );
    _drawQr(canvas, data.url, qrX, qrY, qrSize);
    final tx = qrX + qrSize + 50;
    _tp(
      'S C A N',
      _st(24, FontWeight.w700, sub),
    ).paint(canvas, Offset(tx, footY + 30));
    final cta = _tp(
      t('card_cta'),
      _st(42, FontWeight.w800, ink),
      maxWidth: w - pad - tx,
      maxLines: 2,
    );
    cta.paint(canvas, Offset(tx, footY + 66));
    final urlStr = data.url
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');
    _tp(
      urlStr,
      _st(27, FontWeight.w500, _brown),
      maxWidth: w - pad - tx,
    ).paint(canvas, Offset(tx, footY + 66 + cta.height + 10));
  }

  Paint _sp(Color c, double sw) => Paint()
    ..style = PaintingStyle.stroke
    ..color = c
    ..strokeWidth = sw
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Paint _dashed(Color c, double sw, double on, double off) {
    // 근사 대시(모바일 렌더 성능 고려): 실선 위 얇은 점선 느낌
    return Paint()
      ..style = PaintingStyle.stroke
      ..color = c
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
  }

  void _rr2(
    Canvas c,
    double x,
    double y,
    double w,
    double h,
    double r,
    Paint p,
  ) => c.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
    p,
  );

  void _sh2(Canvas c, Rect r, double rad, double blur, double dy, double a) {
    c.drawRRect(
      RRect.fromRectAndRadius(r.translate(0, dy), Radius.circular(rad)),
      Paint()
        ..color = Color.fromRGBO(93, 64, 55, a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 0.5),
    );
  }

  void _icoCal(Canvas c, double x, double y, double s, Color col) {
    final p = _sp(col, s * 0.08);
    _rr2(c, x + s * 0.1, y + s * 0.16, s * 0.8, s * 0.72, s * 0.13, p);
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

  void _icoWon(Canvas c, double x, double y, double s, Color col) {
    c.drawCircle(Offset(x + s / 2, y + s / 2), s * 0.4, _sp(col, s * 0.08));
    final tp = _tp('\u20A9', _st(s * 0.5, FontWeight.w700, col));
    tp.paint(c, Offset(x + s / 2 - tp.width / 2, y + s / 2 - tp.height / 2));
  }

  void _icoPin(Canvas c, double x, double y, double s, Color col) {
    final p = _sp(col, s * 0.08);
    final cx = x + s / 2, cy = y + s * 0.4, r = s * 0.28;
    final path = Path()
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi * 0.85,
        math.pi * 1.3,
        true,
      )
      ..lineTo(x + s / 2, y + s * 0.9)
      ..close();
    c.drawPath(path, p);
    c.drawCircle(Offset(cx, cy), s * 0.11, p);
  }

  void _icoSub(Canvas c, double x, double y, double s, Color col) {
    final p = _sp(col, s * 0.08);
    _rr2(c, x + s * 0.18, y + s * 0.12, s * 0.64, s * 0.6, s * 0.16, p);
    c.drawLine(
      Offset(x + s * 0.18, y + s * 0.44),
      Offset(x + s * 0.82, y + s * 0.44),
      p,
    );
    final fp = Paint()..color = col;
    c.drawCircle(Offset(x + s * 0.34, y + s * 0.58), s * 0.05, fp);
    c.drawCircle(Offset(x + s * 0.66, y + s * 0.58), s * 0.05, fp);
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

  void _volley(Canvas c, double cx, double cy, double r, Color col) {
    final p = _sp(col, r * 0.12);
    c.drawCircle(Offset(cx, cy), r, p);
    c.drawArc(
      Rect.fromCircle(
        center: Offset(cx - r * 0.2, cy - r * 0.1),
        radius: r * 1.1,
      ),
      -0.5,
      1.2,
      false,
      p,
    );
    c.drawArc(
      Rect.fromCircle(
        center: Offset(cx + r * 0.5, cy + r * 0.6),
        radius: r * 1.1,
      ),
      3.3,
      1.1,
      false,
      p,
    );
    c.drawArc(
      Rect.fromCircle(
        center: Offset(cx - r * 0.4, cy + r * 0.7),
        radius: r * 1.1,
      ),
      1.5,
      1.1,
      false,
      p,
    );
  }

  void _drawQr(Canvas canvas, String url, double x, double y, double size) {
    try {
      final qr = QrPainter(
        data: url,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF1C140D),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF1C140D),
        ),
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
