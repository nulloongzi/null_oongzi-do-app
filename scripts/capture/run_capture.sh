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
# 카피 합성본 디렉터리는 전체 캡처 경로(아래)에서만 만들어진다. 스모크 경로는 그 전에
# fingerprint()를 호출하므로, 미정의 상태로 참조되면 set -u 에 걸려 죽는다 → 빈 값으로 선언.
STORE="${STORE:-}"
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
  for f in "$SCREENS"/*.png ${STORE:+"$STORE"/*.png}; do
    [ -e "$f" ] || continue
    local b m d
    b="$(basename "$f" .png)"
    # store/ 합성본은 이름 충돌 방지로 접두어
    case "$f" in "$STORE"/*) b="store_$b";; esac
    m="$(convert "$f" -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null || echo NA)"
    d="$(identify -format '%wx%h' "$f" 2>/dev/null || echo '?')"
    echo "FP $b mean=$m dim=$d"
    # 각 스샷을 JPEG 썸네일로 로그에 남겨 육안 검증(아티팩트 호스트는 조직 egress
    # 정책에 막혀 다운로드가 안 된다 — 로그가 유일한 확인 경로다).
    # 240px는 "화면이 맞나"까지만 판별됐다. 카드 디자인·글자 가독성처럼 품질을 보려면
    # 부족해서 기본값을 올렸다. 필요하면 FP_THUMB_W 로 조절.
    echo "THUMB_JPG_BEGIN $b"
    convert "$f" -resize "${FP_THUMB_W:-560}x" -quality 72 jpg:- 2>/dev/null | base64 -w0
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

# ── 전체 캡처: 앱 캡처 디렉터(딥링크) 기반 결정적 내비게이션 ──────
# (run #7 debug 검증 완료: 8화면 KO 결정적 캡처 + 릴스 3편. 좌표/마커 브리틀 제거.)
# Maestro(접근성 트리 못 읽음)·좌표 탭(마커 위치 런마다 변동)의 브리틀함을 버리고,
# 앱에 심은 캡처 디렉터를 딥링크로 구동한다: ?capture=<화면>&lang=ko 를 열면
# 앱이 KO 강제 + 데이터 로드 후 해당 화면을 **결정적으로** 연다(CAPTURE_MODE 빌드).
CAP_URL="https://nulloongzi.github.io"
swp() { adb shell input swipe "$1" "$2" "$3" "$4" "${5:-500}" >/dev/null 2>&1; }

# ANR("Pixel Launcher isn't responding") 능동 정리 — hide_error_dialogs가 런처 ANR엔
# 안 먹혀서(검증됨), 포커스가 우리 앱이 아니면 중앙 다이얼로그 'Wait'(300,1360) 탭.
#
# 탭은 **ANR 다이얼로그가 실제로 떠 있을 때만** 한다. 예전 판은 "포커스 줄에 앱 이름이
# 안 보이면 탭"이었는데, 멀티 디스플레이 에뮬에서 `grep -m1` 이 먼저 걸리는 가상
# 디스플레이의 `mCurrentFocus=null` 을 집어 매 캡처마다 화면 한복판을 눌렀다.
# 그 탭이 마커·리스트·버튼을 눌러 지도→상세, 프로필→로그아웃 확인창 식으로
# 스크린샷을 통째로 망가뜨렸다(run #12에서 8장 중 5장). 증거 없으면 손대지 않는다.
dismiss_anr() {
  local i anr
  for i in 1 2 3 4; do
    anr="$(adb shell dumpsys window 2>/dev/null \
      | grep -iE "Application Not Responding|Application Error|isn'?t responding" || true)"
    [ -z "$anr" ] && return 0
    adb shell input tap 300 1360 >/dev/null 2>&1
    adb shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS >/dev/null 2>&1 || true
    sleep 2
  done
}
# 캡처 딥링크로 콜드 실행(앱이 KO 강제 + 화면 이동).
open_cap() { # open_cap <cmd> [wait]
  # -S: 시작 전 강제 종료(콜드 스타트 보장 → 잔존 UI 누적 방지).
  # URL은 디바이스 셸에서 single-quote — '&'가 백그라운드 연산자로 해석되지 않게.
  adb shell "am start -S -n '$APP_ID/.MainActivity' -a android.intent.action.VIEW -d '$CAP_URL/?capture=$1&lang=$CAP_LANG'" >/dev/null 2>&1
  sleep "${2:-30}"; dismiss_anr
}
cap() { dismiss_anr; demo_on; sleep 1; shot "$1"; log "  캡처: $1"; }

# ── 스크린샷 세트(딥링크 결정적) ─────────────────────────────
open_cap map 30;      cap "play_01_map_${CAP_LANG}"
open_cap filter 30;   cap "play_02_filter_${CAP_LANG}"
open_cap pickup 30;   cap "play_03_pickup_${CAP_LANG}"
open_cap detail 33;   cap "play_04_detail_${CAP_LANG}"
open_cap lunchbox 34; cap "play_05_lunchbox_${CAP_LANG}"
open_cap profile 32;  cap "play_06_profile_${CAP_LANG}"
open_cap share 34;    cap "play_07_share_${CAP_LANG}"
open_cap story 36;    cap "play_08_story_${CAP_LANG}"
open_cap login 32;    cap "play_09_login_${CAP_LANG}"

# ── 카피 오버레이 합성(업로드용 최종 이미지) ──────────────────
# Play 마케팅 프레임: 크림 1080×1920 캔버스 + 상단 2줄 카피(나눔고딕Bold) +
# 옐로 언더라인 + 앱 스샷(다크 테두리). 한글 폰트는 워크플로에서 설치(fonts-nanum).
STORE="$ART/store"; mkdir -p "$STORE"
KFONT="$(fc-list 2>/dev/null | grep -i nanum | grep -i bold | head -1 | cut -d: -f1 | xargs)"
[ -z "$KFONT" ] && KFONT="/usr/share/fonts/truetype/nanum/NanumGothicBold.ttf"
compose_store() { # compose_store <basename> <line1> <line2>
  local src="$SCREENS/$1.png" out="$STORE/$1.png" tmp="$STORE/.t_$1.png"
  [ -e "$src" ] || { echo "::warning::합성 스킵(원본 없음): $1"; return; }
  convert "$src" -resize x1440 -bordercolor '#3A2C26' -border 3 "$tmp" 2>/dev/null || return
  convert -size 1080x1920 xc:'#FFF8E1' \
    -fill '#FAC710' -draw 'roundrectangle 470,300 610,309 4,4' \
    -font "$KFONT" -gravity north \
    -fill '#8D6E63' -pointsize 44 -annotate +0+150 "$2" \
    -fill '#4E342E' -pointsize 66 -annotate +0+215 "$3" \
    "$tmp" -gravity south -geometry +0+80 -composite \
    "$out" 2>/dev/null && log "  합성: store/$1.png" || echo "::warning::합성 실패: $1"
  rm -f "$tmp"
}
if [ -e "$KFONT" ]; then
  compose_store "play_01_map_${CAP_LANG}"      "전국 배구 동호회," "지도 한 눈에"
  compose_store "play_02_filter_${CAP_LANG}"   "지역·요일·대상으로" "딱 맞는 팀"
  compose_store "play_04_detail_${CAP_LANG}"   "일정·회비·위치 확인하고" "바로 연락"
  compose_store "play_03_pickup_${CAP_LANG}"   "오늘 당장 뛸" "픽업 게임"
  compose_store "play_05_lunchbox_${CAP_LANG}" "마음에 든 팀은" "‘도시락’에 찜"
  compose_store "play_06_profile_${CAP_LANG}"  "나만의" "‘밥이름’ 닉네임"
  compose_store "play_07_share_${CAP_LANG}"    "카톡·인스타로" "우리 팀 자랑"
  compose_store "play_08_story_${CAP_LANG}"    "내 카드 한 장으로" "스토리에 자랑"
  compose_store "play_09_login_${CAP_LANG}"    "카카오·네이버로" "몇 초면 시작"
else
  echo "::warning::한글 폰트(nanum) 미탐지 — 카피 합성 스킵($KFONT)"
fi

# ── 릴스 원본(raw): 기능별 모션 클립을 언어별로 녹화 ──────────
# 후반합성기(compose_videos.sh)가 이 raw 를 크림 9:16 브랜디드 릴스로 만든다.
# 산출: reels/raw/<feat>_<lang>.mp4 (앱 1080×2400 화면녹화, 무음).
# 각 클립: 대상 언어로 지도에 콜드 안착 → 녹화 시작 → 기능 딥링크로 모션(시트/카메라) 유발.
if [ "$INCLUDE_REELS" = "true" ]; then
  RAW="$REELS/raw"; mkdir -p "$RAW"
  vdur() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null | cut -d. -f1; }

  # 흐름 검증 몬타주: 아티팩트 다운로드가 프록시에 막히므로, 각 흐름 영상의
  # 프레임을 전체 구간에 균등 추출해 base64 로 로그에 남긴다(육안 확인 경로).
  # 흐름은 길어 6장으론 전환을 놓친다 → 12장(4×3).
  flow_montage() { # flow_montage <mp4> <label>
    local mp4="$1" label="$2" dur fps td
    [ -s "$mp4" ] || { echo "MONTAGE_MISSING $label"; return; }
    dur="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$mp4" 2>/dev/null)"
    echo "VID $label dur=${dur%%.*}s dim=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$mp4" 2>/dev/null)"
    fps="$(awk -v d="${dur:-30}" 'BEGIN{ if(d<=0) d=30; printf "%.4f", 12.0/d }')"
    td="$(mktemp -d)"
    ffmpeg -y -loglevel error -i "$mp4" -vf "fps=${fps},scale=270:-1" -frames:v 12 "$td/f_%02d.png" 2>/dev/null
    if ls "$td"/f_*.png >/dev/null 2>&1; then
      montage "$td"/f_*.png -tile 4x3 -geometry +3+3 -background '#FFF8E1' "$td/m.png" 2>/dev/null
      echo "MONTAGE_BEGIN $label"
      convert "$td/m.png" -resize 1100x -quality 72 jpg:- 2>/dev/null | base64 -w0
      echo ""
      echo "MONTAGE_END $label"
    fi
    rm -rf "$td"
  }
  # ── 흐름(flow) 녹화: 여러 기능을 한 테이크로 ─────────────────
  # 앱 안의 캡처 디렉터(flow_*)가 연속 전환을 수행하므로, 여기선 딥링크 한 번 쏘고
  # 흐름이 끝날 때까지 통으로 녹화한다(중간 개입 없음 = 손떨림 없는 데모).
  # 산출은 9:16(1080×1920) 크롭본 — 자막·TTS는 편집에서 얹는다.
  FLOWS_DIR="$REELS/flows"; mkdir -p "$FLOWS_DIR"
  # 흐름은 길어(35~45s) 인코더 부하가 크다. 화질(크롭 후 1080폭)을 살리되 조기 종료를
  # 피하도록 원본 1080×2400 @5Mbps 로 녹화한다.
  FLOW_REC=(--size 1080x2400 --bit-rate 5000000)
  # 9:16 크롭: 위 390px(상태바·검색바)을 덜어내고 아래 상세시트 버튼까지 살린다.
  # (1080×2400 → y=390..2310) 편집에서 다시 자르지 않아도 릴스 규격.
  FLOW_CROP="crop=1080:1920:0:390"

  flow() { # flow <name> <capture_cmd> <secs>
    local name="$1" cmd="$2" secs="$3"
    local dev="/sdcard/flow_${name}.mp4"
    local rawout="$RAW/flow_${name}_${CAP_LANG}.mp4"
    local out="$FLOWS_DIR/${name}_${CAP_LANG}.mp4" d
    log "🎬 흐름 녹화: ${name} (${secs}s)"
    adb shell rm -f "$dev" >/dev/null 2>&1 || true
    # 지도에 콜드 안착시킨 뒤 녹화를 시작하고, 그 다음에 흐름 딥링크를 쏜다.
    # (흐름 시작 자체가 콘텐츠라 전환을 놓치면 안 된다 → 녹화가 먼저.)
    adb shell "am start -S -n '$APP_ID/.MainActivity' -a android.intent.action.VIEW -d '$CAP_URL/?capture=map&lang=$CAP_LANG'" >/dev/null 2>&1
    sleep 24; dismiss_anr; demo_on
    adb shell screenrecord "${FLOW_REC[@]}" --time-limit "$secs" "$dev" &
    local rec=$!; sleep 1
    # 콜드 재시작 없이(-S 없음) 흐름 시작 → 앱이 내부에서 연속 전환.
    adb shell "am start -n '$APP_ID/.MainActivity' -a android.intent.action.VIEW -d '$CAP_URL/?capture=$cmd&lang=$CAP_LANG'" >/dev/null 2>&1
    sleep "$secs"
    adb shell pkill -INT screenrecord >/dev/null 2>&1 || true
    sleep 3; wait "$rec" 2>/dev/null || true
    adb pull "$dev" "$rawout" >/dev/null 2>&1 || true
    adb shell rm -f "$dev" >/dev/null 2>&1 || true
    d="$(vdur "$rawout")"; d="${d:-0}"
    if [ "$d" -lt $(( secs / 2 )) ]; then
      echo "::warning::흐름 녹화 짧음(${d}s < ${secs}s) — 재시도: $name"
      adb shell "am start -S -n '$APP_ID/.MainActivity' -a android.intent.action.VIEW -d '$CAP_URL/?capture=map&lang=$CAP_LANG'" >/dev/null 2>&1
      sleep 24; dismiss_anr; demo_on
      adb shell screenrecord "${FLOW_REC[@]}" --time-limit "$secs" "$dev" &
      rec=$!; sleep 1
      adb shell "am start -n '$APP_ID/.MainActivity' -a android.intent.action.VIEW -d '$CAP_URL/?capture=$cmd&lang=$CAP_LANG'" >/dev/null 2>&1
      sleep "$secs"; adb shell pkill -INT screenrecord >/dev/null 2>&1 || true
      sleep 3; wait "$rec" 2>/dev/null || true
      adb pull "$dev" "$rawout" >/dev/null 2>&1 || true
      adb shell rm -f "$dev" >/dev/null 2>&1 || true
      d="$(vdur "$rawout")"; d="${d:-0}"
    fi
    if [ "$d" -le 0 ]; then echo "::warning::흐름 mp4 회수 실패: $name"; return; fi
    # 9:16 크롭(재인코딩 1회) — 릴스 규격 완성본.
    ffmpeg -y -loglevel error -i "$rawout" -vf "$FLOW_CROP" \
      -c:v libx264 -preset veryfast -pix_fmt yuv420p -r 30 -an "$out" 2>&1 | tail -2
    log "  ↳ flows/${name}_${CAP_LANG}.mp4 (${d}s, 1080x1920)"
  }

  # 흐름 3종(픽업 제외) — 각 흐름은 앱 내부 스크립트가 구동한다.
  flow discover flow_discover 38   # 지도 → 필터 → 결과 → 클럽 상세
  flow save     flow_save     32   # 상세 → 도시락 찜 → 반찬칸 → 식단표
  flow share    flow_share    36   # 밥이름 → 네임카드 → 공유

  # 풀 투어: 3편 이어붙이기(편집 없이 바로 쓰는 앱 소개용).
  TOUR_LIST="$FLOWS_DIR/.tour.txt"; : > "$TOUR_LIST"
  for n in discover save share; do
    f="$FLOWS_DIR/${n}_${CAP_LANG}.mp4"
    [ -s "$f" ] && echo "file '$(basename "$f")'" >> "$TOUR_LIST"
  done
  if [ -s "$TOUR_LIST" ]; then
    ( cd "$FLOWS_DIR" && ffmpeg -y -loglevel error -f concat -safe 0 -i .tour.txt \
        -c copy "full_tour_${CAP_LANG}.mp4" 2>&1 | tail -2 )
    log "  ↳ flows/full_tour_${CAP_LANG}.mp4"
  fi
  rm -f "$TOUR_LIST"

  echo "===== FLOW FINGERPRINT ====="
  for n in discover save share full_tour; do
    flow_montage "$FLOWS_DIR/${n}_${CAP_LANG}.mp4" "flow_${n}"
  done
  echo "===== END FLOW FINGERPRINT ====="
fi

adb logcat -d > "$LOGS/logcat.txt" 2>/dev/null || true
fingerprint
log "완료. screens=$(ls -1 "$SCREENS" 2>/dev/null | wc -l)장, raw=$(ls -1 "$REELS/raw" 2>/dev/null | wc -l)편(후반합성은 compose_videos.sh)."
