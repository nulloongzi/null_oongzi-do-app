// my_card.dart — 내 네임카드 공유 이미지 (1080×1920). 클럽 스토리 카드(story_card.dart)와
// 같은 미감·같은 기법으로 그린다: dart:ui Canvas 직접 렌더 → 결정적, 위젯 트리 불필요.
//
// 왜 CustomPainter인가: 이전 판은 340px 위젯 카드를 RepaintBoundary로 3배 확대해 떴다.
// 기기 폰트·텍스트 스케일에 따라 결과가 흔들리고, 클럽 카드와 미감이 따로 놀았다.
// 공유되는 이미지 두 종류가 서로 다른 브랜드처럼 보이면 안 된다.
//
// 공유 토큰(story_card.dart와 동일): 크림 배경 + 웜 비네트, 라운드 28 카드,
// 소프트 섀도 _sh2, 라인아트 아이콘, 하단 QR + CTA 푸터, Pretendard.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/i18n.dart';
import '../services/schedule_parse.dart';
import 'diet_grid.dart' show DietTeam;
import 'story_card.dart' show loadBrandLogo;

/// 도시락 한 칸. name이 null이면 빈 칸.
class MyCardSlot {
  final String? name;
  final bool isCustom;
  const MyCardSlot({this.name, this.isCustom = false});
}

class MyCardData {
  final String nickname; // 밥이름 전체 "백미밥-a3z"
  final String riceType; // 밥 종류 "백미밥" — 앱 네임카드 좌상단 워터마크와 동일
  final Color bgColor; // 밥 종류 색(프로필)
  final String? joined; // "가입 2026.7.1"
  final String? mainTeam; // 대표팀(첫 찜팀)
  final bool mainTeamCustom;
  final List<MyCardSlot> slots; // 5칸
  final List<DietTeam> diet; // 식단표용
  final String url; // QR 목적지
  final bool feed; // true=피드형(식단표 포함) / false=스토리형

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

/// 세로 배치 계산 결과. 블록이 푸터(QR)를 침범하지 않는지 좌표로 검증하기 위해
/// 그리기와 분리했다.
class MyCardLayout {
  final double heroY, heroH, lbY, lbH, dietY, dietH, rowH, rowGap;
  const MyCardLayout({
    required this.heroY,
    required this.heroH,
    required this.lbY,
    required this.lbH,
    required this.dietY,
    required this.dietH,
    required this.rowH,
    required this.rowGap,
  });

  /// 마지막 블록의 아래끝. 이 값이 footY를 넘으면 QR/CTA를 덮는다.
  double get bottom => dietH > 0 ? dietY + dietH : lbY + lbH;
}

/// 1080×1920 PNG 바이트로 렌더(공유용). 번들 Pretendard라 한글 tofu 없음.
Future<Uint8List?> renderMyCardPng(MyCardData data) async {
  final logo = await loadBrandLogo();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  MyCardPainter(data, logo: logo).paint(canvas, const Size(1080, 1920));
  final pic = recorder.endRecording();
  final img = await pic.toImage(1080, 1920);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

class MyCardPainter extends CustomPainter {
  final MyCardData data;
  final ui.Image? logo;
  MyCardPainter(this.data, {this.logo});

  static const _w = 1080.0, _h = 1920.0, _pad = 80.0;
  static const _ink = Color(0xFF3D2C22);
  static const _sub = Color(0xFFA99A8C);
  static const _dark = Color(0xFF4E342E);
  static const _brown = Color(0xFF8D6E63);
  static const _yellow = Color(0xFFFAC710);
  static const _cream = Color(0xFFFBF3E2);
  static const _cardBg = Color(0xFFFFFDF8);

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

  TextStyle _st(double size, FontWeight w, Color c) => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: size,
    fontWeight: w,
    color: c,
    height: 1.15,
  );

  TextPainter _tp(
    String text,
    TextStyle style, {
    double maxWidth = double.infinity,
    int maxLines = 1,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    return tp;
  }

  // ── 세로 배치 ──────────────────────────────────────────────────
  // 그리기와 분리해 순수 계산으로 둔다. 이 카드가 깨지는 방식은 "블록 합이 푸터를
  // 밀어낸다" 하나인데, 픽셀로 확인하려니 QR 모듈 위에 프로브가 떨어져 헛짚었다.
  // 침범 여부는 좌표로 따지는 게 맞다 → 테스트가 layout()을 직접 검증한다.
  static const footY = 1670.0 - 210.0; // 클럽 카드와 동일한 푸터 위치
  static const _zoneTop = 252.0;
  static const _gap = 34.0;

  MyCardLayout layout() {
    final zoneH = (footY - 46) - _zoneTop;
    final heroH = _heroHeight(compact: data.feed);
    final avail = zoneH - heroH - _gap;

    if (data.feed) {
      // 피드형: 도시락은 팀 칩으로 압축하고 남는 자리를 전부 식단표에 준다.
      // (칸을 5줄로 늘어놓으면 5개 다 찼을 때 식단표가 푸터를 밀어낸다.)
      final lbH = _chipsHeight(_chipLayout().rows);
      final dietH = (avail - _gap - lbH).clamp(200.0, 420.0);
      final stackH = heroH + _gap + lbH + _gap + dietH;
      final y = (_zoneTop + math.max(0.0, (zoneH - stackH) / 2))
          .roundToDouble();
      return MyCardLayout(
        heroY: y,
        heroH: heroH,
        lbY: y + heroH + _gap,
        lbH: lbH,
        dietY: y + heroH + _gap + lbH + _gap,
        dietH: dietH,
        rowH: 0,
        rowGap: 0,
      );
    }
    // 스토리형: 5칸을 그대로 — 도시락통이 주인공이다.
    final n = data.slots.isEmpty ? 1 : data.slots.length;
    const rowGap = 14.0;
    final chrome = _lbChrome + (n - 1) * rowGap;
    final rowH = ((avail - chrome) / n).clamp(56.0, 112.0);
    final lbH = chrome + n * rowH;
    final stackH = heroH + _gap + lbH;
    final y = (_zoneTop + math.max(0.0, (zoneH - stackH) / 2)).roundToDouble();
    return MyCardLayout(
      heroY: y,
      heroH: heroH,
      lbY: y + heroH + _gap,
      lbH: lbH,
      dietY: 0,
      dietH: 0,
      rowH: rowH,
      rowGap: rowGap,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 미리보기(작은 위젯)와 내보내기(1080×1920)가 같은 좌표계를 쓰도록 스케일.
    if (size.width != _w) {
      final s = size.width / _w;
      canvas.scale(s, s);
    }

    _background(canvas);
    _brandHeader(canvas);

    final l = layout();
    _hero(canvas, l.heroY, l.heroH);
    if (data.feed) {
      _lunchboxChips(canvas, l.lbY, l.lbH, _chipLayout());
      _diet(canvas, l.dietY, l.dietH);
    } else {
      _lunchboxRows(canvas, l.lbY, l.lbH, l.rowH, l.rowGap);
    }
    _footer(canvas, footY);
  }

  // ── 배경 / 헤더 (클럽 스토리 카드와 동일) ───────────────────────
  void _background(Canvas canvas) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), Paint()..color = _cream);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _w, _h),
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(_w / 2, _h * 0.42),
          _h * 0.7,
          const [Color(0x99FFFCF0), Color(0x80F0E2C4)],
          const [0.15, 1.0],
        ),
    );
  }

  void _brandHeader(Canvas canvas) {
    final wm = _tp(t('brand'), _st(50, FontWeight.w800, _ink));
    const tile = 64.0, tgap = 18.0, hty = 118.0;
    final total = tile + tgap + wm.width;
    final hsx = (_w - total) / 2;
    _sh2(canvas, Rect.fromLTWH(hsx, hty, tile, tile), 18, 14, 6, 0.16);
    if (logo != null) {
      _rr(canvas, hsx, hty, tile, tile, 18, Paint()..color = Colors.white);
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
      _rr(canvas, hsx, hty, tile, tile, 18, Paint()..color = _yellow);
      _riceBowl(canvas, hsx + 12, hty + 12, tile - 24, Colors.white);
    }
    wm.paint(canvas, Offset(hsx + tile + tgap, hty + tile / 2 - wm.height / 2));
  }

  // ── 히어로: 네임카드 ───────────────────────────────────────────
  // 앱 프로필 카드(밥 색 배경 + 큰 밥이름 + 가입일 + 대표팀 뱃지)를 스토리 규격으로.
  static const _heroPad = 56.0;
  static const _emblem = 132.0;

  double _heroHeight({required bool compact}) {
    final nameTp = _nameTp(compact);
    var hgt = _heroPad + (compact ? _emblem * 0.72 : _emblem) + 26;
    hgt += nameTp.height;
    if ((data.joined ?? '').isNotEmpty) hgt += 12 + (compact ? 28.0 : 32.0);
    if ((data.mainTeam ?? '').isNotEmpty) hgt += 28 + (compact ? 64.0 : 72.0);
    return hgt + _heroPad;
  }

  TextPainter _nameTp(bool compact) => _tp(
    data.nickname,
    _st(compact ? 62 : 76, FontWeight.w800, _ink),
    maxWidth: _w - _pad * 2 - _heroPad * 2,
    maxLines: 2,
    align: TextAlign.center,
  );

  void _hero(Canvas canvas, double y, double hgt) {
    final compact = data.feed;
    const x = _pad, cw = _w - _pad * 2;
    _sh2(canvas, Rect.fromLTWH(x, y, cw, hgt), 28, 40, 20, 0.15);
    _rr(canvas, x, y, cw, hgt, 28, Paint()..color = data.bgColor);
    // 밥 색이 어떤 값이든 글씨가 읽히도록 카드 안쪽을 살짝 밝힌다.
    _rr(canvas, x, y, cw, hgt, 28, Paint()..color = const Color(0x1AFFFFFF));

    // 좌상단 밥 종류 워터마크 — 앱 네임카드(.pc-rice-type)와 같은 자리·같은 톤.
    if (data.riceType.isNotEmpty) {
      _tp(
        data.riceType,
        _st(28, FontWeight.w700, const Color(0x4D5D4037)),
      ).paint(canvas, Offset(x + 30, y + 26));
    }

    var cy = y + _heroPad;

    // 엠블럼: 흰 원 + 브랜드 로고(클럽 카드의 핀+배구공과 같은 문법).
    // 단순화 밥그릇 벡터는 밥·그릇 사이 틈 때문에 이 크기에선 햄버거처럼 보였다
    // (24px 스탬프용으로 그린 패스라 그렇다) → 로고 비트맵을 쓰고, 없을 때만 벡터.
    final es = compact ? _emblem * 0.72 : _emblem;
    final ecx = _w / 2;
    _sh2(
      canvas,
      Rect.fromCircle(center: Offset(ecx, cy + es / 2), radius: es / 2),
      es / 2,
      16,
      8,
      0.16,
    );
    canvas.drawCircle(
      Offset(ecx, cy + es / 2),
      es / 2,
      Paint()..color = Colors.white,
    );
    if (logo != null) {
      final ls = es * 0.68;
      canvas.drawImageRect(
        logo!,
        Rect.fromLTWH(0, 0, logo!.width.toDouble(), logo!.height.toDouble()),
        Rect.fromLTWH(ecx - ls / 2, cy + (es - ls) / 2, ls, ls),
        Paint(),
      );
    } else {
      _riceBowl(canvas, ecx - es * 0.3, cy + es * 0.2, es * 0.6, _yellow);
    }
    cy += es + 26;

    final nameTp = _nameTp(compact);
    nameTp.paint(canvas, Offset(x + _heroPad, cy));
    cy += nameTp.height;

    if ((data.joined ?? '').isNotEmpty) {
      cy += 12;
      final jt = _tp(
        data.joined!,
        _st(compact ? 26 : 30, FontWeight.w500, _brown),
        maxWidth: cw - _heroPad * 2,
        align: TextAlign.center,
      );
      jt.paint(canvas, Offset(ecx - jt.width / 2, cy));
      cy += compact ? 28 : 32;
    }

    if ((data.mainTeam ?? '').isNotEmpty) {
      cy += 28;
      final ph = compact ? 64.0 : 72.0;
      final tt = _tp(
        data.mainTeam!,
        _st(compact ? 32 : 36, FontWeight.w700, _ink),
        maxWidth: cw - _heroPad * 2 - 110,
      );
      final pw = tt.width + 110;
      final psx = ecx - pw / 2;
      _rr(canvas, psx, cy, pw, ph, ph / 2, Paint()..color = Colors.white);
      final icoS = ph * 0.5;
      if (data.mainTeamCustom) {
        _riceBall(canvas, psx + 30, cy + (ph - icoS) / 2, icoS, _brown);
      } else {
        _volley(canvas, psx + 30 + icoS / 2, cy + ph / 2, icoS / 2, _yellow);
      }
      tt.paint(
        canvas,
        Offset(psx + 30 + icoS + 20, cy + ph / 2 - tt.height / 2),
      );
    }
  }

  // ── 도시락 카드 ────────────────────────────────────────────────
  static const _lbPad = 44.0;
  static const _lbHeader = 56.0;
  static const _lbChrome = _lbPad * 2 + _lbHeader + 18;

  /// 카드 껍데기 + "도시락 n/5" 헤더. 본문 시작 y를 돌려준다.
  double _lbShell(Canvas canvas, double y, double hgt) {
    const x = _pad, cw = _w - _pad * 2;
    _sh2(canvas, Rect.fromLTWH(x, y, cw, hgt), 28, 40, 20, 0.15);
    _rr(canvas, x, y, cw, hgt, 28, Paint()..color = _cardBg);

    final ix = x + _lbPad, iw = cw - _lbPad * 2;
    final title = _tp(t('mycard_lunchbox'), _st(40, FontWeight.w800, _ink));
    title.paint(
      canvas,
      Offset(ix, y + _lbPad + (_lbHeader - title.height) / 2),
    );
    final filled = data.slots.where((s) => s.name != null).length;
    final cnt = _tp('$filled / 5', _st(30, FontWeight.w600, _sub));
    cnt.paint(
      canvas,
      Offset(ix + iw - cnt.width, y + _lbPad + (_lbHeader - cnt.height) / 2),
    );
    return y + _lbPad + _lbHeader + 18;
  }

  /// 스토리형 도시락: 5칸을 세로로. 빈 칸도 보여야 "5칸 중 n개"가 읽힌다.
  void _lunchboxRows(
    Canvas canvas,
    double y,
    double hgt,
    double rowH,
    double rowGap,
  ) {
    var cy = _lbShell(canvas, y, hgt);
    const ix = _pad + _lbPad;
    const iw = _w - _pad * 2 - _lbPad * 2;
    for (var i = 0; i < data.slots.length; i++) {
      _slotRow(canvas, ix, cy, iw, rowH, i, data.slots[i]);
      cy += rowH + rowGap;
    }
  }

  // ── 피드형 도시락: 팀 칩(식단표에 자리를 양보) ──────────────────
  static const _chipH = 60.0;
  static const _chipGap = 12.0;

  ({List<String> names, List<int> idx, List<double> w, List<int> row, int rows})
  _chipLayout() {
    const iw = _w - _pad * 2 - _lbPad * 2;
    final names = <String>[], w = <double>[], row = <int>[], idx = <int>[];
    var cx = 0.0, r = 0;
    for (var i = 0; i < data.slots.length; i++) {
      final s = data.slots[i];
      if (s.name == null) continue;
      final tp = _tp(s.name!, _st(30, FontWeight.w700, _dark));
      final cw = tp.width + 34 + _chipH * 0.42 + 18 + 26;
      if (cx + cw > iw && cx > 0) {
        r++;
        cx = 0;
        if (r > 1) break; // 2줄까지만 — 넘치면 잘라낸다
      }
      names.add(s.name!);
      idx.add(i);
      w.add(cw);
      row.add(r);
      cx += cw + _chipGap;
    }
    return (
      names: names,
      idx: idx,
      w: w,
      row: row,
      rows: names.isEmpty ? 1 : row.last + 1,
    );
  }

  double _chipsHeight(int rows) =>
      _lbPad * 2 + _lbHeader + 18 + rows * _chipH + (rows - 1) * _chipGap;

  void _lunchboxChips(
    Canvas canvas,
    double y,
    double hgt,
    ({
      List<String> names,
      List<int> idx,
      List<double> w,
      List<int> row,
      int rows,
    })
    c,
  ) {
    final top = _lbShell(canvas, y, hgt);
    const ix = _pad + _lbPad;
    if (c.names.isEmpty) {
      final e = _tp(t('no_saved_team'), _st(32, FontWeight.w500, _sub));
      e.paint(canvas, Offset(ix, top + (_chipH - e.height) / 2));
      return;
    }
    var cx = ix;
    var curRow = 0;
    for (var i = 0; i < c.names.length; i++) {
      if (c.row[i] != curRow) {
        curRow = c.row[i];
        cx = ix;
      }
      final cy = top + curRow * (_chipH + _chipGap);
      final slot = c.idx[i] % 5;
      _rr(
        canvas,
        cx,
        cy,
        c.w[i],
        _chipH,
        _chipH / 2,
        Paint()..color = _slotBg[slot],
      );
      final icoS = _chipH * 0.42;
      if (data.slots[c.idx[i]].isCustom) {
        _riceBall(
          canvas,
          cx + 26,
          cy + (_chipH - icoS) / 2,
          icoS,
          _slotRail[slot],
        );
      } else {
        _volley(
          canvas,
          cx + 26 + icoS / 2,
          cy + _chipH / 2,
          icoS / 2,
          _slotRail[slot],
        );
      }
      final tp = _tp(c.names[i], _st(30, FontWeight.w700, _dark));
      tp.paint(
        canvas,
        Offset(cx + 26 + icoS + 18, cy + _chipH / 2 - tp.height / 2),
      );
      cx += c.w[i] + _chipGap;
    }
  }

  void _slotRow(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    int i,
    MyCardSlot s,
  ) {
    final rail = _slotRail[i % 5];
    if (s.name == null) {
      // 빈 칸: 색을 쓰지 않고 옅은 윤곽만 — 채워진 칸이 도드라지게.
      _rr(
        canvas,
        x,
        y,
        w,
        h,
        18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x1A8D6E63),
      );
      final tp = _tp(t('mycard_empty_slot'), _st(30, FontWeight.w500, _sub));
      tp.paint(canvas, Offset(x + 34, y + h / 2 - tp.height / 2));
      return;
    }
    _rr(canvas, x, y, w, h, 18, Paint()..color = _slotBg[i % 5]);
    // 좌측 색 레일 — 식단표 블록과 같은 색이라 어느 칸의 일정인지 눈으로 이어진다.
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        const Radius.circular(18),
      ),
    );
    canvas.drawRect(Rect.fromLTWH(x, y, 10, h), Paint()..color = rail);
    canvas.restore();

    final icoS = h * 0.42;
    final tx = x + 34 + icoS + 18;
    if (s.isCustom) {
      _riceBall(canvas, x + 34, y + (h - icoS) / 2, icoS, rail);
    } else {
      _volley(canvas, x + 34 + icoS / 2, y + h / 2, icoS / 2, rail);
    }
    final tp = _tp(
      s.name!,
      _st(36, FontWeight.w700, _dark),
      maxWidth: w - (tx - x) - 34,
    );
    tp.paint(canvas, Offset(tx, y + h / 2 - tp.height / 2));
  }

  // ── 식단표(피드형) ─────────────────────────────────────────────
  void _diet(Canvas canvas, double y, double hgt) {
    const x = _pad, cw = _w - _pad * 2;
    _sh2(canvas, Rect.fromLTWH(x, y, cw, hgt), 28, 40, 20, 0.15);
    _rr(canvas, x, y, cw, hgt, 28, Paint()..color = _cardBg);

    final all = <({SchedEvent e, DietTeam t})>[];
    for (final tm in data.diet) {
      for (final e in tm.events) {
        all.add((e: e, t: tm));
      }
    }
    if (all.isEmpty) {
      final tp = _tp(t('lb_no_sched'), _st(32, FontWeight.w500, _sub));
      tp.paint(
        canvas,
        Offset(x + (cw - tp.width) / 2, y + hgt / 2 - tp.height / 2),
      );
      return;
    }

    const pad = 30.0, timeW = 62.0, headH = 44.0;
    final gx = x + pad + timeW, gy = y + pad + headH;
    final gw = cw - pad * 2 - timeW, gh = hgt - pad * 2 - headH;
    final colW = gw / scheduleDays.length;

    var minH = 24.0, maxH = 0.0;
    for (final v in all) {
      if (v.e.start < minH) minH = v.e.start;
      if (v.e.end > maxH) maxH = v.e.end;
    }
    final startH = (minH.floor() - 1).clamp(6, 22).toInt();
    final endH = (maxH.ceil() + 1).clamp(startH + 1, 24).toInt();
    final hours = endH - startH;
    final rowH = gh / hours;

    // 요일 헤더
    for (var d = 0; d < scheduleDays.length; d++) {
      final tp = _tp(i18nDay(scheduleDays[d]), _st(26, FontWeight.w700, _ink));
      tp.paint(
        canvas,
        Offset(
          gx + colW * d + (colW - tp.width) / 2,
          y + pad + (headH - tp.height) / 2,
        ),
      );
    }
    // 시간 라벨 + 가로선
    final hLine = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    for (var i = 0; i <= hours; i++) {
      final ly = gy + rowH * i;
      canvas.drawLine(Offset(gx, ly), Offset(gx + gw, ly), hLine);
      if (i < hours) {
        final tp = _tp(
          getHourLabel(startH + i),
          _st(20, FontWeight.w500, _sub),
        );
        tp.paint(canvas, Offset(gx - timeW + 8, ly + 4));
      }
    }
    // 세로 요일선
    final vLine = Paint()
      ..color = const Color(0x11000000)
      ..strokeWidth = 1;
    for (var d = 0; d <= scheduleDays.length; d++) {
      final lx = gx + colW * d;
      canvas.drawLine(Offset(lx, gy), Offset(lx, gy + gh), vLine);
    }

    // 이벤트 블록 (겹치면 들여쓰기 — 앱 식단표와 동일 규칙)
    // 표시 범위 밖으로 걸치는 블록이 카드 밖으로 새지 않게 그리드 영역을 클립.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(gx, gy, gw, gh));
    for (var d = 0; d < scheduleDays.length; d++) {
      final day = scheduleDays[d];
      final evs = all.where((v) => v.e.day == day).toList()
        ..sort((a, b) => a.e.start.compareTo(b.e.start));
      for (var i = 0; i < evs.length; i++) {
        final e = evs[i].e, tm = evs[i].t;
        var indent = 0;
        for (var j = 0; j < i; j++) {
          if (e.start < evs[j].e.end && e.end > evs[j].e.start) indent++;
        }
        if (indent > 2) indent = 0;
        final slot = tm.slotIdx % 5;
        final bx = gx + colW * d + 2 + indent * 7.0;
        final by = gy + (e.start - startH) * rowH;
        final bw = colW - 4 - indent * 7.0;
        final bh = math.max(22.0, (e.end - e.start) * rowH - 3);
        if (by + bh < gy || by > gy + gh) continue;
        _rr(canvas, bx, by, bw, bh, 7, Paint()..color = _slotBg[slot]);
        canvas.save();
        canvas.clipRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, bw, bh),
            const Radius.circular(7),
          ),
        );
        canvas.drawRect(
          Rect.fromLTWH(bx, by, 5, bh),
          Paint()..color = _slotRail[slot],
        );
        final tp = _tp(
          tm.name,
          _st(19, FontWeight.w600, _dark),
          maxWidth: bw - 12,
          maxLines: math.max(1, (bh / 22).floor()),
        );
        tp.paint(canvas, Offset(bx + 9, by + 5));
        canvas.restore();
      }
    }
    canvas.restore();
  }

  // ── 푸터: QR + CTA (클럽 스토리 카드와 동일 구조) ───────────────
  void _footer(Canvas canvas, double footY) {
    const footH = 210.0, qrSize = 190.0;
    const qrX = _pad;
    final qrY = footY + (footH - qrSize) / 2;
    _sh2(
      canvas,
      Rect.fromLTWH(qrX - 12, qrY - 12, qrSize + 24, qrSize + 24),
      18,
      16,
      8,
      0.14,
    );
    _rr(
      canvas,
      qrX - 12,
      qrY - 12,
      qrSize + 24,
      qrSize + 24,
      18,
      Paint()..color = Colors.white,
    );
    _drawQr(canvas, data.url, qrX, qrY, qrSize);

    const tx = qrX + qrSize + 50;
    _tp(
      'S C A N',
      _st(24, FontWeight.w700, _sub),
    ).paint(canvas, Offset(tx, footY + 30));
    final cta = _tp(
      t('mycard_cta'),
      _st(42, FontWeight.w800, _ink),
      maxWidth: _w - _pad - tx,
      maxLines: 2,
    );
    cta.paint(canvas, Offset(tx, footY + 66));
    final urlStr = data.url
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');
    _tp(
      urlStr,
      _st(27, FontWeight.w500, _brown),
      maxWidth: _w - _pad - tx,
    ).paint(canvas, Offset(tx, footY + 66 + cta.height + 10));
  }

  // ── 프리미티브 (story_card.dart와 동일 규격) ────────────────────
  Paint _sp(Color c, double sw) => Paint()
    ..style = PaintingStyle.stroke
    ..color = c
    ..strokeWidth = sw
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  void _rr(
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

  /// 밥그릇(로고 단순화) — provider_stamp.dart의 24 viewBox 패스와 동일 형태.
  void _riceBowl(Canvas c, double x, double y, double s, Color col) {
    c.save();
    c.translate(x, y);
    c.scale(s / 24);
    // 그리는 좌표를 위쪽으로 당겨 밥+그릇이 s 안에 꽉 차게.
    c.translate(0, -3.5);
    final paint = Paint()..color = col;
    final rice = Path()
      ..moveTo(12, 4.6)
      ..cubicTo(10.1, 4.6, 8.8, 5.6, 8.1, 6.8)
      ..cubicTo(7.1, 6.4, 5.7, 7.1, 5.7, 8.5)
      ..cubicTo(5.7, 9.4, 6.4, 10, 7.1, 10)
      ..lineTo(16.9, 10)
      ..cubicTo(17.6, 10, 18.3, 9.4, 18.3, 8.5)
      ..cubicTo(18.3, 7.1, 16.9, 6.4, 15.9, 6.8)
      ..cubicTo(15.2, 5.6, 13.9, 4.6, 12, 4.6)
      ..close();
    c.drawPath(rice, paint);
    final bowl = Path()
      ..moveTo(4.2, 11.6)
      ..lineTo(19.8, 11.6)
      ..cubicTo(19.8, 14.7, 17.3, 17.2, 14, 17.8)
      ..lineTo(14, 18.7)
      ..cubicTo(14, 19.1, 13.7, 19.4, 13.3, 19.4)
      ..lineTo(10.7, 19.4)
      ..cubicTo(10.3, 19.4, 10, 19.1, 10, 18.7)
      ..lineTo(10, 17.8)
      ..cubicTo(6.7, 17.2, 4.2, 14.7, 4.2, 11.6)
      ..close();
    c.drawPath(bowl, paint);
    c.restore();
  }

  /// 주먹밥(커스텀 팀) — 둥근 삼각 + 김 띠. 이모지 대신 벡터(캔버스 tofu 방지).
  void _riceBall(Canvas c, double x, double y, double s, Color col) {
    final p = _sp(col, s * 0.1);
    final path = Path()
      ..moveTo(x + s * 0.5, y + s * 0.1)
      ..quadraticBezierTo(x + s * 0.58, y + s * 0.12, x + s * 0.9, y + s * 0.78)
      ..quadraticBezierTo(x + s * 0.94, y + s * 0.9, x + s * 0.8, y + s * 0.9)
      ..lineTo(x + s * 0.2, y + s * 0.9)
      ..quadraticBezierTo(x + s * 0.06, y + s * 0.9, x + s * 0.1, y + s * 0.78)
      ..quadraticBezierTo(x + s * 0.42, y + s * 0.12, x + s * 0.5, y + s * 0.1)
      ..close();
    c.drawPath(path, p);
    c.drawRect(
      Rect.fromLTWH(x + s * 0.3, y + s * 0.62, s * 0.4, s * 0.28),
      Paint()..color = col,
    );
  }

  void _volley(Canvas c, double cx, double cy, double r, Color col) {
    final p = _sp(col, r * 0.14);
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

  @override
  bool shouldRepaint(covariant MyCardPainter old) =>
      old.data != data || old.logo != logo;
}
