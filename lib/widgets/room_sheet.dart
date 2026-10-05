// room_sheet.dart — 🍚 여기 자리 있어요? 입구 띠와 목록 시트(웹과 같은 구성).
//
// 7일 안에 가서 뛸 수 있는 곳(게스트 급구 · 🥄 맛보기 팀 운동 · 픽업)을 시간순으로 보여 준다.
// 항목은 services/this_week.dart 가 만든다(순수 로직). 이 파일은 보여 주기만 한다:
//  · RoomStrip — 지도 위 띠 "🍚 여기 자리 있어요? · {n}곳 ›" + 다가오는 3개를 4초마다 굴린다.
//  · RoomSheet — 종류 칩(여러 개)·날짜 칩(하나 또는 7일 전체), 날짜별 줄, 줄마다 연락하기.
// 줄을 누르면 팀·크루 상세, 연락하기는 상세의 첫 연락 버튼과 같은 일(via:'this_week').
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/deep_link_service.dart' show kCaptureMode;
import '../services/i18n.dart';
import '../services/this_week.dart';
import '../theme.dart';
import 'app_sheet.dart';
import 'glass_surface.dart';

const _guestInk = NurungjiColors.urgentInk;
const _dropInInk = Color(0xFF2E7D32); // 식구 모집 배지와 같은 초록(흰 바탕 5.1:1)

Color _kindInk(String kind) => switch (kind) {
  kTwGuest => _guestInk,
  kTwDropIn => _dropInInk,
  _ => NurungjiColors.teal,
};

Color _kindBg(String kind) => switch (kind) {
  kTwGuest => const Color(0xFFFFF3E0),
  kTwDropIn => const Color(0xFFE8F5E9),
  _ => const Color(0xFFE0F2F1),
};

/// 자리 있어요 시트를 띄운다. 줄·연락 동작은 지도 화면이 넘긴다.
Future<void> showRoomSheet(
  BuildContext context, {
  required List<ThisWeekItem> items,
  required void Function(ThisWeekItem) onOpen,
  required void Function(ThisWeekItem) onContact,
}) => showAppSheet<void>(
  context,
  child: RoomSheet(items: items, onOpen: onOpen, onContact: onContact),
);

/// 지도 위 입구 띠. 항목이 없으면 그리지 않는다(지도 화면이 아예 빼는 게 기본).
class RoomStrip extends StatefulWidget {
  final List<ThisWeekItem> items; // 시간순
  final VoidCallback onTap;
  const RoomStrip({super.key, required this.items, required this.onTap});

  @override
  State<RoomStrip> createState() => _RoomStripState();
}

class _RoomStripState extends State<RoomStrip> {
  int _i = 0;
  Timer? _timer;

  List<ThisWeekItem> get _next => widget.items.take(3).toList();

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    // 캡처 빌드에선 굴리지 않는다 — 스틸마다 띠 글자가 달라지면 이어 붙일 때 티가 난다.
    if (kCaptureMode || _next.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _i = (_i + 1) % _next.length);
    });
  }

  @override
  void didUpdateWidget(covariant RoomStrip old) {
    super.didUpdateWidget(old);
    if (_i >= _next.length) _i = 0;
    if (old.items.length != widget.items.length) _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = _next;
    if (next.isEmpty) return const SizedBox.shrink();
    final e = next[_i % next.length];
    final n = thisWeekPlaceCount(widget.items);
    return Semantics(
      button: true,
      child: GlassSurface(
        color: const Color(0xD9FFFBF0), // 크림 0.85 — 예전 급구 띠와 같은 바탕
        blur: 10,
        radius: BorderRadius.circular(12),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('room_strip'),
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tf('tw_entry', {'n': '$n'}),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: NurungjiColors.dark,
                            ),
                          ),
                          const SizedBox(height: 1),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (child, anim) => SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(anim),
                              child: FadeTransition(
                                opacity: anim,
                                child: child,
                              ),
                            ),
                            child: Text(
                              thisWeekTickerLine(e),
                              key: ValueKey('${e.placeKey}_${e.end}_$_i'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: e.kind == kTwGuest
                                    ? _guestInk
                                    : NurungjiColors.brown,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: NurungjiColors.brown,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoomSheet extends StatefulWidget {
  final List<ThisWeekItem> items; // 시간순
  final void Function(ThisWeekItem) onOpen;
  final void Function(ThisWeekItem) onContact;
  final DateTime Function() clock; // 테스트에서 날짜 칩을 고정한다

  const RoomSheet({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onContact,
    this.clock = DateTime.now,
  });

  @override
  State<RoomSheet> createState() => _RoomSheetState();
}

class _RoomSheetState extends State<RoomSheet> {
  final Set<String> _kinds = kTwKinds.toSet(); // 처음엔 모두 켬
  DateTime? _day; // null = 7일 전체
  late final List<DateTime> _days = thisWeekDays(widget.clock());

  String _kindLabel(String k) => t('tw_kind_$k');

  Widget _chip({
    required Key key,
    required String label,
    required bool on,
    required VoidCallback onTap,
    bool multi = false,
  }) {
    final style = TextStyle(
      color: NurungjiColors.dark,
      fontWeight: on ? FontWeight.w800 : FontWeight.w600,
    );
    return multi
        ? FilterChip(
            key: key,
            label: Text(label),
            selected: on,
            onSelected: (_) => onTap(),
            selectedColor: NurungjiColors.yellow,
            backgroundColor: NurungjiColors.chipBg,
            labelStyle: style,
            shape: const StadiumBorder(),
            showCheckmark: false,
          )
        : ChoiceChip(
            key: key,
            label: Text(label),
            selected: on,
            onSelected: (_) => onTap(),
            selectedColor: NurungjiColors.yellow,
            backgroundColor: NurungjiColors.chipBg,
            labelStyle: style,
            shape: const StadiumBorder(),
            showCheckmark: false,
          );
  }

  Widget _row(ThisWeekItem e) {
    final ink = _kindInk(e.kind);
    final id = '${e.kind}_${e.refId}_${e.end.millisecondsSinceEpoch}';
    final sub = [e.title, if (e.place.isNotEmpty) e.place].join(' · ');
    return InkWell(
      key: ValueKey('tw_row_$id'),
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.pop(context);
        widget.onOpen(e);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        thisWeekTimeLabel(e),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: NurungjiColors.dark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _kindBg(e.kind),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _kindLabel(e.kind),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: NurungjiColors.dark,
                    ),
                  ),
                  if (e.msg != null)
                    Text(
                      e.msg!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: e.kind == kTwGuest ? ink : NurungjiColors.brown,
                      ),
                    ),
                ],
              ),
            ),
            if (e.channel != null) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                key: ValueKey('tw_contact_$id'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NurungjiColors.dark,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () => widget.onContact(e),
                child: Text(t('tw_contact')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = filterThisWeek(widget.items, kinds: _kinds, day: _day);
    final groups = groupThisWeekByDay(shown);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 바로 아래 부제가 붙으므로 SheetTitle(아래 여백 14) 대신 같은 글꼴로 직접
          Text(
            t('tw_title'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: NurungjiColors.dark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            t('tw_sub'),
            style: const TextStyle(fontSize: 13, color: NurungjiColors.brown),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in kTwKinds)
                _chip(
                  key: ValueKey('tw_kind_$k'),
                  label: _kindLabel(k),
                  on: _kinds.contains(k),
                  multi: true,
                  onTap: () => setState(
                    () => _kinds.contains(k) ? _kinds.remove(k) : _kinds.add(k),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(
                  key: const ValueKey('tw_day_all'),
                  label: t('tw_all_days'),
                  on: _day == null,
                  onTap: () => setState(() => _day = null),
                ),
                for (var i = 0; i < _days.length; i++) ...[
                  const SizedBox(width: 6),
                  _chip(
                    key: ValueKey('tw_day_$i'),
                    label: thisWeekDayLabel(_days[i]),
                    on: _day == _days[i],
                    onTap: () => setState(() => _day = _days[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  t('tw_empty'),
                  key: const ValueKey('tw_empty'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: NurungjiColors.brown,
                  ),
                ),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final g in groups) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 2),
                      child: Text(
                        thisWeekDayLabel(g.day),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: NurungjiColors.brown,
                        ),
                      ),
                    ),
                    for (final e in g.items) _row(e),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
