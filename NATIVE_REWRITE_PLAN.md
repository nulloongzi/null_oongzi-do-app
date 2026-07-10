# 누룽지도 — 풀 네이티브 재작성 플랜

> 결정(2026-06): WebView 셸 → **풀 네이티브 Flutter** 로 재작성. 지도는 **카카오맵 유지**.
> 이 문서가 멀티주 작업의 앵커. 세션이 바뀌어도 여기서 이어간다.

---

## 0. 목표 / 비목표
- **목표**: 끊김 없는 네이티브 UX. 구글 로그인 정상화(웹뷰 OAuth 차단 탈출), 부드러운 전환.
- **지도**: 카카오 데이터 유지 → `kakao_map_plugin`(내부 WebView 기반) 또는 카카오 네이티브 SDK 채널. ⚠️ 완전 네이티브 지도는 아님(카카오 공식 Flutter SDK 부재).
- **웹은 유지**: `nulloongzi.github.io/...?club=/?spot=` 는 **미설치자 즉시 진입(인스타 깔때기) + SEO** 용으로 남긴다. 네이티브는 설치자용 주 경험.
- **데이터**: 기존 Firestore 컬렉션(`clubs`, `pickup_games`, `users`, `verification_requests`) **그대로 재사용 — 마이그레이션 없음.** 룰도 그대로.
- **비목표**: 데이터 모델 변경, 웹 폐기.

## 1. 작업 환경 현실 (중요)
- 이 클라우드 샌드박스엔 **Flutter SDK 없음** → 네이티브는 **CI(GitHub Actions) APK 빌드로만** 검증. 매 변경 = 빌드(수 분)+실기기 설치. **풀 재작성엔 매우 느림.**
- **강력 권장**: 로컬 Flutter 개발환경(또는 Flutter 깔린 환경) 확보. 그러면 hot reload로 수십 배 빠름. 안 되면 CI 루프로 진행은 가능(느림 감수).

## 2. 아키텍처
- **Flutter** (기존 프로젝트 재사용, `lib/` 재구성).
- **Firebase (네이티브 SDK)**: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_analytics`.
  - `firebase_options.dart` 생성(FlutterFire CLI `flutterfire configure`) — 기존 `google-services.json`(Android) 재사용, iOS는 `GoogleService-Info.plist` 필요.
- **인증**: `firebase_auth` + `google_sign_in`(이미 의존성 있음) + 이메일. → 웹뷰 OAuth 차단 문제 해소.
- **지도**: `kakao_map_plugin`(WebView 기반) 우선 검토. 마커/클러스터/오버레이 동등 기능 확인 후 확정.
- **상태관리**: 가볍게 `provider` 또는 `ChangeNotifier`(과설계 금지).
- **i18n**: `flutter_localizations` + ARB, 또는 기존 KO/EN 딕셔너리 포팅.
- **모델**: `Club`, `PickupSpot` 등 Firestore ↔ Dart 모델 + 레포지토리 계층.

## 3. 단계 (Phase) — 각 단계 = CI 빌드 + 실기기 검증
- **P0 셋업**: 의존성 추가, `firebase_options.dart`, 폴더 구조(`lib/{models,services,screens,widgets,l10n}`), CI 빌드 유지. (기존 웹뷰 main.dart는 native 준비될 때까지 보존 → 깨진 앱 배포 방지)
- **P1 인증** (최우선·기반): 네이티브 구글/이메일 로그인 + 프로필. → "권한(로그인)" 문제 해결.
  - ⚠️ Firebase에 앱 **SHA-1 등록** 필요. CI 디버그 키스토어가 매번 바뀌는 문제 → **고정 디버그 키스토어를 레포에 커밋**(디버그용은 비밀 아님)해 SHA-1 안정화 → 1회 등록.
- **P2 데이터 계층**: Firestore 모델 + 레포지토리(clubs/pickup 읽기·쓰기), 익명 인증.
- **P3 지도 화면**: 카카오맵 + 마커/클러스터 + 동호회/픽업 탭 + 검색/필터.
- **P4 상세 바텀시트**: 클럽/픽업 상세 + 공유(스토리 카드: 네이티브 렌더 or 카드용 미니 WebView 재사용 검토).
- **P5 등록 폼**: 클럽/픽업 등록 + 지도 피커 + 지오코딩.
- **P6 부가**: 도시락, 프로필, 급구 티커, i18n, 릴스 임베드.
- **P7 딥링크**: Android App Links / iOS Universal Links → `?club=/?spot=`가 **앱으로** 열림(+웹 폴백 유지).

## 4. 사람 선결조건 (코드로 못 함)
1. **로컬 Flutter 개발환경**(강력 권장 — 속도) 또는 CI 루프 수용.
2. **Firebase에 앱 SHA-1 등록**(구글 로그인용). 고정 디버그 키스토어 SHA-1은 P1에서 뽑아 전달.
3. **iOS 타겟이면** Firebase iOS 앱 + `GoogleService-Info.plist`.
4. **지도 플러그인 확정**(`kakao_map_plugin` 기능 검토 결과 보고 결정).

## 5. 리스크
- 카카오맵 플러그인이 WebView 기반 → 지도 부분은 "완전 네이티브"가 아니며, 기존 웹뷰의 렌더 이슈가 지도 화면에 일부 남을 수 있음.
- 풀 재작성 = 큰 표면적. 기능 누락/회귀 위험 → 단계별 실기기 검증 필수.
- CI-only 개발은 느림 → 로컬 환경 확보가 사실상 권장 조건.

## 6. 다음 액션
- **P1(인증)부터 시작.** 고정 디버그 키스토어 생성 → SHA-1 산출 → Firebase 등록 안내 → 네이티브 로그인 구현 → CI 빌드 → 실기기 확인.
- 웹앱(funnel)은 그대로 운영(스토리 카드/딥링크/임베드는 이미 라이브).
