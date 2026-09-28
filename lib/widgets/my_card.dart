// my_card.dart — 내 네임카드 공유 이미지. 팀·픽업 카드(story_card.dart)와 같은 틀·같은
// 키트(share_card_kit.dart)로 그린다: dart:ui Canvas 직접 렌더 → 결정적, 위젯 트리 불필요.
//
// 두 규격 (docs/design-system.md §7 — 웹 js/my-card.js 와 같은 숫자):
//  · 스토리형 1080×1920 (9:16) — 밥색 필드(신원) + 도시락통
//  · 피드형  1080×1440 (3:4)  — 밥색 필드(신원) + 도시락통 + 식단표
//    인스타가 2025년부터 3:4 업로드·그리드를 지원한다. 4:5는 그리드 썸네일에서 위아래가 잘렸다.
//
// 구조(두 규격 공통): 전폭 밥색 필드(머리글 + 신원) / 본문 카드(필드 아랫단을 덮음) /
// 티켓 스텁(QR). 남는 세로는 밥색 필드·도시락통이 먹는다 — 빈 크림 띠를 남기지 않는다.
//
// 도시락통은 화면 UI(웹 .lunchbox-grid)와 같은 6열 그리드. 칸 색이 식단표 블록 색과
// 같아서 도시락통이 곧 식단표의 범례가 된다.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/i18n.dart';
import '../services/schedule_parse.dart';
import 'diet_grid.dart' show DietTeam;
import 'share_card_kit.dart';
import 'story_card.dart' show loadBrandLogo;

/// 도시락 한 칸. name이 null이면 빈 칸.
class MyCardSlot {
  final String? name;
  final bool isCustom;
  const MyCardSlot({this.name, this.isCustom = false});
}

class MyCardData {
  final String nickname; // 밥이름 전체 "백미밥-a3z"
  final String riceType; // 밥 종류 "백미밥"
  final Color bgColor; // 밥 종류 색(프로필) — 필드 색
  final String? joined; // "가입 2026.7.1"
  final String? mainTeam; // 대표팀(첫 찜팀)
  final bool mainTeamCustom;
  final List<MyCardSlot> slots; // 5칸: 0=밥 1=국 2~4=반찬
  final List<DietTeam> diet; // 식단표용
  final String url; // QR 목적지
  final bool feed; // true=피드형(3:4, 식단표 포함) / false=스토리형(9:16)

  const MyCardData({
    required this.nickname,
    required this.bgColor,
    required this.url,
    this.riceType = '',
    this.joined,
    this.mainTeam,
    this.mainTeamCustom = false,
    this.slots = const [],
    this.diet = const [],
    this.feed = false,
  });
}

/// 배치 계산 결과. 블록이 스텁(QR)을 침범하지 않는지 좌표로 검증하기 위해
/// 그리기와 분리했다.
class MyCardLayout {
  final CardFmt fmt;
  final double fieldH; // 밥색 필드 아래끝 (y=0 부터)
  final Rect identity;
  final Rect bento; // 도시락통
  final Rect diet; // 식단표 (스토리형은 Rect.zero)
  final double stubTop; // QR 스텁 윗단(절취선)
  const MyCardLayout({
    required this.fmt,
    required this.fieldH,
    required this.identity,
    required this.bento,
    required this.diet,
    required this.stubTop,
  });

  /// 본문 블록의 아래끝. 이 값이 stubTop - gap 을 넘으면 QR 스텁을 덮는다.
  double get bottom =>
      math.max(bento.bottom, diet == Rect.zero ? 0.0 : diet.bottom);
}

/// 공유용 PNG 바이트로 렌더. 규격은 data.feed 에 따라 3:4 / 9:16.
Future<Uint8List?> renderMyCardPng(MyCardData data) async {
  final logo = await loadBrandLogo();
  final painter = MyCardPainter(data, logo: logo);
  final size = painter.canvasSize;
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final pic = recorder.endRecording();
  final img = await pic.toImage(size.width.round(), size.height.round());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

// 웹 js/my-card.js 의 BENTO / ID_STORY / ID_FEED 와 같은 값.
const _bentoStoryMin = 440.0, _bentoStoryMax = 760.0;
const _bentoFeedH = 360.0, _bentoFeedMinH = 300.0, _dietMin = 320.0;
// 스토리 신원(세로 스택)
const _sEmblem = 136.0, _sGapE = 28.0, _sName = 72.0, _sNameMin = 44.0;
const _sGapN = 12.0, _sJoined = 34.0, _sGapJ = 28.0, _sPill = 60.0;
// 피드 신원(가로 한 줄)
const _fEmblem = 120.0, _fGap = 32.0, _fName = 56.0, _fNameMin = 36.0;
const _fJoined = 30.0, _fGapJ = 14.0, _fPill = 52.0;

class MyCardPainter extends CustomPainter {
  final MyCardData data;
  final ui.Image? logo;
  MyCardPainter(this.data, {this.logo});

  static const _ink = ShareCard.ink;
  static const _sub = ShareCard.sub;
  static const _brown = ShareCard.brown;
  static const _dark = ShareCard.dark;

  // 도시락 5칸 색 — 앱 도시락/식단표와 동일해야 "같은 칸"으로 읽힌다.
  static const _slotRail = [
    Color(0xFFFBC02D),
    Color(0xFFF57C00),
    Color(0xFF689F38),
    Color(0xFFD84315),
    Color(0xFF8E24AA),
  ];
  static const _slotBg = [
    Color(0xFFFFFDE7),
    Color(0xFFFFF3E0),
    Color(0xFFF1F8E9),
    Color(0xFFFBE9E7),
    Color(0xFFF3E5F5),
  ];
  // 식단표 블록: 칸 배경과 레일 색의 45% 혼합(웹 SLOTFILL 과 같은 값).
  static const _slotFill = [
    Color(0xFFFDE293),
    Color(0xFFFABD7B),
    Color(0xFFB3D099),
    Color(0xFFEB9E88),
    Color(0xFFC68ED3),
  ];

  /// 도시락통 그리드 — 웹 .lunchbox-grid / js/my-card.js 와 같은 배치.
  ///   6열 / 행비 0.8 : 1.2, 행1 반찬 3칸(각 2열), 행2 밥(1~3열) | 국(4~6열)
  static const _grid = <List<int>>[
    // [slot, row, col, span]
    [2, 0, 0, 2], [3, 0, 2, 2], [4, 0, 4, 2],
    [0, 1, 0, 3], [1, 1, 3, 3],
  ];
  static const _rowFr = [0.8, 1.2];

  /// 슬롯 인덱스 → 라벨 키(0=밥 1=국 2~4=반찬). 웹과 같은 mc_* — 이모지는 뺀다.
  static const _slotLabelKeys = [
    'mc_rice',
    'mc_soup',
    'mc_side1',
    'mc_side2',
    'mc_side3',
  ];

  CardFmt get _fmt => data.feed ? ShareCard.feed : ShareCard.story;
  Size get canvasSize => Size(ShareCard.w, _fmt.h);

  /// QR 스텁 윗단.
  double get stubTop => ShareCard.stubTop(_fmt);

  bool get _hasJoined => (data.joined ?? '').isNotEmpty;
  bool get _hasTeam => (data.mainTeam ?? '').isNotEmpty;

  double _identityStoryH() {
    var h = _sEmblem + _sGapE + _sName + 8;
    if (_hasJoined) h += _sGapN + _sJoined;
    if (_hasTeam) h += _sGapJ + _sPill;
    return h;
  }

  double _identityFeedTextH() {
    var h = _fName + 8;
    if (_hasJoined) h += 6 + _fJoined;
    if (_hasTeam) h += _fGapJ + _fPill;
    return h;
  }

  // ── 배치 (웹 myCardLayout 과 같은 산술) ───────────────────────
  MyCardLayout layout() {
    final fmt = _fmt;
    final st = ShareCard.stubTop(fmt);
    final headBot = fmt.top + ShareCard.headerH;
    final bodyBot = st - ShareCard.gap;
    const x = ShareCard.m, w = ShareCard.bodyW;

    if (!data.feed) {
      final idH = _identityStoryH();
      final minTop = headBot + 40 + idH + 48; // 신원 아래 최소 간격 48
      final bentoH = (bodyBot - minTop).clamp(_bentoStoryMin, _bentoStoryMax);
      final cardY = bodyBot - bentoH;
      return MyCardLayout(
        fmt: fmt,
        fieldH: cardY + ShareCard.overlap,
        // 신원은 머리글 ~ 도시락통 사이 가운데 (남는 세로가 위아래로 고르게)
        identity: Rect.fromLTWH(
          x,
          headBot + (cardY - headBot - idH) / 2,
          w,
          idH,
        ),
        bento: Rect.fromLTWH(x, cardY, w, bentoH),
        diet: Rect.zero,
        stubTop: st,
      );
    }
    final fid = math.max(_fEmblem, _identityFeedTextH());
    final idY = headBot + 32;
    final bY = idY + fid + 40;
    var bH = _bentoFeedH;
    if (bodyBot - (bY + bH + 24) < _dietMin) bH = _bentoFeedMinH;
    final dY = bY + bH + 24;
    return MyCardLayout(
      fmt: fmt,
      fieldH: bY + ShareCard.overlap,
      identity: Rect.fromLTWH(x, idY, w, fid),
      bento: Rect.fromLTWH(x, bY, w, bH),
      diet: Rect.fromLTWH(x, dY, w, bodyBot - dY),
      stubTop: st,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 미리보기(작은 위젯)와 내보내기가 같은 좌표계를 쓰도록 스케일.
    if (size.width != ShareCard.w) canvas.scale(size.width / ShareCard.w);
    final l = layout();
    cardBackground(canvas, l.fmt.h);
    _field(canvas, l.fieldH);
    cardHeader(canvas, l.fmt.top, logo);
    if (data.feed) {
      _identityFeed(canvas, l.identity);
    } else {
      _identityStory(canvas, l.identity);
    }
    _bento(canvas, l.bento);
    if (l.diet != Rect.zero) _timetable(canvas, l.diet);
    cardStub(canvas, l.fmt, data.url, t('mycard_cta'));
  }

  // ── 밥색 필드 ─────────────────────────────────────────────────
  // 프로필 밥 색 + 밝힘 + 밥알 무늬(시드 고정 → 매번 같은 그림, 웹과 같은 난수열).
  void _field(Canvas c, double h) {
    final r = Rect.fromLTWH(0, 0, ShareCard.w, h);
    c.drawRect(r, Paint()..color = data.bgColor);
    // 밥 색이 어떤 값이든 글씨가 읽히도록 살짝 밝힌다
    c.drawRect(r, Paint()..color = const Color(0x4DFFFFFF));
    var seed = 7;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    final grain = Paint()..color = const Color(0x8CFFFFFF);
    for (var i = 0; i < 70; i++) {
      final gx = rnd() * ShareCard.w, gy = rnd() * h, rot = rnd() * math.pi;
      c.save();
      c.translate(gx, gy);
      c.rotate(rot);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 22, height: 12),
        grain,
      );
      c.restore();
    }
    c.drawRect(
      Rect.fromLTWH(0, h - 160, ShareCard.w, 160),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, h - 160), Offset(0, h), const [
          Color(0x00FBF3E2),
          Color(0xFFFBF3E2),
        ]),
    );
  }

  void _emblem(Canvas c, Offset center, double s) {
    final circle = Path()
      ..addOval(Rect.fromCircle(center: center, radius: s / 2));
    cardShadow(c, circle);
    c.drawPath(circle, Paint()..color = Colors.white);
    if (logo != null) {
      cardLogoCircle(c, logo!, center, s / 2 - 6);
    } else {
      cardVolley(c, center.dx, center.dy, s * 0.3, ShareCard.yellow);
    }
  }

  /// 대표팀 알약: 배구공(벡터) + 팀 이름. centered면 x가 가운데, 아니면 왼쪽.
  void _teamPill(
    Canvas c,
    double x,
    double y,
    double h,
    double maxW, {
    required bool centered,
  }) {
    final st = cardStyle(h >= 60 ? 28 : 25, FontWeight.w700, _dark);
    final ico = h * 0.44;
    final lb = cardEllip(data.mainTeam!, st, maxW - (24 + ico + 12 + 26));
    final pw = 24 + ico + 12 + cardMeasure(lb, st) + 26;
    final px = centered ? x - pw / 2 : x;
    cardPill(c, px, y, pw, h);
    cardVolley(
      c,
      px + 24 + ico / 2,
      y + h / 2,
      ico / 2,
      const Color(0xFFE0A800),
    );
    cardText(c, lb, st, px + 24 + ico + 12, y + h / 2 + 1, middle: true);
  }

  void _identityStory(Canvas c, Rect r) {
    final cx = r.center.dx;
    var y = r.top;
    _emblem(c, Offset(cx, y + _sEmblem / 2), _sEmblem);
    y += _sEmblem + _sGapE;
    final fs = cardFit(
      data.nickname,
      r.width,
      _sName,
      _sNameMin,
      FontWeight.w800,
    );
    final nst = cardStyle(fs, FontWeight.w800, _ink);
    cardText(
      c,
      cardEllip(data.nickname, nst, r.width),
      nst,
      cx,
      y + _sName / 2,
      align: TextAlign.center,
      middle: true,
    );
    y += _sName + 8;
    if (_hasJoined) {
      y += _sGapN;
      cardText(
        c,
        data.joined!,
        cardStyle(28, FontWeight.w600, _brown),
        cx,
        y + _sJoined / 2,
        align: TextAlign.center,
        middle: true,
      );
      y += _sJoined;
    }
    if (_hasTeam) {
      y += _sGapJ;
      _teamPill(c, cx, y, _sPill, r.width, centered: true);
    }
  }

  void _identityFeed(Canvas c, Rect r) {
    _emblem(c, Offset(r.left + _fEmblem / 2, r.center.dy), _fEmblem);
    final tx = r.left + _fEmblem + _fGap, tw = r.right - tx;
    var y = r.top + (r.height - _identityFeedTextH()) / 2;
    final fs = cardFit(data.nickname, tw, _fName, _fNameMin, FontWeight.w800);
    final nst = cardStyle(fs, FontWeight.w800, _ink);
    cardText(
      c,
      cardEllip(data.nickname, nst, tw),
      nst,
      tx,
      y + _fName / 2,
      middle: true,
    );
    y += _fName + 8;
    if (_hasJoined) {
      y += 6;
      cardText(
        c,
        data.joined!,
        cardStyle(26, FontWeight.w600, _brown),
        tx,
        y + _fJoined / 2,
        middle: true,
      );
      y += _fJoined;
    }
    if (_hasTeam) {
      y += _fGapJ;
      _teamPill(c, tx, y, _fPill, tw, centered: false);
    }
  }

  void _sectionTitle(
    Canvas c,
    double x,
    double y,
    String text,
    String right,
    double w,
  ) {
    cardText(c, text, cardStyle(32, FontWeight.w800, _ink), x, y);
    if (right.isNotEmpty) {
      cardText(
        c,
        right,
        cardStyle(24, FontWeight.w700, _sub),
        x + w,
        y + 6,
        align: TextAlign.right,
      );
    }
  }

  // ── 도시락통 ───────────────────────────────────────────────────
  void _bento(Canvas c, Rect r) {
    cardPanel(c, r);
    const ip = 32.0;
    final ix = r.left + ip, iw = r.width - ip * 2;
    final filled = data.slots.where((s) => s.name != null).length;
    _sectionTitle(c, ix, r.top + ip, t('mycard_lunchbox'), '$filled / 5', iw);
    final cy = r.top + ip + 32 + 20;
    const gap = 14.0;
    final gridH = (r.bottom - ip) - cy;
    final colW = (iw - gap * 5) / 6;
    final unit = (gridH - gap) / (_rowFr[0] + _rowFr[1]);
    final rowH = [_rowFr[0] * unit, _rowFr[1] * unit];
    final rowY = [cy, cy + rowH[0] + gap];
    for (final g in _grid) {
      final slot = g[0], row = g[1], col = g[2], span = g[3];
      _cell(
        c,
        Rect.fromLTWH(
          ix + (colW + gap) * col,
          rowY[row],
          colW * span + gap * (span - 1),
          rowH[row],
        ),
        slot,
        span,
      );
    }
  }

  /// 도시락 칸 하나. 빈 칸에는 키워드만 — 화면 UI 의 "국을 담아주세요" 같은 명령형은
  /// 공유물에 나가면 받아 보는 사람에게 하는 말처럼 읽힌다.
  void _cell(Canvas c, Rect r, int slot, int span) {
    final s = slot < data.slots.length ? data.slots[slot] : const MyCardSlot();
    final label = stripEmoji(t(_slotLabelKeys[slot]));
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(16));
    if (s.name == null) {
      c.drawRRect(rr, Paint()..color = const Color(0x0D8D6E63));
      _dashedRRect(c, rr);
      cardText(
        c,
        label,
        cardStyle(24, FontWeight.w700, const Color(0x808D6E63)),
        r.center.dx,
        r.center.dy,
        align: TextAlign.center,
        middle: true,
      );
      return;
    }
    c.drawRRect(rr, Paint()..color = _slotBg[slot]);
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _slotRail[slot],
    );
    c.save();
    c.clipRRect(rr);
    c.drawRect(
      Rect.fromLTWH(r.left, r.top, 10, r.height),
      Paint()..color = _slotRail[slot],
    );
    cardText(
      c,
      label,
      cardStyle(20, FontWeight.w700, const Color(0x663D2C22)),
      r.left + 22,
      r.top + 12,
    );
    final big = span >= 3;
    final fs = data.feed ? (big ? 30.0 : 24.0) : (big ? 36.0 : 28.0);
    final lh = (fs * 1.22).roundToDouble();
    final st = cardStyle(fs, FontWeight.w800, _ink);
    final lines = cardWrapWords(s.name!, st, r.width - 40, 2);
    final sy = r.center.dy + 10 - (lines.length - 1) * lh / 2;
    for (var i = 0; i < lines.length; i++) {
      cardText(
        c,
        lines[i],
        st,
        r.center.dx + 5,
        sy + i * lh,
        align: TextAlign.center,
        middle: true,
      );
    }
    c.restore();
  }

  /// 빈 칸 점선 테두리 (웹 setLineDash([10, 8]) 과 같은 간격).
  void _dashedRRect(Canvas c, RRect rr) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x478D6E63);
    for (final m in (Path()..addRRect(rr)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 18) {
        c.drawPath(m.extractPath(d, math.min(d + 10, m.length)), paint);
      }
    }
  }

  // ── 식단표 (피드형) ────────────────────────────────────────────
  void _timetable(Canvas c, Rect r) {
    cardPanel(c, r);
    const ip = 32.0;
    final ix = r.left + ip, iw = r.width - ip * 2;
    _sectionTitle(c, ix, r.top + ip, t('mycard_timetable'), '', iw);
    final top = r.top + ip + 32 + 20;

    final all = <({SchedEvent e, DietTeam t})>[
      for (final tm in data.diet)
        for (final e in tm.events) (e: e, t: tm),
    ];
    if (all.isEmpty) {
      cardText(
        c,
        t('lb_no_sched'),
        cardStyle(26, FontWeight.w500, _sub),
        r.center.dx,
        (top + r.bottom - ip) / 2,
        align: TextAlign.center,
        middle: true,
      );
      return;
    }
    var minH = 24.0, maxH = 0.0;
    for (final v in all) {
      if (v.e.start < minH) minH = v.e.start;
      if (v.e.end > maxH) maxH = v.e.end;
    }
    final h0 = math.min(22, math.max(6, minH.floor() - 1));
    final h1 = math.min(24, math.max(h0 + 3, maxH.ceil() + 1));
    final hours = h1 - h0;
    const headH = 36.0, timeW = 44.0;
    final gx = ix + timeW, gy = top + headH, gw = iw - timeW;
    final gh = (r.bottom - ip) - gy;
    final colW = gw / scheduleDays.length, rowH = gh / hours;

    final dayst = cardStyle(24, FontWeight.w700, _ink);
    for (var d = 0; d < scheduleDays.length; d++) {
      cardText(
        c,
        i18nDay(scheduleDays[d]),
        dayst,
        gx + colW * d + colW / 2,
        top + headH / 2 - 4,
        align: TextAlign.center,
        middle: true,
      );
    }
    // 시간축: 촘촘하면 두 시간마다. 라벨은 선 '위'에 — 마지막 눈금(끝시각)까지 찍는다.
    final every = rowH >= 40 ? 1 : 2;
    final hLine = Paint()
      ..color = const Color(0x143D2C22)
      ..strokeWidth = 1;
    final tst = cardStyle(20, FontWeight.w600, _sub);
    for (var i = 0; i <= hours; i++) {
      final ly = gy + rowH * i;
      c.drawLine(Offset(gx, ly), Offset(gx + gw, ly), hLine);
      if ((h0 + i) % every == 0 || i == hours) {
        cardText(
          c,
          '${h0 + i}',
          tst,
          gx - 8,
          ly + 2 - 20,
          align: TextAlign.right,
        );
      }
    }
    final vLine = Paint()
      ..color = const Color(0x0F3D2C22)
      ..strokeWidth = 1;
    for (var d = 0; d <= scheduleDays.length; d++) {
      c.drawLine(
        Offset(gx + colW * d, gy),
        Offset(gx + colW * d, gy + gh),
        vLine,
      );
    }

    // 겹치는 일정은 칸을 레인으로 나눠 나란히 + 블록이 크면 팀 이름(웹과 같은 규칙).
    c.save();
    c.clipRect(Rect.fromLTWH(gx, gy, gw, gh));
    for (var d = 0; d < scheduleDays.length; d++) {
      final day = scheduleDays[d];
      final evs = all.where((v) => v.e.day == day).toList()
        ..sort((a, b) => a.e.start.compareTo(b.e.start));
      final lanes = assignLanes([for (final v in evs) v.e]);
      for (var i = 0; i < evs.length; i++) {
        final e = evs[i].e, tm = evs[i].t;
        final slot = tm.slotIdx % 5;
        final lw = (colW - 4) / lanes[i].lanes;
        final bx = gx + colW * d + 2 + lw * lanes[i].lane;
        final by = gy + (e.start - h0) * rowH + 1;
        final bw = lw - (lanes[i].lanes > 1 ? 2 : 0);
        final bh = math.max(14.0, (e.end - e.start) * rowH - 3);
        final block = cardRRect(bx, by, bw, bh, 6);
        c.drawRRect(block, Paint()..color = _slotFill[slot]);
        c.drawRect(
          Rect.fromLTWH(bx, by, math.min(5.0, bw), bh),
          Paint()..color = _slotRail[slot],
        );
        if (bw >= 56 && bh >= 44) {
          c.save();
          c.clipRRect(block);
          final nst = cardStyle(18, FontWeight.w800, _ink);
          final nl = cardWrapWords(tm.name, nst, bw - 12, 2);
          for (var n = 0; n < nl.length; n++) {
            cardText(
              c,
              nl[n],
              nst,
              bx + bw / 2 + 2,
              by + bh / 2 + (n - (nl.length - 1) / 2) * 22,
              align: TextAlign.center,
              middle: true,
            );
          }
          c.restore();
        }
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant MyCardPainter old) =>
      old.data != data || old.logo != logo;
}
