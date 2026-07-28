# 핸드오프 — 배포 준비 & 마케팅 (다음 세션 시작점)

> 이 문서는 테스트 인프라(Phase 1~3)를 마친 세션이, **배포 준비 + 마케팅 전략** 세션으로
> 넘기기 위한 컨텍스트 요약이다. 새 세션은 이 파일부터 읽고 시작하면 된다.

## 📌 진행 현황 (2026-07-22 업데이트)
배포 준비 대부분 완료. **남은 건 Play 내부테스트 업로드 1건**.

- ✅ **웹**: GitHub Pages 라이브 배포 완료 (등록 마찰 개선 반영, 커밋 `7283363`).
- ✅ **앱 코드**: 팀 등록 마찰 4종 개선 + 측정 이벤트 파리티 + FB App ID 정정 전부 main 반영.
- ✅ **서명 릴리스 빌드**: `release-aab.yml`(workflow_dispatch)로 **서명된 AAB** 빌드 가능해짐.
  최신 정정본 AAB = [Actions 런 #3](https://github.com/nulloongzi/null_oongzi-do-app/actions/runs/29896465501) 아티팩트 (`2.0.0+6`).
- ✅ **SDK 릴리스 등록 + 실기기 검증**(debug APK, `debug-fixed` 서명):
  - 네이버맵: NCP Maps 앱에 패키지명 `com.nulloongzi.nulloongzido` 등록됨 (client id `t4mzao93mh` 일치) → 지도 정상.
  - 카카오: Android 플랫폼에 키해시 3종 등록(디버그 `7+iGjU4…` / 앱서명 `SRKtuXxf…` / 업로드 `pw8B1jHS…`) → 공유 정상.
  - 인스타 스토리: FB App ID를 **비즈니스 ID(잘못) → 실제 App ID `1632483851162862`로 정정** → 스토리 공유 정상.
- ✅ **패키지명/서명키/versionCode**: Play 업로드 시도가 "서명 인증서" 단계까지 도달 → 패키지명 일치·versionCode 6>live 사실상 확인.
- ⏳ **남은 1건**: 업로드 키 재설정 유예로 인해 **재업로드는 2026-07-22 22:22 KST 이후 가능**. 그때 런 #3 AAB를
  내부테스트 트랙에 업로드 → Play 앱서명 키 경로 최종 확인.

## 제품 개요
- **누룽지도** — 한국 배구 동호회 찾기 지도 앱. 지역/요일/대상 필터, 픽업 게임, 도시락(찜한 팀),
  밥이름 닉네임, 카카오 공유, KO/EN 다국어.
- 데이터: Firestore 단일 소스(`clubs`/`pickup_games`). 인앱 등록 + 카카오 챗봇으로 인증/관리.

## 레포 2개
| 레포 | 스택 | 배포 |
|---|---|---|
| `nulloongzi/null_oongzi-do` (웹) | Vanilla JS + Firebase + Kakao Maps | GitHub Pages, 라이브 (nulloongzido.com) |
| `nulloongzi/null_oongzi-do-app` (앱) | Flutter 네이티브 + 네이버맵 | ⚠️ 아래 "배포 이력" 참고 |

## 배포 이력 (중요)
- **Google Play에 이미 출시돼 있음** — "누룽지도 - 배구 동호회 지도" (개발자 Nulloongzi,
  **10+ 다운로드**, 3세 이상). 단, **기존 스토어 버전은 웹뷰 앱**.
- 스토어 자산 이미 존재: 아이콘(밥그릇+배구공), 스크린샷 4장, 앱 지원 링크.
- **이번 Flutter 앱(`null_oongzi-do-app`) = 웹뷰 → 네이티브 재작성.** 즉 신규 출시가 아니라
  기존 리스팅을 **업데이트로 교체**하는 시나리오.

## 배포의 첫 갈림길 (해결됨 — 기록용)
**기존 웹뷰 앱과 같은 리스팅으로 무중단 업데이트하려면** 아래가 일치해야 한다:
- **패키지명(applicationId):** `com.nulloongzi.nulloongzido` (`android/app/build.gradle.kts`).
  → ✅ Play 업로드가 서명 단계까지 도달 = 기존 리스팅과 패키지명 일치 확인됨.
- **업로드 서명 키:** ✅ 레포 릴리스 keystore가 Play가 인식한 (재설정된) 업로드 키와 일치.
  단 **업로드 키 재설정 유예**로 2026-07-22 22:22 KST 이후 재업로드 가능.
- **versionCode:** 현재 `pubspec.yaml` = **`2.0.0+6`** (versionCode 6). ✅ 업로드 시 버전 에러 없었으므로 live보다 큼.

## 배포 전 기술 체크리스트 (앱)
- [x] 패키지명/서명/versionCode 일치 (위 — Play 업로드 시도로 확인)
- [x] 프로덕션 SDK 등록: 네이버맵(패키지명), 카카오(키해시 3종), FB(App ID 정정) — **실기기 debug APK로 3종 동작 검증 완료**
- [x] release 빌드: `release-aab.yml`로 서명 AAB 빌드 (`.github/workflows/build-apk.yml`은 debug APK 사이드로드용)
- [ ] **Play 내부테스트 업로드** → 앱서명 키 경로 최종 확인 (업로드 키 재설정 유예는 2026-07-22 만료 — 이제 가능)
- [ ] 스토어 리스팅 갱신: 네이티브 전환에 맞춰 스크린샷/설명 업데이트 여지

### 소셜 로그인 추가(2026-07-28, `2.1.0+7`)에 따른 배포 영향
- [x] 릴리즈 AAB에 네이버 시크릿 주입: `release-aab.yml`이 `NAVER_CLIENT_SECRET` 주입 +
      `--dart-define=NAVER_LOGIN_ENABLED=true`. 시크릿 없으면 빌드를 **실패**시켜
      "네이버 버튼 빠진 릴리즈"가 스토어에 나가는 사고를 막는다.
- [x] 카카오 로그인: 콘솔 Android 플랫폼에 키해시 3종(디버그/앱서명/업로드) 이미 등록됨 →
      Play 앱서명 빌드에서도 로그인 동작. 별도 등록 불필요.
- [x] 네이버 로그인: 콘솔 "로그인 오픈 API 서비스 환경"에 Android 패키지명 등록 완료.
      (네이버는 키해시를 쓰지 않고 패키지명으로 식별)
- [ ] **개인정보처리방침 갱신 필요** — 웹 레포 `privacy.md`가 일반 템플릿 상태라
      소셜 로그인 수집 항목(카카오/네이버 회원번호, 구글 계정 이메일)과 처리위탁(Google Firebase)이
      빠져 있다. Play **데이터 보안(Data safety)** 설문과 내용이 일치해야 한다.
- [ ] Play 데이터 보안 설문 갱신: 계정 식별자·이메일 수집 항목 반영
- [ ] iOS도 낼지 결정(현재 android 중심; `ios/` 존재하나 App Store 이력 불명. FB Info.plist도 정정됨)

## 테스트/CI 상태 (방금 완료 — 안심하고 배포 가능한 근거)
Phase 1~3 완료, 두 레포 main green. 코드 변경 시 자동 게이트가 회귀를 막음.
- 웹: ESLint · 유닛 90 · Firestore/Storage 룰 55(에뮬) · Playwright 스모크 4 — push/PR 게이트
- 앱: `analyze --fatal-infos`+`format` 하드 게이트 · 테스트 68(순수+fake Firebase+골든) — push/PR 게이트
- 앱 e2e: 안드 에뮬 + Firebase 에뮬 실흐름(게스트 게이트→로그인→도시락→등록 룰) — 수동/주간 스케줄
- 부수 성과: 인증 승인 페이지 **XSS 취약점 수정**, 기존 미사용 코드 정리.

## 마케팅 프레이밍 (정정된 현실)
- **콜드 런칭 아님 → "리론치 + 초기 성장".** 이미 스토어에 있으나 10+ 다운로드라 사실상 제로베이스.
- 소구점 후보: 웹뷰→네이티브 전환으로 **"부드러운 지도·빠른 앱"**, 픽업 게임/도시락/밥이름 차별 기능,
  전국 배구 동호회를 지도 한 눈에.
- 타깃: 배구 동호회 가입 희망자, 픽업 게임 참가자. (KO 우선, EN 지원)
- 채널 아이디어(다음 세션에서 구체화): 배구 커뮤니티/카페/인스타, 동호회 총무 대상 등록 유도,
  기존 웹(nulloongzido.com)과의 유입 연계.

## 참고 파일 경로
- 앱: `lib/main.dart`(네이버맵/카카오 SDK 키·초기화) · `lib/services/story_share.dart`(FB App ID `kFacebookAppId`) ·
  `android/app/src/main/res/values/strings.xml`(`facebook_app_id`) · `ios/Runner/Info.plist`(FacebookAppID) ·
  `android/app/build.gradle.kts`(패키지·서명, debug=`debug-fixed.keystore`) · `pubspec.yaml`(version `2.0.0+6`)
- 릴리스: `.github/workflows/release-aab.yml`(서명 AAB, 수동) · `.github/workflows/build-apk.yml`(debug APK, 수동)
- 웹: `privacy.md` · `docs/testing-methodology.md`(테스트 사다리 근거)
