// 도시락통처럼 MapScreen 밖에서 연 상세가 팀을 고친 뒤 지도 목록을 다시 읽게 하는 신호.
// showClubDetail 의 onChanged 로 requestClubsReload 를 넘기면, 듣고 있는 MapScreen 이 _load 한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/screens/detail_sheet.dart';

void main() {
  test('requestClubsReload 는 부를 때마다 듣는 쪽을 한 번씩 깨운다', () async {
    var heard = 0;
    void listener() => heard++;
    clubsReloadRequest.addListener(listener);
    addTearDown(() => clubsReloadRequest.removeListener(listener));

    await requestClubsReload();
    await requestClubsReload();
    expect(heard, 2);
  });
}
