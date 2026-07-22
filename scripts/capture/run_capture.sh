#!/usr/bin/env bash
# scripts/capture/run_capture.sh — CI 에뮬레이터 안에서 마케팅 자산을 캡처한다.
# reactivecircus/android-emulator-runner 의 `script:` 로 호출된다(호스트 러너 셸,
# adb 는 부팅된 에뮬에 연결됨). 설계·함정: docs/handoff-ci-screenshot-capture.md
#
# 필수 env: APK_PATH
# 선택 env: ARTIFACTS_DIR(기본 marketing-assets) · SMOKE_ONLY(true) · CAP_LANG(ko)
#           INCLUDE_REELS(true) · TEST_ACCOUNT_EMAIL/PASSWORD(로그인 화면용, 옵션)
set -euo pipefail

APP_ID="com.nulloongzi.nulloongzido"
APK="${APK_PATH:?APK_PATH env 필요}"
ART="${ARTIFACTS_DIR:-marketing-assets}"
SMOKE_ONLY="${SMOKE_ONLY:-true}"
CAP_LANG="${CAP_LANG:-ko}"
INCLUDE_REELS="${INCLUDE_REELS:-true}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLOWS="$(cd "$HERE/../../.maestro" && pwd)"
SCREENS="$ART/screens"
REELS="$ART/reels"
LOGS="$ART/logs"
mkdir -p "$SCREENS" "$REELS" "$LOGS"

# record.sh(자식 프로세스)가 참조 — export 필요.
export APP_ID REELS CAP_LANG

log() { echo "▶ $*"; }

# ── 부팅 대기 ────────────────────────────────────────────────
log "에뮬 부팅 대기…"
adb wait-for-device
for _ in $(seq 1 120); do
  [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
  sleep 2
done
adb shell input keyevent 82 >/dev/null 2>&1 || true  # 잠금 해제(스와이프-없는 프로필이라도 안전)

# ── 앱 설치 ──────────────────────────────────────────────────
log "APK 설치: $APK"
adb install -r -g "$APK" || adb install -r "$APK"

# 시스템 에러/ANR 다이얼로그 억제 — 느린 SwiftShader 에뮬에서 "Pixel Launcher isn't
# responding" 팝업이 스샷을 오염시키고, 앱 위를 덮어 좌표 탭/캡처를 방해한다.
adb shell settings put global hide_error_dialogs 1 >/dev/null 2>&1 || true
adb shell settings put secure anr_show_background 0 >/dev/null 2>&1 || true
adb shell svc power stayon true >/dev/null 2>&1 || true
adb shell settings put system screen_off_timeout 1800000 >/dev/null 2>&1 || true

# ── 상태바 정리(프로 스샷): Android demo mode ────────────────
demo_on() {
  adb shell settings put global sysui_demo_allowed 1 || true
  local b="com.android.systemui.demo"
  adb shell am broadcast -a "$b" -e command clock -e hhmm 1200 >/dev/null 2>&1 || true
  adb shell am broadcast -a "$b" -e command battery -e level 100 -e plugged false >/dev/null 2>&1 || true
  adb shell am broadcast -a "$b" -e command network -e wifi show -e level 4 >/dev/null 2>&1 || true
  adb shell am broadcast -a "$b" -e command network -e mobile show -e datatype none -e level 4 >/dev/null 2>&1 || true
  adb shell am broadcast -a "$b" -e command notifications -e visible false >/dev/null 2>&1 || true
}
demo_off() {
  adb shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null 2>&1 || true
}
trap demo_off EXIT

# 프레임버퍼 캡처(네이티브 지도 포함). Flutter takeScreenshot 은 플랫폼뷰를 검게 잡음.
shot() { adb exec-out screencap -p > "$SCREENS/$1.png"; }

# 캡처 결과 지문: 아티팩트를 못 받는 환경(에이전트 프록시)에서도 로그로 검증하기 위해
#  · 각 스샷의 평균 밝기+해상도(블랙/블랭크 조기 감지)
#  · 지도 1장은 base64 썸네일(로그에서 육안 확인)
fingerprint() {
  echo "===== CAPTURE FINGERPRINT ====="
  for f in "$SCREENS"/*.png; do
    [ -e "$f" ] || continue
    local b m d
    b="$(basename "$f" .png)"
    m="$(convert "$f" -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null || echo NA)"
    d="$(identify -format '%wx%h' "$f" 2>/dev/null || echo '?')"
    echo "FP $b mean=$m dim=$d"
    # 각 스샷을 JPEG 썸네일(≈240px)로 로그에 남겨 좌표 보정/육안 검증(프록시가 아티팩트 차단해도).
    echo "THUMB_JPG_BEGIN $b"
    convert "$f" -resize 240x -quality 70 jpg:- 2>/dev/null | base64 -w0
    echo ""
    echo "THUMB_JPG_END $b"
  done
  echo "===== END FINGERPRINT ====="
}

# ── 스모크 게이트: 지도 렌더(함정4) ──────────────────────────
# 앱을 깨끗이 띄우고 지도 타일이 뜰 때까지 대기 → 스샷 → (near-)black 판정.
log "앱 실행 + 지도 렌더 대기…"
adb shell am force-stop "$APP_ID" || true
adb shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 28  # Firebase init + 첫 로드 + 네이버맵 타일 페치 여유
demo_on
sleep 2
shot "play_01_map_${CAP_LANG}"

MEAN="$(convert "$SCREENS/play_01_map_${CAP_LANG}.png" -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null || echo NA)"
log "지도 스샷 평균 밝기 = $MEAN (0=검정, 1=흰색)"
if [ "$MEAN" != "NA" ] && awk -v m="$MEAN" 'BEGIN{exit !(m < 0.03)}'; then
  echo "::error::지도 화면이 (거의) 검정입니다 — 함정4: x86_64 SwiftShader 네이버맵 타일 미렌더 의심."
  echo "::error::완화: -gpu 옵션/이미지 조합 변경, 대기 증가. 그래도 안 되면 실기기(사용자 폰) 폴백."
  adb logcat -d > "$LOGS/logcat_smoke.txt" 2>/dev/null || true
  exit 1
fi
log "✅ 지도 렌더 확인(비-검정)."

if [ "$SMOKE_ONLY" = "true" ]; then
  fingerprint
  log "smoke_only=true → 지도 스모크만 하고 종료. 아티팩트에서 play_01_map 을 눈으로 확인하세요."
  exit 0
fi

# ── 전체 캡처: 순수 adb 좌표 내비게이션 ──────────────────────
# Maestro는 이 앱(네이티브 NaverMap + Flutter 오버레이)의 접근성 트리를 못 읽어
# 텍스트 매칭이 전부 실패했다(로그: Assertion "동호회" is visible = false). 그래서
# 좌표 탭(input tap/swipe) + screencap 으로 직접 시퀀싱한다(핸드오프 대안 경로).
# ⚠️ 좌표는 1080×2400(pixel_6) 추정값 — 로그의 JPEG 썸네일로 라운드마다 보정한다.
tap() { adb shell input tap "$1" "$2" >/dev/null 2>&1; }
swp() { adb shell input swipe "$1" "$2" "$3" "$4" "${5:-500}" >/dev/null 2>&1; }
back() { adb shell input keyevent 4 >/dev/null 2>&1; }
relaunch() { # relaunch [wait]
  adb shell am force-stop "$APP_ID" >/dev/null 2>&1 || true
  adb shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  sleep "${1:-30}"
}
cap() { demo_on; sleep 1; shot "$1"; log "  캡처: $1"; }

# 좌표 프리셋(1080×2400 추정, ⚠️보정 대상)
X_TAB_CLUBS=415;  Y_TAB=345         # 🏐 동호회 탭
X_TAB_PICKUP=565
X_LANG=915;       Y_TOPBAR=215      # 검색바 우측 'EN/한' 토글
X_FILTER=1000                        # 검색바 우측 필터(tune) 아이콘
X_MARKER=540;     Y_MARKER=1150      # 지도 중앙 마커(상세 트리거) 추정

# EN 세트면 최초 1회 언어 토글
[ "$CAP_LANG" = "en" ] && { tap $X_LANG $Y_TOPBAR; sleep 2; }

# 1) 지도 (gate에서 이미 로드 → 재기동 짧게)
relaunch 8
[ "$CAP_LANG" = "en" ] && { tap $X_LANG $Y_TOPBAR; sleep 2; }
cap "play_01_map_${CAP_LANG}"

# 2) 픽업 목록
tap $X_TAB_PICKUP $Y_TAB; sleep 5; cap "play_03_pickup_${CAP_LANG}"

# 3) 동호회 복귀 → 필터 시트
tap $X_TAB_CLUBS $Y_TAB; sleep 2
tap $X_FILTER $Y_TOPBAR; sleep 3; cap "play_02_filter_${CAP_LANG}"
back; sleep 2

# 4) 클럽 상세(마커 탭)
tap $X_MARKER $Y_MARKER; sleep 4; cap "play_04_detail_${CAP_LANG}"
back; sleep 2

# (공유/도시락/프로필 화면은 좌표 확정 후 라운드2에서 추가)
log "TEST_ACCOUNT_* 로그인 세트 및 공유 화면은 좌표 보정(라운드2) 후 추가 예정."

# ── 릴스: adb screenrecord + 좌표 제스처 ─────────────────────
# 1080×2400 원본 녹화 → 릴스(1080×1920)는 편집서 크롭.
if [ "$INCLUDE_REELS" = "true" ]; then
  reel() { # reel <name> <gesture-fn> <secs>
    local name="$1" fn="$2" secs="${3:-18}" dev="/sdcard/${1}.mp4"
    log "🎬 릴스 녹화: $name"
    relaunch 12; demo_on
    adb shell screenrecord --bit-rate 8000000 --time-limit "$secs" "$dev" &
    local rec=$!; sleep 1
    "$fn"
    adb shell pkill -INT screenrecord >/dev/null 2>&1 || true
    sleep 2; wait "$rec" 2>/dev/null || true
    adb pull "$dev" "$REELS/${name}.mp4" >/dev/null 2>&1 && log "  ↳ $REELS/${name}.mp4" || echo "::warning::mp4 회수 실패: $name"
    adb shell rm -f "$dev" >/dev/null 2>&1 || true
  }
  g_findmap() { sleep 2; swp 800 1300 300 1100 1100; sleep 2; tap $X_MARKER $Y_MARKER; sleep 3; }
  g_pickup()  { sleep 2; tap $X_TAB_PICKUP $Y_TAB; sleep 4; swp 540 1600 540 900 700; sleep 3; }
  g_finale()  { sleep 2; swp 800 1400 300 1200 1300; sleep 1; swp 300 1200 800 1400 1300; sleep 1; swp 540 1600 540 1000 1300; sleep 2; }
  reel "reel_1_findmap" g_findmap 16
  reel "reel_3_pickup"  g_pickup  16
  reel "reel_7_finale"  g_finale  16
fi

adb logcat -d > "$LOGS/logcat.txt" 2>/dev/null || true
fingerprint
log "완료. screens=$(ls -1 "$SCREENS" 2>/dev/null | wc -l)장, reels=$(ls -1 "$REELS" 2>/dev/null | wc -l)편."
