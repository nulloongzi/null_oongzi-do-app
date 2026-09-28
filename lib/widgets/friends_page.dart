// friends_page.dart — 🍚 팝업 둘째 장: 밥친구 목록 · 추가(초대코드) · 상세. 웹 js/friends.js 포팅.
// 식단표 겹쳐 보기·합석은 2·3단계. 이 장은 관계만 다룬다.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/analytics.dart';
import '../services/friend_share_service.dart';
import '../services/friends_service.dart';
import '../services/i18n.dart';
import '../services/schedule_parse.dart';
import '../services/share_service.dart';
import '../theme.dart';
import 'bounce_tap.dart';
import 'warm_avatar.dart';

enum _View { list, add, detail }

String inviteUrl(String code) =>
    '${ShareService.siteBase}?invite=${Uri.encodeComponent(code)}';

Color _hex(String s) {
  final h = s.replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? const Color(0xFFFFF9C4) : Color(v);
}

class FriendsPage extends StatefulWidget {
  /// 초대 링크(?invite=)로 들어오면 추가 화면을 열고 이 코드를 바로 찾는다.
  final String? initialCode;
  const FriendsPage({super.key, this.initialCode});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final hub = FriendsHub.instance;
  final _code = TextEditingController();
  _View _view = _View.list;
  String? _detailId;
  InviteLookup? _lookup;
  bool _looking = false;
  String? _confirm; // 두 단계 확인 중인 동작: 'regen' | 'unfriend'
  bool _showQr = false;
  String? _msg;
  Timer? _msgTimer;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCode;
    if (c != null && c.isNotEmpty) {
      _view = _View.add;
      _code.text = c;
      WidgetsBinding.instance.addPostFrameCallback((_) => _doLookup());
    }
    if (_view == _View.add) _ensureCode();
    // 로그인이 늦게 끝나면(딥링크로 열린 경우) 그때 받는다
    hub.state.addListener(_onStateForCode);
  }

  void _onStateForCode() {
    if (_view == _View.add) _ensureCode();
  }

  @override
  void dispose() {
    hub.state.removeListener(_onStateForCode);
    _code.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return; // 네트워크 중에 팝업을 닫았을 수 있다
    setState(() => _msg = m);
    _msgTimer?.cancel();
    _msgTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _msg = null);
    });
  }

  void _go(_View v, {String? detail}) => setState(() {
    _view = v;
    _confirm = null;
    _detailId = detail;
    if (v == _View.add) {
      _lookup = null;
      _showQr = false;
      _ensureCode();
    }
  });

  Future<void> _doLookup() async {
    setState(() {
      _looking = true;
      _lookup = null;
    });
    try {
      final r = await hub.svc.lookup(_code.text, hub.state.value);
      if (mounted) setState(() => _lookup = r);
    } catch (_) {
      if (mounted) setState(() => _lookup = const InviteLookup('error'));
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<void> _request(InviteLookup r) async {
    final me = hub.state.value.uid;
    if (me == null || r.uid == null || r.code == null) return;
    if (hub.state.value.friends.length >= kMaxFriends) {
      _toast(t('fr_err_full'));
      return;
    }
    if (await hub.requestsToday() >= kMaxRequestsPerDay) {
      _toast(t('fr_err_daily'));
      return;
    }
    try {
      final out = await hub.svc.sendRequest(me, r.code!, r.uid!);
      if (out == 'sent') await hub.noteRequestSent();
      if (!mounted) return;
      setState(
        () => _lookup = InviteLookup(
          out == 'sent' ? 'sent' : 'friend',
          code: r.code,
          uid: r.uid,
          profile: r.profile,
        ),
      );
      _toast(
        t(
          out == 'accepted'
              ? 'fr_accepted_short'
              : out == 'friend'
              ? 'fr_lk_friend'
              : 'fr_sent_toast',
        ),
      );
    } catch (_) {
      _toast(t('fr_err_generic'));
    }
  }

  /// 거절·취소·끊기: 실패하면 안내 (버리는 Future 가 없게).
  Future<void> _remove(String id, String why) async {
    try {
      await hub.svc.remove(id, why);
    } catch (_) {
      _toast(t('fr_err_generic'));
    }
  }

  /// 내 초대코드는 추가 화면을 열 때 한 번만 받는다 — build 에서 부르면 재빌드마다 겹쳐 두 번 발급된다.
  void _ensureCode() {
    if (hub.myCode != null || hub.state.value.uid == null) return;
    hub.ensureMyCode().then((_) {
      if (mounted) setState(() {});
    }, onError: (_) {});
  }

  Future<void> _copy(String text, String msg) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast(msg);
  }

  @override
  Widget build(BuildContext context) {
    // 관계 · 공유 설정 · 친구 도시락 셋 중 무엇이 바뀌어도 다시 그린다
    return ListenableBuilder(
      listenable: Listenable.merge([
        hub.state,
        hub.share,
        hub.friendLunchboxes,
        hub.myMeal,
      ]),
      builder: (ctx, _) => _frame(hub.state.value),
    );
  }

  Widget _frame(FriendState st) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFDF8),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...switch (_view) {
          _View.add => _add(st),
          _View.detail => _detail(st),
          _View.list => _list(st),
        },
        if (_msg != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: NurungjiColors.dark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _msg!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFF8E1), fontSize: 13),
            ),
          ),
      ],
    ),
  );

  // ── 조각 ────────────────────────────────────────────────────────
  Widget _head(String title, {VoidCallback? onBack, Widget? right}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        if (onBack != null)
          Semantics(
            button: true,
            label: t('fr_back'),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(0, 2, 10, 4),
                child: Icon(
                  Icons.chevron_left,
                  size: 26,
                  color: NurungjiColors.dark,
                ),
              ),
            ),
          ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: NurungjiColors.dark,
            ),
          ),
        ),
        if (right != null) right,
      ],
    ),
  );

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 6),
    child: Text(
      s,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: NurungjiColors.brown,
      ),
    ),
  );

  Widget _btn(
    String label,
    VoidCallback? onTap, {
    bool yellow = false,
    bool danger = false,
    bool small = false,
  }) {
    final bg = danger
        ? const Color(0xFFD84315)
        : (yellow ? NurungjiColors.yellow : const Color(0xFFF5EFE3));
    final fg = danger
        ? Colors.white
        : (yellow ? NurungjiColors.dark : NurungjiColors.brown);
    return BounceTap(
      onTap: onTap ?? () {},
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 14,
            vertical: small ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: small ? 12 : 13,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(String color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _hex(color),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0x99FFFFFF), width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F5D4037),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    alignment: Alignment.center,
    child: CustomPaint(
      size: Size.square(size * 0.58),
      painter: const _BowlPainter(),
    ),
  );

  String _mealText(FriendMeal m) =>
      tf('fr_meal_tier', {'tier': t('fr_warm_${m.tier}'), 'n': '${m.n}'});

  Widget _mealCard(FriendState st, FriendLink l, FriendMeal m) {
    final p = st.profileOf(l.other);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: BounceTap(
        onTap: () => _go(_View.detail, detail: l.id),
        child: Container(
          width: 84,
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF3E2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              WarmAvatar(
                size: 48,
                tier: m.tier,
                big: true,
                child: _avatar(p.color, 48),
              ),
              const SizedBox(height: 6),
              Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: NurungjiColors.dark,
                ),
              ),
              Text(
                _mealText(m),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: warmInk[m.tier],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(String title, String sub) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: NurungjiColors.dark,
          ),
        ),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: NurungjiColors.brown),
        ),
      ],
    ),
  );

  String _since(FriendLink l) {
    final d = l.acceptedAt;
    if (d == null) return t('fr_friend');
    return tf('fr_since', {'d': '${d.year}.${d.month}.${d.day}'});
  }

  // ── 목록 ────────────────────────────────────────────────────────
  List<Widget> _list(FriendState st) {
    final out = <Widget>[
      _head(
        tf('fr_title_n', {'n': '${st.friends.length}'}),
        right: _btn(
          t('fr_add_btn'),
          () => _go(_View.add),
          yellow: true,
          small: true,
        ),
      ),
    ];
    if (!st.loaded) {
      out.add(
        Text(
          t('fr_loading'),
          style: const TextStyle(color: NurungjiColors.brown),
        ),
      );
      return out;
    }
    if (st.incoming.isNotEmpty) {
      out.add(_label(t('fr_incoming')));
      for (final l in st.incoming) {
        final p = st.profileOf(l.other);
        out.add(
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x29FAC710),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _avatar(p.color, 36),
                const SizedBox(width: 10),
                _meta(p.name, t('fr_req_sub')),
                _btn(
                  t('fr_reject'),
                  () => _remove(l.id, 'reject'),
                  small: true,
                ),
                const SizedBox(width: 6),
                _btn(
                  t('fr_accept'),
                  () async {
                    if (st.friends.length >= kMaxFriends) {
                      _toast(t('fr_err_full')); // 받는 쪽도 100명 상한
                      return;
                    }
                    try {
                      await hub.svc.accept(l.id);
                      _toast(tf('fr_accepted_toast', {'name': p.name}));
                    } catch (_) {
                      _toast(t('fr_err_generic'));
                    }
                  },
                  yellow: true,
                  small: true,
                ),
              ],
            ),
          ),
        );
      }
    }
    if (hub.needsShareConfirm) out.add(_ShareConfirmCard(onDone: _toast));
    final hot = [
      for (final l in st.friends) (l: l, m: hub.mealOf(l.other)),
    ].where((v) => v.m.n > 0).toList()..sort((a, b) => b.m.n - a.m.n);
    if (hot.isNotEmpty) {
      out.add(_label(t('fr_meal_title')));
      // 합석이 낯선 사람에게 한 줄
      out.add(
        Text(
          t('fr_meal_hint'),
          style: const TextStyle(fontSize: 12, color: Color(0xFFA99A8C)),
        ),
      );
      out.add(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
          child: Row(children: [for (final v in hot) _mealCard(st, v.l, v.m)]),
        ),
      );
    }
    if (st.friends.isEmpty) {
      out.add(
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x4D8D6E63), width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                t('fr_empty_title'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: NurungjiColors.dark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t('fr_empty_body'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: NurungjiColors.brown,
                ),
              ),
              const SizedBox(height: 10),
              _btn(t('fr_add_btn'), () => _go(_View.add), yellow: true),
            ],
          ),
        ),
      );
    } else {
      // 합석 많은 순, 같으면 이름순
      final sorted = [...st.friends]
        ..sort(
          (a, b) => hub.mealOf(b.other).n != hub.mealOf(a.other).n
              ? hub.mealOf(b.other).n - hub.mealOf(a.other).n
              : st
                    .profileOf(a.other)
                    .name
                    .compareTo(st.profileOf(b.other).name),
        );
      for (final l in sorted) {
        final p = st.profileOf(l.other);
        final meal = hub.mealOf(l.other);
        out.add(
          InkWell(
            onTap: () => _go(_View.detail, detail: l.id),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              child: Row(
                children: [
                  WarmAvatar(
                    size: 38,
                    tier: meal.tier,
                    child: _avatar(p.color, 38),
                  ),
                  const SizedBox(width: 12),
                  _meta(
                    p.name,
                    hub.isLunchboxChanged(l.other)
                        ? t('fr_lb_changed')
                        : (meal.n > 0 ? _mealText(meal) : _since(l)),
                  ),
                  if (hub.isLunchboxChanged(l.other))
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                        color: NurungjiColors.yellow,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: NurungjiColors.yellow,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  const Icon(Icons.chevron_right, color: Color(0xFFA99A8C)),
                ],
              ),
            ),
          ),
        );
      }
    }
    if (st.outgoing.isNotEmpty) {
      out.add(_label(t('fr_outgoing')));
      for (final l in st.outgoing) {
        final p = st.profileOf(l.other);
        out.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                _avatar(p.color, 30),
                const SizedBox(width: 10),
                _meta(p.name, t('fr_waiting')),
                _btn(
                  t('fr_cancel'),
                  () => _remove(l.id, 'cancel'),
                  small: true,
                ),
              ],
            ),
          ),
        );
      }
    }
    if (st.friends.isNotEmpty) {
      final on = !hub.share.value.hideAll;
      out.add(
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF3E2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _meta(t('fr_vis_title'), t(on ? 'fr_vis_on' : 'fr_vis_off')),
              Switch(
                value: on,
                activeTrackColor: NurungjiColors.brown,
                onChanged: (v) => hub.setHideAll(!v).catchError((_) {
                  _toast(t('fr_err_generic'));
                }),
              ),
            ],
          ),
        ),
      );
    }
    return out;
  }

  // ── 추가 ────────────────────────────────────────────────────────
  List<Widget> _add(FriendState st) {
    final code = hub.myCode;
    final r = _lookup;
    return [
      _head(t('fr_add_title'), onBack: () => _go(_View.list)),
      _label(t('fr_my_code')),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0x2EFAC710),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                code ?? '······',
                // 'monospace' 는 iOS 에서 기본 글꼴로 빠진다 — Pretendard 고정폭 숫자로
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.4,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: NurungjiColors.dark,
                ),
              ),
            ),
            _btn(
              t('fr_copy'),
              code == null
                  ? null
                  : () {
                      _copy(code, t('fr_code_copied'));
                      Track.event('invite_code_copy', {'kind': 'code'});
                    },
              yellow: true,
              small: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _btn(
            t('fr_copy_link'),
            code == null
                ? null
                : () {
                    _copy(inviteUrl(code), t('fr_link_copied'));
                    Track.event('invite_code_copy', {'kind': 'link'});
                  },
            small: true,
          ),
          _btn(
            t('fr_show_qr'),
            code == null ? null : () => setState(() => _showQr = !_showQr),
            small: true,
          ),
          if (_confirm == 'regen')
            _btn(
              t('fr_regen_confirm'),
              () async {
                setState(() => _confirm = null);
                if (code == null) return; // 아직 못 받은 코드는 바꿀 수 없다
                try {
                  await hub.regenerate();
                  _toast(t('fr_regen_done'));
                } catch (_) {
                  _toast(t('fr_err_generic'));
                }
              },
              danger: true,
              small: true,
            )
          else
            _btn(
              t('fr_regen'),
              code == null ? null : () => setState(() => _confirm = 'regen'),
              small: true,
            ),
        ],
      ),
      if (_confirm == 'regen') _note(t('fr_regen_note')),
      if (_showQr && code != null)
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Semantics(
              label: t('fr_qr_aria'),
              child: QrImageView(data: inviteUrl(code), size: 160),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Expanded(child: Divider(color: Color(0x338D6E63))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                t('fr_enter_divider'),
                style: const TextStyle(fontSize: 12, color: Color(0xFFA99A8C)),
              ),
            ),
            const Expanded(child: Divider(color: Color(0x338D6E63))),
          ],
        ),
      ),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _doLookup(),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: t('fr_code_ph'),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0x408D6E63)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _btn(t('fr_find'), _looking ? null : _doLookup, yellow: true),
        ],
      ),
      const SizedBox(height: 10),
      if (_looking)
        _note(t('fr_lk_loading'))
      else if (r != null)
        _lookupResult(r),
      const SizedBox(height: 6),
      _note(t('fr_accept_note')),
    ];
  }

  Widget _note(String s, {bool center = false}) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      s,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFFA99A8C),
        height: 1.5,
      ),
    ),
  );

  Widget _lookupResult(InviteLookup r) {
    const msgs = {
      'invalid': 'fr_lk_invalid',
      'not_found': 'fr_lk_not_found',
      'self': 'fr_lk_self',
      'error': 'fr_err_generic',
    };
    if (msgs.containsKey(r.status)) {
      return Text(
        t(msgs[r.status]!),
        style: const TextStyle(fontSize: 13, color: NurungjiColors.brown),
      );
    }
    const subs = {
      'ok': 'fr_lk_ok',
      'friend': 'fr_lk_friend',
      'sent': 'fr_lk_sent',
      'received': 'fr_lk_received',
    };
    final p = r.profile ?? const FriendProfile('?', '#FFF9C4');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3E2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _avatar(p.color, 36),
          const SizedBox(width: 10),
          _meta(p.name, t(subs[r.status] ?? 'fr_lk_ok')),
          if (r.status == 'ok' || r.status == 'received')
            _btn(
              t(r.status == 'received' ? 'fr_accept' : 'fr_request'),
              () => _request(r),
              yellow: true,
            ),
        ],
      ),
    );
  }

  // ── 상세 ────────────────────────────────────────────────────────
  List<Widget> _detail(FriendState st) {
    FriendLink? l;
    for (final f in st.friends) {
      if (f.id == _detailId) l = f;
    }
    if (l == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _go(_View.list);
      });
      return const [];
    }
    final link = l;
    final p = st.profileOf(link.other);
    final meal = hub.mealOf(link.other);
    return [
      _head(p.name, onBack: () => _go(_View.list)),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _hex(p.color),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            WarmAvatar(
              size: 56,
              tier: meal.tier,
              big: true,
              child: _avatar('#FFFFFF', 56),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: NurungjiColors.dark,
                    ),
                  ),
                  if (meal.tier > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _mealText(meal),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: warmInk[meal.tier],
                        ),
                      ),
                    ),
                  Text(
                    _since(link),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6D5443),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _FriendLunchboxView(other: link.other),
      const SizedBox(height: 10),
      Center(
        child: _confirm == 'unfriend'
            ? _btn(t('fr_unfriend_confirm'), () async {
                try {
                  await hub.svc.remove(link.id, 'unfriend');
                  _go(_View.list);
                  _toast(t('fr_unfriended'));
                } catch (_) {
                  _toast(t('fr_err_generic'));
                }
              }, danger: true)
            : _btn(
                t('fr_unfriend'),
                () => setState(() => _confirm = 'unfriend'),
              ),
      ),
      if (_confirm == 'unfriend') _note(t('fr_unfriend_note'), center: true),
    ];
  }
}

/// 밥그릇 — 웹 friends.js 아바타와 같은 24 viewBox 패스(로고 단순화).
class _BowlPainter extends CustomPainter {
  const _BowlPainter();

  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 24);
    final paint = Paint()..color = NurungjiColors.dark;
    c.drawPath(
      Path()
        ..moveTo(12, 4.6)
        ..cubicTo(10.1, 4.6, 8.8, 5.6, 8.1, 6.8)
        ..cubicTo(7.1, 6.4, 5.7, 7.1, 5.7, 8.5)
        ..cubicTo(5.7, 9.4, 6.4, 10, 7.1, 10)
        ..lineTo(16.9, 10)
        ..cubicTo(17.6, 10, 18.3, 9.4, 18.3, 8.5)
        ..cubicTo(18.3, 7.1, 16.9, 6.4, 15.9, 6.8)
        ..cubicTo(15.2, 5.6, 13.9, 4.6, 12, 4.6)
        ..close(),
      paint,
    );
    c.drawPath(
      Path()
        ..moveTo(4.2, 11.6)
        ..lineTo(19.8, 11.6)
        ..cubicTo(19.8, 14.7, 17.3, 17.2, 14, 17.8)
        ..lineTo(14, 18.7)
        ..cubicTo(14, 19.1, 13.7, 19.4, 13.3, 19.4)
        ..lineTo(10.7, 19.4)
        ..cubicTo(10.3, 19.4, 10, 19.1, 10, 18.7)
        ..lineTo(10, 17.8)
        ..cubicTo(6.7, 17.2, 4.2, 14.7, 4.2, 11.6)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── 2단계: 식단표 공유 ────────────────────────────────────────────

/// 첫 밥친구 때 '보일 팀' 확인. 기본이 전부 보이기라, 이걸 마치기 전에는 사본을 쓰지 않는다.
class _ShareConfirmCard extends StatefulWidget {
  final void Function(String) onDone;
  const _ShareConfirmCard({required this.onDone});

  @override
  State<_ShareConfirmCard> createState() => _ShareConfirmCardState();
}

class _ShareConfirmCardState extends State<_ShareConfirmCard> {
  final hub = FriendsHub.instance;
  late Future<List<({String id, FriendTeam team})>> _teams = _load();
  Set<String>? _off; // 체크를 끈 팀
  Future<List<({String id, FriendTeam team})>> _load() =>
      hub.shareSvc.myTeams(hub.state.value.uid ?? '');
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x29FAC710),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x99FAC710), width: 1.5),
      ),
      child: FutureBuilder<List<({String id, FriendTeam team})>>(
        future: _teams,
        builder: (ctx, snap) {
          final teams = snap.data ?? const [];
          _off ??= snap.hasData ? {...hub.share.value.hidden} : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('fr_share_title'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: NurungjiColors.dark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t('fr_share_body'),
                style: const TextStyle(
                  fontSize: 13,
                  color: NurungjiColors.brown,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              if (snap.hasError)
                // 팀 목록을 못 읽으면 영원히 도는 대신 다시 시도
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t('fr_err_generic'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: NurungjiColors.brown,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _teams = _load()),
                      child: Text(t('fr_retry')),
                    ),
                  ],
                )
              else if (!snap.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (teams.isEmpty)
                Text(
                  t('fr_share_none'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFA99A8C),
                  ),
                )
              else
                for (final x in teams)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDF8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: NurungjiColors.brown,
                      value: !_off!.contains(x.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _off!.remove(x.id);
                        } else {
                          _off!.add(x.id);
                        }
                      }),
                      title: Text(
                        '${x.team.isCustom ? '🍙 ' : ''}${x.team.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: NurungjiColors.dark,
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 6),
              BounceTap(
                onTap: () async {
                  if (_busy || !snap.hasData) return;
                  setState(() => _busy = true);
                  try {
                    await hub.confirmShare(_off!.toList());
                    widget.onDone(t('fr_share_done'));
                  } catch (_) {
                    widget.onDone(t('fr_err_generic'));
                  }
                  if (mounted) setState(() => _busy = false);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: NurungjiColors.yellow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    t('fr_share_ok'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: NurungjiColors.dark,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

const _slotFill = [
  Color(0xFFFDE293),
  Color(0xFFFABD7B),
  Color(0xFFB3D099),
  Color(0xFFEB9E88),
  Color(0xFFC68ED3),
];
const _slotRail = [
  Color(0xFFFBC02D),
  Color(0xFFF57C00),
  Color(0xFF689F38),
  Color(0xFFD84315),
  Color(0xFF8E24AA),
];
const _slotBg = [
  Color(0xFFFFFDE7),
  Color(0xFFFFF3E0),
  Color(0xFFF1F8E9),
  Color(0xFFFBE9E7),
  Color(0xFFF3E5F5),
];

/// 친구 상세: 친구 도시락 칩 + 식단표 겹쳐 보기(친구 칸 채움 · 내 칸 테두리).
class _FriendLunchboxView extends StatefulWidget {
  final String other;
  const _FriendLunchboxView({required this.other});

  @override
  State<_FriendLunchboxView> createState() => _FriendLunchboxViewState();
}

class _FriendLunchboxViewState extends State<_FriendLunchboxView> {
  final hub = FriendsHub.instance;
  late final Future<(FriendLunchbox, List<FriendTeam>)> _f = () async {
    final lb = await hub.reloadFriendLunchbox(widget.other);
    final mine = await hub.shareSvc.myTeams(hub.state.value.uid ?? '');
    await hub.markLunchboxSeen(widget.other);
    return (lb, [for (final x in mine) x.team]);
  }();

  Widget _note(String s) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text(
      s,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFFA99A8C),
        height: 1.5,
      ),
    ),
  );

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Text(
      s,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: NurungjiColors.brown,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(FriendLunchbox, List<FriendTeam>)>(
      future: _f,
      builder: (ctx, snap) {
        if (snap.hasError) return _note(t('fr_err_generic'));
        if (!snap.hasData) return _note(t('fr_loading'));
        final (lb, mine) = snap.data!;
        if (lb.status != 'ok') {
          return _note(
            t(lb.status == 'hidden' ? 'fr_lb_hidden' : 'fr_lb_none'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(t('fr_lb_title')),
            if (lb.teams.isEmpty)
              _note(t('fr_lb_empty'))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tm in lb.teams)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _slotBg[tm.slot % 5],
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _slotRail[tm.slot % 5],
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '${tm.isCustom ? '🍙 ' : ''}${tm.name}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: NurungjiColors.dark,
                        ),
                      ),
                    ),
                ],
              ),
            _label(t('fr_tt_title')),
            FriendTimetable(
              mine: mine,
              theirs: lb.teams,
              meals: hub.mealOf(widget.other).overlaps,
            ),
            if (hub.mealOf(widget.other).n == 0)
              _note(t('fr_meal_zero'))
            else
              // 합석 목록을 글로 한 번 더 — 표만으로는 요일·시각을 읽기 어렵다
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    for (final o in sortOverlaps(
                      hub.mealOf(widget.other).overlaps,
                    ))
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBF3E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${i18nDay(o.day)} ${fmtHourRange(o.start, o.end)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: NurungjiColors.dark,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lb.teams
                                        .where((tm) => tm.id == o.id)
                                        .map((tm) => tm.name)
                                        .firstOrNull ??
                                    '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: NurungjiColors.brown,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 겹쳐 본 식단표. 친구 칸은 도시락 색으로 채우고, 내 칸은 테두리만. 합석 표시는 3단계에서 얹는다.
class FriendTimetable extends StatelessWidget {
  final List<FriendTeam> mine;
  final List<FriendTeam> theirs;
  final List<MealOverlap> meals;
  const FriendTimetable({
    super.key,
    required this.mine,
    required this.theirs,
    this.meals = const [],
  });

  @override
  Widget build(BuildContext context) {
    final friendEv = [
      for (final tm in theirs)
        for (final e in tm.events) (e: e, tm: tm),
    ];
    if (friendEv.isEmpty) {
      return Text(
        t('fr_tt_empty'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Color(0xFFA99A8C)),
      );
    }
    final myEv = [
      for (final tm in mine)
        for (final e in tm.events) (e: e, tm: tm),
    ];
    var minH = 24.0, maxH = 0.0;
    for (final v in [...friendEv, ...myEv]) {
      if (v.e.start < minH) minH = v.e.start;
      if (v.e.end > maxH) maxH = v.e.end;
    }
    // 23시 이후 일정이면 clamp(h0 + 3, 24) 의 아래가 위보다 커져 던진다 → 웹과 같은 min/max
    final h0 = math.min(22, math.max(6, minH.floor() - 1));
    final h1 = math.min(24, math.max(h0 + 3, maxH.ceil() + 1));
    final span = (h1 - h0).toDouble();
    final height = (span * 22).clamp(180.0, 400.0);
    const timeW = 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x2E8D6E63)),
          ),
          child: LayoutBuilder(
            builder: (ctx, c) {
              final colW = (c.maxWidth - timeW) / 7;
              Widget block(({SchedEvent e, FriendTeam tm}) v, bool me) {
                final d = scheduleDays.indexOf(v.e.day);
                final slot = v.tm.slot % 5;
                return Positioned(
                  left: timeW + colW * d + 2,
                  width: colW - 4,
                  top: (v.e.start - h0) / span * height,
                  height: ((v.e.end - v.e.start) / span * height).clamp(
                    4.0,
                    height,
                  ),
                  child: Tooltip(
                    message: v.tm.name,
                    child: Container(
                      decoration: me
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: NurungjiColors.brown,
                                width: 1.5,
                              ),
                            )
                          : BoxDecoration(
                              color: _slotFill[slot],
                              borderRadius: BorderRadius.circular(5),
                              border: Border(
                                left: BorderSide(
                                  color: _slotRail[slot],
                                  width: 3,
                                ),
                              ),
                            ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(1),
                      child: me
                          ? null
                          : Text(
                              v.tm.name,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.clip,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                color: NurungjiColors.dark,
                              ),
                            ),
                    ),
                  ),
                );
              }

              final every = span > 8 ? 2 : 1;
              return Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: timeW),
                      for (final d in scheduleDays)
                        Expanded(
                          child: Text(
                            i18nDay(d),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: NurungjiColors.dark,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: height,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        for (var i = 0; i <= 7; i++)
                          Positioned(
                            left: timeW + colW * i,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 1,
                              color: const Color(0x1F8D6E63),
                            ),
                          ),
                        for (var h = h0; h <= h1; h++)
                          if ((h - h0) % every == 0 || h == h1)
                            Positioned(
                              left: 0,
                              width: timeW - 4,
                              top: ((h - h0) / span * height - 6).clamp(
                                0.0,
                                height - 12,
                              ),
                              child: Text(
                                '$h',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFFA99A8C),
                                ),
                              ),
                            ),
                        for (final v in friendEv) block(v, false),
                        for (final v in myEv) block(v, true),
                        // 합석 칸: 금빛으로 맨 위에
                        for (final m in meals)
                          Positioned(
                            left:
                                timeW + colW * scheduleDays.indexOf(m.day) + 2,
                            width: colW - 4,
                            top: (m.start - h0) / span * height,
                            height: ((m.end - m.start) / span * height).clamp(
                              4.0,
                              height,
                            ),
                            child: Tooltip(
                              message: t('fr_tt_meal_legend'),
                              child: Container(
                                alignment: Alignment.center,
                                // 합석 칸: 효과 없이 단색(웹 .fr-tt-blk.gs 와 같은 값)
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5B82E),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: const Color(0xFFC98A12),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  t('fr_tt_meal'),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF5D4037),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 12,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: NurungjiColors.brown, width: 1.5),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              t('fr_tt_me'),
              style: const TextStyle(fontSize: 11, color: NurungjiColors.brown),
            ),
            const SizedBox(width: 12),
            Container(
              width: 12,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFFABD7B),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              t('fr_tt_friend'),
              style: const TextStyle(fontSize: 11, color: NurungjiColors.brown),
            ),
            if (meals.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                width: 12,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5B82E),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0xFFC98A12)),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                t('fr_tt_meal_legend'),
                style: const TextStyle(
                  fontSize: 11,
                  color: NurungjiColors.brown,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
