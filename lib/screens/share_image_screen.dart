// share_image_screen.dart — 포장하기: 네임카드(밥도감) · 식단표 두 장 중 하나를 이미지로 공유.
// 렌더는 widgets/my_card.dart(1080×1920 Canvas)가 담당 — 클럽 스토리 카드와 같은 미감.
// 이 화면은 데이터를 모아 MyCardData 로 만들고, 미리보기와 공유 버튼만 제공한다.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/club.dart';
import '../models/profile.dart';
import '../services/data_repository.dart';
import '../services/friends_service.dart';
import '../services/i18n.dart';
import '../services/lunchbox_service.dart';
import '../services/profile_service.dart';
import '../services/rice_dex.dart';
import '../services/schedule_parse.dart';
import '../services/analytics.dart';
import '../services/share_service.dart';
import '../services/story_share.dart' show shareStoryPng;
import '../theme.dart';
import '../widgets/diet_grid.dart' show DietTeam;
import '../widgets/my_card.dart';
import '../widgets/story_card.dart' show loadBrandLogo;

class ShareImageScreen extends StatefulWidget {
  const ShareImageScreen({super.key});

  @override
  State<ShareImageScreen> createState() => _ShareImageScreenState();
}

class _ShareImageScreenState extends State<ShareImageScreen> {
  final _repo = DataRepository();
  final _lb = LunchboxService();
  Profile? _profile;
  LunchboxData? _data;
  final Map<String, Club> _clubs = {};
  bool _loading = true;
  bool _sharing = false;
  MyCardMode _mode =
      MyCardMode.card; // 네임카드(기본) ↔ 식단표 — 웹 #previewShape 와 같은 두 칸
  ui.Image? _logo; // 미리보기용 브랜드 로고(한 번만 로드 — 토글마다 다시 읽지 않게)

  // 밥친구 프로필이 늦게 오면 밥도감 칸이 덜 찬 채로 보인다 — 오는 대로 다시 그린다.
  void _onFriends() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    FriendsHub.instance.state.addListener(_onFriends);
    _load();
    loadBrandLogo().then((img) {
      if (mounted) setState(() => _logo = img);
    });
  }

  @override
  void dispose() {
    FriendsHub.instance.state.removeListener(_onFriends);
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _repo.currentUid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _repo.loadClubs(),
        _lb.load(uid),
        ProfileService().ensureProfile(uid),
      ]);
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
      final name =
          (m is Map ? m['name'] : null) as String? ?? t('lb_custom_team');
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

  /// 밥도감: 나 + 밥친구 전체의 밥 종류(웹 loadFriendRices). 친구 프로필은 FriendsHub 가
  /// 이미 받아 둔다. 카드에 나가는 친구 정보는 밥 종류뿐 — 이름·팀·일정은 없다.
  RiceDex _dex(String myRice) {
    final st = FriendsHub.instance.state.value;
    if (st.uid == null) return RiceDex.build(myRice, const <String>[]);
    return RiceDex.build(myRice, [
      for (final l in st.friends) st.profileOf(l.other).rice,
    ]);
  }

  /// 화면 상태 → 카드 렌더 데이터. 미리보기와 공유가 같은 값을 쓴다.
  MyCardData _cardData() {
    final p = _profile;
    final d = _data;
    final slots = <MyCardSlot>[];
    final diet = <DietTeam>[];
    for (var i = 0; i < 5; i++) {
      final id = d?.bookmarks[i];
      final r = id == null ? null : _resolve(id);
      if (id == null) {
        slots.add(const MyCardSlot());
        continue;
      }
      if (r == null) {
        slots.add(MyCardSlot(name: t('deleted_team')));
        continue;
      }
      slots.add(MyCardSlot(name: r.name, isCustom: r.isCustom));
      diet.add(
        DietTeam(
          name: r.name,
          isCustom: r.isCustom,
          slotIdx: i,
          events: r.events,
        ),
      );
    }
    final first = slots.firstWhere(
      (s) => s.name != null,
      orElse: () => const MyCardSlot(),
    );
    return MyCardData(
      nickname: p?.fullNickname ?? '',
      riceType: p?.nickname ?? '',
      bgColor: p?.bgColor ?? NurungjiColors.light,
      joined: p?.createdAt == null
          ? null
          : '${t('joined')} ${p!.createdAt!.year}.${p.createdAt!.month}.${p.createdAt!.day}',
      mainTeam: first.name,
      mainTeamCustom: first.isCustom,
      slots: slots,
      diet: diet,
      url: ShareService.siteBase,
      mode: _mode,
      dex: _dex(p?.nickname ?? ''),
    );
  }

  void _pick(MyCardMode m) {
    if (m == _mode) return;
    Track.event('mycard_render', {'mode': m.name});
    setState(() => _mode = m);
  }

  /// story=true: 인스타 스토리로 바로(팀·픽업 카드와 같은 흐름 — 링크 복사 + 링크 스티커 안내).
  /// story=false: OS 공유시트(카톡·저장 등).
  Future<void> _share({required bool story}) async {
    setState(() => _sharing = true);
    try {
      final png = await renderMyCardPng(_cardData());
      if (png == null) throw Exception('render failed');
      Track.event('mycard_share', {
        'mode': _mode.name,
        'channel': story ? 'ig_story' : 'system',
      });
      if (story) {
        if (!mounted) return;
        await shareStoryPng(
          context,
          png,
          ShareService.siteBase,
          prefix: 'nurungji_card',
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/nurungji_card_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      debugPrint('share image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t('err_share'))));
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Center(child: _preview()),
                  ),
                ),
                // 카드 선택(웹 #previewShape): 네임카드 = 나는 어떤 밥(밥도감) · 식단표 = 이번 주 언제 뛰는지.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      key: const ValueKey('share_mode_card'),
                      label: Text(t('share_mode_card')),
                      selected: _mode == MyCardMode.card,
                      onSelected: (_) => _pick(MyCardMode.card),
                    ),
                    ChoiceChip(
                      key: const ValueKey('share_mode_diet'),
                      label: Text(t('share_mode_diet')),
                      selected: _mode == MyCardMode.diet,
                      onSelected: (_) => _pick(MyCardMode.diet),
                    ),
                  ],
                ),
                // 공유: 인스타 스토리 직행(기본) · 다른 앱으로(OS 공유시트 — 카톡·저장)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            key: const ValueKey('share_story_btn'),
                            onPressed: _sharing
                                ? null
                                : () => _share(story: true),
                            icon: _sharing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: NurungjiColors.dark,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_outlined),
                            label: Text(t('mycard_share_story')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          key: const ValueKey('share_other_btn'),
                          onPressed: _sharing
                              ? null
                              : () => _share(story: false),
                          icon: const Icon(Icons.ios_share),
                          label: Text(t('mycard_share_other')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// 미리보기 — 내보내는 것과 같은 painter를 축소해 그린다(WYSIWYG). 둘 다 9:16.
  /// 로고가 아직 안 왔으면 노란 타일 폴백으로 그려진다(레이아웃은 동일).
  Widget _preview() {
    final painter = MyCardPainter(_cardData(), logo: _logo);
    return AspectRatio(
      aspectRatio: painter.canvasSize.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(painter: painter, size: Size.infinite),
      ),
    );
  }
}
