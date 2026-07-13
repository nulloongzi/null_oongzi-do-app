# 배포 준비 (Deploy Readiness) — Google Play 리론치

> 출발점: `docs/handoff-deploy-marketing.md`. 이 문서는 그 핸드오프의 체크리스트를 **실제 코드에
> 대조해 검증**하고, 남은 갭과 사람이 해야 할 작업을 실행 순서로 정리한다.
> 상태 범례: ✅ 코드 확인됨 · ⚠️ 사람 확인 필요(코드로 불가) · ⛔ 갭(작업 필요)

---

## 0. 지금 상태 한 줄 요약
앱 코드는 **사실상 배포 가능**하다 — main green, 웹과 기능 패리티(`docs/feature-parity.md`),
네이티브 재작성 완료. 남은 건 **코드가 아니라 스토어/서명/키 등록 절차**다. 아래 3개 갈림길만
확정하면 제출 가능.

---

## 1. 가장 먼저 확정할 3가지 (배포 경로를 가름 — 코드로 알 수 없음)

### 1-1. 패키지명 일치 여부  ⚠️
- 이 앱 `applicationId` = **`com.nulloongzi.nulloongzido`**
  (`android/app/build.gradle.kts` ✅ 확인).
- **할 일:** Play Console → 기존 "누룽지도" 웹뷰 앱의 패키지명이 위와 **동일한지 확인.**
  - 동일 → 같은 리스팅 업데이트 가능(무중단, 다운로드/리뷰 유지).
  - 다름 → 같은 리스팅 업데이트 **불가.** 신규 앱으로 출시하거나, applicationId를 기존 값에
    맞춰야 함(단, Firebase/카카오/네이버 콘솔의 패키지명 등록도 함께 바꿔야 함).

### 1-2. 업로드 서명 키 확보  ⚠️ (가장 큰 리스크)
- 레포엔 **릴리즈 키스토어 없음**(`android/key.properties` 부재 ✅ — 비밀이므로 정상).
  커밋된 건 `debug-fixed.keystore`(디버그 전용, 스토어 제출 불가).
- **할 일:** 아래 중 어디에 해당하는지 확인 → 경로 결정:
  - **원본 업로드 키스토어 보유** → 그 키로 서명하면 같은 리스팅 업데이트 OK. (가장 깔끔)
  - **Play App Signing 등록됨**(구글이 앱 서명 키 관리) → 업로드 키를 새로 만들어
    Play Console에서 재설정 가능 → 같은 리스팅 업데이트 OK.
  - **둘 다 아님 / 분실** → 같은 리스팅 업데이트 **불가.** 패키지명 바꿔 신규 출시해야 함
    (다운로드/리뷰 리셋, 마케팅 전략도 '신규'로 전환 — `marketing-plan.md` 시나리오 B).

### 1-3. iOS 포함 여부  ⚠️
- 코드에 `ios/` 타깃 존재 ✅, 그러나 App Store 출시 이력 불명.
- **할 일:** 이번 배포에 iOS 포함할지 결정. 포함 시 선결: Apple 개발자 계정,
  Firebase iOS 앱 + `GoogleService-Info.plist`, 네이버맵/카카오 iOS 키 등록.
  → 표면적을 줄이려면 **이번엔 Android만, iOS는 후속 세션** 권장.

---

## 2. 기술 체크리스트 (핸드오프 대조 + 검증 결과)

| 항목 | 상태 | 근거 / 할 일 |
|---|---|---|
| 패키지명 확인 | ⚠️ | `com.nulloongzi.nulloongzido` (§1-1) |
| 업로드 서명 키 | ⚠️ | 미커밋(정상). 키 확보/등록 필요 (§1-2) |
| versionCode 증가 | ⚠️ | 현재 `pubspec.yaml` = `1.0.0+5` → **스토어 live 값보다 커야** 함. live가 5 이상이면 `+6` 등으로 올릴 것 |
| **릴리즈 빌드(AAB)** | ⛔→✅ | 기존 CI는 **디버그 APK만**(`build-apk.yml`) → **`release-aab.yml` 추가함**(서명된 AAB). Secrets 등록 후 실행 (§3) |
| 네이버맵 Client ID | ✅(값) / ⚠️(등록) | `lib/main.dart` `kNaverMapClientId = 't4mzao93mh'`. 네이버 콘솔에 **릴리즈 패키지명/키해시** 등록 확인 필요 |
| 카카오 네이티브 앱키 | ✅(값) / ⚠️(등록) | `lib/main.dart` `KakaoSdk.init(nativeAppKey:'24e0161…')`. 카카오 콘솔에 **릴리즈 키해시** 등록 확인 필요 |
| Firebase SHA-1 | ⚠️ | 디버그 키 SHA-1은 등록됨(고정 키스토어). **릴리즈 업로드 키 SHA-1도** Firebase에 추가해야 구글 로그인 정상 |
| 개인정보처리방침 | ✅(존재) / ⚠️(최신성) | 웹 레포 `privacy.md` 라이브. 네이티브 수집 항목(위치·기기·Analytics)과 일치하는지 검토 |
| 스토어 리스팅 갱신 | ⚠️ | 웹뷰→네이티브 전환 반영해 스크린샷/설명 업데이트 (`marketing-plan.md` §스토어 최적화) |
| 데이터 마이그레이션 | ✅ | 없음 — 기존 Firestore 컬렉션 재사용(`NATIVE_REWRITE_PLAN.md`) |
| 앱 기능 패리티 | ✅ | `docs/feature-parity.md` — 웹↔앱 패리티 확보, main green |

---

## 3. 실행 순서 (Android 리론치)

1. **§1의 3가지 확정** (패키지명 · 서명 키 · iOS 여부).
2. **versionCode 확인/증가** — Play Console의 현재 live versionCode 확인 → `pubspec.yaml`의
   `+N`을 그보다 크게. (커밋)
3. **콘솔 키 등록 점검** — 릴리즈 업로드 키의 SHA-1/키해시를 Firebase·카카오·네이버 콘솔에 등록.
   - 키해시 산출: `keytool -exportcert -alias <alias> -keystore <keystore> | openssl sha1 -binary | openssl base64` (카카오/네이버) · SHA-1은 `keytool -list -v` (Firebase).
4. **GitHub Secrets 등록** (`release-aab.yml`용):
   `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
5. **AAB 빌드** — Actions → **Release AAB** → Run workflow → 아티팩트 `nulloongzido-release-aab` 내려받기.
   (로컬 Flutter 있으면 `flutter build appbundle --release` 로 동일)
6. **내부 테스트 트랙 업로드** — Play Console → 내부 테스트에 AAB 올려 실기기 설치·로그인·지도·등록 스모크.
7. **스토어 리스팅 갱신** — 스크린샷/설명/무엇이 새로운지(네이티브 전환) 업데이트.
8. **단계적 출시** — 프로덕션에 20%부터 롤아웃 → 크래시/ANR 모니터 → 100%.

---

## 4. 알려진 편차 / 배포 전 검토 권장 (코드 확인됨)
- 앱 지도 = **네이버 지도**(문서는 카카오 허용). 배포엔 문제없음 — 네이버 콘솔 키 등록만 확인.
- `lib/screens/home_screen.dart` = 미사용 죽은 코드(`docs/HANDOFF.md`). 배포 차단 아님, 정리 선택.
- 급구 배너: 웹은 '인증팀만', 앱은 '모든 소유자' — 정책 차이(`feature-parity.md`). 의도 확인 권장.
- 만료 프리셋 이전 등록된 픽업은 `expire_at` 없어 자동 소멸 안 됨 — 운영상 수동 정리.

---

## 5. 사람만 할 수 있는 것 (요약)
- Play Console 접근(패키지명 확인 · versionCode 확인 · 업로드 · 리스팅 편집).
- 업로드 키스토어 확보/생성 및 GitHub Secrets 등록.
- Firebase/카카오/네이버 콘솔에 릴리즈 키 등록.
- iOS 포함 시 Apple 개발자 계정 및 iOS Firebase 설정.
