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
    m="$(convert "$f" -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null || echo NA)"
    d="$(identify -format '%wx%h' "$f" 2>/dev/null || echo '?')"
    echo "FP $(basename "$f") mean=$m dim=$d"
  done
  local mapf="$SCREENS/play_01_map_${CAP_LANG}.png"
  if [ -e "$mapf" ]; then
    echo "THUMB_B64_BEGIN play_01_map_${CAP_LANG} png ~100px"
    convert "$mapf" -resize 100x -strip png:- 2>/dev/null | base64 -w0
    echo ""
    echo "THUMB_B64_END"
  fi
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

# ── Maestro 설치(전체 캡처용) ────────────────────────────────
log "Maestro 설치…"
export MAESTRO_VERSION="1.39.0"
curl -fsSL "https://get.maestro.mobile.dev" | bash
export PATH="$PATH:$HOME/.maestro/bin"
maestro --version || { echo "::error::Maestro 설치 실패"; exit 1; }

# Maestro 플로우 공통 env (flows 에서 ${OUT}, ${APPLANG} 로 참조)
MENV=(--env "OUT=$PWD/$SCREENS" --env "APPLANG=$CAP_LANG" --env "APP_ID=$APP_ID")

run_flow() {  # run_flow <flow-file>
  log "flow: $1"
  maestro test "${MENV[@]}" "$FLOWS/$1" 2>&1 | tee -a "$LOGS/maestro.log" || {
    echo "::warning::flow 실패(계속): $1"
  }
}

# ── 스크린샷 세트(게스트 열람 가능 화면) ─────────────────────
demo_on
for f in \
  flows/screens/00_map.yaml \
  flows/screens/01_filter.yaml \
  flows/screens/02_pickup.yaml \
  flows/screens/03_club_detail.yaml \
  flows/screens/04_share.yaml
do run_flow "$f"; done

# ── 로그인 필요 화면(옵션): 도시락/프로필/닉네임 ─────────────
if [ -n "${TEST_ACCOUNT_EMAIL:-}" ] && [ -n "${TEST_ACCOUNT_PASSWORD:-}" ]; then
  log "테스트 계정 감지 → 로그인 필요 화면 캡처."
  MENV+=(--env "EMAIL=$TEST_ACCOUNT_EMAIL" --env "PASSWORD=$TEST_ACCOUNT_PASSWORD")
  for f in flows/login/05_lunchbox.yaml flows/login/06_profile.yaml; do run_flow "$f"; done
else
  log "TEST_ACCOUNT_* 시크릿 없음 → 로그인 필요 화면(도시락/프로필/닉네임) 스킵."
fi

# ── 릴스 화면녹화(mp4) ───────────────────────────────────────
# 참고: pixel_6 는 1080×2400 → 녹화 원본도 그 해상도. 릴스(1080×1920)는 편집에서 크롭.
if [ "$INCLUDE_REELS" = "true" ]; then
  demo_on
  # record.sh <name> <maestro-flow> : screenrecord 로 감싸 플로우를 녹화.
  "$HERE/record.sh" "reel_1_findmap" "$FLOWS/flows/reels/reel_1_findmap.yaml"
  "$HERE/record.sh" "reel_2_filter"  "$FLOWS/flows/reels/reel_2_filter.yaml"
  "$HERE/record.sh" "reel_3_pickup"  "$FLOWS/flows/reels/reel_3_pickup.yaml"
  "$HERE/record.sh" "reel_7_finale"  "$FLOWS/flows/reels/reel_7_finale.yaml"
fi

adb logcat -d > "$LOGS/logcat.txt" 2>/dev/null || true
fingerprint
log "완료. screens=$(ls -1 "$SCREENS" | wc -l)장, reels=$(ls -1 "$REELS" 2>/dev/null | wc -l)편."
