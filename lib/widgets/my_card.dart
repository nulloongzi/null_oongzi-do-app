// my_card.dart — 내 공유 이미지(포장하기). 팀·픽업 카드(story_card.dart)와 같은 틀·같은
// 키트(share_card_kit.dart)로 그린다: dart:ui Canvas 직접 렌더 → 결정적, 위젯 트리 불필요.
//
// 두 장 — 목적으로 나눈다(규격은 둘 다 스토리 9:16, docs/design-system.md §7-4 ·
// 웹 js/my-card.js 와 같은 숫자):
//  · 네임카드 card — "나는 어떤 밥이야". 밥색 필드(밥도감 번호·희귀도·밥 이름·한 줄 성격·
//    밥이름·대표팀) + 도시락통 + 밥도감(내 밥상 5×5 도장판 · 상차림 단계)
//  · 식단표 diet   — "나 이번 주 이때 운동해". 한 줄 헤드라인(화·목·토 저녁형) + 시간표
// 밥친구는 밥도감의 '밥 종류'로만 들어간다 — 친구 이름·팀·요일·시간은 어느 카드에도 없다.
//
// 구조(두 장 공통): 전폭 밥색 필드(머리글 + 신원) / 본문 카드(필드 아랫단을 덮음) /
// 티켓 스텁(QR). 남는 세로는 탄력 요소(네임카드 도시락통 · 식단표 시간표)가 먹는다.
//
// 도시락통은 화면 UI(웹 .lunchbox-grid)와 같은 6열 그리드. 칸 색이 식단표 블록 색과
// 같아서 도시락통(식단표 카드에선 팀 범례)이 곧 식단표의 범례가 된다.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/i18n.dart';
import '../services/rice_dex.dart';
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

enum MyCardMode { card, diet }

class MyCardData {
  final String nickname; // 밥이름 전체 "백미밥-a3z"
  final String riceType; // 밥 종류 "백미밥"
  final Color bgColor; // 밥 종류 색(프로필) — 필드 색
  final String? joined; // "가입일: 2026.7.1"
  final String? mainTeam; // 대표팀(첫 찜팀)
  final bool mainTeamCustom;
  final List<MyCardSlot> slots; // 5칸: 0=밥 1=국 2~4=반찬
  final List<DietTeam> diet; // 식단표용
  final String url; // QR 목적지
  final MyCardMode mode;
  final RiceDex? dex; // 밥도감(나 + 밥친구 전체의 밥 종류). null 이면 riceType 하나로 센다

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
    this.mode = MyCardMode.card,
    this.dex,
  });
}

/// 배치 계산 결과. 블록이 스텁(QR)을 침범하지 않는지 좌표로 검증하기 위해
/// 그리기와 분리했다. 쓰지 않는 블록은 Rect.zero.
class MyCardLayout {
  final CardFmt fmt;
  final double fieldH; // 밥색 필드 아래끝 (y=0 부터)
  final Rect identity;
  final Rect bento; // 도시락통 (네임카드)
  final Rect dex; // 밥도감 (네임카드)
  final Rect diet; // 시간표 (식단표)
  final double stubTop; // QR 스텁 윗단(절취선)
  const MyCardLayout({
    required this.fmt,
    required this.fieldH,
    required this.identity,
    required this.stubTop,
    this.bento = Rect.zero,
    this.dex = Rect.zero,
    this.diet = Rect.zero,
  });

  /// 본문 블록의 아래끝. 이 값이 stubTop - gap 을 넘으면 QR 스텁을 덮는다.
  double get bottom => [
    identity.bottom,
    if (bento != Rect.zero) bento.bottom,
    if (dex != Rect.zero) dex.bottom,
    if (diet != Rect.zero) diet.bottom,
  ].reduce(math.max);
}

/// 식단표 헤드라인(웹 myCardDietSummary 와 같은 규칙).
///  · 요일: 운동하는 요일(월→일), 5일 이상이면 "주 N일"
///  · 성향: 시작 17시 이후 저녁형 · 12시 이후 낮형 · 그 전 아침형 — 많은 쪽(동률은 저녁 > 낮)
///  · 요약: "주 N회 · N시간 코트 위"(시간은 0.5 단위 반올림)
///  · 범례: 일정이 있는 팀, 도시락 칸 순서
({String head, String sub, List<({int slot, String name})> legend}) dietSummary(
  List<DietTeam> teams,
) {
  final days = <int>{};
  var hours = 0.0, n = 0, eve = 0, noon = 0, morn = 0;
  final legend = <({int slot, String name})>[];
  for (final tm in teams) {
    if (tm.events.isEmpty) continue;
    legend.add((slot: tm.slotIdx, name: tm.name));
    for (final e in tm.events) {
      final di = scheduleDays.indexOf(e.day);
      if (di < 0) continue;
      n++;
      days.add(di);
      hours += math.max(0, e.end - e.start);
      if (e.start >= 17) {
        eve++;
      } else if (e.start >= 12) {
        noon++;
      } else {
        morn++;
      }
    }
  }
  legend.sort((a, b) => a.slot.compareTo(b.slot));
  if (n == 0) return (head: t('mycard_diet_empty'), sub: '', legend: legend);
  final kind = eve >= noon && eve >= morn
      ? 'mycard_kind_eve'
      : (noon >= morn ? 'mycard_kind_noon' : 'mycard_kind_morn');
  final ds = days.toList()..sort();
  final head = ds.length <= 4
      ? '${ds.map((d) => i18nDay(scheduleDays[d])).join('·')} ${t(kind)}'
      : '${tf('mycard_diet_ndays', {'n': '${ds.length}'})} ${t(kind)}';
  final h = (hours * 2).round() / 2;
  final hs = h == h.roundToDouble() ? '${h.toInt()}' : '$h';
  return (
    head: head,
    sub: tf('mycard_diet_sub', {'n': '$n', 'h': hs}),
    legend: legend,
  );
}

/// 공유용 PNG 바이트로 렌더. 둘 다 9:16.
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

// 웹 js/my-card.js 의 BENTO / DEX / ID_CARD / ID_DIET 와 같은 값.
const _bentoMin = 280.0, _bentoMax = 760.0;
const _dexH = 324.0, _dexCell = 44.0, _dexGap = 10.0, _dexCols = 5;
// 네임카드 신원(가운데 세로 스택)
const _cChip = 52.0, _cGapC = 20.0, _cRice = 124.0, _cRiceMin = 72.0;
const _cGapR = 18.0, _cLine = 36.0, _cGapL = 22.0, _cNick = 34.0;
const _cGapK = 26.0, _cPill = 60.0;
// 식단표 신원(왼쪽 정렬)
const _dWho = 48.0, _dGapW = 24.0, _dHead = 84.0, _dHeadMin = 52.0;
const _dGapH = 12.0, _dSub = 38.0, _dGapS = 24.0, _dChip = 48.0;
const _legendBlue = Color(0xFF81D4FA); // 전설(밥아저씨) — 도감에서 혼자 다른 색

Color _hex(String h) =>
    Color(int.parse(h.replaceFirst('#', ''), radix: 16) | 0xFF000000);

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

  CardFmt get _fmt => ShareCard.story;
  Size get canvasSize => Size(ShareCard.w, _fmt.h);

  /// QR 스텁 윗단.
  double get stubTop => ShareCard.stubTop(_fmt);

  bool get _hasJoined => (data.joined ?? '').isNotEmpty;
  bool get _hasTeam => (data.mainTeam ?? '').isNotEmpty;
  RiceDex get _dexState =>
      data.dex ?? RiceDex.build(data.riceType, const <String>[]);

  double _identityCardH() {
    var h = _cRice + _cGapL + _cNick;
    if (_dexState.mine != null) h += _cChip + _cGapC + _cGapR + _cLine;
    if (_hasTeam) h += _cGapK + _cPill;
    return h;
  }

  static const double _identityDietH =
      _dWho + _dGapW + _dHead + _dGapH + _dSub + _dGapS + _dChip;

  // ── 배치 (웹 myCardLayout 과 같은 산술) ───────────────────────
  MyCardLayout layout() {
    final fmt = _fmt;
    final st = ShareCard.stubTop(fmt);
    final headBot = fmt.top + ShareCard.headerH;
    final bodyBot = st - ShareCard.gap;
    const x = ShareCard.m, w = ShareCard.bodyW;

    if (data.mode == MyCardMode.diet) {
      final tY = headBot + 32 + _identityDietH + 40;
      return MyCardLayout(
        fmt: fmt,
        fieldH: tY + ShareCard.overlap,
        identity: Rect.fromLTWH(x, headBot + 32, w, _identityDietH),
        diet: Rect.fromLTWH(x, tY, w, bodyBot - tY),
        stubTop: st,
      );
    }
    final idH = _identityCardH();
    final dexY = bodyBot - _dexH;
    final bentoBot = dexY - ShareCard.gap;
    final minTop = headBot + 32 + idH + 40;
    final bentoH = (bentoBot - minTop).clamp(_bentoMin, _bentoMax);
    final cardY = bentoBot - bentoH;
    return MyCardLayout(
      fmt: fmt,
      fieldH: cardY + ShareCard.overlap,
      // 신원은 머리글 ~ 도시락통 사이 가운데 (남는 세로가 위아래로 고르게)
      identity: Rect.fromLTWH(x, headBot + (cardY - headBot - idH) / 2, w, idH),
      bento: Rect.fromLTWH(x, cardY, w, bentoH),
      dex: Rect.fromLTWH(x, dexY, w, _dexH),
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
    if (data.mode == MyCardMode.diet) {
      _identityDiet(canvas, l.identity);
      _timetable(canvas, l.diet);
      cardStub(canvas, l.fmt, data.url, t('mycard_cta_diet'));
    } else {
      _identityCard(canvas, l.identity);
      _bento(canvas, l.bento);
      _dex(canvas, l.dex);
      cardStub(canvas, l.fmt, data.url, t('mycard_cta'));
    }
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
    final lb = cardEllip(
      stripEmoji(data.mainTeam),
      st,
      maxW - (24 + ico + 12 + 26),
    );
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

  // 밥이름·팀 이름은 사용자 입력이라 이모지가 섞일 수 있다 — 캔버스에서는 □로 깨지니 뺀다
  String get _nick => stripEmoji(data.nickname);

  // ── 네임카드 신원 ─────────────────────────────────────────────
  // [밥도감 No.01 · 흔함] / 밥 이름(크게) / 한 줄 성격 / 밥이름 · 가입일 / 대표팀
  void _chipRow(
    Canvas c,
    double cx,
    double y,
    double h,
    List<({String text, Color bg, Color fg})> chips,
  ) {
    const gap = 12.0;
    final ws = [
      for (final ch in chips)
        cardMeasure(ch.text, cardStyle(24, FontWeight.w800, ch.fg)) + 44,
    ];
    final total =
        ws.fold<double>(0, (s, w) => s + w) + gap * (chips.length - 1);
    var x = cx - total / 2;
    for (var i = 0; i < chips.length; i++) {
      c.drawRRect(
        cardRRect(x, y, ws[i], h, h / 2),
        Paint()..color = chips[i].bg,
      );
      cardText(
        c,
        chips[i].text,
        cardStyle(24, FontWeight.w800, chips[i].fg),
        x + ws[i] / 2,
        y + h / 2 + 1,
        align: TextAlign.center,
        middle: true,
      );
      x += ws[i] + gap;
    }
  }

  void _identityCard(Canvas c, Rect r) {
    final cx = r.center.dx;
    var y = r.top;
    final mine = _dexState.mine;
    if (mine != null) {
      final legend = mine.rarity == RiceRarity.legend;
      _chipRow(c, cx, y, _cChip, [
        (
          text: tf('dex_no', {'n': mine.no.toString().padLeft(2, '0')}),
          bg: _ink,
          fg: ShareCard.card,
        ),
        (
          text: t('dex_r_${mine.rarity.name}'),
          bg: legend ? _legendBlue : ShareCard.card,
          fg: legend ? _ink : _brown,
        ),
      ]);
      y += _cChip + _cGapC;
    }
    final rice = stripEmoji(data.riceType);
    final fs = cardFit(rice, r.width, _cRice, _cRiceMin, FontWeight.w900);
    final rst = cardStyle(fs, FontWeight.w900, _ink);
    cardText(
      c,
      cardEllip(rice, rst, r.width),
      rst,
      cx,
      y + _cRice / 2,
      align: TextAlign.center,
      middle: true,
    );
    y += _cRice;
    if (mine != null) {
      y += _cGapR;
      final lst = cardStyle(32, FontWeight.w600, _dark);
      cardText(
        c,
        cardEllip(t('rice_line_${mine.no}'), lst, r.width),
        lst,
        cx,
        y + _cLine / 2,
        align: TextAlign.center,
        middle: true,
      );
      y += _cLine;
    }
    y += _cGapL;
    final kst = cardStyle(28, FontWeight.w700, _brown);
    final who = _hasJoined ? '$_nick  ·  ${data.joined}' : _nick;
    cardText(
      c,
      cardEllip(who, kst, r.width),
      kst,
      cx,
      y + _cNick / 2,
      align: TextAlign.center,
      middle: true,
    );
    y += _cNick;
    if (_hasTeam) {
      y += _cGapK;
      _teamPill(c, cx, y, _cPill, r.width, centered: true);
    }
  }

  // ── 밥도감 ─────────────────────────────────────────────────────
  // 왼쪽 5×5 도장판(모은 밥은 그 밥 색, 나는 굵은 먹색 테두리, 못 모은 칸은 점선),
  // 오른쪽 상차림 단계 · 모은 수 · 다음 단계까지.
  void _dex(Canvas c, Rect r) {
    cardPanel(c, r);
    final x = _dexState, list = RiceDex.list;
    final rows = (list.length / _dexCols).ceil();
    const gw = _dexCols * _dexCell + (_dexCols - 1) * _dexGap;
    final gh = rows * _dexCell + (rows - 1) * _dexGap;
    final gx = r.left + 40, gy = r.top + (r.height - gh) / 2;
    const rad = _dexCell / 2;
    for (var i = 0; i < list.length; i++) {
      final it = list[i];
      final o = Offset(
        gx + (i % _dexCols) * (_dexCell + _dexGap) + rad,
        gy + (i ~/ _dexCols) * (_dexCell + _dexGap) + rad,
      );
      final isMine = x.mine?.no == it.no;
      if (x.owned.contains(it.name)) {
        c.drawCircle(o, rad - 2, Paint()..color = _hex(it.color));
        c.drawCircle(
          o,
          rad - 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isMine ? 6 : 3
            ..color = isMine ? _ink : _brown,
        );
      } else {
        _dashedCircle(
          c,
          o,
          rad - 2,
          it.rarity == RiceRarity.legend
              ? _legendBlue
              : const Color(0x668D6E63),
        );
      }
    }
    final tx = gx + gw + 44, tw = r.right - 36 - tx;
    final st = x.stage, lv = math.max(1, st.lv);
    const blockH = 30 + 10 + 72 + 8 + 38 + 12 + 30;
    var y = r.top + (r.height - blockH) / 2;
    final a = cardStyle(24, FontWeight.w800, _brown);
    cardText(c, cardEllip(t('dex_title'), a, tw), a, tx, y + 15, middle: true);
    y += 30 + 10;
    final stage = t('dex_st_$lv');
    final bst = cardStyle(
      cardFit(stage, tw, 64, 40, FontWeight.w900),
      FontWeight.w900,
      _ink,
    );
    cardText(c, cardEllip(stage, bst, tw), bst, tx, y + 36, middle: true);
    y += 72 + 8;
    final cst = cardStyle(32, FontWeight.w800, _ink);
    final count = tf('dex_count', {
      'n': '${x.count}',
      'total': '${RiceDex.total}',
    });
    cardText(c, cardEllip(count, cst, tw), cst, tx, y + 19, middle: true);
    y += 38 + 12;
    final nst = cardStyle(24, FontWeight.w600, _brown);
    final next = st.next > 0
        ? tf('dex_next', {'stage': t('dex_st_${st.next}'), 'n': '${st.need}'})
        : t('dex_done');
    cardText(c, cardEllip(next, nst, tw), nst, tx, y + 15, middle: true);
  }

  /// 점선 원(웹 setLineDash([6, 6]) 과 같은 간격).
  void _dashedCircle(Canvas c, Offset o, double r, Color col) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = col;
    for (final m
        in (Path()..addOval(Rect.fromCircle(center: o, radius: r)))
            .computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 12) {
        c.drawPath(m.extractPath(d, math.min(d + 6, m.length)), paint);
      }
    }
  }

  // ── 식단표 신원 ─────────────────────────────────────────────────
  // (밥 색 점) 밥이름 / 헤드라인 / 주 N회 · N시간 / 팀 범례(도시락 칸 색)
  void _identityDiet(Canvas c, Rect r) {
    final s = dietSummary(data.diet);
    var y = r.top;
    final dot = Offset(r.left + 20, y + _dWho / 2);
    c.drawCircle(dot, 20, Paint()..color = data.bgColor);
    c.drawCircle(
      dot,
      20,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _brown,
    );
    final wst = cardStyle(30, FontWeight.w800, _ink);
    cardText(
      c,
      cardEllip(_nick, wst, r.width - 56),
      wst,
      r.left + 56,
      y + _dWho / 2 + 1,
      middle: true,
    );
    y += _dWho + _dGapW;
    final hst = cardStyle(
      cardFit(s.head, r.width, 76, _dHeadMin, FontWeight.w900),
      FontWeight.w900,
      _ink,
    );
    cardText(
      c,
      cardEllip(s.head, hst, r.width),
      hst,
      r.left,
      y + _dHead / 2,
      middle: true,
    );
    y += _dHead + _dGapH;
    if (s.sub.isNotEmpty) {
      final sst = cardStyle(32, FontWeight.w700, _dark);
      cardText(
        c,
        cardEllip(s.sub, sst, r.width),
        sst,
        r.left,
        y + _dSub / 2,
        middle: true,
      );
    }
    y += _dSub + _dGapS;
    final n = s.legend.length;
    if (n == 0) return;
    const gap = 12.0;
    final maxW = (r.width - gap * (n - 1)) / n;
    final lst = cardStyle(24, FontWeight.w800, _ink);
    var x = r.left;
    for (final it in s.legend) {
      final lb = cardEllip(stripEmoji(it.name), lst, maxW - 64);
      final w = cardMeasure(lb, lst) + 64;
      cardPill(c, x, y, w, _dChip);
      c.drawCircle(
        Offset(x + 28, y + _dChip / 2),
        9,
        Paint()..color = _slotRail[it.slot % 5],
      );
      cardText(c, lb, lst, x + 46, y + _dChip / 2 + 1, middle: true);
      x += w + gap;
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
    final compact = r.height < 440;
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
        compact,
      );
    }
  }

  /// 도시락 칸 하나. 빈 칸에는 키워드만 — 화면 UI 의 "국을 담아주세요" 같은 명령형은
  /// 공유물에 나가면 받아 보는 사람에게 하는 말처럼 읽힌다.
  void _cell(Canvas c, Rect r, int slot, int span, bool compact) {
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
    // 낮은 칸(네임카드의 반찬 줄)은 라벨을 빼고 이름만 — 라벨과 이름이 겹친다. 칸 색이 곧 밥·국·반찬.
    final showLabel = r.height >= 80;
    if (showLabel) {
      cardText(
        c,
        label,
        cardStyle(20, FontWeight.w700, const Color(0x663D2C22)),
        r.left + 22,
        r.top + 12,
      );
    }
    final big = span >= 3;
    // 네임카드는 도시락통 아래 밥도감이 있어 낮다 → compact(웹과 같은 기준 440)
    final fs = compact ? (big ? 30.0 : 24.0) : (big ? 36.0 : 28.0);
    final lh = (fs * 1.22).roundToDouble();
    final st = cardStyle(fs, FontWeight.w800, _ink);
    final lines = cardWrapWords(stripEmoji(s.name), st, r.width - 40, 2);
    final sy = r.center.dy + (showLabel ? 10 : 0) - (lines.length - 1) * lh / 2;
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

  // ── 식단표 시간표 ──────────────────────────────────────────────
  // 칸 제목은 빼고(헤드라인이 제목) 블록 색 = 도시락 칸 색.
  void _timetable(Canvas c, Rect r) {
    cardPanel(c, r);
    const ip = 32.0;
    final ix = r.left + ip, iw = r.width - ip * 2;
    final top = r.top + ip;

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
