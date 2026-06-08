# 누룽지도 앱 (Flutter) — 인계 노트 (UI/UX 계속)

> 새 세션이 이어받기 위한 단일 출발점. 먼저 이 파일을 읽고, 아래 "소스 오브 트루스" 문서를 본 뒤 작업한다.

## 브랜치 / 소스 오브 트루스
- **앱 개발 브랜치**: `claude/gifted-hamilton-UaSAK` — 여기에 계속 커밋·푸시. **main 직접 push 금지.**
- **디자인·기능 기준 문서**(웹 레포 `nulloongzi/null_oongzi-do`, 브랜치 `claude/html-flutter-design-docs-Flr2x`):
  - `docs/design.md` — 시각 마스터(토큰·전 화면 명세)
  - `docs/PHILOSOPHY.md` — 제품 철학(노스스타)
  - `docs/flutter/00-overview.md` — 아키텍처·Firestore 스키마·localStorage·애널리틱스·새니타이즈
  - `docs/flutter/10-instagram-flywheel.md` — **먼저 읽기**(차별점)
  - `docs/flutter/01~09` — 기능별 동작 명세
- 앱 HEAD 기준: 전 작업 **CI 전부 green**, 최신 APK는 GitHub Actions `build-apk.yml` 아티팩트(`nulloongzido-debug-apk`).

## 절대 불변 (바꾸지 말 것)
1. **환대 > 위상 — 랭킹/별점/순위 UI 금지.** 모든 클럽·스팟 동등하게 보이게.
2. 디자인 토큰 박제: 옐로 `#fac710` · 다크 `#4e342e` · 브라운 `#8d6e63` · 크림 배경 `#fff8e1` · 픽업 틸 `#13a89e` · 급구 `#ff7043`. **그림자는 갈색 `rgba(93,64,55,.15)`(검정 아님).**
3. 플라이휠 3축: 딥링크 `?club=`/`?spot=` · 스토리카드+링크스티커 · `insta_reel` 임베드. 하나라도 끊으면 차별점 소멸.
4. 외국인 축: **저장은 KO, 표시만 EN.** 영어모드에서 6s 강조 + English-OK 1급.
5. Firestore 컬렉션/필드명은 웹과 **100% 동일**(같은 백엔드 공유). localStorage 키 = SharedPreferences 동일.

## 재사용할 공용 빌딩블록 (이미 구현됨 — 새로 만들지 말 것)
- `lib/theme.dart` → `NurungjiColors`(yellow/dark/brown/bg/light/chipBg/chipFg/teal/**urgent**) + `AppTheme`(Noto Sans KR).
- `lib/widgets/bounce_tap.dart` → **`BounceTap`** — 모든 탭 요소 누르면 spring 축소(easeOutBack 120ms, Listener 기반이라 자식 탭 비간섭).
- `lib/widgets/glass_surface.dart` → **`GlassSurface`**(블러+반투명+흰테두리+갈색그림자) / `GlassSurface.cream`.
- `lib/services/i18n.dart` → `t(key)`, `tf`, `appLang`, 표시 변환 `i18nTarget/i18nPrice/i18nDay/i18nRegion/i18nSchedule`. **새 문자열은 반드시 `lib/l10n/strings.dart`에 `{ko,en}` 키 추가 후 `t()`로** (하드코딩 KO 금지).
- `lib/services/analytics.dart` → `Track.event(name, params)`(미초기화/실패 시 no-op).
- `lib/services/data_repository.dart` → clubs/pickup CRUD, `currentUid`, `ensureUid()`(픽업 익명), `isAdmin()`(`/admins/{uid}`), `loadPickups()`(만료 필터 포함).

## 화면 구조 (lib/screens, lib/widgets)
- `map_screen.dart` — 메인. 지도 위 **글래스 검색바**(🔎+입력+EN토글+필터/English) + **탭 pill**(동호회|픽업) + 급구 티커/픽업 토글 + **코너 FAB**(🍱도시락·🍚프로필 좌 / 📝등록·📍내위치 우). `_isAdmin` 상태 보유.
- `detail_sheet.dart` — `showClubDetail`/`showSpotDetail`(둘 다 `isAdmin` 파라미터; 수정/삭제 = 소유자 OR 관리자). 시간표·태그·가격·일정 모두 i18n 변환 적용.
- `club_form_screen.dart` / `pickup_form_screen.dart` — 등록/수정(한·영). 픽업폼엔 **유효기간 칩**(이번주말/1개월기본/3개월/상시 → `expire_at`).
- `lunchbox_screen.dart`(도시락 5칸+식단표), `profile_screen.dart`, `login_screen.dart`, `share_image_screen.dart`.
- 위젯: `schedule_timetable.dart`, `diet_grid.dart`, `filter_sheet.dart`(영어모드 6s 우선+힌트), `pickup_list_panel.dart`, `chip_select.dart`, `schedule_editor.dart`, `map_picker.dart`, `story_card.dart`(1080×1920 CustomPainter + QR + 지하철역), `insta_embed.dart`, `share_menu.dart`.

## 지금까지 완료 (전부 green)
i18n 데이터 변환 · 영어모드 6s 강조/힌트 · BounceTap · GlassSurface · 애널리틱스 12이벤트 · 등록폼 한/영 · 잔여 KO 문자열 영어화 · 스토리카드(지하철역 enrich) · **글래스 FAB 레이아웃** · 픽업 **자동만료(B)** + 픽업/클럽 **소유자 OR 관리자** 수정·삭제.

## Deviation / 남은 것 (인지)
- 앱은 **네이버 지도**(문서는 카카오 허용 — 줌/클러스터는 SDK 변환 사항).
- `lib/screens/home_screen.dart` = **미사용 죽은 코드**(정리 가능).
- 픽업 `📝 등록`은 두 탭 모두 노출(앱은 지도/목록 토글 구조).
- 만료 변경 *전* 등록된 픽업은 `expire_at` 없어 "상시"로 취급(자동 안 사라짐) — 삭제로 직접 정리.
- 규칙/TTL은 웹이 배포(백엔드 공유) — 앱은 클라이언트 패리티만.

## 작업 방식
- 로컬 flutter 없음 → 검증은 **GitHub Actions `build-apk.yml`**. **단계별 커밋 → 푸시 → CI 그린 확인** 패턴.
- Conventional Commits. JS가 아니라 Dart지만 디자인 토큰/문자열 규칙은 위 불변 준수.
- 열린 **PR #1**(→ main) 존재. PR 생성/머지는 사용자 명시 요청 시에만.
