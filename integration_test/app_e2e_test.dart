// integration_test/app_e2e_test.dart — Tier 4 e2e (방법론 Phase 3).
// 실기기/에뮬레이터에서 앱을 실제 부팅해 Firebase Local Emulator(Auth/Firestore/Storage)
// 스위트에 붙인 뒤, 게스트 게이트 → 익명 로그인 → 도시락 → 등록(룰 통과) 라운드트립을
// 한 시나리오로 검증한다.
//
// 실행(CI: .github/workflows/e2e.yml):
//   flutter test integration_test --dart-define=EMU_HOST=10.0.2.2
// 전제: Firebase 에뮬레이터 기동(auth 9099 / firestore 8080 / storage 9199,
//       룰은 웹 레포 firestore.rules/storage.rules).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nulloongzido/main.dart' as app;
import 'package:nulloongzido/firebase_options.dart';
import 'package:nulloongzido/screens/login_screen.dart';
import 'package:nulloongzido/screens/lunchbox_screen.dart';
import 'package:nulloongzido/services/data_repository.dart';

// 안드로이드 에뮬레이터에서 호스트 머신은 10.0.2.2.
const _emuHost = String.fromEnvironment('EMU_HOST', defaultValue: '10.0.2.2');

/// finder가 나타날 때까지 폴링. NaverMap 플랫폼뷰/티커 때문에 pumpAndSettle은
/// 수렴하지 않을 수 있어 고정 간격 pump로 대기한다.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('시간 내에 위젯을 찾지 못함: $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // main()보다 먼저 초기화해 에뮬레이터에 연결 (main은 apps.isEmpty 가드로 스킵).
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAuth.instance.useAuthEmulator(_emuHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(_emuHost, 8080);
    await FirebaseStorage.instance.useStorageEmulator(_emuHost, 9199);
  });

  testWidgets('e2e: 부팅 → 게스트 게이트 → 익명 로그인 → 도시락 → 등록 룰 라운드트립', (tester) async {
    // ── 0. 게스트 상태 보장 + 부팅 ──
    await FirebaseAuth.instance.signOut();
    app.main();
    // 지도 셸 UI(도시락 FAB)가 뜰 때까지 대기 = Firebase init + 첫 로드 완료
    await pumpUntil(
      tester,
      find.text('🍱'),
      timeout: const Duration(seconds: 40),
    );

    // ── 1. 게스트 게이트: 로그인 없이 도시락 → LoginScreen ──
    await tester.tap(find.text('🍱'));
    await pumpUntil(tester, find.byType(LoginScreen));
    expect(
      find.byType(LunchboxScreen),
      findsNothing,
      reason: '게스트에게 도시락이 바로 열리면 안 됨',
    );
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump(const Duration(milliseconds: 600));

    // ── 2. 익명 로그인(Auth 에뮬레이터) 후 도시락 열림 ──
    await FirebaseAuth.instance.signInAnonymously();
    expect(FirebaseAuth.instance.currentUser, isNotNull);
    await tester.tap(find.text('🍱'));
    await pumpUntil(tester, find.byType(LunchboxScreen));
    expect(find.byType(LoginScreen), findsNothing);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump(const Duration(milliseconds: 600));

    // ── 3. 등록 라운드트립: 프로덕션 경로(DataRepository) → 실제 룰 통과 검증 ──
    final repo = DataRepository();

    // 클럽: registered_by==uid·is_verified=false 등 룰 필드가 create를 통과해야 함
    final clubId = await repo.createClub({
      'name': 'e2e검증클럽',
      'address': '서울 강남구',
      'coordinates': {'lat': 37.5, 'lng': 127.0},
    });
    final club = await repo.getClub(clubId);
    expect(club, isNotNull);
    expect(club!.name, 'e2e검증클럽');
    expect(club.isVerified, false);

    // 픽업: owner_uid==uid 룰 + 만료 필터 통과(expire_at 없음=상시)
    await repo.createPickup({'title': 'e2e픽업', 'english_ok': true});
    final spots = await repo.loadPickups();
    expect(spots.any((s) => s.title == 'e2e픽업'), true);

    // 뒷정리(에뮬레이터라 필수는 아니지만 재실행 안정성)
    await repo.deleteClub(clubId);
  }, timeout: const Timeout(Duration(minutes: 6)));
}
