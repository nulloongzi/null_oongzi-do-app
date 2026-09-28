// friends_page.dart — 🍚 팝업 둘째 장: 밥친구 목록 · 추가(초대코드) · 상세. 웹 js/friends.js 포팅.
// 식단표 겹쳐 보기·겸상은 2·3단계. 이 장은 관계만 다룬다.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/analytics.dart';
import '../services/friends_service.dart';
import '../services/i18n.dart';
import '../services/share_service.dart';
import '../theme.dart';
import 'bounce_tap.dart';

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
  }

  @override
  void dispose() {
    _code.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  void _toast(String m) {
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
    try {
      final out = await hub.svc.sendRequest(me, r.code!, r.uid!);
      if (!mounted) return;
      setState(
        () => _lookup = InviteLookup(
          out == 'sent' ? 'sent' : 'friend',
          code: r.code,
          uid: r.uid,
          profile: r.profile,
        ),
      );
      _toast(t(out == 'accepted' ? 'fr_accepted_short' : 'fr_sent_toast'));
    } catch (_) {
      _toast(t('fr_err_generic'));
    }
  }

  Future<void> _copy(String text, String msg) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast(msg);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FriendState>(
      valueListenable: hub.state,
      builder: (ctx, st, _) => Container(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: NurungjiColors.dark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _msg!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFF8E1),
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

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
                  () => hub.svc.remove(l.id, 'reject'),
                  small: true,
                ),
                const SizedBox(width: 6),
                _btn(
                  t('fr_accept'),
                  () async {
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
      final sorted = [...st.friends]
        ..sort(
          (a, b) =>
              st.profileOf(a.other).name.compareTo(st.profileOf(b.other).name),
        );
      for (final l in sorted) {
        final p = st.profileOf(l.other);
        out.add(
          InkWell(
            onTap: () => _go(_View.detail, detail: l.id),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              child: Row(
                children: [
                  _avatar(p.color, 38),
                  const SizedBox(width: 12),
                  _meta(p.name, _since(l)),
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
                  () => hub.svc.remove(l.id, 'cancel'),
                  small: true,
                ),
              ],
            ),
          ),
        );
      }
    }
    return out;
  }

  // ── 추가 ────────────────────────────────────────────────────────
  List<Widget> _add(FriendState st) {
    final code = hub.myCode;
    if (code == null && st.uid != null) {
      hub.ensureMyCode().then((_) {
        if (mounted) setState(() {});
      }, onError: (_) {});
    }
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
              () => setState(() => _confirm = 'regen'),
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
            _avatar('#FFFFFF', 56),
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
      _note(t('fr_diet_soon'), center: true),
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
