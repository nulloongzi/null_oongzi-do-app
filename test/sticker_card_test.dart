// 릴스 프레임(앱 전용) — 규격 웹 레포 docs/design-system.md §7-6.
// 9:16 투명, 시트는 내용 높이만큼(최대 절반) 프레임 끝까지, 로고는 시트 안 이름 줄 끝(QR·링크 없음).
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/models/club.dart';
import 'package:nulloongzido/services/i18n.dart';
import 'package:nulloongzido/widgets/sticker_card.dart';

Club _club({bool urgent = false}) => Club(
  id: 'C1',
  name: 'GVT',
  isVerified: true,
  insta: 'gvt',
  target: '성인, 대학생',
  schedule: '토 13:00~17:00',
  price: '월 3만원',
  address: '경기 구리시 체육관로 1',
  lat: 37.6,
  lng: 127.1,
  isRecruiting: true,
  recruitMsg: '🔥 남자부 모집중!!',
  isUrgent: urgent,
  urgentMsg: urgent ? '2명 급구' : null,
);

void main() {
  setUp(() => appLang.value = 'ko');

  test('시트에 보이는 칸을 시트와 같은 표기로 채운다', () {
    final d = StickerData.fromClub(_club());
    expect(d.schedule, '토요일 PM 1:00 ~ PM 5:00');
    expect(d.recruit!.msg, '남자부 모집중!!'); // 캔버스엔 이모지를 쓰지 않는다
    expect(d.tags, ['#성인', '#대학생']);
    expect(d.urgent, isNull);
  });

  test('제목은 시트 윗단 바로 아래, 로고는 시트 안 이름 줄 오른쪽 끝', () {
    final l = stickerLayout(StickerData.fromClub(_club()));
    expect(l.title, inExclusiveRange(l.top, l.top + 120)); // 손잡이·힌트 없이 바로 제목
    expect(l.logo.top, greaterThan(l.top)); // 영상 위가 아니라 흰 시트 위
    expect(l.logo.right, lessThan(frameW - 40));
    expect(l.logo.center.dy, closeTo(l.title + 32, 20)); // 이름 줄 가운데
  });

  test('시트 높이는 내용만큼 — 짧으면 낮고, 길어도 화면 절반에서 멈춘다', () {
    final short = stickerLayout(
      const StickerData(title: 'X', schedule: '토요일 PM 1:00 ~ PM 5:00'),
    );
    final full = stickerLayout(StickerData.fromClub(_club(urgent: true)));
    expect(short.top, greaterThan(full.top));
    expect(short.top, greaterThan(frameH * 0.8));
    final long = stickerLayout(
      StickerData(
        title: '아주 긴 이름의 배구 동호회 서울 송파 화요일 목요일 모임',
        schedule: '가 ' * 80,
        tags: [for (var i = 0; i < 30; i++) '#태그$i'],
        fee: '나 ' * 80,
        address: '다 ' * 80,
      ),
    );
    expect(long.top, frameTopMin);
  });

  test('급구가 있으면 제목 위에 띠', () {
    final l = stickerLayout(StickerData.fromClub(_club(urgent: true)));
    expect(l.urgent, lessThan(l.title));
  });

  test('PNG 는 1080×1920 RGBA', () async {
    final png = await renderStickerPng(StickerData.fromClub(_club()));
    expect(png, isNotNull);
    int be(int i) =>
        (png![i] << 24) | (png[i + 1] << 16) | (png[i + 2] << 8) | png[i + 3];
    expect(be(16), 1080);
    expect(be(20), 1920);
    expect(png![25], 6);
  });
}
