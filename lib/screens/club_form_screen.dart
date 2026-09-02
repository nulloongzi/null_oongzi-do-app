// club_form_screen.dart — 동호회(클럽) 등록/수정 폼. 웹 registration.js 포팅.
// 로그인 필수(AuthGate가 보장). 좌표는 지도 피커로 직접 선택(지오코딩 불필요).
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../models/club.dart';
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

/// 동호회 등록/수정 폼: 풀스크린 라우트 대신 지도 위 모달 바텀시트(웹 등록 팝업 대응).
/// 등록·수정 성공 시 true 반환.
Future<bool?> showClubFormSheet(
  BuildContext context, {
  required NLatLng initialCenter,
  Club? editing,
}) => showAppSheet<bool>(
  context,
  background: Colors.white, // 웹 등록 모달: 흰 배경
  child: ClubFormScreen(initialCenter: initialCenter, editing: editing),
);

class ClubFormScreen extends StatefulWidget {
  final NLatLng initialCenter;
  final Club? editing; // 수정 모드면 기존 클럽
  const ClubFormScreen({
    super.key,
    this.initialCenter = const NLatLng(37.5559, 127.0838),
    this.editing,
  });

  @override
  State<ClubFormScreen> createState() => _ClubFormScreenState();
}

class _ClubFormScreenState extends State<ClubFormScreen> {
  final _repo = DataRepository();

  final _name = TextEditingController();
  final _targetNote = TextEditingController();
  final _address = TextEditingController();
  final _price = TextEditingController();
  final _insta = TextEditingController();
  final _link = TextEditingController();
  final _ownerEmail =
      TextEditingController(); // 관리자 전용: 소유자 재지정(웹 regOwnerEmail)
  bool _isAdminUser = false;
  final List<TextEditingController> _reels = []; // 릴스 다중 입력(행마다 1개)

  final Set<String> _targets = {};
  final List<ScheduleBlock> _blocks = [];

  double? _lat;
  double? _lng;
  bool _saving = false;
  bool _geocoding = false;

  // 인라인 에러(웹 regError 대응): 폼 상단 배너 + 미입력 필수 필드 하이라이트.
  String? _formError;
  final Set<String> _invalid = {};

  bool get _isEdit => widget.editing != null;

  // 검증 실패를 스낵바 대신 폼 상단 배너로 표시(웹 showRegError 대응).
  void _err(String msg) {
    if (!mounted) return;
    setState(() => _formError = msg);
  }

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
    if (r != null) {
      _snack(t('f_addr_found'));
    } else {
      // 지오코딩 실패 → 하드 블록 대신 지도 피커로 폴백 유도(웹과 동일 방향).
      Track.event('registration_geocode_fail');
      _snack(t('f_addr_notfound'));
      await _pickLocation();
    }
  }

  // 웹 reg-target-chip data-val: 값은 한글 고정(필터·기존데이터 호환), 라벨만 한/영.
  List<ChipOption> get _targetOptions => [
    (label: t('t_adult'), value: '성인'),
    (label: t('t_college'), value: '대학생'),
    (label: t('t_youth'), value: '청소년'),
    (label: t('t_any'), value: '무관'),
    (label: t('t_women'), value: '여성전용'),
    (label: t('t_men'), value: '남성전용'),
    (label: t('t_expro'), value: '선출가능'),
    (label: t('t_6s'), value: '6인제'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _name.text = e.name;
      _address.text = e.address ?? '';
      _price.text = e.price ?? '';
      _insta.text = e.insta ?? '';
      for (final r in e.instaReels) {
        _reels.add(TextEditingController(text: r)); // 멀티 릴스: 행마다 하나
      }
      _link.text = e.link ?? '';
      _lat = e.lat;
      _lng = e.lng;
      // target 문자열 → 칩 부분일치 프리셀렉트 (잔여 표현은 메모 복원 불가 → 비움)
      final tgt = e.target ?? '';
      for (final o in _targetOptions) {
        if (tgt.contains(o.value)) _targets.add(o.value);
      }
      _blocks.addAll(ScheduleBlock.groupFromRaw(e.scheduleRaw));
    }
    if (_blocks.isEmpty) _blocks.add(ScheduleBlock());
    if (_reels.isEmpty) _reels.add(TextEditingController()); // 최소 1행 노출
    _repo
        .isAdmin()
        .then((v) {
          if (mounted && v) setState(() => _isAdminUser = true);
        })
        .catchError((_) {});
    // 측정 파리티(웹 registration_open): 등록 폼 도달 = 퍼널 진입 신호
    Track.event('registration_open', {'mode': _isEdit ? 'edit' : 'create'});
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _targetNote,
      _address,
      _price,
      _insta,
      _link,
      _ownerEmail,
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // 웹 getRegTargetValue: 선택칩 ', ' 결합 + 메모를 괄호로 덧붙임
  String _targetValue() {
    final base = _targetOptions
        .where((o) => _targets.contains(o.value))
        .map((o) => o.value)
        .join(', ');
    final note = _targetNote.text.trim();
    if (note.isEmpty) return base;
    return base.isEmpty ? note : '$base ($note)';
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
      // 웹 coord2Address 대응: 찍은 좌표의 주소를 자동으로 채운다(이후 수정 가능).
      // 프로그램적 대입은 onChanged를 안 타므로 방금 확정한 좌표가 무효화되지 않는다.
      final before = _address.text;
      final addr = await GeocodingService.reverseGeocode(result.$1, result.$2);
      if (addr != null && mounted && _address.text == before) {
        _address.text = addr;
      }
    }
  }

  Future<void> _submit() async {
    // 재검증 전에 이전 에러 상태 초기화(웹 clearRegError 대응)
    setState(() {
      _formError = null;
      _invalid.clear();
    });
    final name = _name.text.trim();
    final target = _targetValue();
    final address = _address.text.trim();
    if (name.isEmpty || target.isEmpty || address.isEmpty) {
      setState(() {
        _invalid.addAll([
          if (name.isEmpty) 'name',
          if (target.isEmpty) 'target',
          if (address.isEmpty) 'address',
        ]);
      });
      return _err(t('cf_req'));
    }
    if (_lat == null || _lng == null) return _err(t('f_pick_loc'));
    // 길이 가드(웹과 동일 · permission-denied 예방)
    if (name.length > 60) return _err(t('cf_name_max'));
    if (target.length > 80) return _err(t('cf_target_max'));
    if (address.length > 200) return _err(t('cf_addr_max'));

    final price = _price.text.trim();
    if (price.length > 100) return _err(t('cf_price_max'));

    // insta 핸들(선택)
    var insta = _insta.text.trim();
    if (insta.isNotEmpty) {
      final s = Sanitize.instaHandle(insta);
      if (s.isEmpty) return _err(t('cf_insta_invalid'));
      insta = s;
    }
    // 가입/문의 링크(선택)
    var link = _link.text.trim();
    if (link.isNotEmpty) {
      final s = Sanitize.url(link);
      if (s.isEmpty) return _err(t('f_link_invalid'));
      link = s;
    }
    // 릴스/게시물(선택)
    // 릴스(선택, 여러 개): 줄바꿈으로 구분, 각각 공개 permalink 검증
    final reels = <String>[];
    for (final c in _reels) {
      final ln = c.text.trim();
      if (ln.isEmpty) continue;
      final s = Sanitize.instaPostUrl(ln);
      if (s.isEmpty) return _err(t('f_reel_invalid'));
      reels.add(s);
    }

    final fields = <String, dynamic>{
      'name': name,
      'target': target,
      'address': address,
      'coordinates': {'lat': _lat, 'lng': _lng},
      'schedule': ScheduleBlock.toText(_blocks),
      'schedule_raw': ScheduleBlock.toRaw(_blocks),
      'price': price,
      'contact': {'insta': insta, 'link': link},
      'insta_reel': reels.isNotEmpty ? reels.first : '', // 웹 호환(단일)
      'insta_reels': reels,
    };

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _repo.updateClub(widget.editing!.id, fields);
        // 관리자 전용: 이메일 → 소유자 재지정 (웹 adminReassignOwner 동일 호출)
        final ownerEmail = _ownerEmail.text.trim().toLowerCase();
        if (_isAdminUser && ownerEmail.isNotEmpty) {
          await FirebaseFunctions.instance
              .httpsCallable('adminReassignOwner')
              .call({'clubId': widget.editing!.id, 'email': ownerEmail});
        }
      } else {
        await _repo.createClub(fields);
      }
      if (!mounted) return;
      Track.event('club_register', {'mode': _isEdit ? 'edit' : 'create'});
      _snack(_isEdit ? t('f_updated') : t('cf_created'));
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      _err('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(_isEdit ? t('cf_edit_title') : t('cf_title')),
            if (_formError != null) _errorBanner(_formError!),
            _group(
              t('cf_name'),
              _input(
                _name,
                t('cf_name_hint'),
                invalid: _invalid.contains('name'),
              ),
            ),
            _group(
              t('cf_target'),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MultiChoiceChips(
                    options: _targetOptions,
                    selected: _targets,
                    onChanged: (s) => setState(() {
                      _targets
                        ..clear()
                        ..addAll(s);
                    }),
                  ),
                  const SizedBox(height: 8),
                  _input(_targetNote, t('cf_target_note')),
                ],
              ),
              invalid: _invalid.contains('target'),
            ),
            _group(
              t('cf_addr'),
              _addressRow(invalid: _invalid.contains('address')),
            ),
            // 선택 정보는 접기 섹션으로(체감 폼 길이 축소). 편집 시엔 펼쳐 시작.
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _isEdit,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                title: Text(
                  t('cf_optional_summary'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: NurungjiColors.brown,
                    fontSize: 14,
                  ),
                ),
                children: [
                  const SizedBox(height: 8),
                  _group(
                    t('cf_sched'),
                    ScheduleEditor(
                      blocks: _blocks,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  _group(t('cf_price'), _input(_price, t('cf_price_hint'))),
                  _group(t('cf_insta'), _input(_insta, t('cf_insta_hint'))),
                  _group(
                    t('f_reel_label'),
                    ReelEditor(
                      controllers: _reels,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  _group(t('cf_link'), _input(_link, t('f_contact_hint'))),
                ],
              ),
            ),
            if (_isAdminUser && _isEdit)
              _group(
                t('cf_owner_email'),
                _input(_ownerEmail, t('cf_owner_email_hint')),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: NurungjiColors.dark,
                      ),
                    )
                  : Text(_isEdit ? t('save') : t('cf_submit')),
            ),
          ],
        ),
      ),
    );
  }

  // 인라인 에러 배너(웹 .reg-error 대응)
  Widget _errorBanner(String msg) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        border: const Border(
          left: BorderSide(color: Color(0xFFD32F2F), width: 3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        msg,
        style: const TextStyle(
          color: Color(0xFFB71C1C),
          fontSize: 13,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _group(String label, Widget child, {bool invalid = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: invalid ? const Color(0xFFD32F2F) : NurungjiColors.dark,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _input(TextEditingController c, String hint, {bool invalid = false}) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        hintText: hint,
        errorText: invalid ? t('cf_field_required') : null,
      ),
    );
  }

  Widget _addressRow({bool invalid = false}) {
    final picked = _lat != null && _lng != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _address,
          // 주소를 직접 고치면 이전 좌표 무효화(웹 동일) → 재검색/피커 유도
          onChanged: (_) {
            if (_lat != null) {
              setState(() {
                _lat = null;
                _lng = null;
              });
            }
          },
          decoration: InputDecoration(
            hintText: t('cf_addr_hint'),
            errorText: invalid ? t('cf_field_required') : null,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _geocoding ? null : _geocode,
                icon: _geocoding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
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
          ],
        ),
        if (picked)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: NurungjiColors.teal,
                ),
                const SizedBox(width: 4),
                Text(
                  '${t('f_loc_set')} (${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: NurungjiColors.brown,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
