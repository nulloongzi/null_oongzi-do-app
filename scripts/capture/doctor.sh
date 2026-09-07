#!/usr/bin/env bash
# scripts/capture/doctor.sh — 캡처 파이프라인이 왜 기대대로 안 나오는지 진단한다.
#
# PowerShell 에서 adb·딥링크를 직접 치면 인용부호(\" 미지원)와 & 때문에 명령이
# 깨진다. 진단은 여기 모아두고 셸에서는 이 파일만 부른다.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"
export MSYS2_ARG_CONV_EXCL='/sdcard;/data/local/tmp'

APP_ID="com.nulloongzi.nulloongzido"
ART="${ARTIFACTS_DIR:-$ROOT/marketing-assets}"
ok()   { printf '\033[0;32m  ✔ %s\033[0m\n' "$*"; }
bad()  { printf '\033[1;31m  ✘ %s\033[0m\n' "$*"; }
info() { printf '\033[0;36m  · %s\033[0m\n' "$*"; }
hd()   { printf '\033[1;33m\n▶ %s\033[0m\n' "$*"; }

hd "1. 기기"
if adb devices | awk 'NR>1 && $2=="device"' | grep -q .; then
  ok "$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r') / $(adb shell wm size 2>/dev/null | tr -d '\r' | tail -1)"
else
  bad "연결된 기기 없음"; exit 1
fi

hd "2. 기기 시각 (비트 타이밍의 기준)"
D="$(adb shell 'date +%s.%N' 2>/dev/null | tr -d '\r')"
info "date +%s.%N → $D"
case "$D" in
  [0-9]*.[0-9]*) ok "나노초까지 지원 — 비트 타이밍 계산 가능" ;;
  [0-9]*N*|*%N*) bad "%N 미지원 — 기준 시각을 못 잡는다(비트가 어긋남)" ;;
  *) bad "예상 밖 출력 — 비트 타이밍을 신뢰할 수 없음" ;;
esac

hd "3. 설치된 APK 에 비트 코드가 있나"
adb logcat -c >/dev/null 2>&1
adb shell am force-stop "$APP_ID" >/dev/null 2>&1
adb shell "am start -S -n '$APP_ID/.MainActivity' -a android.intent.action.VIEW -d 'https://nulloongzi.github.io/?capture=flow_discover&lang=ko'" >/dev/null 2>&1
info "flow_discover 실행 — 14초 대기(지도 로드 + 첫 두 비트)"
sleep 14
N="$(adb logcat -d 2>/dev/null | grep -c CAPTURE_BEAT)"
if [ "${N:-0}" -gt 0 ]; then
  ok "CAPTURE_BEAT ${N}건"
  adb logcat -d 2>/dev/null | grep -o 'CAPTURE_BEAT .*' | sed 's/^/    /' | head
else
  bad "CAPTURE_BEAT 0건 — 설치된 APK 가 구버전이다"
  info "해결: SKIP_BUILD 없이 scripts/capture/local_capture.sh 를 다시 실행"
fi
adb shell am force-stop "$APP_ID" >/dev/null 2>&1

hd "4. 지난 캡처 산출물"
for f in "$ART"/reels/flows/*_beats.txt; do
  [ -e "$f" ] || { bad "비트 파일 없음: reels/flows/*_beats.txt"; break; }
  if [ -s "$f" ]; then ok "$(basename "$f"): $(tr '\n' ' ' < "$f")"
  else bad "$(basename "$f"): 비어 있음"; fi
done
for d in reels/flows reels/final motion stills; do
  c="$(ls -1 "$ART/$d" 2>/dev/null | wc -l | tr -d ' ')"
  info "$d — ${c}개"
done

hd "요약"
echo "  2·3 이 모두 ✔ 이면 다음 캡처부터 자막이 정확한 화면에 붙는다."
echo "  3 이 ✘ 이면 재빌드가 필요하다(Dart 코드가 APK 에 안 들어갔다)."
