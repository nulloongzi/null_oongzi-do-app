// share_image_screen.dart — 내 네임카드+도시락+식단표를 이미지로 캡처해 공유. 웹 generateShareImage 포팅.
// RepaintBoundary → toImage(pixelRatio) → PNG → share_plus.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/club.dart';
import '../models/profile.dart';
import '../services/data_repository.dart';
import '../services/i18n.dart';
import '../services/lunchbox_service.dart';
import '../services/profile_service.dart';
import '../services/schedule_parse.dart';
import '../theme.dart';
import '../widgets/diet_grid.dart';

class ShareImageScreen extends StatefulWidget {
  const ShareImageScreen({super.key});

  @override
  State<ShareImageScreen> createState() => _ShareImageScreenState();
}

class _ShareImageScreenState extends State<ShareImageScreen> {
  final _repaintKey = GlobalKey();
  final _repo = DataRepository();
  final _lb = LunchboxService();
  Profile? _profile;
  LunchboxData? _data;
  final Map<String, Club> _clubs = {};
  bool _loading = true;
  bool _sharing = false;
  bool _feedMode = true; // 포장 형태: 피드형(식단표 포함)↔스토리형(웹 sh_pick_shape)

  static const _slotBorder = [
    Color(0xFFFBC02D), Color(0xFFF57C00), Color(0xFF689F38),
    Color(0xFFD84315), Color(0xFF8E24AA),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _repo.currentUid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait(
          [_repo.loadClubs(), _lb.load(uid), ProfileService().ensureProfile(uid)]);
      _clubs
        ..clear()
        ..addEntries((results[0] as List<Club>).map((c) => MapEntry(c.id, c)));
      _data = results[1] as LunchboxData;
      _profile = results[2] as Profile;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  ({String name, bool isCustom, List<SchedEvent> events})? _resolve(String id) {
    final d = _data;
    if (d == null) return null;
    if (d.customTeams.containsKey(id)) {
      final m = d.customTeams[id];
      final name = (m is Map ? m['name'] : null) as String? ?? '커스텀 팀';
      final sched = (m is Map ? m['schedule'] : null) as String?;
      return (name: name, isCustom: true, events: eventsFromText(sched));
    }
    final c = _clubs[id];
    if (c != null) {
      final ev = (c.scheduleRaw != null && c.scheduleRaw!.isNotEmpty)
          ? eventsFromRaw(c.scheduleRaw)
          : eventsFromText(c.schedule);
      return (name: c.name, isCustom: false, events: ev);
    }
    return null;
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final png = bytes.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/nurungji_card_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(png);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${t('share_title')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('share_image_title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: _card(),
                      ),
                    ),
                  ),
                ),
                // 포장 형태 선택(웹 sh_pick_shape): 피드형=식단표 포함 / 스토리형=카드+도시락
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ChoiceChip(
                      label: Text(t('share_mode_feed')),
                      selected: _feedMode,
                      onSelected: (_) => setState(() => _feedMode = true)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                      label: Text(t('share_mode_story')),
                      selected: !_feedMode,
                      onSelected: (_) => setState(() => _feedMode = false)),
                ]),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sharing ? null : _share,
                        icon: _sharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: NurungjiColors.dark))
                            : const Icon(Icons.ios_share),
                        label: Text(t('share_image_btn')),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _card() {
    final p = _profile;
    final dietTeams = _dietTeams();
    return Container(
      width: 340,
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF7E3), Color(0xFFFFE9B8)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p != null) _profileCard(p),
          const SizedBox(height: 14),
          _lunchbox(),
          if (_feedMode && dietTeams.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14)),
              child: DietGrid(teams: dietTeams),
            ),
          ],
          const SizedBox(height: 14),
          Center(
            child: Text('🍚 ${t('brand')}',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: NurungjiColors.brown)),
          ),
        ],
      ),
    );
  }

  Widget _profileCard(Profile p) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🍚', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 6),
          Text(p.fullNickname,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: NurungjiColors.dark)),
        ],
      ),
    );
  }

  Widget _lunchbox() {
    final d = _data;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('lunchbox_title'),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: NurungjiColors.dark)),
          const SizedBox(height: 8),
          for (var i = 0; i < 5; i++) _slot(i, d),
        ],
      ),
    );
  }

  Widget _slot(int i, LunchboxData? d) {
    final id = d?.bookmarks[i];
    final r = id == null ? null : _resolve(id);
    final filled = id != null;
    final label = !filled
        ? '—'
        : (r == null ? t('deleted_team') : (r.isCustom ? '🍙 ${r.name}' : r.name));
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: _slotBorder[i], width: 4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontWeight: filled ? FontWeight.w700 : FontWeight.w400,
              color: filled ? NurungjiColors.dark : NurungjiColors.brown)),
    );
  }

  List<DietTeam> _dietTeams() {
    final out = <DietTeam>[];
    final d = _data;
    if (d == null) return out;
    for (var i = 0; i < 5; i++) {
      final id = d.bookmarks[i];
      if (id == null) continue;
      final r = _resolve(id);
      if (r == null) continue;
      out.add(DietTeam(
          name: r.name, isCustom: r.isCustom, slotIdx: i, events: r.events));
    }
    return out;
  }
}
