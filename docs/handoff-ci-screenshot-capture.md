# 핸드오프 — CI 에뮬레이터 자동 스크린샷·영상 캡처 (다음 세션 시작점)

> 목표: **GitHub Actions 에뮬레이터에서 앱을 띄워 Play 스토어 스크린샷 + 릴스용 화면녹화를
> 자동으로 뽑아 아티팩트로 올리는 워크플로**를 구축한다. 이 파일부터 읽고 시작하면 된다.
> 관련: 마케팅 카피/스토리보드는 `docs/marketing-launch.md`, 배포 현황은 `docs/handoff-deploy-marketing.md`.

## 왜 CI 에뮬인가 (배경)
- 마케팅 에셋 중 **텍스트/스토리보드는 완료**, **실제 이미지·영상은 미제작**(`marketing-launch.md` D절 전부 미체크).
- 로컬(에이전트 컨테이너)은 **`/dev/kvm` 없음 + 가상화 플래그 없음** → 에뮬레이터 실행 불가로 확인됨.
- **GitHub Actions ubuntu 러너는 KVM 지원** → 에뮬 실제 구동 가능. 레포에 이미 에뮬 인프라 존재(아래).
- 실기기 캡처가 품질은 더 좋지만, 이 문서의 목적은 **반복·재현 가능한 자동 파이프라인**(매 버전 스샷 자동 갱신).

## 재사용할 기존 인프라
- `.github/workflows/e2e.yml` — `reactivecircus/android-emulator-runner@v2`, **api-level 34 · x86_64 · pixel_6**.
  이걸 템플릿으로 새 워크플로(`capture-assets.yml`)를 만든다.
- `integration_test/app_e2e_test.dart` — 기존 e2e 드라이버(참고용).
- `.github/workflows/build-apk.yml`(debug APK) · `release-aab.yml`(서명 AAB) — 앱 빌드 참고.
- `debug-fixed.keystore`(커밋됨) + 릴리스 keystore(시크릿 `ANDROID_KEYSTORE_*`).

## 산출물 (이 워크플로가 아티팩트로 내놔야 할 것)
### 1) Play 스토리보드 스크린샷 (1080×2400, pixel_6)
`marketing-launch.md` D절 + 기능 목록 기준, 각 화면 1장:
1. 지도(마커 뜬 상태) 2. 필터 적용 결과 3. 픽업 목록/상세 4. 클럽 상세 바텀시트
5. 도시락(찜 목록) 6. 밥이름 닉네임/프로필 7. 카카오 공유 8. 인스타 스토리 카드
- **KO 우선**, 여유되면 EN도(앱 내 수동 토글). Play는 최소 2장, 권장 4~8장.
### 2) 릴스 원본 화면녹화 (1080×1920 세로, mp4)
`marketing-launch.md` B절 7편 스토리보드대로 각 기능 조작을 녹화 → 편집 원본으로 넘김.
| # | 주제 | 녹화할 조작 |
|---|---|---|
| 1 | 지도로 팀 찾기 | 지도 열기 → 마커 탭 → 상세 |
| 2 | 필터 | 필터 3종 적용 → 결과 좁혀짐 |
| 3 | 픽업 게임 | 픽업 목록 → 참가 |
| 4 | 도시락 | 하트 → 도시락에 담김 |
| 5 | 밥이름 닉네임 | 닉네임 생성 |
| 6 | 공유 | 카톡/인스타 스토리 카드 |
| 7 | 피날레 | 지도 부드러운 패닝 |
- 피처 그래픽(1024×500)은 **캡처 아님 → 별도 디자인**. 이 워크플로 범위 밖.

## 기술 설계 — 핵심 결정 & 함정 (반드시 읽을 것)

### ⚠️ 함정 1: 네이티브 지도는 Flutter 스크린샷으로 안 잡힌다
`flutter_naver_map`은 **네이티브 SurfaceView(플랫폼 뷰)**. Flutter의
`IntegrationTestWidgetsFlutterBinding.takeScreenshot()` / `flutter drive --screenshot`은
**플랫폼 뷰를 검게(black) 캡처**한다. → 지도가 들어간 화면은 반드시
**`adb exec-out screencap -p > shot.png`** (프레임버퍼 전체 캡처)로 떠야 한다.
영상도 **`adb shell screenrecord`** 사용(네이티브 레이어 포함).

### ✅ 권장 드라이버: Maestro
- Maestro(`maestro test`)는 선언적 UI 플로우 + `takeScreenshot`이 **내부적으로 adb screencap 사용**
  → 지도 포함 네이티브 뷰까지 제대로 캡처. 좌표 하드코딩보다 견고(텍스트/id 매칭).
- 대안: 순수 `adb shell input tap/swipe` + `screencap`/`screenrecord`를 sleep으로 시퀀싱한
  쉘 스크립트(reactivecircus action의 `script:`에 인라인). 단순하지만 좌표 브ittle.
- 기존 `integration_test`는 로직 검증엔 좋지만 **지도 캡처엔 부적합**(함정 1). 캡처는 Maestro/adb로.

### ⚠️ 함정 2: DEBUG 리본
debug 빌드는 우상단 빨간 "DEBUG" 리본이 박힘 → 마케팅용 불가.
→ **release(또는 profile) APK**로 설치. release는 시크릿 keystore로 서명(업로드 키
`pw8B1jHS…`, 카카오 등록됨). `release-aab.yml`의 서명 스텝을 그대로 가져와 `flutter build apk --release`.

### ⚠️ 함정 3: 지도가 뜨려면 서명 키 + 데이터
- **네이버맵**: 패키지명 `com.nulloongzi.nulloongzido` 기반(NCP 등록됨) → 어떤 서명이든 뜸.
- **카카오/인스타 공유**: 카카오는 서명 키해시 필요 → release=업로드 키(`pw8B1jHS`) 등록됨 ✓.
  인스타는 FB App ID `1632483851162862`(정정됨) ✓.
- **데이터**: 마커가 있어야 지도가 예쁨 → e2e처럼 Firebase 에뮬(빈 데이터) 말고 **프로덕션
  Firestore**로 띄워야 실제 클럽 마커가 보인다. 앱 firebase 설정이 prod를 가리키는지 확인.
- **네트워크**: 에뮬에서 카카오/네이버/파이어스토어로 아웃바운드 되는지(러너는 보통 열림).

### ⚠️ 함정 4: 에뮬 GPU에서 지도 렌더 (최대 리스크)
x86_64 에뮬 소프트웨어 GL(SwiftShader)에서 네이버맵 타일이 **빈 화면**날 수 있음.
- 완화: `emulator-options: -gpu swiftshader_indirect` 시도, API/이미지 조합 바꿔보기,
  부팅 후 지도 뜰 때까지 충분히 대기.
- **가장 먼저 이걸 검증**하라(스모크: 지도 화면 1장만 떠보기). 안 되면 릴스/스샷 자동화는
  실기기 폴백으로 전환(사용자 폰). 헛수고 방지 위해 **1번으로 지도 렌더부터 확인**.

### 상태바 정리(프로 스샷)
캡처 전 Android demo mode로 상태바 고정:
```
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
# 끝나면: adb shell am broadcast -a com.android.systemui.demo -e command exit
```

## 단계별 실행 계획 (새 세션이 이 순서로)
1. **스모크**: `capture-assets.yml` 초안 — e2e.yml 복사 → Firebase 에뮬 제거, **prod 앱**으로
   release APK 설치 → 지도 화면 하나 `adb exec-out screencap` → 아티팩트 업로드.
   **지도 타일이 뜨는지부터 확인**(함정 4). 여기서 막히면 전략 재검토.
2. 지도 OK면 **Maestro 도입**: `.maestro/` 플로우 작성(기능별). Maestro 설치 스텝 추가.
   각 플로우 끝에 `takeScreenshot`. KO 기준 8화면.
3. **릴스 녹화**: 각 조작 시나리오를 `adb shell screenrecord`로 감싸 mp4 7편. (Maestro 실행과
   병렬로 screenrecord 시작/종료 시퀀싱.)
4. **정리**: 상태바 demo mode, 파일명 규칙(`play_01_map_ko.png`, `reel_1_findmap.mp4`),
   아티팩트 이름 `nulloongzido-marketing-assets`, retention 14~30일.
5. (선택) EN 캡처 세트, 다크/라이트, 디바이스 프로필 추가(태블릿 스샷 등).

## 리스크 & 폴백
- **지도 렌더 실패(함정 4)** = 최대 리스크 → 스모크로 조기 판정. 실패 시 **실기기(사용자 폰) +
  release APK** 로 폴백(품질은 더 좋음, 자동화만 포기). release APK 클린 빌드는
  `release-aab.yml`의 `--release` 방식으로 금방 가능.
- 좌표 브ittle → Maestro 텍스트/id 매칭 권장.
- prod 데이터 오염 주의: **읽기 전용 화면만** 조작(등록/찜 저장 같은 write는 테스트 계정으로).

## 구현 상태 (이 세션) — 파이프라인 착수 완료, CI 실행/보정 대기
파이프라인 골격을 만들었다. **아직 실제 러너에서 돌려보지 않았다** — 다음 세션의 첫 일은
smoke 실행으로 함정4(지도 렌더)를 판정하고, 성공하면 좌표를 보정하는 것.

### 추가된 파일
- `.github/workflows/capture-assets.yml` — 수동 실행(workflow_dispatch) 워크플로.
  입력: `build_type`(release|debug), `smoke_only`(기본 true), `capture_lang`(ko|en),
  `include_reels`. release=업로드 키(시크릿 `ANDROID_KEYSTORE_*`)로 서명(카카오 키해시 OK,
  함정2), debug=커밋된 `debug-fixed.keystore`(시크릿 불필요, 지도 렌더 검증용으로 충분).
  에뮬: api-34 · x86_64 · google_apis · pixel_6(=1080×2400, Play 규격) ·
  `-gpu swiftshader_indirect`(함정4 완화). Firebase 에뮬 없음 → **prod Firestore**(실제 마커).
- `scripts/capture/run_capture.sh` — 러너에서: 부팅 대기 → APK 설치 → demo mode 상태바 →
  **지도 렌더 스모크 게이트**(`adb exec-out screencap` + ImageMagick 평균밝기<0.03 이면 실패) →
  smoke_only면 종료, 아니면 Maestro 설치 후 스샷/릴스 캡처 → 아티팩트로 회수.
- `scripts/capture/record.sh` — 한 Maestro 플로우를 `adb shell screenrecord`로 감싸 mp4 녹화
  (SIGINT로 정상 flush). 네이티브 지도 레이어 포함(함정1).
- `.maestro/` — 캡처 플로우:
  - `flows/screens/` (게스트 열람, 기본 실행): `00_map`→play_01, `01_filter`→play_02,
    `02_pickup`→play_03(+상세), `03_club_detail`→play_04, `04_share`→play_07.
  - `flows/login/` (로그인 필요, **시크릿 `TEST_ACCOUNT_EMAIL/PASSWORD` 있을 때만**):
    `05_lunchbox`→play_05, `06_profile`→play_06(+닉네임). `_login_email.yaml` 이메일 로그인 서브플로우.
  - `flows/reels/` (`include_reels=true`): `reel_1_findmap`·`reel_2_filter`·`reel_3_pickup`·`reel_7_finale`.
  - 산출물 규격대로 파일명(`play_01_map_ko.png`, `reel_1_findmap.mp4`), 아티팩트
    `nulloongzido-marketing-assets`, retention 30일.

### 실행 순서 (다음 세션)
1. **Actions → "Capture Marketing Assets (emulator)" → Run**: `build_type=debug`, `smoke_only=true`.
   → 아티팩트 `screens/play_01_map_ko.png` 를 눈으로 확인. **검정이면 함정4** — job 로그의
   평균밝기 값 + `logs/logcat_smoke.txt` 확인, `-gpu`/이미지/대기 조정. 안 되면 실기기 폴백.
2. 지도 OK면 `build_type=release`, `smoke_only=false` 로 재실행 → 스샷/릴스 세트 확보.
3. **좌표 보정**: 아이콘 전용(필터 tune)·네이티브 마커·픽업 카드 탭은 `point:` 근사값이다
   (pixel_6 1080×2400 기준, 각 flow에 `⚠️ 보정` 주석). 첫 스샷을 보고 정확한 좌표/알려진
   칩 라벨로 교체. 텍스트 앵커(동호회/픽업/EN/적용하기/공유하기/🍱/🍚)는 그대로 견고.
4. 로그인 세트가 필요하면 레포 Secrets에 `TEST_ACCOUNT_EMAIL/PASSWORD`(전용 테스트 계정) 등록.
5. (선택) `capture_lang=en` 로 EN 세트.

### 알려진 한계 / 주의
- **미검증**: 워크플로/스크립트/플로우는 문법·구조만 확인. 에뮬 지도 렌더와 좌표는 실행 후 확정.
- prod 쓰기 방지: 열람 화면만 조작. 픽업 '참가'·닉네임 '저장'은 누르지 않음. 로그인 세트는
  전용 테스트 계정 사용.
- 릴스 원본은 디바이스 해상도(1080×2400)로 녹화 → 릴스(1080×1920)는 **편집에서 크롭**.

## ✅ 최종 해결 — 앱 "캡처 디렉터"(딥링크)로 완전 자동화 (CI 7런째 성공)
좌표 탭·마커 운·언어 브리틀함을 **앱 코드로 근본 해결**. 이제 **push 한 번에 8화면 KO
스샷 + 릴스 3편이 결정적으로** 나온다(수동 개입 0).

**앱(`kCaptureMode` = `--dart-define=CAPTURE_MODE=true` 빌드 전용):**
- `deep_link_service.dart`: `?capture=<cmd>&lang=ko` 파싱.
- `map_screen._runCapture()`: KO 강제(`appLang`) + 데이터 로드 대기 후 화면을 **결정적으로** 오픈.
  상세용 클럽은 급구→검증→첫 순으로 선택(예쁜 컷, 매번 동일). 도시락/프로필은 익명 로그인
  우회 + 데모 찜 1건 시드로 빈 화면 방지. 일반 릴리즈엔 무영향(플래그 off).
- 지원 cmd: `map/filter/pickup/detail/share/story/lunchbox/profile/login`.

**CI(`run_capture.sh`):** `am start -a VIEW -d 'https://nulloongzi.github.io/?capture=<cmd>&lang=ko'`
(디바이스 셸 single-quote로 `&` 보호)로 8화면 캡처. 릴스는 지도 로드 후 녹화 시작→액션
딥링크로 카메라비행/시트슬라이드 모션 유발.

**검증된 산출(run #7, debug):** play_01 지도 / 02 필터 / 03 픽업탭 / 04 상세(피터팬) /
05 도시락(찜 시드) / 06 밥이름 프로필(오곡밥-gnp) / 07 공유메뉴 / 08 인스타스토리 — **전부
한국어·ANR無·매번 동일**. FP mean이 화면별로 모두 다름(=결정적 내비 성공). 릴스 3편.

> 아래 "6런 검증 결과 / 좌표표"는 디렉터 도입 전(좌표 탭) 기록 — 히스토리로 남김.
> 좌표는 더 이상 안 쓴다(딥링크가 대체).

### ⚠️ 함정 5: 남겨둔 ANR 탭이 스샷을 망가뜨린다 (run #12에서 발각)

"좌표는 더 이상 안 쓴다, **ANR dismiss(300,1360)만 유지**" — 그 하나가 문제였다.

`dismiss_anr()` 의 옛 판정은 **"포커스 줄에 앱 이름이 안 보이면 ANR로 간주하고 탭"** 이었다.
멀티 디스플레이 에뮬에서 `dumpsys window | grep -m1 mCurrentFocus` 가 먼저 걸리는 가상
디스플레이의 `mCurrentFocus=null` 을 집는 바람에, **앱이 멀쩡히 떠 있는데도 매 캡처마다
화면 한복판(300,1360)을 눌렀다.** `cap()` 이 스샷 직전에 이걸 부르므로 피해가 확정적이다.

run #12 결과 8장 중 5장이 이 탭 때문에 엉뚱한 화면이었다:

| 스샷 | 탭이 누른 것 | 실제로 찍힌 화면 |
|---|---|---|
| 01 지도 | 지도 마커 | 클럽 상세 시트 |
| 05 도시락 | 찜 목록의 클럽 카드 | 클럽 상세 시트 |
| 06 프로필 | 네임카드의 로그아웃 버튼 | **"로그아웃 하시겠습니까?" 확인창** |
| 07 공유 | 공유 메뉴 스크림 | 클럽 상세 시트 |
| 02·04 | 빈 영역 | (우연히) 정상 |

**FP mean만 보고 "화면별로 값이 다르니 결정적 내비 성공"이라고 판정한 게 run #7의 오류다.**
값이 다른 것과 의도한 화면인 것은 다르다. 썸네일을 실제로 열어봐야 한다.

**수정:** ANR 다이얼로그가 실제로 떠 있다는 **양성 증거**(`Application Not Responding` /
`Application Error` / `isn't responding`)가 있을 때만 탭한다. 증거가 없으면 아무것도 누르지
않는다. 없는 것을 근거로 행동하지 말 것 — 그게 이 버그의 형태였다.

### 화면 세트 (현재 9장)
`map / filter / pickup / detail / lunchbox / profile / share / story / login`

- `pickup` 은 목록 패널(`_pickupListView = true`)로 연다. 지도만 찍으면 스토어에서
  "픽업"인지 알아볼 수 없다.
- `story` 는 `shareStoryCard()` 를 부르지 않는다 — 그건 '링크 스티커' **안내 다이얼로그**부터
  띄워서 안내문이 찍힌다. 공유 이미지 미리보기(`ShareImageScreen`)를 연다.
- `login` 은 `LoginScreen` 을 push. 캡처 빌드에 `--dart-define=NAVER_LOGIN_ENABLED=true` 를
  주므로 카카오·네이버 버튼이 **스토어에 나가는 릴리즈 AAB와 동일하게** 보인다.

## 실행 검증 결과 (CI 6런, 2026-07-22) — 파이프라인 실동작 확인
GitHub Actions에서 6번 돌려 **에뮬레이터 실기동 캡처를 실제로 검증**했다(로그 base64 썸네일로 육안 확인).
함정4·ANR·드라이버 이슈를 모두 해결하고 마케팅 자산을 뽑는 파이프라인이 **동작함**.

### 해결한 3대 이슈
1. **함정4(지도 렌더)** — SwiftShader에서 네이버맵이 실제로 뜬다(평균밝기 0.87, 서울 전역
   마커·클러스터·급구 티커까지). 스모크 게이트 통과.
2. **Maestro 폐기** — Maestro가 이 앱(네이티브 NaverMap+Flutter)의 **접근성 트리를 못 읽어**
   모든 텍스트 매칭 실패(`Assertion "동호회" is visible = false`). → **순수 adb 좌표 탭**
   (`input tap/swipe` + `screencap`/`screenrecord`)으로 전환. `.maestro/`는 참고용으로 남김.
3. **런처 ANR** — "Pixel Launcher isn't responding" 팝업이 화면을 덮고 탭 포커스를 훔침.
   `hide_error_dialogs`는 이 런처 ANR엔 무효 → `dismiss_anr()`(포커스가 앱이 아니면 'Wait'
   버튼 탭 + CLOSE_SYSTEM_DIALOGS)로 능동 제거. **해결됨**.

### 안정적으로 나오는 것 (매 런)
- **play_01 지도** — 깨끗(ANR無), 실데이터, release 서명. **히어로 스샷**.
- **play_02 필터 시트** — 지역/요일/대상 칩. 필터 아이콘(954,211)이 안정적 → 매번 성공.
  (참고: 필터 시트는 앱 언어와 무관하게 **항상 한국어** — strings.dart 설계: 등록/필터 폼은
  개설자 대상이라 KO 고정.)
- **릴스 3편**(reel_1_findmap/3_pickup/7_finale) mp4. 8~10MB.
- 릴리스 서명 빌드(시크릿 유효, step6/9 success).

### 아직 브리틀 (좌표/데이터 의존 — 다음 세션 보정)
- **픽업 탭 전환** — 탭 pill은 고정 UI인데 좌표(765,420)가 근소하게 빗나감. 실측 재보정 필요.
- **마커→상세** — 마커 위치가 **런마다 카메라/데이터에 따라 달라** 고정좌표(540,980)가
  맞을 때(라운드2: 실제 클럽 상세 '시흥 픽업게임' 캡처 성공)와 빗나갈 때가 있음. 근본적 브리틀.
  → 대안: 앱에 "첫 마커로 카메라 이동/상세 열기" 딥링크나 테스트 훅을 두면 결정적.
- **공유 메뉴(play_07)** — 상세가 열려야 도달 → 상세 브리틀에 종속.
- **언어**: 에뮬 로케일이 en이라 지도/탭 chrome이 영어. 인앱 토글(864,211) 탭이 빗나감.
  → 더 견고: **에뮬 AVD 로케일을 ko-KR로** 설정하거나 토글 좌표 재실측.

### 확정/측정 좌표 (1080×2400, pixel_6, 급구 티커 있을 때)
| 요소 | 좌표 | 상태 |
|---|---|---|
| 검색바 행 y | 211 | ✅ |
| 필터(tune) 아이콘 | 954,211 | ✅ 안정 |
| 언어 토글 '한' | ~846,211 | ⚠️ 재실측 |
| 탭 행 y | ~420 | ✅ |
| 동호회 탭 x / 픽업 탭 x | 430 / 765 | ⚠️ 픽업 재보정 |
| 마커(상세) | 540,980 | ⚠️ 데이터 의존 |
| 상세 '공유' 버튼 | 877,2283 | (상세 열리면) |
| ANR 'Wait' | 300,1360 | ✅ 동작 |

### 워크플로 실행 방법(확정)
- 워크플로가 default 브랜치에 없어 API `workflow_dispatch`는 404. → `claude/**` **push**로 실행.
  일반 push는 debug+smoke(안전). 커밋 메시지 마커로 승격: `[cap-full]`(전체) `[cap-reels]`(릴스)
  `[cap-release]`(서명). 예: 마커 3개 넣고 push → release 전체 세트.
- 결과 검증: 아티팩트 호스트(blob)가 에이전트 프록시에 막히면, 스크립트 `fingerprint()`가
  **각 스샷 평균밝기 + JPEG 썸네일을 CI 로그에 base64로** 출력하므로 로그만으로 육안 검증 가능.
- ⚠️ 에뮬 boot는 간헐 실패(`Timeout waiting for emulator to boot`) — 재실행하면 됨.
  에뮬 리소스를 과하게(-cores 4 on 4-vCPU) 주면 부팅 불안정 → 기본값 근처 유지.

## 참고 경로
- 캡처 워크플로/스크립트/플로우: `.github/workflows/capture-assets.yml`, `scripts/capture/`, `.maestro/`
- 마케팅 카피·릴스 스토리보드: `docs/marketing-launch.md` (A절 카피 / B절 릴스7편 / D절 체크리스트)
- 디자인 규격: `docs/design-system.md`
- 에뮬 워크플로 템플릿: `.github/workflows/e2e.yml`
- 앱 빌드/서명: `.github/workflows/release-aab.yml`, `build-apk.yml`, `android/app/build.gradle.kts`
- SDK 키/서명 요약(카카오 키해시 3종, 네이버 패키지명, FB App ID): `docs/handoff-deploy-marketing.md`

## 상태 스냅샷 (이 문서 작성 시점)
- 앱 코드: main에 등록 마찰 개선 + 측정 파리티 + FB App ID 정정 반영 완료(`2.0.0+6`).
- 정정 서명 AAB 빌드 완료(Actions Release AAB 런 #3). Play 업로드는 업로드 키 유예로 대기 중.
- 실기기 debug APK로 지도·카카오·인스타 스토리 3종 동작 검증 완료(단 DEBUG 리본).
- **캡처 파이프라인 실동작 검증 완료** — CI 6런으로 함정4·ANR·Maestro 이슈 해결, 지도/필터
  스샷 + 릴스 3편을 release 서명으로 안정 생산 확인. 상세는 "실행 검증 결과" 섹션 참조.
  잔여: 픽업/마커/공유 좌표 브리틀, 언어(에뮬 로케일), 로그인 세트(테스트 계정 시크릿).
