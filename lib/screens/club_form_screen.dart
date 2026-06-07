// club_form_screen.dart — 동호회(클럽) 등록/수정 폼. 웹 registration.js 포팅.
// 로그인 필수(AuthGate가 보장). 좌표는 지도 피커로 직접 선택(지오코딩 불필요).
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../models/club.dart';
import '../models/schedule_block.dart';
import '../services/data_repository.dart';
import '../services/geocoding_service.dart';
import '../services/sanitize.dart';
import '../theme.dart';
import '../widgets/chip_select.dart';
import '../widgets/map_picker.dart';
import '../widgets/schedule_editor.dart';

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
  final _reel = TextEditingController();
  final _link = TextEditingController();

  final Set<String> _targets = {};
  final List<ScheduleBlock> _blocks = [];

  double? _lat;
  double? _lng;
  bool _saving = false;
  bool _geocoding = false;

  bool get _isEdit => widget.editing != null;

  // 주소 → 좌표 (Cloud Function). 실패 시 지도 피커로 폴백 안내.
  Future<void> _geocode() async {
    final addr = _address.text.trim();
    if (addr.isEmpty) {
      _snack('주소를 입력해주세요');
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
    _snack(r != null ? '주소를 찾았어요!' : '주소를 못 찾았어요 — 지도에서 선택해주세요');
  }

  // 웹 reg-target-chip data-val (한글 값 그대로 저장 → 필터·기존데이터 호환)
  static const _targetOptions = <ChipOption>[
    (label: '성인', value: '성인'),
    (label: '대학생', value: '대학생'),
    (label: '청소년', value: '청소년'),
    (label: '무관', value: '무관'),
    (label: '여성전용', value: '여성전용'),
    (label: '남성전용', value: '남성전용'),
    (label: '선출가능', value: '선출가능'),
    (label: '6인제', value: '6인제'),
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
      _reel.text = e.instaReel ?? '';
      _link.text = e.link ?? '';
      _lat = e.lat;
      _lng = e.lng;
      // target 문자열 → 칩 부분일치 프리셀렉트 (잔여 표현은 메모 복원 불가 → 비움)
      final t = e.target ?? '';
      for (final o in _targetOptions) {
        if (t.contains(o.value)) _targets.add(o.value);
      }
      _blocks.addAll(ScheduleBlock.groupFromRaw(e.scheduleRaw));
    }
    if (_blocks.isEmpty) _blocks.add(ScheduleBlock());
  }

  @override
  void dispose() {
    for (final c in [_name, _targetNote, _address, _price, _insta, _reel, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
    }
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final target = _targetValue();
    final address = _address.text.trim();
    if (name.isEmpty || target.isEmpty || address.isEmpty) {
      _snack('이름·대상·주소는 필수예요');
      return;
    }
    if (_lat == null || _lng == null) {
      _snack('지도에서 위치를 선택해주세요');
      return;
    }
    // 길이 가드(웹과 동일 · permission-denied 예방)
    if (name.length > 60) return _snack('팀 이름은 60자 이하로');
    if (target.length > 80) return _snack('대상은 80자 이하로');
    if (address.length > 200) return _snack('주소는 200자 이하로');

    final price = _price.text.trim();
    if (price.length > 100) return _snack('회비는 100자 이하로');

    // insta 핸들(선택)
    var insta = _insta.text.trim();
    if (insta.isNotEmpty) {
      final s = Sanitize.instaHandle(insta);
      if (s.isEmpty) return _snack('인스타 핸들 형식이 올바르지 않아요');
      insta = s;
    }
    // 가입/문의 링크(선택)
    var link = _link.text.trim();
    if (link.isNotEmpty) {
      final s = Sanitize.url(link);
      if (s.isEmpty) return _snack('링크 형식이 올바르지 않아요 (http/https)');
      link = s;
    }
    // 릴스/게시물(선택)
    var reel = _reel.text.trim();
    if (reel.isNotEmpty) {
      final s = Sanitize.instaPostUrl(reel);
      if (s.isEmpty) return _snack('인스타 게시물/릴스 링크 형식이 올바르지 않아요');
      reel = s;
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
      'insta_reel': reel,
    };

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _repo.updateClub(widget.editing!.id, fields);
      } else {
        await _repo.createClub(fields);
      }
      if (!mounted) return;
      _snack(_isEdit ? '수정됐어요!' : '동호회가 등록됐어요!');
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      _snack('${_isEdit ? '수정' : '등록'} 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '동호회 수정' : '동호회 등록')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _group('팀 이름 (필수)', _input(_name, '예: GVT 배구클럽')),
            _group(
              '대상 (필수)',
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
                  _input(_targetNote, '기타 조건 (예: 구력 1년 이상) — 선택'),
                ],
              ),
            ),
            _group('주소 (필수) — 실제 체육관', _addressRow()),
            _group(
              '운동 시간 (스케줄)',
              ScheduleEditor(blocks: _blocks, onChanged: () => setState(() {})),
            ),
            _group('회비 및 게스트비', _input(_price, '예: 월 3만원 / 게스트 1만원')),
            _group('인스타그램 핸들 (선택)', _input(_insta, '예: gvt__official')),
            _group('인스타 릴스/게시물 링크 (선택)',
                _input(_reel, '예: https://www.instagram.com/reel/...')),
            _group('가입/문의 링크 (선택)',
                _input(_link, '예: https://open.kakao.com/o/...')),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: NurungjiColors.dark))
                  : Text(_isEdit ? '저장' : '등록하기'),
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
        _input(_address, '예: 서울 송파구 올림픽로 424'),
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
              label: const Text('주소로 검색'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('지도에서'),
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
                '위치 선택됨 (${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)})',
                style: const TextStyle(
                    fontSize: 12, color: NurungjiColors.brown),
              ),
            ]),
          ),
      ],
    );
  }
}
