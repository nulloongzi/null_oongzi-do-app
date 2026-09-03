#!/usr/bin/env bash
# scripts/capture/run_capture.sh — CI 에뮬레이터 안에서 마케팅 자산을 캡처한다.
# reactivecircus/android-emulator-runner 의 `script:` 로 호출된다(호스트 러너 셸,
# adb 는 부팅된 에뮬에 연결됨). 설계·함정: docs/handoff-ci-screenshot-capture.md
#
# 필수 env: APK_PATH
# 선택 env: ARTIFACTS_DIR(기본 marketing-assets) · SMOKE_ONLY(true) · CAP_LANG(ko)
#           INCLUDE_REELS(true) · TEST_ACCOUNT_EMAIL/PASSWORD(로그인 화면용, 옵션)
set -euo pipefail

# ── ImageMagick 호출 정규화 (Windows/Git Bash 안전) ──────────────
# IM7 의 실행파일은 `magick` 이다. Windows 에서 `convert` 는 **OS 기본 디스크 변환
# 유틸(C:\Windows\System32\convert.exe)** 과 이름이 겹쳐, Git Bash 에서 그쪽이
# 먼저 잡히면 이미지가 아니라 볼륨 변환을 시도한다(치명적).
# magick 이 있으면 전부 magick 경유로 강제한다. Linux IM6 에서는 원래 바이너리 사용.
# ── Git Bash(MSYS2) 경로 변환 차단 ──────────────────────────
# MSYS2 런타임은 네이티브 .exe 에 넘기는 "/로 시작하는 인자"를 윈도우 경로로 자동
# 변환한다. adb 에는 치명적이다 — **기기 안의 경로**인 /sdcard/x.png 가
# C:\Program Files\Git\sdcard\x.png 로 바뀌어 screencap·pull·screenrecord 가
# 통째로 실패한다(로컬 폴더에 파일이 안 생겨서 원인이 잘 안 보인다).
# 기기 경로 접두어만 변환에서 제외한다 — 로컬 경로 변환은 그대로 필요하다
# (adb pull 의 목적지는 윈도우 경로여야 한다). 리눅스/macOS 에서는 무시된다.
export MSYS2_ARG_CONV_EXCL='/sdcard;/data/local/tmp'

IM_OK=0
if command -v magick >/dev/null 2>&1; then
  convert()  { magick "$@"; }
  identify() { magick identify "$@"; }
  montage()  { magick montage "$@"; }
  compare()  { magick compare "$@"; }
  IM_OK=1
elif command -v convert >/dev/null 2>&1 && convert -version 2>/dev/null | grep -qi imagemagick; then
  IM_OK=1   # IM6(리눅스). `convert` 가 System32 디스크 유틸이면 여기 안 걸린다.
fi


APP_ID="com.nulloongzi.nulloongzido"
APK="${APK_PATH:?APK_PATH env 필요}"
ART="${ARTIFACTS_DIR:-marketing-assets}"
SMOKE_ONLY="${SMOKE_ONLY:-true}"
CAP_LANG="${CAP_LANG:-ko}"
INCLUDE_REELS="${INCLUDE_REELS:-true}"
# 실행할 단계. 콤마 구분: play(스토어 스샷) · stills(모션용 스틸) · flows(흐름 녹화).
# 예) PHASES=stills,flows  → 스토어 스샷 9장(약 5분)을 건너뛴다.
PHASES="${PHASES:-play,stills,flows}"
# 아티팩트를 다운로드할 수 없는 CI 에서는 base64 썸네일이 유일한 검증 경로지만,
# 로컬에서는 파일을 바로 열어보면 되고 콘솔만 뒤덮는다 → 끌 수 있게 한다.
FINGERPRINT="${FINGERPRINT:-true}"
want() { case ",$PHASES," in *,"$1",*) return 0;; esac; return 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLOWS="$(cd "$HERE/../../.maestro" && pwd)"
SCREENS="$ART/screens"
# 카피 합성본 디렉터리는 전체 캡처 경로(아래)에서만 만들어진다. 스모크 경로는 그 전에
# fingerprint()를 호출하므로, 미정의 상태로 참조되면 set -u 에 걸려 죽는다 → 빈 값으로 선언.
STORE="${STORE:-}"
# stills/ 도 같은 이유로 미리 빈 값 선언(스모크 경로가 fingerprint 를 먼저 부른다).
STILLS="${STILLS:-}"
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
#
# `adb exec-out` 은 바이너리를 그대로 흘려보내는 게 정상이지만, 환경(특히 Windows 의
# 셸/어댑터 조합)에 따라 개행이 CRLF 로 번역돼 PNG 가 조용히 깨진다. 깨진 PNG 는
# 파일 크기가 멀쩡해 보여서 그대로 진행되고, 나중에 밝기 측정·합성이 전부 실패한다.
# → 매직바이트로 검증하고, 깨졌으면 기기 저장 후 pull 하는 방식(바이너리 안전)으로
#   런 전체를 전환한다.
is_png() {
  [ -s "$1" ] || return 1
  [ "$(head -c8 "$1" | od -An -tx1 | tr -d ' \n')" = "89504e470d0a1a0a" ]
}
SHOT_MODE="${SHOT_MODE:-execout}"
capture_to() { # capture_to <파일경로>
  local out="$1"
  if [ "$SHOT_MODE" = "execout" ]; then
    adb exec-out screencap -p > "$out" 2>/dev/null || true
    is_png "$out" && return 0
    echo "::warning::exec-out PNG 손상 감지 → pull 방식으로 전환합니다."
    SHOT_MODE=pull
  fi
  adb shell screencap -p /sdcard/_cap.png >/dev/null 2>&1
  adb pull /sdcard/_cap.png "$out" >/dev/null 2>&1
  adb shell rm -f /sdcard/_cap.png >/dev/null 2>&1
  if is_png "$out"; then return 0; fi
  echo "::error::스크린샷을 만들지 못했습니다: $out"
  echo "::error::exec-out·pull 두 방식 모두 실패 — adb 가 기기 경로를 제대로 못 받고 있을 수 있습니다."
  echo "::error::확인: adb shell screencap -p /sdcard/_cap.png && adb pull /sdcard/_cap.png ."
  return 1
}
shot() { capture_to "$SCREENS/$1.png"; }

# 캡처 결과 지문: 아티팩트를 못 받는 환경(에이전트 프록시)에서도 로그로 검증하기 위해
#  · 각 스샷의 평균 밝기+해상도(블랙/블랭크 조기 감지)
#  · 지도 1장은 base64 썸네일(로그에서 육안 확인)
fingerprint() {
  [ "$FINGERPRINT" = "true" ] || return 0
  echo "===== CAPTURE FINGERPRINT ====="
  for f in "$SCREENS"/*.png ${STORE:+"$STORE"/*.png} ${STILLS:+"$STILLS"/*.png}; do
    [ -e "$f" ] || continue
    local b m d
    b="$(basename "$f" .png)"
    # store/ 합성본·stills/ 는 이름 충돌 방지로 접두어
    case "$f" in
      "$STORE"/*) b="store_$b";;
      "$STILLS"/*) b="still_$b";;
    esac
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

SMOKE_PNG="$SCREENS/play_01_map_${CAP_LANG}.png"
MEAN="$(convert "$SMOKE_PNG" -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null || echo NA)"
log "지도 스샷 평균 밝기 = $MEAN (0=검정, 1=흰색)"
# NA 는 "지도가 멀쩡하다"는 뜻이 아니라 **측정 자체가 실패했다**는 뜻이다.
# 원인이 둘(깨진 PNG / ImageMagick 부재)인데 결과가 완전히 다르므로 갈라서 진단한다.
if [ "$MEAN" = "NA" ]; then
  if ! is_png "$SMOKE_PNG"; then
    echo "::error::스크린샷이 PNG 가 아닙니다($SMOKE_PNG) — adb 캡처가 깨졌습니다."
    echo "::error::SHOT_MODE=pull 로 다시 실행해 보세요: SHOT_MODE=pull bash scripts/capture/local_capture.sh"
    exit 1
  fi
  if [ "$IM_OK" != 1 ]; then
    echo "::error::ImageMagick 을 찾지 못했습니다(밝기 측정·스틸 합성 불가)."
    echo "::error::Windows: winget install ImageMagick.ImageMagick 후 셸을 새로 여세요(PATH 갱신)."
    exit 1
  fi
  echo "::warning::PNG·ImageMagick 은 정상인데 밝기 측정만 실패했습니다 — 계속 진행합니다."
fi
if [ "$MEAN" != "NA" ] && awk -v m="$MEAN" 'BEGIN{exit !(m < 0.03)}'; then
  echo "::error::지도 화면이 (거의) 검정입니다 — 함정4: x86_64 SwiftShader 네이버맵 타일 미렌더 의심."
  echo "::error::완화: -gpu 옵션/이미지 조합 변경, 대기 증가. 그래도 안 되면 실기기(사용자 폰) 폴백."
  adb logcat -d > "$LOGS/logcat_smoke.txt" 2>/dev/null || true
  exit 1
fi
# 밝기만으로는 "인증 실패로 빈 지도" 를 못 잡는다 — 인증이 깨져도 배경은 옅은 회색이라
# 검정 판정에 안 걸린다. 앱의 onAuthFailed(main.dart)가 남기는 로그를 직접 확인한다.
NAVER_AUTH_ERR="$(adb logcat -d 2>/dev/null | grep -iE '네이버지도 인증 실패|NaverMapSdk.*(Auth|401|403)' | tail -3 || true)"
if [ -n "$NAVER_AUTH_ERR" ]; then
  echo "::error::네이버 지도 인증에 실패했습니다 — 타일이 안 뜬 상태로 캡처됩니다."
  echo "$NAVER_AUTH_ERR" | sed 's/^/::error::  /'
  echo "::error::앱 코드가 아니라 NCP 콘솔 설정 문제입니다(키/서비스 활성화/쿼터). CAPTURE_IGNORE_AUTH=1 로 무시하고 진행 가능."
  [ -n "${CAPTURE_IGNORE_AUTH:-}" ] || exit 1
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
# 스토어용 9장. 영상만 뽑을 때는 순수 낭비(약 5분)라 단계로 분리했다 → PHASES=stills,flows
if want play; then
open_cap map 30;      cap "play_01_map_${CAP_LANG}"
open_cap filter 30;   cap "play_02_filter_${CAP_LANG}"
open_cap pickup 30;   cap "play_03_pickup_${CAP_LANG}"
open_cap detail 33;   cap "play_04_detail_${CAP_LANG}"
open_cap lunchbox 34; cap "play_05_lunchbox_${CAP_LANG}"
open_cap profile 32;  cap "play_06_profile_${CAP_LANG}"
open_cap share 34;    cap "play_07_share_${CAP_LANG}"
open_cap story 36;    cap "play_08_story_${CAP_LANG}"
open_cap login 32;    cap "play_09_login_${CAP_LANG}"
fi

# ── 모션그래픽용 스틸 세트(st_*) ─────────────────────────────
# 에뮬 실시간 녹화는 GPU 없는 CI(SwiftShader)에서 렉·타일로딩 때문에 품질이 안 난다.
# 대신 정확한 UI 상태 스틸을 찍고, 전환은 후반작업에서 앱의 실제 모션으로 재현한다.
#
# 결정적 요구사항: **스텝 사이에 콜드 재시작(-S)을 하지 않는다.**
# 재시작하면 지도 카메라가 달라져 '배경만' 스틸과 '오버레이' 스틸의 배경이 어긋나고,
# 두 장의 차이로 시트 레이어·좌표를 뽑는 합성이 통째로 깨진다.
if want stills; then
STILLS="$ART/stills"; mkdir -p "$STILLS"   # (상단에서 빈 값으로 선언됨 — 여기서 확정)
fi
step() { # step <cmd> <wait>
  # -S 없음: 실행 중인 액티비티에 새 인텐트만 전달 → 카메라/스크롤 상태 유지.
  adb shell "am start -n '$APP_ID/.MainActivity' -a android.intent.action.VIEW -d '$CAP_URL/?capture=$1&lang=$CAP_LANG'" >/dev/null 2>&1
  sleep "${2:-6}"; dismiss_anr
}
still() { dismiss_anr; demo_on; sleep 1; capture_to "$STILLS/$1.png"; log "  스틸: $1"; }
# 앱이 남긴 오버레이 좌표(CAPTURE_RECT)를 수거한다. 이미지 휴리스틱으로는 시트 상단을
# 안정적으로 못 찾는다(스크림이 전면을 덮고, 시트 내부 대비도 케이스마다 달라 검출이 튄다).
collect_rects() {
  adb logcat -d 2>/dev/null \
    | grep -o "CAPTURE_RECT cmd=[A-Za-z_]* sheetTopPx=-\?[0-9]*" \
    | awk '{print $2" "$3}' | sed 's/cmd=//; s/sheetTopPx=//' \
    | awk '!seen[$1]++ || 1' > "$STILLS/rects.txt" 2>/dev/null || true
  log "  좌표 수거: $(wc -l < "$STILLS/rects.txt" 2>/dev/null || echo 0)건"
  sed 's/^/    RECT /' "$STILLS/rects.txt" 2>/dev/null || true
}

# 세션 시작만 콜드로(깨끗한 출발) — 이후는 델타만 적용.
# 카메라가 움직이는 스텝(04·05)은 타일 로딩 여유를 크게 준다 — #28에서 fitBounds/
# centerOnPin 직후 9초로는 부족해 지도가 연녹색 민무늬로 찍혔다.
if want stills; then
# 이전 런의 CAPTURE_RECT 가 링버퍼에 남아 있으면 collect_rects 가 그것까지 주워
# 옛 좌표를 쓸 수 있다(UI 가 바뀌면 합성이 어긋난다) → 스틸 시작 전에 비운다.
adb logcat -c >/dev/null 2>&1 || true
open_cap st_map 30;         still "01_map"
step st_filter_open 7;      still "02_filter_open"
step st_filter_set 7;       still "03_filter_set"
step st_map_filtered 20;    still "04_map_filtered"
step st_club_bg 20;         still "05_club_bg"
step st_club_sheet 7;       still "06_club_sheet"
step st_lunchbox_bg 9;      still "07_lunchbox_bg"
step st_lunchbox 8;         still "08_lunchbox"
step st_lunchbox_diet 9;    still "09_lunchbox_diet"
step st_profile_bg 7;       still "10_profile_bg"
step st_profile 7;          still "11_profile"
step st_namecard 12;        still "12_namecard"
step st_share_bg 9;         still "13_share_bg"
step st_share 7;            still "14_share"
collect_rects
fi

# ── 카피 오버레이 합성(업로드용 최종 이미지) ──────────────────
# Play 마케팅 프레임: 크림 1080×1920 캔버스 + 상단 2줄 카피(나눔고딕Bold) +
# 옐로 언더라인 + 앱 스샷(다크 테두리). 한글 폰트는 워크플로에서 설치(fonts-nanum).
# 이 블록은 play 단계 전용이다. 예전엔 단계와 무관하게 실행됐는데, 폰트 탐색이
# `set -euo pipefail` 아래에서 스크립트를 통째로 죽였다: Windows 에는 fc-list 가
# 없어 파이프가 실패 → pipefail → 명령치환 실패 → set -e 종료. 그것도 **에러 한 줄
# 없이** 끝나서 원인이 안 보였다(스틸까지 다 찍고 흐름 녹화 직전에 사라짐).
if want play; then
STORE="$ART/store"; mkdir -p "$STORE"
KFONT="$(fc-list 2>/dev/null | grep -i nanum | grep -i bold | head -1 | cut -d: -f1 | xargs || true)"
[ -n "$KFONT" ] || KFONT="/usr/share/fonts/truetype/nanum/NanumGothicBold.ttf"
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
fi

# ── 릴스 원본(raw): 기능별 모션 클립을 언어별로 녹화 ──────────
# 후반합성기(compose_videos.sh)가 이 raw 를 크림 9:16 브랜디드 릴스로 만든다.
# 산출: reels/raw/<feat>_<lang>.mp4 (앱 1080×2400 화면녹화, 무음).
# 각 클립: 대상 언어로 지도에 콜드 안착 → 녹화 시작 → 기능 딥링크로 모션(시트/카메라) 유발.
if [ "$INCLUDE_REELS" = "true" ] && want flows; then
  RAW="$REELS/raw"; mkdir -p "$RAW"
  # ffprobe 실패(파일 없음·손상)는 흔한 정상 경로다. pipefail 아래에서 그대로 두면
  # d="$(vdur ...)" 가 set -e 를 물어 스크립트가 조용히 끝난다 → 항상 0 을 돌려준다.
  vdur() {
    ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null \
      | cut -d. -f1 || true
  }

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
      montage "$td"/f_*.png -tile 4x3 -geometry +3+3 -background '#FFF8E1' "$td/m.png" 2>/dev/null || true
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
  # 녹화 해상도·크롭은 **기기 해상도에서 계산한다.** 예전엔 1080×2400(에뮬 pixel_6)로
  # 박아뒀는데, 실제 폰은 제각각이다(갤럭시 Z 플립 6 = 1080×2640). screenrecord 에
  # 다른 크기를 주면 스케일이 끼어 화면이 왜곡되고, 고정 크롭은 시트 하단 버튼을
  # 잘라먹는다. 폭이 1080 을 넘을 때만 1080 기준으로 비율 유지 축소한다.
  DEV_WH="$(adb shell wm size 2>/dev/null | tr -d '\r' | awk -F': ' '/Override|Physical/{print $2}' | tail -1)"
  case "$DEV_WH" in [0-9]*x[0-9]*) ;; *) DEV_WH="1080x2400";; esac
  DEV_W="${DEV_WH%x*}"; DEV_H="${DEV_WH#*x}"
  REC_W="$DEV_W"; REC_H="$DEV_H"
  if [ "$DEV_W" -gt 1080 ]; then
    REC_W=1080
    REC_H="$(awk -v h="$DEV_H" -v w="$DEV_W" 'BEGIN{printf "%d", int(h*1080/w/2)*2}')"
  fi
  # 9:16 크롭: 위쪽(상태바·검색바)을 덜어내고 아래 상세시트 버튼까지 살린다.
  # 기준값 390px 은 1080 폭에서의 값 — 다른 폭이면 비례로 환산한다.
  CROP_H="$(awk -v w="$REC_W" 'BEGIN{printf "%d", int(w*16/9/2)*2}')"
  CROP_Y="$(awk -v h="$REC_H" -v ch="$CROP_H" -v w="$REC_W" \
    'BEGIN{y=int(390*w/1080); if (y+ch>h) y=h-ch; if (y<0) y=0; printf "%d", y}')"
  # 흐름은 길어(35~45s) 인코더 부하가 크다. 실기기는 대역폭 여유가 있어 8Mbps.
  FLOW_REC=(--size "${REC_W}x${REC_H}" --bit-rate 8000000)
  FLOW_CROP="crop=${REC_W}:${CROP_H}:0:${CROP_Y},scale=1080:1920:flags=lanczos"
  log "녹화 ${REC_W}x${REC_H} → 크롭 ${REC_W}x${CROP_H}@y=${CROP_Y} → 1080x1920 (기기 $DEV_WH)"

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
    if ! ffmpeg -y -loglevel error -i "$rawout" -vf "$FLOW_CROP" \
        -c:v libx264 -preset veryfast -pix_fmt yuv420p -r 30 -an "$out" 2>&1 | tail -2; then
      echo "::warning::9:16 크롭 인코딩 실패: $name (원본은 raw/ 에 남아 있음)"
      return
    fi
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
    [ -s "$f" ] && echo "file '$(basename "$f")'" >> "$TOUR_LIST" || true
  done
  if [ -s "$TOUR_LIST" ]; then
    ( cd "$FLOWS_DIR" && ffmpeg -y -loglevel error -f concat -safe 0 -i .tour.txt \
        -c copy "full_tour_${CAP_LANG}.mp4" 2>&1 | tail -2 ) \
      || echo "::warning::풀 투어 이어붙이기 실패"
    log "  ↳ flows/full_tour_${CAP_LANG}.mp4"
  fi
  rm -f "$TOUR_LIST"

  if [ "$FINGERPRINT" = "true" ]; then
  echo "===== FLOW FINGERPRINT ====="
  for n in discover save share full_tour; do
    flow_montage "$FLOWS_DIR/${n}_${CAP_LANG}.mp4" "flow_${n}"
  done
  echo "===== END FLOW FINGERPRINT ====="
  fi
fi

adb logcat -d > "$LOGS/logcat.txt" 2>/dev/null || true
fingerprint
log "완료. screens=$(ls -1 "$SCREENS" 2>/dev/null | wc -l)장, raw=$(ls -1 "$REELS/raw" 2>/dev/null | wc -l)편(후반합성은 compose_videos.sh)."
