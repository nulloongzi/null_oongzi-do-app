// pickup_filter_test.dart — 픽업 목록 필터(지역·English OK·키워드) 순수 로직.
// 웹 tests/pickup-filter.test.js 와 같은 케이스를 덮는다 — 두 플랫폼 결과가 갈리면
// 공유 링크("서울 ∧ English OK")가 서로 다른 목록을 보여주게 되므로 여기서 잡는다.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/models/pickup_spot.dart';
import 'package:nulloongzido/services/pickup_filter.dart';
import 'package:nulloongzido/services/region_match.dart';

PickupSpot spot({
  String id = 'x',
  String title = '픽업',
  String? region,
  String? address,
  String? venueName,
  String? insta,
  bool englishOk = false,
  double? lat,
  double? lng,
}) => PickupSpot(
  id: id,
  title: title,
  region: region,
  address: address,
  venueName: venueName,
  insta: insta,
  englishOk: englishOk,
  lat: lat,
  lng: lng,
);

void main() {
  group('regionOptionsAll', () {
    test('동호회 필터와 같은 8개 지역', () {
      expect(regionOptionsAll, [
        '서울',
        '경기',
        '인천',
        '강원',
        '충청',
        '전라',
        '경상',
        '제주',
      ]);
    });
  });

  group('pickupRegionMatch', () {
    test('지역 미지정이면 전부 통과', () {
      expect(pickupRegionMatch(spot(region: '경기'), ''), isTrue);
      expect(pickupRegionMatch(spot(), ''), isTrue);
    });

    test('region 필드가 우선 — 좌표/주소 없어도 매칭된다', () {
      expect(pickupRegionMatch(spot(region: '서울'), '서울'), isTrue);
      expect(pickupRegionMatch(spot(region: '경기'), '서울'), isFalse);
    });

    test('region 필드가 광역 묶음의 하위값이어도 매칭', () {
      expect(pickupRegionMatch(spot(region: '대전'), '충청'), isTrue);
      expect(pickupRegionMatch(spot(region: '부산'), '경상'), isTrue);
      expect(pickupRegionMatch(spot(region: '광주'), '전라'), isTrue);
      expect(pickupRegionMatch(spot(region: '부산'), '충청'), isFalse);
    });

    test('region 없으면 주소 접두어 폴백 (칩 도입 이전 문서 호환)', () {
      expect(pickupRegionMatch(spot(address: '서울 송파구 올림픽로 25'), '서울'), isTrue);
      expect(pickupRegionMatch(spot(address: '경기 성남시 분당구'), '서울'), isFalse);
    });

    test('주소 폴백도 광역 묶음을 편다', () {
      expect(pickupRegionMatch(spot(address: '대전 유성구'), '충청'), isTrue);
      expect(pickupRegionMatch(spot(address: '울산 남구'), '경상'), isTrue);
      expect(pickupRegionMatch(spot(address: '전북 전주시'), '전라'), isTrue);
    });

    test('접두어 매칭이라 주소 중간의 지역명은 걸리지 않는다', () {
      expect(pickupRegionMatch(spot(address: '경기 서울대입구로 1'), '서울'), isFalse);
    });

    test('region·주소 둘 다 없으면 지역 필터가 걸릴 때 제외', () {
      expect(pickupRegionMatch(spot(title: '수요 픽업'), '서울'), isFalse);
    });

    test('region 필드가 있으면 주소는 보지 않는다 (칩이 진실)', () {
      expect(
        pickupRegionMatch(spot(region: '서울', address: '경기 성남시'), '서울'),
        isTrue,
      );
      expect(
        pickupRegionMatch(spot(region: '경기', address: '서울 강남구'), '서울'),
        isFalse,
      );
    });
  });

  group('filterPickupSpots', () {
    final spots = [
      spot(
        id: 'a',
        title: 'Seoul Sunday 6s',
        region: '서울',
        englishOk: true,
        insta: 'seoul6s',
      ),
      spot(id: 'b', title: '수요 픽업', address: '서울 마포구 월드컵로'),
      spot(
        id: 'c',
        title: 'Busan Beach',
        region: '경상',
        englishOk: true,
        venueName: '해운대',
      ),
      // 지역·주소·좌표 전부 없는 크루 (인스타로만 굴러가는 모임)
      spot(id: 'd', title: '떠돌이 크루', englishOk: true),
    ];

    test('필터 없으면 전부', () {
      expect(filterPickupSpots(spots).length, 4);
    });

    test('englishOnly', () {
      expect(filterPickupSpots(spots, englishOnly: true).map((s) => s.id), [
        'a',
        'c',
        'd',
      ]);
    });

    test('region — region 필드와 주소 폴백을 함께 잡는다', () {
      expect(filterPickupSpots(spots, region: '서울').map((s) => s.id), [
        'a',
        'b',
      ]);
    });

    test('region + englishOnly 조합 (외국인에게 보낼 목록)', () {
      expect(
        filterPickupSpots(
          spots,
          region: '서울',
          englishOnly: true,
        ).map((s) => s.id),
        ['a'],
      );
    });

    test('키워드는 제목/장소/주소/인스타를 훑고 대소문자를 무시한다', () {
      // 'b'는 주소가 한글이라 라틴 키워드에는 걸리지 않는다 — 의도된 동작.
      expect(filterPickupSpots(spots, keyword: 'SEOUL').map((s) => s.id), [
        'a',
      ]);
      expect(filterPickupSpots(spots, keyword: '서울').map((s) => s.id), ['b']);
      expect(filterPickupSpots(spots, keyword: '해운대').map((s) => s.id), ['c']);
      expect(filterPickupSpots(spots, keyword: 'seoul6s').map((s) => s.id), [
        'a',
      ]);
    });

    test('키워드 공백은 무시', () {
      expect(filterPickupSpots(spots, keyword: '   ').length, 4);
    });

    test('좌표 없는 크루도 목록에는 남는다 (지도에만 안 뜸)', () {
      final r = filterPickupSpots(spots, englishOnly: true).map((s) => s.id);
      expect(r, contains('d'));
    });

    test('빈 목록에도 터지지 않는다', () {
      expect(filterPickupSpots([], region: '서울'), isEmpty);
    });
  });

  group('PickupSpot.fromDoc 파싱 계약', () {
    test('insta·region은 없으면 null (기존 문서 호환)', () {
      final s = spot();
      expect(s.insta, isNull);
      expect(s.region, isNull);
      expect(s.lat, isNull);
      expect(s.lng, isNull);
    });
  });
}
