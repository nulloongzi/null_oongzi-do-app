// 상세 시트를 **실제 본문 그대로** 좁은 폰 폭에서 렌더한다.
//
// 단위 테스트가 못 잡는 유일한 종류의 회귀가 레이아웃 오버플로다 — 위젯을 빈
// Scaffold 안에서 따로 그리면 통과하지만, 실제 시트의 Row/Expanded 제약 안에서는
// "RenderFlex overflowed by N pixels" 로 깨진다. 특히 주소 행은 [아이콘][주소 Expanded]
// [버튼들] 구성이라 버튼이 늘어나면 바로 밀린다(길찾기 추가가 그 경우).
//
// 접근성 배율(textScale 1.3)까지 도는 이유: 시스템 글꼴을 키운 기기에서만 터지는
// 오버플로가 실제로 가장 흔하다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/models/pickup_spot.dart';
import 'package:nulloongzido/screens/detail_sheet.dart';
import 'package:nulloongzido/theme.dart';
import 'package:nulloongzido/widgets/data_trust_row.dart';

/// 좁은 폰(360dp) + 지정 배율. 스크롤 가능한 시트라 세로 넘침은 정상이므로
/// 가로 제약만 실제와 같게 주고 세로는 넉넉히 둔다.
Widget host(Widget Function(BuildContext) build, {double scale = 1.0}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SizedBox(
            width: 360,
            child: SingleChildScrollView(child: Builder(builder: build)),
          ),
        ),
      ),
    );

PickupSpot spot({
  double? lat,
  double? lng,
  String? address,
  String venue = '잠실학생체육관',
}) => PickupSpot(
  id: 'pk-1',
  title: '잠실 토요 6인제 픽업 크루',
  sport: '6s',
  level: 'any',
  venueName: venue,
  address: address,
  region: '서울',
  insta: 'smoke_crew',
  feeInfo: '1회 1만원',
  lat: lat,
  lng: lng,
  lastVerifiedAt: DateTime.now(),
);

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('픽업 상세: 좌표 있는 크루(주소복사+길찾기) 오버플로 없음 · x$scale', (tester) async {
      await tester.pumpWidget(
        host(
          (ctx) => spotDetailBody(
            ctx,
            spot(lat: 37.5, lng: 127.0, address: '서울 송파구 올림픽로 25'),
            close: () {},
          ),
          scale: scale,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('픽업 상세: 좌표 없는 크루(길찾기 미노출) 오버플로 없음 · x$scale', (tester) async {
      await tester.pumpWidget(
        host(
          (ctx) => spotDetailBody(ctx, spot(address: '서울 송파구'), close: () {}),
          scale: scale,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      // 좌표가 없으면 길찾기는 붙지 않는다(지도 앱으로 보낼 좌표가 없으므로)
      expect(find.text('🚀 길찾기'), findsNothing);
    });
  }

  // 릴스 프레임은 관리자 전용이 아니다 — 로그인 안 한 게스트도 상세 릴스 칸에서 만든다.
  // 릴스가 없는 크루는 릴스 칸에 안내 + '만들기'가 뜬다.
  testWidgets('픽업 상세: 릴스 없으면 릴스 칸 안내 + 만들기(비로그인)', (tester) async {
    await tester.pumpWidget(
      host((ctx) => spotDetailBody(ctx, spot(), close: () {})),
    );
    await tester.pump();
    expect(find.text('📷 인스타 릴스'), findsOneWidget);
    expect(find.text('아직 릴스가 없어요'), findsOneWidget);
    expect(find.text('🎬 만들기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('픽업 상세: 좌표가 있으면 길찾기가 실제로 뜬다', (tester) async {
    await tester.pumpWidget(
      host(
        (ctx) => spotDetailBody(
          ctx,
          spot(lat: 37.5, lng: 127.0, address: '서울 송파구 올림픽로 25'),
          close: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('🚀 길찾기'), findsOneWidget);
    expect(find.text('📍 주소 복사'), findsOneWidget);
  });

  testWidgets('픽업 상세: 신뢰도 줄이 본문 안에 실제로 렌더된다', (tester) async {
    await tester.pumpWidget(
      host((ctx) => spotDetailBody(ctx, spot(address: '서울 송파구'), close: () {})),
    );
    await tester.pump();
    expect(find.textContaining('최종 확인'), findsOneWidget);
    expect(find.text('정보가 틀렸어요'), findsOneWidget);
  });

  // 동호회 본문은 showClubDetail 안에 인라인이라 따로 부를 수 없다. 다만 내가 바꾼 건
  // '신뢰도 줄을 추가한 것'뿐이고 그 위젯은 양쪽에서 같은 모양이므로, 좁은 폭 + 큰 배율에서
  // 그 줄 자체가 안 밀리는지를 직접 본다(동호회 주소/액션 행 레이아웃은 이번에 안 건드렸다).
  testWidgets('신뢰도 줄: 360dp + 배율 1.3 에서 오버플로 없음', (tester) async {
    await tester.pumpWidget(
      host(
        (ctx) => const DataTrustRow(
          kind: 'club',
          targetId: 'c-1',
          targetName: '강남 배구클럽',
          dataStatus: 'needs_check', // 경고 문구까지 붙은 가장 긴 상태
        ),
        scale: 1.3,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  group('장소 줄', () {
    test('장소 이름과 주소가 같으면 한 번만', () {
      expect(pickupWhereLines('서울광남초등학교', '서울광남초등학교'), ['서울광남초등학교']);
      expect(pickupWhereLines('서울 광남초등학교', '서울광남초등학교'), ['서울광남초등학교']);
    });
    test('주소가 장소 이름을 품으면 주소만', () {
      expect(pickupWhereLines('광남초', '서울광남초등학교'), ['서울광남초등학교']);
    });
    test('다르면 장소 이름 · 주소 두 줄', () {
      expect(pickupWhereLines('잠실학생체육관', '서울 송파구 올림픽로 25'), [
        '잠실학생체육관',
        '서울 송파구 올림픽로 25',
      ]);
    });
    test('한쪽만 있으면 그것만', () {
      expect(pickupWhereLines('', '서울 송파구'), ['서울 송파구']);
      expect(pickupWhereLines('잠실학생체육관', null), ['잠실학생체육관']);
      expect(pickupWhereLines(null, ' '), isEmpty);
    });
  });

  testWidgets('픽업 상세: 같은 장소 이름 · 주소는 한 번만 보인다', (tester) async {
    await tester.pumpWidget(
      host(
        (ctx) => spotDetailBody(
          ctx,
          spot(lat: 37.5, lng: 127.0, venue: '서울광남초등학교', address: '서울광남초등학교'),
          close: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('서울광남초등학교 · 서울광남초등학교'), findsNothing);
    expect(find.text('서울광남초등학교'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 짧으면 알약 옆 한 줄, 길면 알약 둘이 아랫줄에 나란히 — 세로로 쌓지 않는다.
  for (final scale in [1.0, 1.3]) {
    testWidgets('픽업 상세: 긴 장소면 알약 둘이 아랫줄에 나란히 · x$scale', (tester) async {
      await tester.pumpWidget(
        host(
          (ctx) => spotDetailBody(
            ctx,
            spot(
              lat: 37.5,
              lng: 127.0,
              venue: '서울특별시교육청 광진구 광남초등학교 실내체육관',
              address: '서울 광진구 광나루로 123',
            ),
            close: () {},
          ),
          scale: scale,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final copy = tester.getRect(find.text('📍 주소 복사'));
      final dir = tester.getRect(find.text('🚀 길찾기'));
      final name = tester.getRect(find.text('서울특별시교육청 광진구 광남초등학교 실내체육관'));
      expect(
        (copy.center.dy - dir.center.dy).abs(),
        lessThan(1),
        reason: '같은 줄',
      );
      expect(copy.top, greaterThan(name.bottom), reason: '글 아래');
    });
  }

  testWidgets('픽업 상세: 짧은 주소면 알약과 한 줄', (tester) async {
    await tester.pumpWidget(
      host(
        (ctx) => spotDetailBody(
          ctx,
          spot(lat: 37.5, lng: 127.0, venue: '', address: '송파구'),
          close: () {},
        ),
      ),
    );
    await tester.pump();
    final copy = tester.getRect(find.text('📍 주소 복사'));
    final addr = tester.getRect(find.text('송파구'));
    expect((copy.center.dy - addr.center.dy).abs(), lessThan(4));
  });
}
