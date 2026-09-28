// 예약 닉네임 판정 — 웹 레포 firestore.rules · js/profile.js 와 같은 목록·같은 정규화.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nulloongzido/services/profile_service.dart';

void main() {
  test('룰과 같은 단어 목록', () {
    // firestore.rules: matches('.*(누룽지|nulloongzi|nuloongzi|nullongzi|nurungji|nurungzi|nuroongzi).*')
    expect(
      kReservedNicknameWords.join('|'),
      '누룽지|nulloongzi|nuloongzi|nullongzi|nurungji|nurungzi|nuroongzi',
    );
  });

  test('변형도 걸린다', () {
    for (final n in [
      '누룽지',
      '누룽지2',
      '누 룽 지',
      '누룽지도',
      'Nulloongzi',
      'NULL_OONGZI',
      'null-oongzi',
      'Null.Oongzi',
      'nurungji',
      'x누룽지x',
    ]) {
      expect(isReservedNickname(n), isTrue, reason: n);
    }
  });

  test('보통 이름은 통과', () {
    for (final n in [
      '현미밥-a3k',
      '누룽',
      '룽지',
      '밥아저씨',
      'null',
      'oongzi',
      '',
      null,
    ]) {
      expect(isReservedNickname(n), isFalse, reason: '$n');
    }
  });

  test('운영자 · 공식 계정만 예약 닉네임을 쓸 수 있다', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('admins').doc('admin').set({'x': 1});
    await db.collection('official_accounts').doc('sub').set({'x': 1});
    final svc = ProfileService(db: db);
    expect(await svc.canUseReservedNickname('admin'), isTrue);
    expect(await svc.canUseReservedNickname('sub'), isTrue);
    expect(await svc.canUseReservedNickname('someone'), isFalse);
  });
}
