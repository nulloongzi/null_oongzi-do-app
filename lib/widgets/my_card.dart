// my_card.dart — 내 네임카드 공유 이미지. 클럽 스토리 카드(story_card.dart)와
// 같은 미감·같은 기법으로 그린다: dart:ui Canvas 직접 렌더 → 결정적, 위젯 트리 불필요.
//
// 왜 CustomPainter인가: 이전 판은 340px 위젯 카드를 RepaintBoundary로 3배 확대해 떴다.
// 기기 폰트·텍스트 스케일에 따라 결과가 흔들리고, 클럽 카드와 미감이 따로 놀았다.
// 공유되는 이미지 두 종류가 서로 다른 브랜드처럼 보이면 안 된다.
//
// 두 규격:
//  · 스토리형 1080×1920 (9:16) — 네임카드 + 도시락통
//  · 피드형  1080×1350 (4:5)  — 네임카드(가로) + [도시락통 | 시간표]
//    인스타 피드의 제 규격이 4:5다. 9:16으로 내면 피드에서 잘린다.
//
// 도시락통은 보온도시락 스택 은유로 그린다 — 맨 아래 밥(1칸), 그 위 국(1칸),
// 맨 위 반찬(한 줄 3칸). 5칸이 도시락 슬롯 수와 정확히 맞고, 칸 색이 시간표
// 블록 색과 같아서 도시락통이 곧 시간표의 범례가 된다.
//
// 공유 토큰(story_card.dart와 동일): 크림 배경 + 웜 비네트, 라운드 카드,
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
  final List<MyCardSlot> slots; // 5칸: 0=밥 1=국 2~4=반찬
  final List<DietTeam> diet; // 시간표용
  final String url; // QR 목적지
  final bool feed; // true=피드형(4:5, 시간표 포함) / false=스토리형(9:16)

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

/// 배치 계산 결과. 블록이 푸터(QR)를 침범하지 않는지 좌표로 검증하기 위해
/// 그리기와 분리했다.
class MyCardLayout {
  final Rect hero;
  final Rect box; // 도시락통
  final Rect diet; // 시간표 (스토리형은 Rect.zero)
  const MyCardLayout({
    required this.hero,
    required this.box,
    required this.diet,
  });

  /// 마지막 블록의 아래끝. 이 값이 footTop을 넘으면 QR/CTA를 덮는다.
  double get bottom => math.max(
    hero.bottom,
    math.max(box.bottom, diet == Rect.zero ? 0.0 : diet.bottom),
  );
}

/// 공유용 PNG 바이트로 렌더. 규격은 data.feed 에 따라 4:5 / 9:16.
/// 번들 Pretendard라 한글 tofu 없음.
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

class MyCardPainter extends CustomPainter {
  final MyCardData data;
  final ui.Image? logo;
  MyCardPainter(this.data, {this.logo});

  static const _w = 1080.0, _pad = 80.0;
  static const _ink = Color(0xFF3D2C22);
  static const _sub = Color(0xFFA99A8C);
  static const _dark = Color(0xFF4E342E);
  static const _brown = Color(0xFF8D6E63);
  static const _yellow = Color(0xFFFAC710);
  static const _cream = Color(0xFFFBF3E2);
  static const _cardBg = Color(0xFFFFFDF8);
  static const _hair = Color(0x228D6E63); // 도시락통 윤곽

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

  Size get canvasSize => Size(_w, data.feed ? 1350.0 : 1920.0);
  double get _h => canvasSize.height;

  // 헤더/푸터 위치는 규격별로. 스토리형은 클럽 카드와 동일 좌표를 유지한다.
  double get _headerY => data.feed ? 72.0 : 118.0;
  double get _footH => data.feed ? 176.0 : 210.0;
  double get footTop => data.feed ? 1074.0 : 1460.0;
  double get _zoneTop => data.feed ? 176.0 : 252.0;
  double get _qrSize => data.feed ? 158.0 : 190.0;

  static const _gap = 30.0;

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

  /// 주어진 폭·줄수에 들어가는 가장 큰 글자 크기로 레이아웃. 다 안 되면 마지막(가장 작은) 것.
  TextPainter _fit(
    String text, {
    required double maxWidth,
    required int maxLines,
    required List<double> sizes,
  }) {
    TextPainter? last;
    for (final s in sizes) {
      final tp = _tp(
        text,
        _st(s, FontWeight.w700, _dark),
        maxWidth: maxWidth,
        maxLines: maxLines,
        align: TextAlign.center,
      );
      if (!tp.didExceedMaxLines) return tp;
      last = tp;
    }
    return last!;
  }

  // ── 배치 ───────────────────────────────────────────────────────
  MyCardLayout layout() {
    final zoneBot = footTop - (data.feed ? 34.0 : 46.0);
    final zoneH = zoneBot - _zoneTop;
    const cw = _w - _pad * 2;

    if (data.feed) {
      // 가로 히어로 + 아래 2열(도시락통 | 시간표). 4:5는 세로가 귀해서
      // 히어로를 띠로 눕히고, 남는 높이를 통째로 2열에 준다.
      final heroH = _heroFeedHeight();
      final rowY = _zoneTop + heroH + _gap;
      final rowH = zoneH - heroH - _gap;
      const boxW = 400.0, colGap = 24.0;
      return MyCardLayout(
        hero: Rect.fromLTWH(_pad, _zoneTop, cw, heroH),
        box: Rect.fromLTWH(_pad, rowY, boxW, rowH),
        diet: Rect.fromLTWH(
          _pad + boxW + colGap,
          rowY,
          cw - boxW - colGap,
          rowH,
        ),
      );
    }

    // 스토리형: 세로 히어로 + 도시락통(가운데, 시원하게).
    final heroH = _heroStoryHeight();
    final boxH = zoneH - heroH - _gap;
    const boxW = 640.0;
    return MyCardLayout(
      hero: Rect.fromLTWH(_pad, _zoneTop, cw, heroH),
      box: Rect.fromLTWH((_w - boxW) / 2, _zoneTop + heroH + _gap, boxW, boxH),
      diet: Rect.zero,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 미리보기(작은 위젯)와 내보내기가 같은 좌표계를 쓰도록 스케일.
    if (size.width != _w) canvas.scale(size.width / _w);

    _background(canvas);
    _brandHeader(canvas);

    final l = layout();
    if (data.feed) {
      _heroFeed(canvas, l.hero);
    } else {
      _heroStory(canvas, l.hero);
    }
    _bento(canvas, l.box);
    if (l.diet != Rect.zero) _timetable(canvas, l.diet);
    _footer(canvas);
  }

  // ── 배경 / 헤더 (클럽 스토리 카드와 동일) ───────────────────────
  void _background(Canvas canvas) {
    final all = Rect.fromLTWH(0, 0, _w, _h);
    canvas.drawRect(all, Paint()..color = _cream);
    canvas.drawRect(
      all,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(_w / 2, _h * 0.42),
          _h * 0.7,
          const [Color(0x99FFFCF0), Color(0x80F0E2C4)],
          const [0.15, 1.0],
        ),
    );
  }

  void _brandHeader(Canvas canvas) {
    final fs = data.feed ? 42.0 : 50.0;
    final tile = data.feed ? 54.0 : 64.0;
    final wm = _tp(t('brand'), _st(fs, FontWeight.w800, _ink));
    const tgap = 18.0;
    final hsx = (_w - (tile + tgap + wm.width)) / 2;
    final hty = _headerY;
    _sh2(canvas, Rect.fromLTWH(hsx, hty, tile, tile), 18, 14, 6, 0.16);
    _rr(canvas, hsx, hty, tile, tile, 18, Paint()..color = Colors.white);
    if (logo != null) {
      _logoIn(canvas, Rect.fromLTWH(hsx, hty, tile, tile), 1.0, 18);
    } else {
      _riceBowl(
        canvas,
        hsx + tile * 0.2,
        hty + tile * 0.2,
        tile * 0.6,
        _yellow,
      );
    }
    wm.paint(canvas, Offset(hsx + tile + tgap, hty + tile / 2 - wm.height / 2));
  }

  /// 로고 비트맵을 rect 안에 비율(scale)만큼 중앙 배치. clip은 radius>0일 때만.
  void _logoIn(Canvas canvas, Rect rect, double scale, double radius) {
    final s = math.min(rect.width, rect.height) * scale;
    final dst = Rect.fromCenter(center: rect.center, width: s, height: s);
    canvas.save();
    if (radius > 0) {
      canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    }
    canvas.drawImageRect(
      logo!,
      Rect.fromLTWH(0, 0, logo!.width.toDouble(), logo!.height.toDouble()),
      dst,
      Paint(),
    );
    canvas.restore();
  }

  // ── 히어로: 네임카드 ───────────────────────────────────────────
  // 앱 프로필 카드(밥 색 배경 + 큰 밥이름 + 가입일 + 대표팀 뱃지)를 공유 규격으로.
  static const _heroPad = 52.0;

  TextPainter _nameStoryTp() => _tp(
    data.nickname,
    _st(76, FontWeight.w800, _ink),
    maxWidth: _w - _pad * 2 - _heroPad * 2,
    maxLines: 2,
    align: TextAlign.center,
  );

  double _heroStoryHeight() {
    var hgt = _heroPad + 132 + 26 + _nameStoryTp().height;
    if ((data.joined ?? '').isNotEmpty) hgt += 12 + 32;
    if ((data.mainTeam ?? '').isNotEmpty) hgt += 26 + 72;
    return hgt + _heroPad;
  }

  void _heroStory(Canvas canvas, Rect r) {
    _heroShell(canvas, r);
    var cy = r.top + _heroPad;
    const es = 132.0;
    _emblem(canvas, Offset(_w / 2, cy + es / 2), es);
    cy += es + 26;

    final nameTp = _nameStoryTp();
    nameTp.paint(canvas, Offset(r.left + _heroPad, cy));
    cy += nameTp.height;

    if ((data.joined ?? '').isNotEmpty) {
      cy += 12;
      final jt = _tp(data.joined!, _st(30, FontWeight.w500, _brown));
      jt.paint(canvas, Offset(_w / 2 - jt.width / 2, cy));
      cy += 32;
    }
    if ((data.mainTeam ?? '').isNotEmpty) {
      cy += 26;
      _teamPill(canvas, Offset(_w / 2, cy), 72, 36, centered: true);
    }
  }

  double _heroFeedHeight() => 200;

  void _heroFeed(Canvas canvas, Rect r) {
    _heroShell(canvas, r);
    // 가로 띠: 엠블럼 왼쪽, 텍스트 오른쪽.
    const es = 108.0;
    final ecx = r.left + 40 + es / 2;
    _emblem(canvas, Offset(ecx, r.center.dy), es);

    final tx = ecx + es / 2 + 32;
    final maxW = r.right - 40 - tx;
    final nameTp = _tp(
      data.nickname,
      _st(54, FontWeight.w800, _ink),
      maxWidth: maxW,
    );
    final hasJoin = (data.joined ?? '').isNotEmpty;
    final hasTeam = (data.mainTeam ?? '').isNotEmpty;
    var blockH = nameTp.height;
    if (hasJoin) blockH += 6 + 28;
    if (hasTeam) blockH += 14 + 56;
    var cy = r.center.dy - blockH / 2;

    nameTp.paint(canvas, Offset(tx, cy));
    cy += nameTp.height;
    if (hasJoin) {
      cy += 6;
      _tp(
        data.joined!,
        _st(26, FontWeight.w500, _brown),
      ).paint(canvas, Offset(tx, cy));
      cy += 28;
    }
    if (hasTeam) {
      cy += 14;
      _teamPill(canvas, Offset(tx, cy), 56, 30, centered: false, maxW: maxW);
    }
  }

  void _heroShell(Canvas canvas, Rect r) {
    _sh2(canvas, r, 28, 40, 20, 0.15);
    _rr(
      canvas,
      r.left,
      r.top,
      r.width,
      r.height,
      28,
      Paint()..color = data.bgColor,
    );
    // 밥 색이 어떤 값이든 글씨가 읽히도록 카드 안쪽을 살짝 밝힌다.
    _rr(
      canvas,
      r.left,
      r.top,
      r.width,
      r.height,
      28,
      Paint()..color = const Color(0x1AFFFFFF),
    );
    // 좌상단 밥 종류 워터마크 — 앱 네임카드(.pc-rice-type)와 같은 자리·톤.
    if (data.riceType.isNotEmpty) {
      _tp(
        data.riceType,
        _st(26, FontWeight.w700, const Color(0x4D5D4037)),
      ).paint(canvas, Offset(r.left + 28, r.top + 24));
    }
  }

  /// 흰 원 + 브랜드 로고. 단순화 밥그릇 벡터는 24px 스탬프용 패스라 크게 키우면
  /// 밥·그릇 사이 틈이 도드라져 햄버거처럼 보인다 → 로고 비트맵 우선.
  void _emblem(Canvas canvas, Offset center, double es) {
    _sh2(
      canvas,
      Rect.fromCircle(center: center, radius: es / 2),
      es / 2,
      16,
      8,
      0.16,
    );
    canvas.drawCircle(center, es / 2, Paint()..color = Colors.white);
    if (logo != null) {
      _logoIn(
        canvas,
        Rect.fromCenter(center: center, width: es, height: es),
        0.68,
        0,
      );
    } else {
      _riceBowl(
        canvas,
        center.dx - es * 0.3,
        center.dy - es * 0.3,
        es * 0.6,
        _yellow,
      );
    }
  }

  /// 대표팀 알약. centered=true면 at을 중심으로, false면 왼쪽 기준.
  void _teamPill(
    Canvas canvas,
    Offset at,
    double ph,
    double fs, {
    required bool centered,
    double maxW = double.infinity,
  }) {
    final icoS = ph * 0.5;
    final tt = _tp(
      data.mainTeam!,
      _st(fs, FontWeight.w700, _ink),
      maxWidth: maxW == double.infinity ? double.infinity : maxW - 110,
    );
    final pw = tt.width + 30 + icoS + 20 + 30;
    final psx = centered ? at.dx - pw / 2 : at.dx;
    final psy = at.dy;
    _rr(canvas, psx, psy, pw, ph, ph / 2, Paint()..color = Colors.white);
    if (data.mainTeamCustom) {
      _riceBall(canvas, psx + 30, psy + (ph - icoS) / 2, icoS, _brown);
    } else {
      _volley(canvas, psx + 30 + icoS / 2, psy + ph / 2, icoS / 2, _yellow);
    }
    tt.paint(
      canvas,
      Offset(psx + 30 + icoS + 20, psy + ph / 2 - tt.height / 2),
    );
  }

  // ── 도시락통 (보온도시락 스택) ─────────────────────────────────
  // 위→아래: 반찬(3칸) / 국(1칸) / 밥(1칸). 슬롯 0=밥 1=국 2~4=반찬.
  // 칸 색은 시간표 블록 색과 같아서, 이 통이 곧 시간표의 범례가 된다.
  void _bento(Canvas canvas, Rect r) {
    _sh2(canvas, r, 30, 40, 20, 0.15);
    _rr(canvas, r.left, r.top, r.width, r.height, 30, Paint()..color = _cardBg);
    // 보온도시락 외피 느낌: 얇은 윤곽 + 좌우 잠금쇠.
    _rr(
      canvas,
      r.left,
      r.top,
      r.width,
      r.height,
      30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _hair,
    );
    for (final side in [r.left - 5, r.right - 9]) {
      _rr(
        canvas,
        side,
        r.top + r.height * 0.42,
        14,
        54,
        7,
        Paint()..color = _hair,
      );
    }

    const ip = 26.0;
    final ix = r.left + ip, iw = r.width - ip * 2;
    var cy = r.top + ip;

    // 헤더: 도시락 n/5
    final title = _tp(t('mycard_lunchbox'), _st(34, FontWeight.w800, _ink));
    title.paint(canvas, Offset(ix, cy));
    final filled = data.slots.where((s) => s.name != null).length;
    final cnt = _tp('$filled / 5', _st(26, FontWeight.w600, _sub));
    cnt.paint(canvas, Offset(ix + iw - cnt.width, cy + 6));
    cy += 46;

    // 남은 높이를 3단으로: 반찬 0.30 / 국 0.28 / 밥 0.42 (밥이 가장 크다)
    const capH = 26.0, tierGap = 14.0;
    final body = (r.bottom - ip) - cy - capH * 3 - tierGap * 2;
    final hBanchan = body * 0.30, hGuk = body * 0.28, hBap = body * 0.42;

    cy = _tier(canvas, ix, cy, iw, hBanchan, t('mycard_tier_sides'), [2, 3, 4]);
    cy += tierGap;
    cy = _tier(canvas, ix, cy, iw, hGuk, t('mycard_tier_soup'), [1]);
    cy += tierGap;
    _tier(canvas, ix, cy, iw, hBap, t('mycard_tier_rice'), [0]);
  }

  /// 한 단(층)을 그린다. 캡션 + 칸들. 다음 y를 돌려준다.
  double _tier(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    String caption,
    List<int> slots,
  ) {
    _tp(
      caption,
      _st(22, FontWeight.w700, const Color(0x808D6E63)),
    ).paint(canvas, Offset(x + 2, y));
    final top = y + 26;
    const cellGap = 10.0;
    final cw = (w - cellGap * (slots.length - 1)) / slots.length;
    for (var i = 0; i < slots.length; i++) {
      _cell(
        canvas,
        Rect.fromLTWH(x + (cw + cellGap) * i, top, cw, h),
        slots[i],
        wide: slots.length == 1,
      );
    }
    return top + h;
  }

  /// 도시락 칸 하나. 채워진 칸은 슬롯 색으로 칠하고 테두리를 두른다.
  void _cell(Canvas canvas, Rect r, int slot, {required bool wide}) {
    final s = slot < data.slots.length ? data.slots[slot] : const MyCardSlot();
    if (s.name == null) {
      _rr(
        canvas,
        r.left,
        r.top,
        r.width,
        r.height,
        14,
        Paint()..color = const Color(0x40FFFFFF),
      );
      _rr(
        canvas,
        r.left,
        r.top,
        r.width,
        r.height,
        14,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _hair,
      );
      return;
    }
    _rr(
      canvas,
      r.left,
      r.top,
      r.width,
      r.height,
      14,
      Paint()..color = _slotBg[slot],
    );
    _rr(
      canvas,
      r.left,
      r.top,
      r.width,
      r.height,
      14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = _slotRail[slot],
    );
    // 두 줄로 못 박고 글자를 줄인다. 좁은 반찬 칸에서 긴 팀 이름이 3줄로
    // 쪼개지면 세로로 길쭉해져 읽기 어려웠다 — 줄 수를 고정하고 크기를 양보한다.
    final tp = _fit(
      s.name!,
      maxWidth: r.width - 20,
      maxLines: 2,
      sizes: wide
          ? const [30.0, 26.0, 23.0, 20.0]
          : const [21.0, 19.0, 17.0, 15.0, 13.0],
    );
    tp.paint(
      canvas,
      Offset(r.left + (r.width - tp.width) / 2, r.center.dy - tp.height / 2),
    );
    // 커스텀 팀은 주먹밥 표식(이모지 대신 벡터).
    if (s.isCustom && wide) {
      _riceBall(canvas, r.left + 14, r.top + 12, 26, _slotRail[slot]);
    }
  }

  // ── 시간표 (피드형 우측) ───────────────────────────────────────
  // 블록에 팀 이름을 쓰지 않는다 — 좁아서 읽히지도 않고, 색이 도시락 칸과
  // 같으므로 왼쪽 도시락통이 범례 역할을 한다.
  void _timetable(Canvas canvas, Rect r) {
    _sh2(canvas, r, 30, 40, 20, 0.15);
    _rr(canvas, r.left, r.top, r.width, r.height, 30, Paint()..color = _cardBg);

    const ip = 22.0;
    final ix = r.left + ip;
    var cy = r.top + ip;
    _tp(
      t('mycard_timetable'),
      _st(30, FontWeight.w800, _ink),
    ).paint(canvas, Offset(ix, cy));
    cy += 44;

    final all = <({SchedEvent e, DietTeam t})>[];
    for (final tm in data.diet) {
      for (final e in tm.events) {
        all.add((e: e, t: tm));
      }
    }
    if (all.isEmpty) {
      final tp = _tp(
        t('lb_no_sched'),
        _st(24, FontWeight.w500, _sub),
        maxWidth: r.width - ip * 2,
        maxLines: 2,
        align: TextAlign.center,
      );
      tp.paint(
        canvas,
        Offset(r.left + (r.width - tp.width) / 2, r.center.dy - tp.height / 2),
      );
      return;
    }

    const timeW = 42.0, headH = 34.0;
    final gx = ix + timeW, gy = cy + headH;
    final gw = r.width - ip * 2 - timeW, gh = (r.bottom - ip) - gy;
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
      final tp = _tp(i18nDay(scheduleDays[d]), _st(22, FontWeight.w700, _ink));
      tp.paint(
        canvas,
        Offset(
          gx + colW * d + (colW - tp.width) / 2,
          cy + (headH - tp.height) / 2,
        ),
      );
    }

    // 시간축: 24시간 숫자만, 촘촘하면 두 시간마다. 'PM 12/PM 1/…'을 매 시간
    // 찍으니 축이 글자로 꽉 차 답답했다.
    final every = rowH >= 40 ? 1 : 2;
    final hLine = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    for (var i = 0; i <= hours; i++) {
      final ly = gy + rowH * i;
      canvas.drawLine(Offset(gx, ly), Offset(gx + gw, ly), hLine);
      if (i < hours && (startH + i) % every == 0) {
        final tp = _tp('${startH + i}', _st(20, FontWeight.w500, _sub));
        tp.paint(canvas, Offset(gx - 8 - tp.width, ly + 3));
      }
    }
    final vLine = Paint()
      ..color = const Color(0x11000000)
      ..strokeWidth = 1;
    for (var d = 0; d <= scheduleDays.length; d++) {
      final lx = gx + colW * d;
      canvas.drawLine(Offset(lx, gy), Offset(lx, gy + gh), vLine);
    }

    // 이벤트 블록: 겹치면 칸을 레인으로 나눠 나란히. 앱 식단표에서 가져온
    // '5px 들여쓰기'는 나중 블록이 앞 블록을 덮어버려서(4개 이상 겹치면
    // indent가 0으로 리셋돼 완전히 가림) 이 카드에선 쓸 수 없다 —
    // 블록에 팀 이름이 없으니 5px 띠 하나가 유일한 단서였다.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(gx, gy, gw, gh));
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
        final by = gy + (e.start - startH) * rowH;
        final bw = lw - (lanes[i].lanes > 1 ? 2 : 0);
        final bh = math.max(14.0, (e.end - e.start) * rowH - 3);
        // 색을 진하게: 옅은 배경 + 얇은 띠는 작게 보면 선처럼 읽혔다.
        _rr(
          canvas,
          bx,
          by,
          bw,
          bh,
          6,
          Paint()..color = Color.lerp(_slotBg[slot], _slotRail[slot], 0.45)!,
        );
        canvas.drawRect(
          Rect.fromLTWH(bx, by, math.min(4.0, bw), bh),
          Paint()..color = _slotRail[slot],
        );
      }
    }
    canvas.restore();
  }

  // ── 푸터: QR + CTA (클럽 스토리 카드와 동일 구조) ───────────────
  void _footer(Canvas canvas) {
    final footY = footTop, footH = _footH, qrSize = _qrSize;
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

    final tx = qrX + qrSize + 44;
    final ctaFs = data.feed ? 38.0 : 42.0;
    _tp(
      'S C A N',
      _st(22, FontWeight.w700, _sub),
    ).paint(canvas, Offset(tx, footY + 26));
    final cta = _tp(
      t('mycard_cta'),
      _st(ctaFs, FontWeight.w800, _ink),
      maxWidth: _w - _pad - tx,
      maxLines: 2,
    );
    cta.paint(canvas, Offset(tx, footY + 58));
    final urlStr = data.url
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');
    _tp(
      urlStr,
      _st(25, FontWeight.w500, _brown),
      maxWidth: _w - _pad - tx,
    ).paint(canvas, Offset(tx, footY + 58 + cta.height + 8));
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
