#!/usr/bin/env bash
# scripts/capture/local_capture.sh — 내 PC(또는 연결된 실제 폰)에서 마케팅 영상을 뽑는다.
#
# 왜 로컬인가: GitHub 호스티드 러너엔 GPU 가 없어 에뮬이 SwiftShader(CPU 렌더링)로
# 떨어진다. 하드웨어 대비 10~20배 느려 지도 타일이 안 오고 녹화가 렉걸린다.
# 로컬 GPU(또는 실제 폰)에서는 같은 스크립트가 그대로 60fps 실제 푸티지를 만든다.
#
# **실제 폰을 USB 로 연결하는 걸 권장한다.** 스크립트가 딥링크로 앱을 전부 조종하므로
# 손으로 촬영할 필요가 없다 — 폰은 꽂아두기만 하면 된다. 진짜 GPU·진짜 관성.
#
# 사용법:
#   scripts/capture/local_capture.sh                # 영상에 필요한 것만(스틸+흐름) — 기본
#   MODE=stills scripts/capture/local_capture.sh    # 스틸만(빠름)
#   MODE=video  scripts/capture/local_capture.sh    # 흐름 영상만
#   MODE=all    scripts/capture/local_capture.sh    # + 스토어 스샷 9장(약 5분 추가)
#   SKIP_BUILD=1 scripts/capture/local_capture.sh   # APK 재빌드 없이 기존 것 사용
#   KEEP_OUT=1   scripts/capture/local_capture.sh   # 기존 산출물 유지(중단 후 이어서)
#
# 필요한 것: adb(Android SDK) · flutter · ffmpeg · imagemagick
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

MODE="${MODE:-motion}"                    # motion(기본) | stills | video | all
OUT="${ARTIFACTS_DIR:-$ROOT/marketing-assets}"
LANG_TAG="${CAP_LANG:-ko}"
APK_OUT="build/app/outputs/flutter-apk/app-debug.apk"

say()  { printf '\033[1;33m▶ %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# ── 사전 점검 ────────────────────────────────────────────────
for c in adb ffmpeg; do
  command -v "$c" >/dev/null 2>&1 || die "$c 가 없습니다. (adb=Android SDK, ffmpeg)"
done
# ImageMagick: IM7 은 magick, IM6 은 convert. Windows 의 convert.exe(디스크 유틸)와
# 혼동하지 않도록 magick 을 우선 확인한다.
command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1 \
  || die "ImageMagick 이 없습니다. (Windows: winget install ImageMagick.ImageMagick / macOS: brew install imagemagick)"
[ -n "${SKIP_BUILD:-}" ] || command -v flutter >/dev/null 2>&1 || die "flutter 가 없습니다. SKIP_BUILD=1 로 기존 APK 를 쓰거나 Flutter 를 설치하세요."

# ── 기기 확인 ────────────────────────────────────────────────
adb start-server >/dev/null 2>&1 || true
DEV_COUNT="$(adb devices | awk 'NR>1 && $2=="device"' | wc -l | tr -d ' ')"
[ "$DEV_COUNT" -ge 1 ] || die "연결된 기기가 없습니다.
  · 실제 폰: USB 연결 + 개발자옵션 > USB 디버깅 허용 (권장 — 진짜 GPU)
  · 에뮬레이터: GPU 가속으로 실행 (Android Studio 기본값이 hardware 입니다)"
[ "$DEV_COUNT" -eq 1 ] || die "기기가 여러 대 연결돼 있습니다. 하나만 남기거나 ANDROID_SERIAL 을 지정하세요."

DEV_MODEL="$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
DEV_SIZE="$(adb shell wm size 2>/dev/null | tr -d '\r' | awk -F': ' '{print $2}')"
say "기기: $DEV_MODEL ($DEV_SIZE)"
# 크롭은 소스 해상도에 자동 대응한다(compose_motion.sh). 참고용으로만 알린다.
case "$DEV_SIZE" in
  1080x2400) ;;
  *) printf '\033[0;36m  · 1080x2400 이 아니지만 크롭은 자동 대응합니다(9:16 정규화).\033[0m\n' ;;
esac

# ── Gradle 힙 사전 점검 ──────────────────────────────────────
# 이 프로젝트의 android/gradle.properties 는 CI 러너 기준으로 -Xmx8G 를 잡는다.
# 개인 PC(특히 16GB 이하)에서는 JVM 이 힙을 확보하지 못해 Gradle 데몬이 통째로
# 크래시한다("Gradle build daemon disappeared unexpectedly" + hs_err_pid*.log).
# 레포 파일은 건드리지 않고, 사용자 레벨 설정(~/.gradle/gradle.properties)이
# 프로젝트 설정보다 우선한다는 점을 이용해 안내한다.
if [ -z "${SKIP_BUILD:-}" ]; then
  want_g="$(grep -o 'Xmx[0-9]*G' android/gradle.properties 2>/dev/null | head -1 | tr -dc '0-9')"
  user_props="$HOME/.gradle/gradle.properties"
  have_override=0
  [ -f "$user_props" ] && grep -q 'org.gradle.jvmargs' "$user_props" && have_override=1
  # 가용 RAM(GB) — Linux/macOS/Git Bash 각각 다른 경로
  ram_g=""
  if [ -r /proc/meminfo ]; then
    ram_g="$(awk '/MemTotal/{printf "%d", $2/1024/1024}' /proc/meminfo)"
  elif command -v sysctl >/dev/null 2>&1; then
    ram_g="$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%d", $1/1024/1024/1024}')"
  elif command -v wmic >/dev/null 2>&1; then
    ram_g="$(wmic computersystem get TotalPhysicalMemory 2>/dev/null | tr -dc '0-9' | awk '{printf "%d", $1/1024/1024/1024}')"
  fi
  if [ -n "${want_g:-}" ] && [ "$have_override" = 0 ] && [ -n "$ram_g" ] && [ "$ram_g" -gt 0 ] \
     && [ "$want_g" -gt $(( ram_g / 2 )) ]; then
    printf '\033[1;31m'
    echo "✗ Gradle 힙 설정이 이 PC 에 과합니다: -Xmx${want_g}G (전체 RAM ${ram_g}GB)"
    echo "  그대로 두면 Gradle 데몬이 크래시합니다. 아래를 실행해 사용자 레벨로 낮추세요:"
    printf '\033[0m'
    safe=$(( ram_g / 4 )); [ "$safe" -lt 2 ] && safe=2
    echo ""
    echo "    mkdir -p ~/.gradle"
    echo "    printf 'org.gradle.jvmargs=-Xmx${safe}G -XX:MaxMetaspaceSize=1G\\norg.gradle.workers.max=2\\n' > ~/.gradle/gradle.properties"
    echo ""
    echo "  (레포 파일은 CI 기준이므로 건드리지 않습니다. 사용자 설정이 우선합니다.)"
    exit 1
  fi
fi

# ── APK 빌드 & 설치 ──────────────────────────────────────────
if [ -z "${SKIP_BUILD:-}" ]; then
  say "APK 빌드 (CAPTURE_MODE=true)…"
  flutter build apk --debug --dart-define=CAPTURE_MODE=true
fi
[ -f "$APK_OUT" ] || die "APK 가 없습니다: $APK_OUT (SKIP_BUILD 를 빼고 다시 실행)"
say "설치…"
adb install -r -g "$APK_OUT" >/dev/null 2>&1 || adb install -r "$APK_OUT" >/dev/null

# ── 캡처 ─────────────────────────────────────────────────────
# 기본은 깨끗한 산출물(부분 실패가 이전 런 결과와 섞이지 않게).
# 중간에 끊겨 다시 돌릴 때는 KEEP_OUT=1 로 남긴다.
[ -n "${KEEP_OUT:-}" ] || rm -rf "$OUT"
mkdir -p "$OUT"
case "$MODE" in
  # 스토어 스샷 9장은 영상과 무관한데 5분쯤 잡아먹는다 → 기본에서 뺐다.
  motion) PH=stills,flows      ; REELS=true  ;;
  stills) PH=stills            ; REELS=false ;;
  video)  PH=flows             ; REELS=true  ;;
  all)    PH=play,stills,flows ; REELS=true  ;;
  *) die "MODE 는 motion|stills|video|all 중 하나" ;;
esac

say "캡처 시작 (MODE=$MODE · 단계=$PH)…"
APK_PATH="$APK_OUT" ARTIFACTS_DIR="$OUT" SMOKE_ONLY=false \
  CAP_LANG="$LANG_TAG" INCLUDE_REELS="$REELS" PHASES="$PH" \
  SHOT_MODE="${SHOT_MODE:-execout}" \
  bash "$HERE/run_capture.sh"

# ── 후반작업(스틸 → 시연 영상) ───────────────────────────────
if [ "$MODE" != "video" ]; then
  say "모션 합성…"
  ARTIFACTS_DIR="$OUT" CAP_LANG="$LANG_TAG" bash "$HERE/compose_motion.sh" \
    2>&1 | grep -vE '^[A-Za-z0-9+/=]{200,}$' | grep -vE 'MONTAGE_(BEGIN|END)'
fi

say "완료 — $OUT"
find "$OUT" -name '*.mp4' -o -name '*.png' | head -40
printf '\n\033[1;32m영상: %s/motion/  ·  흐름 원본: %s/reels/flows/\033[0m\n' "$OUT" "$OUT"
