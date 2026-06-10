// pickup_form_screen.dart — 픽업 스팟 등록/수정 폼. 웹 pickup-host.js 포팅.
// 누구나 등록(무로그인=익명 인증). 좌표는 지도 피커로 직접 선택(지오코딩 불필요).
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../models/pickup_spot.dart';
import '../models/schedule_block.dart';
import '../services/data_repository.dart';
import '../services/analytics.dart';
import '../services/geocoding_service.dart';
import '../services/i18n.dart';
import '../services/sanitize.dart';
import '../theme.dart';
import '../widgets/app_sheet.dart';
import '../widgets/chip_select.dart';
import '../widgets/map_picker.dart';
import '../widgets/reel_editor.dart';
import '../widgets/schedule_editor.dart';

/// 픽업 등록/수정 폼: 풀스크린 라우트 대신 지도 위 모달 바텀시트(웹 등록 팝업 대응).
/// 등록·수정 성공 시 true 반환.
Future<bool?> showPickupFormSheet(
  BuildContext context, {
  required NLatLng initialCenter,
  PickupSpot? editing,
}) =>
    showAppSheet<bool>(context,
        background: Colors.white, // 웹 등록 모달: 흰 배경
        child: PickupFormScreen(initialCenter: initialCenter, editing: editing));

class PickupFormScreen extends StatefulWidget {
  /// 폼 진입 시 지도 중심 (피커 초기 위치). 기본 서울.
  final NLatLng initialCenter;

  /// 수정 모드면 기존 스팟. null이면 신규 등록.
  final PickupSpot? editing;

  const PickupFormScreen({
    super.key,
    this.initialCenter = const NLatLng(37.5559, 127.0838),
    this.editing,
  });

  @override
  State<PickupFormScreen> createState() => _PickupFormScreenState();
}

class _PickupFormScreenState extends State<PickupFormScreen> {
  final _repo = DataRepository();

  // 텍스트 입력 (웹 TEXT_FIELDS 대응)
  final _title = TextEditingController();
  final _venue = TextEditingController();
  final _address = TextEditingController();
  final _scheduleMemo = TextEditingController(); // 일정 메모(비정기)
  final _thisWeek = TextEditingController();
  final _fee = TextEditingController();
  final _contact = TextEditingController();
  final _notes = TextEditingController();
  final List<TextEditingController> _reels = []; // 릴스 다중 입력(행마다 1개)

  // 칩 선택
  String _sport = '6s';
  String _level = 'any';
  String _expire = '1m'; // 유효기간(B): weekend/1m/3m/always. 기본 1개월
  bool _beginnerFriendly = false;
  bool _englishOk = false;

  // 구조화 일정 블록
  final List<ScheduleBlock> _blocks = [];

  // 지도 피커로 선택한 좌표
  double? _lat;
  double? _lng;

  bool _saving = false;
  bool _geocoding = false;

  bool get _isEdit => widget.editing != null;

  // 주소 → 좌표 (Cloud Function). 실패 시 지도 피커로 폴백 안내.
  Future<void> _geocode() async {
    final addr = _address.text.trim();
    if (addr.isEmpty) {
      _snack(t('f_addr_empty'));
      return;
    }
    setState(() => _geocoding = true);
    final r = await GeocodingService.geocode(addr);
    if (!mounted) return;
    setState(() {
      _geocoding = false;
      if (r != null) {
        _lat = r.lat;
        _lng = r.lng;
        if (r.roadAddress != null && r.roadAddress!.isNotEmpty) {
          _address.text = r.roadAddress!;
        }
      }
    });
    _snack(r != null ? t('f_addr_found') : t('f_addr_notfound'));
  }

  List<ChipOption> get _sportOptions => [
        (label: t('sport_6s'), value: '6s'),
        (label: t('sport_9s'), value: '9s'),
        (label: t('sport_mixed'), value: 'mixed'),
      ];
  List<ChipOption> get _levelOptions => [
        (label: t('lv_beginner'), value: 'beginner'),
        (label: t('lv_intermediate'), value: 'intermediate'),
        (label: t('lv_advanced'), value: 'advanced'),
        (label: t('lv_any'), value: 'any'),
      ];
  List<ChipOption> get _expireOptions => [
        (label: t('pk_exp_weekend'), value: 'weekend'),
        (label: t('pk_exp_1m'), value: '1m'),
        (label: t('pk_exp_3m'), value: '3m'),
        (label: t('pk_exp_always'), value: 'always'),
      ];

  // 유효기간 프리셋 → DateTime|null (웹 computeExpireAt 포팅). null=상시.
  DateTime? _computeExpireAt(String preset) {
    final now = DateTime.now();
    if (preset == 'always') return null;
    if (preset == 'weekend') {
      final wd = now.weekday % 7; // 일=0..토=6 (웹 getDay와 동일)
      var s = DateTime(now.year, now.month, now.day + (wd == 0 ? 0 : 7 - wd),
          23, 59, 59);
      if (s.isBefore(now)) s = s.add(const Duration(days: 7));
      return s;
    }
    final months = preset == '3m' ? 3 : 1; // 기본 1개월
    return DateTime(
        now.year, now.month + months, now.day, now.hour, now.minute, now.second);
  }

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _title.text = e.title;
      _venue.text = e.venueName ?? '';
      _address.text = e.address ?? '';
      _scheduleMemo.text = e.scheduleText ?? '';
      _thisWeek.text = e.thisWeek ?? '';
      _fee.text = e.feeInfo ?? '';
      _contact.text = e.contactLink ?? '';
      for (final r in e.instaReels) {
        _reels.add(TextEditingController(text: r)); // 멀티 릴스: 행마다 하나
      }
      _notes.text = e.notes ?? '';
      _sport = e.sport ?? '6s';
      _level = e.level ?? 'any';
      _expire = e.expireAt != null ? '1m' : 'always'; // 웹과 동일(편집 시 1m/상시)
      _beginnerFriendly = e.beginnerFriendly;
      _englishOk = e.englishOk;
      _lat = e.lat;
      _lng = e.lng;
      _blocks.addAll(ScheduleBlock.groupFromRaw(e.scheduleRaw));
    }
    if (_blocks.isEmpty) _blocks.add(ScheduleBlock());
    if (_reels.isEmpty) _reels.add(TextEditingController()); // 최소 1행 노출
  }

  @override
  void dispose() {
    for (final c in [
      _title, _venue, _address, _scheduleMemo,
      _thisWeek, _fee, _contact, _notes,
    ]) {
      c.dispose();
    }
    for (final c in _reels) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickLocation() async {
    final start = (_lat != null && _lng != null)
        ? NLatLng(_lat!, _lng!)
        : widget.initialCenter;
    final result = await Navigator.push<(double, double)>(
      context,
      MaterialPageRoute(builder: (_) => MapPickerScreen(initial: start)),
    );
    if (result != null) {
      setState(() {
        _lat = result.$1;
        _lng = result.$2;
      });
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final address = _address.text.trim();
    if (title.isEmpty || address.isEmpty) {
      _snack(t('pf_req'));
      return;
    }
    if (_lat == null || _lng == null) {
      _snack(t('f_pick_loc'));
      return;
    }

    // 링크(선택): http(s)만
    var contact = _contact.text.trim();
    if (contact.isNotEmpty) {
      final s = Sanitize.url(contact);
      if (s.isEmpty) {
        _snack(t('f_link_invalid'));
        return;
      }
      contact = s;
    }

    // 릴스/게시물(선택, 여러 개): 줄바꿈 구분, 각각 공개 permalink 검증
    final reels = <String>[];
    for (final c in _reels) {
      final ln = c.text.trim();
      if (ln.isEmpty) continue;
      final s = Sanitize.instaPostUrl(ln);
      if (s.isEmpty) {
        _snack(t('f_reel_invalid'));
        return;
      }
      reels.add(s);
    }

    final fields = <String, dynamic>{
      'title': title,
      'sport': _sport,
      'level': _level,
      'beginner_friendly': _beginnerFriendly,
      'english_ok': _englishOk,
      'venue_name': _venue.text.trim(),
      'address': address,
      'coordinates': {'lat': _lat, 'lng': _lng},
      'schedule': ScheduleBlock.toText(_blocks),
      'schedule_raw': ScheduleBlock.toRaw(_blocks),
      'schedule_text': _scheduleMemo.text.trim(),
      'fee_info': _fee.text.trim(),
      'contact_link': contact,
      'this_week': _thisWeek.text.trim(),
      'insta_reel': reels.isNotEmpty ? reels.first : '', // 웹 호환(단일)
      'insta_reels': reels,
      'notes': _notes.text.trim(),
      'expire_at': _computeExpireAt(_expire), // DateTime?→Firestore Timestamp/null
    };

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _repo.updatePickup(widget.editing!.id, fields);
      } else {
        await _repo.createPickup(fields);
      }
      if (!mounted) return;
      Track.event('pickup_create', {'mode': _isEdit ? 'edit' : 'create'});
      _snack(_isEdit ? t('f_updated') : t('pf_created'));
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      _snack('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(_isEdit ? t('pf_edit_title') : t('pf_title')),
            _group(t('pf_name'), _input(_title, t('pf_name_hint'))),
            _group(
              t('pf_sport'),
              SingleChoiceChips(
                options: _sportOptions,
                selected: _sport,
                onChanged: (v) => setState(() => _sport = v),
              ),
            ),
            _group(
              t('pf_level'),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChoiceChips(
                    options: _levelOptions,
                    selected: _level,
                    onChanged: (v) => setState(() => _level = v),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    _toggle(t('pf_beginner'), _beginnerFriendly,
                        (v) => setState(() => _beginnerFriendly = v)),
                    _toggle(t('pf_english'), _englishOk,
                        (v) => setState(() => _englishOk = v)),
                  ]),
                ],
              ),
            ),
            _group(t('pf_venue'), _input(_venue, t('pf_venue_hint'))),
            _group(t('pf_addr'), _addressRow()),
            _group(
              t('pf_sched'),
              ScheduleEditor(blocks: _blocks, onChanged: () => setState(() {})),
            ),
            _group(t('pf_sched_memo'), _input(_scheduleMemo, t('pf_sched_memo_hint'))),
            _group(t('pf_thisweek'), _input(_thisWeek, t('pf_thisweek_hint'))),
            _group(t('pf_fee'), _input(_fee, t('pf_fee_hint'))),
            _group(t('pf_contact'), _input(_contact, t('f_contact_hint'))),
            _group(
              t('f_reel_label'),
              ReelEditor(controllers: _reels, onChanged: () => setState(() {})),
            ),
            _group(t('pf_notes'), _input(_notes, t('pf_notes_hint'))),
            _group(
              t('pk_f_expire'),
              SingleChoiceChips(
                options: _expireOptions,
                selected: _expire,
                onChanged: (v) => setState(() => _expire = v),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: NurungjiColors.dark))
                  : Text(_isEdit ? t('save') : t('pf_submit')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: NurungjiColors.dark)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _input(TextEditingController c, String hint) {
    return TextField(
      controller: c,
      decoration: InputDecoration(hintText: hint),
    );
  }

  Widget _addressRow() {
    final picked = _lat != null && _lng != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _input(_address, t('pf_addr_hint')),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _geocoding ? null : _geocode,
              icon: _geocoding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search, size: 18),
              label: Text(t('f_addr_search')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(t('f_addr_map')),
            ),
          ),
        ]),
        if (picked)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              const Icon(Icons.check_circle,
                  size: 16, color: NurungjiColors.teal),
              const SizedBox(width: 4),
              Text(
                '${t('f_loc_set')} (${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)})',
                style: const TextStyle(
                    fontSize: 12, color: NurungjiColors.brown),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _toggle(String label, bool on, ValueChanged<bool> onCh) {
    return FilterChip(
      label: Text(label),
      selected: on,
      onSelected: onCh,
      selectedColor: NurungjiColors.yellow,
      backgroundColor: NurungjiColors.chipBg,
      labelStyle: TextStyle(
        color: NurungjiColors.dark,
        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
      ),
      shape: const StadiumBorder(),
      showCheckmark: false,
    );
  }
}
