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
#   scripts/capture/local_capture.sh                # 흐름 영상 + 스틸 + 후반작업 전부
#   MODE=stills scripts/capture/local_capture.sh    # 스틸만(빠름)
#   MODE=video  scripts/capture/local_capture.sh    # 흐름 영상만
#   SKIP_BUILD=1 scripts/capture/local_capture.sh   # APK 재빌드 없이 기존 것 사용
#
# 필요한 것: adb(Android SDK) · flutter · ffmpeg · imagemagick
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

MODE="${MODE:-all}"                       # all | stills | video
OUT="${ARTIFACTS_DIR:-$ROOT/marketing-assets}"
LANG_TAG="${CAP_LANG:-ko}"
APK_OUT="build/app/outputs/flutter-apk/app-debug.apk"

say()  { printf '\033[1;33m▶ %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# ── 사전 점검 ────────────────────────────────────────────────
for c in adb ffmpeg convert; do
  command -v "$c" >/dev/null 2>&1 || die "$c 가 없습니다. (adb=Android SDK, ffmpeg/convert=ImageMagick)"
done
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
case "$DEV_SIZE" in
  1080x2400) ;;
  *) printf '\033[1;33m  ⚠ 화면이 1080x2400 이 아닙니다 — 9:16 크롭 좌표(CROP_Y)를 조정해야 할 수 있습니다.\033[0m\n' ;;
esac

# ── APK 빌드 & 설치 ──────────────────────────────────────────
if [ -z "${SKIP_BUILD:-}" ]; then
  say "APK 빌드 (CAPTURE_MODE=true)…"
  flutter build apk --debug --dart-define=CAPTURE_MODE=true
fi
[ -f "$APK_OUT" ] || die "APK 가 없습니다: $APK_OUT (SKIP_BUILD 를 빼고 다시 실행)"
say "설치…"
adb install -r -g "$APK_OUT" >/dev/null 2>&1 || adb install -r "$APK_OUT" >/dev/null

# ── 캡처 ─────────────────────────────────────────────────────
rm -rf "$OUT"; mkdir -p "$OUT"
case "$MODE" in
  stills) SMOKE=false; REELS=false ;;
  video)  SMOKE=false; REELS=true  ;;
  all)    SMOKE=false; REELS=true  ;;
  *) die "MODE 는 all|stills|video 중 하나" ;;
esac

say "캡처 시작 (MODE=$MODE)…"
APK_PATH="$APK_OUT" ARTIFACTS_DIR="$OUT" SMOKE_ONLY="$SMOKE" \
  CAP_LANG="$LANG_TAG" INCLUDE_REELS="$REELS" \
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
