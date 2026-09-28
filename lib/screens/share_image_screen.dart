// share_image_screen.dart — 내 네임카드+도시락+식단표를 이미지로 공유.
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
import '../services/friend_share_service.dart';
import '../services/friends_service.dart';
import '../services/i18n.dart';
import '../services/lunchbox_service.dart';
import '../services/profile_service.dart';
import '../services/schedule_parse.dart';
import '../services/analytics.dart';
import '../services/share_service.dart';
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
  bool _feedMode = true; // 포장 형태: 피드형(식단표 포함)↔스토리형(웹 sh_pick_shape)
  bool _withFriends = false; // '밥친구 포함' — 기본 꺼짐. 합석 친구가 없으면 잠긴다
  ui.Image? _logo; // 미리보기용 브랜드 로고(한 번만 로드 — 토글마다 다시 읽지 않게)

  @override
  void initState() {
    super.initState();
    _load();
    loadBrandLogo().then((img) {
      if (mounted) setState(() => _logo = img);
    });
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

  static Color _hexColor(String hex) {
    try {
      return Color(
        int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000,
      );
    } catch (_) {
      return const Color(0xFFFFF9C4);
    }
  }

  /// 카드에 넣을 밥친구: 이번 주 합석하는 친구만, 합석 많은 순 최대 4명(웹 myCardFriends).
  /// '식단표 전부 숨기기'를 켠 친구는 목록에 있어도 넣지 않는다 — 밖으로 나가는 이미지라 더 보수적으로.
  List<MyCardFriend> _cardFriends() {
    final hub = FriendsHub.instance;
    final st = hub.state.value;
    if (st.uid == null) return const [];
    final picked = pickCardFriends([
      for (final l in st.friends)
        CardFriendEntry(
          name: st.profileOf(l.other).name,
          color: st.profileOf(l.other).color,
          tier: hub.mealOf(l.other).tier,
          n: hub.mealOf(l.other).teams,
          hidden: hub.friendLunchboxes.value[l.other]?.status == 'hidden',
        ),
    ]);
    return [
      for (final f in picked)
        MyCardFriend(
          name: f.name,
          color: _hexColor(f.color),
          tier: f.tier,
          n: f.n,
        ),
    ];
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
      feed: _feedMode,
      friends: _withFriends ? _cardFriends() : const [],
    );
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final png = await renderMyCardPng(_cardData());
      if (png == null) throw Exception('render failed');
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/nurungji_card_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${t('share_title')}: $e')));
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
                // 포장 형태 선택(웹 sh_pick_shape): 피드형=식단표 포함 / 스토리형=카드+도시락
                // + '밥친구 포함' 스위치(웹 #previewFriends). 합석 친구가 없으면 흐리게 잠긴다.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: Text(t('share_mode_feed')),
                      selected: _feedMode,
                      onSelected: (_) => setState(() => _feedMode = true),
                    ),
                    ChoiceChip(
                      label: Text(t('share_mode_story')),
                      selected: !_feedMode,
                      onSelected: (_) => setState(() => _feedMode = false),
                    ),
                    Builder(
                      builder: (_) {
                        final can = _cardFriends().isNotEmpty;
                        final chip = FilterChip(
                          key: const ValueKey('share_friends_toggle'),
                          avatar: Icon(
                            _withFriends && can
                                ? Icons.toggle_on
                                : Icons.toggle_off_outlined,
                            size: 20,
                          ),
                          label: Text(t('share_friends_toggle')),
                          selected: _withFriends && can,
                          onSelected: can
                              ? (v) {
                                  Track.event('mycard_friends', {
                                    'on': v ? 1 : 0,
                                  });
                                  setState(() => _withFriends = v);
                                }
                              : null,
                        );
                        return can
                            ? chip
                            : Tooltip(
                                message: t('share_friends_none'),
                                triggerMode: TooltipTriggerMode.tap,
                                child: chip,
                              );
                      },
                    ),
                  ],
                ),
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
                                  strokeWidth: 2,
                                  color: NurungjiColors.dark,
                                ),
                              )
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

  /// 미리보기 — 내보내는 것과 같은 painter를 축소해 그린다(WYSIWYG).
  /// 규격도 그대로 따라간다(피드형 4:5 / 스토리형 9:16).
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
