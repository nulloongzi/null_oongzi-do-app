// 밥도감 표 — 웹 tests/my-card.test.js '밥도감 표' 와 같은 기대값.
// 번호·희귀도·상차림 경계가 웹과 어긋나면 같은 친구 목록이 플랫폼마다 다른 단계로 보인다.
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/friends_service.dart';
import 'package:nulloongzido/services/rice_dex.dart';

void main() {
  test('25종 · 번호는 kRiceData 순서 · 희귀도는 뽑기 가중치', () {
    expect(RiceDex.total, 25);
    final a = RiceDex.info('현미밥')!;
    expect([a.no, a.color, a.rarity], [1, '#FFF9C4', RiceRarity.common]);
    expect(RiceDex.info('오곡밥')!.rarity, RiceRarity.common);
    expect(RiceDex.info('차조밥')!.rarity, RiceRarity.rare);
    expect(RiceDex.info('밥아저씨')!.no, 25);
    expect(RiceDex.info('밥아저씨')!.rarity, RiceRarity.legend);
    expect(RiceDex.info('누룽지'), isNull);
    expect(RiceDex.riceOf('흑미밥-z9'), '흑미밥');
  });

  test('상차림: 혼밥 1 · 밥상 2–5 · 한상차림 6–12 · 잔칫상 13–24 · 수라상 25', () {
    List<int> st(int n) {
      final s = RiceDex.stageOf(n);
      return [s.lv, s.next, s.need];
    }

    expect(st(1), [1, 2, 1]);
    expect(st(5), [2, 3, 1]);
    expect(st(6), [3, 4, 7]);
    expect(st(9), [3, 4, 4]);
    expect(st(13), [4, 5, 12]);
    expect(st(24), [4, 5, 1]);
    expect(st(25), [5, 0, 0]);
  });

  test('밥친구 전체 + 나, 같은 밥은 한 번, 도감에 없는 이름은 세지 않는다', () {
    final x = RiceDex.build('현미밥', ['현미밥', '흑미밥', '흑미밥', '팥밥', '밥아저씨', '']);
    expect(x.count, 3);
    expect(x.owned, {'현미밥', '흑미밥', '밥아저씨'});
    expect(x.mine!.no, 1);
    expect(x.stage.lv, 2);
    // 내 닉네임이 도감 밖이어도 친구 밥은 센다
    final y = RiceDex.build('누룽지', ['백미밥']);
    expect(y.mine, isNull);
    expect(y.count, 1);
  });

  test('친구 밥 종류: users.nickname 이 있으면 그것, 없으면 밥이름 앞부분', () {
    expect(const FriendProfile('흑미밥-z9', '#FFF176').rice, '흑미밥');
    expect(const FriendProfile('맛있는흑미-z9', '#FFF176', '흑미밥').rice, '흑미밥');
  });
}
