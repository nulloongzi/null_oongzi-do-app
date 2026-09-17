// club_form_screen.dart — 동호회(클럽) 등록/수정 폼. 웹 registration.js 포팅.
// 로그인 필수(AuthGate가 보장). 좌표는 지도 피커로 직접 선택(지오코딩 불필요).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../models/club.dart';
import '../models/schedule_block.dart';
import '../services/target_parse.dart';
import '../services/club_admin.dart';
import '../services/data_repository.dart';
import '../services/deep_link_service.dart' show kCaptureMode;
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

/// 캡처 시연용: 등록 폼을 밖에서 한 단계씩 진행시킨다.
///
/// 폼 상태는 private 이고 시연은 손으로 입력할 수 없다. 값만 밀어 넣는 게 아니라
/// 사용자가 하는 것과 **같은 코드 경로**(_geocode·_pickLocation·_submit)를 부른다 —
/// 그래야 영상에 나오는 게 실제 동작과 같다.
/// 값은 "<단계>:<일련번호>" 로 준다. 같은 단계를 연달아 부를 수 있어야 해서다.
final ValueNotifier<String> clubFormDemo = ValueNotifier<String>('');

/// 방금 끝난 단계를 시연 쪽에 알린다("<단계>:<일련번호>").
///
/// 지오코딩·저장은 네트워크라 고정 대기로는 못 맞춘다. 실측에서 첫 지오코딩이
/// 5초 걸렸는데 3초만 기다렸더니, 늦게 도착한 결과가 그 사이에 입력한 시설
/// 이름을 덮어써서 ② 단계가 통째로 사라졌다. 기다릴 것은 시간이 아니라 완료다.
final ValueNotifier<String> clubFormDemoDone = ValueNotifier<String>('');

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
  bool _areaOnly = false; // 대략적인 위치만 공개(location_precision: area)
  String? _ownerHint; // 관리자 힌트: 현재 소유자 닉네임(웹 reg_owner_hint)
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
        // 주소로 찾은 경우엔 입력값을 보존한다 — 사용자가 적은 주소가 더 정확할
        // 수 있고, 정규화된 표기로 덮어쓰면 되레 낯설어진다(웹과 같은 방향).
        //
        // 다만 **장소 이름으로** 찾았다면 얘기가 다르다. '석관중' 은 주소가 아니라
        // 이름이라, 그대로 두면 다른 사람에게 주소로 안 읽힌다. 이때만 실제
        // 도로명으로 채운다(이후 직접 수정 가능).
        _lat = r.lat;
        _lng = r.lng;
        if (r.matchedByPlaceName && (r.roadAddress ?? '').isNotEmpty) {
          _address.text = r.roadAddress!;
        }
      }
    });
    if (r != null) {
      _snack(
        r.matchedByPlaceName && r.placeName != null
            ? '${r.placeName} ${t('f_addr_found')}'
            : t('f_addr_found'),
      );
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
      _areaOnly = isAreaOnly(e);
      // target 문자열 → 칩 + 기타 메모. 메모까지 되돌려야 한다 — 안 그러면
      // 수정하고 저장하는 것만으로 괄호 안 내용이 소리 없이 지워진다.
      final parts = parseTargetValue(e.target, [
        for (final o in _targetOptions) o.value,
      ]);
      _targets.addAll(parts.chips);
      _targetNote.text = parts.note;

      // schedule_raw 가 없는 문서(구글시트 접수분)는 텍스트에서 되살린다.
      // 없으면 상세엔 시간표가 보이는데 폼만 비어서, 사용자가 멀쩡한 시간을
      // 처음부터 다시 입력해야 했다.
      _blocks.addAll(ScheduleBlock.groupFromRaw(e.scheduleRaw));
      if (_blocks.isEmpty) {
        _blocks.addAll(ScheduleBlock.groupFromText(e.schedule));
      }
    }
    if (_blocks.isEmpty) _blocks.add(ScheduleBlock());
    if (_reels.isEmpty) _reels.add(TextEditingController()); // 최소 1행 노출
    _repo
        .isAdmin()
        .then((v) {
          if (mounted && v) {
            setState(() => _isAdminUser = true);
            if (_isEdit) _loadOwnerHint(); // 소유자 이메일 필드 힌트(관리자 전용)
          }
        })
        .catchError((_) {});
    // 측정 파리티(웹 registration_open): 등록 폼 도달 = 퍼널 진입 신호
    Track.event('registration_open', {'mode': _isEdit ? 'edit' : 'create'});
    if (kCaptureMode) clubFormDemo.addListener(_onDemo);
  }

  // ── 캡처 시연 ────────────────────────────────────────────────
  void _onDemo() {
    final v = clubFormDemo.value;
    if (v.isEmpty) return;
    unawaited(_demoStep(v.split(':').first));
  }

  /// 한 글자씩 넣어 '사람이 치는' 것처럼 보이게 한다. 값을 한 번에 꽂으면
  /// 영상에서 글자가 순간이동해 합성한 티가 난다.
  Future<void> _demoType(TextEditingController c, String text) async {
    c.text = '';
    for (var i = 0; i < text.length; i++) {
      if (!mounted) return;
      c.text = text.substring(0, i + 1);
      c.selection = TextSelection.collapsed(offset: c.text.length);
      await Future<void>.delayed(const Duration(milliseconds: 55));
    }
  }

  Future<void> _demoStep(String step) async {
    if (!mounted) return;
    switch (step) {
      case 'name':
        await _demoType(_name, '누룽지 배구클럽');
      case 'target':
        if (mounted) setState(() => _targets.add('성인'));
      case 'addr_type': // ① 직접 입력
        // 폼 힌트에 적힌 예시 주소 — 지오코딩이 확실히 잡는다. 앞서 쓰던
        // '서울 성북구 화랑로13길 144' 는 네이버가 0건을 돌려줘 장소 검색으로
        // 넘어갔고, 스낵바에 체육관 이름이 떠서 '주소를 그대로 입력' 자막과
        // 어긋났다(①과 ②의 구분이 무너진다).
        await _demoType(_address, '서울 송파구 올림픽로 424');
      case 'addr_place': // ② 시설 이름으로
        await _demoType(_address, '잠실학생체육관');
      case 'addr_search': // ①② 같은 버튼 — 서버가 주소 실패 시 장소 검색으로 넘어간다
        await _geocode();
      case 'addr_map': // ② 지도에서 고르기(확정은 mapPickerDemoConfirm)
        await _pickLocation();
      case 'submit':
        await _submit();
    }
    clubFormDemoDone.value = '$step:${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  void dispose() {
    clubFormDemo.removeListener(_onDemo);
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

  // 현재 소유자(registered_by)의 공개 users 문서에서 닉네임 조회 → 이메일 필드
  // 힌트로 표시(웹 registration.js:212-229 placeholder 대응). 실패는 조용히 무시.
  Future<void> _loadOwnerHint() async {
    final uid = widget.editing?.registeredBy;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _ownerHint = t('cf_owner_none'));
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final d = doc.data();
      if (!mounted || d == null) return;
      final nick = (d['full_nickname'] ?? d['nickname'] ?? uid).toString();
      setState(() {
        _ownerHint = t('cf_owner_current').replaceAll('{nick}', nick);
      });
    } catch (_) {}
  }

  void _snack(String msg) {
    if (!mounted) return;
    // '잠실학생체육관 위치를 찾았어요' 같은 안내는 시연 영상의 핵심 장면이다.
    // 기본 위치의 스낵바는 화면 맨 아래라 9:16 정규화에서 제스처바와 함께
    // 잘려나갈 수 있다 → 캡처 빌드에서만 살짝 띄운다(map_screen 과 같은 처리).
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: kCaptureMode
            ? SnackBarBehavior.floating
            : SnackBarBehavior.fixed,
        margin: kCaptureMode
            ? const EdgeInsets.only(left: 24, right: 24, bottom: 120)
            : null,
      ),
    );
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
      if (mounted && _address.text == before) {
        if (addr != null) {
          _address.text = addr;
        } else if (before.trim().isEmpty) {
          // 실패 + 주소칸 비어있음 → 기본 문구(웹 registration.js:305-309)
          _address.text = t('f_map_loc');
        }
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
    // 릴스(선택, 여러 개): 행 분해·permalink 검증·중복 제거는 collectReels가
    // 일괄 처리(웹 registration.js:358-368 멀티 릴스 루프 대응)
    final reels = Sanitize.collectReels(_reels.map((c) => c.text));
    if (reels == null) return _err(t('f_reel_invalid'));

    setState(() => _saving = true);
    // 좌표 미확정이면 제출 시 주소 지오코딩 폴백(웹 registration.js:407-432).
    // 성공해도 주소는 사용자 입력값 그대로 저장(roadAddress로 교체하지 않음).
    if (_lat == null || _lng == null) {
      final r = await GeocodingService.geocode(address);
      if (!mounted) return;
      if (r == null) {
        Track.event('registration_geocode_fail');
        setState(() => _saving = false);
        _err(t('f_pick_loc'));
        // 웹(:426-436)·앱의 주소검색 버튼과 동일: 에러만 두지 않고 피커를 연다.
        await _pickLocation();
        return;
      }
      setState(() {
        _lat = r.lat;
        _lng = r.lng;
      });
    }

    // ── 위치 공개 수준 ──
    // '대략만'을 골랐으면 **여기서** 값을 뭉갠다. 화면에서만 흐리는 건 소용이
    // 없다 — clubs 는 allow read: if true 라 Firestore 를 직접 읽으면 정확한
    // 값이 그대로 나온다. 원본 주소는 기기 밖으로 나가지 않는다.
    var saveLat = _lat;
    var saveLng = _lng;
    var saveAddress = address;
    if (_areaOnly) {
      saveLat = roundToAreaGrid(_lat);
      saveLng = roundToAreaGrid(_lng);
      var label = areaLabel(address);
      if (label.isEmpty && saveLat != null && saveLng != null) {
        // '하남종합운동장국민체육센터' 처럼 주소가 아예 없는 입력. 뭉갠 좌표를
        // 거꾸로 물어 시·군·구를 얻는다.
        label = areaLabel(
          await GeocodingService.reverseGeocode(saveLat, saveLng),
        );
        if (!mounted) return;
      }
      if (label.isEmpty) {
        // 라벨이 없다고 원문을 그대로 두면 흐리려던 게 무의미해진다 — 멈춘다.
        setState(() => _saving = false);
        return _err(t('reg_area_label_fail'));
      }
      saveAddress = label;
    }

    final fields = <String, dynamic>{
      'name': name,
      'target': target,
      'address': saveAddress,
      'coordinates': {'lat': saveLat, 'lng': saveLng},
      'location_precision': _areaOnly ? 'area' : 'exact',
      'schedule': ScheduleBlock.toText(_blocks),
      'schedule_raw': ScheduleBlock.toRaw(_blocks),
      'price': price,
      'contact': {'insta': insta, 'link': link},
      'insta_reel': reels.isNotEmpty ? reels.first : '', // 웹 호환(단일)
      'insta_reels': reels,
    };

    try {
      if (_isEdit) {
        // 관리자 전용: 소유자 재지정을 먼저 — 실패하면 저장 자체를 중단
        // (웹 registration.js:456-476 재지정→update 순서와 동일)
        final ownerEmail = _ownerEmail.text.trim().toLowerCase();
        if (_isAdminUser && ownerEmail.isNotEmpty) {
          await FirebaseFunctions.instance
              .httpsCallable('adminReassignOwner')
              .call({'clubId': widget.editing!.id, 'email': ownerEmail});
        }
        await _repo.updateClub(widget.editing!.id, fields);
      } else {
        await _repo.createClub(fields);
      }
      if (!mounted) return;
      Track.event('club_register', {'mode': _isEdit ? 'edit' : 'create'});
      _snack(_isEdit ? t('f_updated') : t('cf_created'));
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      // 저장 실패 현지화(웹 reg_save_err 대응): FirebaseException은 message 우선
      final msg = e is FirebaseException ? (e.message ?? '$e') : '$e';
      _err(t('cf_save_err') + msg);
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
            _tipBanner(),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _addressRow(invalid: _invalid.contains('address')),
                  _areaOnlyRow(),
                ],
              ),
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
                // 힌트에 현재 소유자 닉네임(웹 reg_owner_hint placeholder 대응)
                _input(_ownerEmail, _ownerHint ?? t('cf_owner_email_hint')),
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

  // 장소별 개별 등록 안내 배너(웹 index.html:291-293 노란 tip 배너 대응)
  Widget _tipBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x1AFFC107), // rgba(255,193,7,.1)
        border: const Border(
          left: BorderSide(color: Color(0xFFFFC107), width: 3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        t('cf_tip'),
        style: const TextStyle(
          color: Color(0xFF555555),
          fontSize: 13,
          height: 1.4,
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

  // 대략적인 위치만 공개 — 주소칸 바로 아래. 여기 말고 '선택 정보' 안으로
  // 넣으면 접혀 있어서 못 보고 지나간다. 학교·공공 체육관을 빌려 쓰는 팀은
  // 정확한 핀이 그대로 민원이 되기 때문에, 등록하는 그 자리에서 보여야 한다.
  Widget _areaOnlyRow() => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _areaOnly = !_areaOnly),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _areaOnly,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => setState(() => _areaOnly = v ?? false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('reg_area_only'),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: NurungjiColors.brown,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_areaOnly)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 2),
            child: Text(
              t('reg_area_only_desc'),
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: Color(0xFF888888),
              ),
            ),
          ),
      ],
    ),
  );

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
