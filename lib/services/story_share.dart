// story_share.dart — 스토리 카드 PNG 렌더 → 인스타 스토리 네이티브 공유. 웹 shareStory 포팅.
// IG 미설치/실패 시 OS 공유시트로 PNG 폴백. 링크는 자동 복사(IG '링크 스티커'용).
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:appinio_social_share/appinio_social_share.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/share_card_kit.dart';
import '../widgets/story_card.dart';
import 'i18n.dart';
import 'share_service.dart';
import 'station_service.dart';

// strings.xml / Info.plist 의 FacebookAppID 와 동일해야 스티커 탭→딥링크가 동작.
const String kFacebookAppId = '1632483851162862';

/// 첫 공유 시 1회: '링크 스티커' 붙이는 법 안내(인스타는 외부앱 자동 링크를 막음).
Future<void> _maybeShowCoach(BuildContext context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('story_coach_seen') ?? false) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(t('coach_title')),
        content: Text(t('coach_steps'), style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(t('coach_go')),
          ),
        ],
      ),
    );
    await prefs.setBool('story_coach_seen', true);
  } catch (_) {}
}

Future<void> shareStoryCard(BuildContext context, StoryCardData data) async {
  final messenger = ScaffoldMessenger.of(context);
  // 가까운 지하철역 enrich (실패해도 무시 → 지역 라벨 폴백)
  var card = data;
  if (data.lat != null && data.lng != null) {
    final st = await StationService.nearest(data.lat!, data.lng!);
    if (st != null) card = data.copyWith(station: st.cardLabel);
  }

  Uint8List? png;
  try {
    png = await renderStoryCardPng(card);
  } catch (_) {}
  if (png == null) {
    messenger.showSnackBar(SnackBar(content: Text(t('err_card'))));
    return;
  }
  if (!context.mounted) return;
  await shareStoryPng(context, png, data.url);
}

/// 이미 그린 9:16 PNG 를 인스타 스토리로. 팀·픽업 카드와 포장하기(내 카드)가 같은 흐름을 쓴다:
/// 첫 1회 '링크 스티커' 안내 → 링크 자동 복사 + 안내 스낵바 → IG 스토리(스티커) →
/// IG 미설치·실패·iOS 는 OS 공유시트로 폴백.
Future<void> shareStoryPng(
  BuildContext context,
  Uint8List png,
  String url, {
  String prefix = 'nurungji_story',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  // 1회 코치: 링크 스티커 붙이는 법 안내
  await _maybeShowCoach(context);
  // IG '링크 스티커' 붙여넣기 쉽게 링크 자동 복사 + 매번 안내 스낵바
  await ShareService.copy(url);
  messenger.showSnackBar(
    SnackBar(
      content: Text(t('story_link_hint')),
      duration: const Duration(seconds: 4),
    ),
  );

  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(png);

  final appinio = AppinioSocialShare();
  try {
    if (Platform.isAndroid) {
      await appinio.android.shareToInstagramStory(
        kFacebookAppId,
        stickerImage: file.path,
        backgroundTopColor: '#fff8e1',
        backgroundBottomColor: '#fac710',
        attributionURL: url,
      );
    } else {
      // iOS/기타: PNG를 OS 공유시트로 (네이티브 빌드는 안드로이드 우선)
      await Share.shareXFiles([XFile(file.path)], text: url);
    }
  } catch (e) {
    // IG 미설치 등 → PNG를 OS 공유시트로 폴백
    try {
      await Share.shareXFiles([XFile(file.path)], text: url);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('${t('err_share')}: $e')));
    }
  }
}

/// 피드 이미지(3:4, 1080×1440) → OS 공유시트. 인스타 피드·카톡에 이미지로 올리는 용도.
/// 스토리와 달리 IG 스티커가 아니라서 링크 복사·코치가 필요 없다(웹 shareFeedCard 대응).
Future<void> shareFeedCard(BuildContext context, StoryCardData data) async {
  final messenger = ScaffoldMessenger.of(context);
  var card = data;
  if (data.lat != null && data.lng != null) {
    final st = await StationService.nearest(data.lat!, data.lng!);
    if (st != null) card = data.copyWith(station: st.cardLabel);
  }
  Uint8List? png;
  try {
    png = await renderStoryCardPng(card, format: CardFormat.feed);
  } catch (_) {}
  if (png == null) {
    messenger.showSnackBar(SnackBar(content: Text(t('err_card'))));
    return;
  }
  try {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/nurungji_feed_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(png);
    await Share.shareXFiles([XFile(file.path)], text: data.url);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('${t('err_share')}: $e')));
  }
}
