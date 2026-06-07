// story_share.dart — 스토리 카드 PNG 렌더 → 인스타 스토리 네이티브 공유. 웹 shareStory 포팅.
// IG 미설치/실패 시 OS 공유시트로 PNG 폴백. 링크는 자동 복사(IG '링크 스티커'용).
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:appinio_social_share/appinio_social_share.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/story_card.dart';
import 'share_service.dart';

// strings.xml / Info.plist 의 FacebookAppID 와 동일해야 스티커 탭→딥링크가 동작.
const String kFacebookAppId = '129937258232161';

Future<void> shareStoryCard(BuildContext context, StoryCardData data) async {
  final messenger = ScaffoldMessenger.of(context);
  // IG '링크 스티커' 붙여넣기 쉽게 링크 자동 복사 + 1회 안내
  await ShareService.copy(data.url);
  messenger.showSnackBar(const SnackBar(
    content: Text('링크 복사됨 — 스토리에 "링크 스티커"로 붙여넣으면 탭 1번에 입장돼요'),
    duration: Duration(seconds: 4),
  ));

  Uint8List? png;
  try {
    png = await renderStoryCardPng(data);
  } catch (_) {}
  if (png == null) {
    messenger.showSnackBar(const SnackBar(content: Text('카드 생성에 실패했어요')));
    return;
  }

  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/nurungji_story_${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(png);

  final appinio = AppinioSocialShare();
  try {
    if (Platform.isAndroid) {
      await appinio.android.shareToInstagramStory(
        kFacebookAppId,
        stickerImage: file.path,
        backgroundTopColor: '#fff8e1',
        backgroundBottomColor: '#fac710',
        attributionURL: data.url,
      );
    } else {
      // iOS/기타: PNG를 OS 공유시트로 (네이티브 빌드는 안드로이드 우선)
      await Share.shareXFiles([XFile(file.path)], text: data.url);
    }
  } catch (e) {
    // IG 미설치 등 → PNG를 OS 공유시트로 폴백
    try {
      await Share.shareXFiles([XFile(file.path)], text: data.url);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('공유 실패: $e')));
    }
  }
}
