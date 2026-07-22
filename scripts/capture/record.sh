#!/usr/bin/env bash
# scripts/capture/record.sh — 하나의 Maestro 플로우를 adb screenrecord 로 감싸 mp4 로 녹화.
# 네이티브 지도 레이어까지 담기 위해 screenrecord(프레임버퍼) 사용(함정1).
# 사용: record.sh <name> <maestro-flow-file>
# 필요 env: REELS(출력 dir) · APP_ID · CAP_LANG · (PATH 에 maestro)
set -euo pipefail

NAME="${1:?name 필요}"
FLOW="${2:?flow 파일 필요}"
REELS="${REELS:?REELS env 필요}"
APP_ID="${APP_ID:?APP_ID env 필요}"
LANG_CODE="${CAP_LANG:-ko}"
DEV_MP4="/sdcard/${NAME}.mp4"

echo "🎬 녹화 시작: $NAME  ($FLOW)"

# 깨끗한 시작 상태로.
adb shell am force-stop "$APP_ID" || true

# screenrecord 를 백그라운드로. screenrecord 는 최대 180s 하드리밋(--time-limit).
# --bit-rate 8M: 릴스 원본 화질. 해상도는 디바이스 기본(1080×2400) — 편집서 크롭.
adb shell screenrecord --bit-rate 8000000 --time-limit 180 "$DEV_MP4" &
REC_PID=$!
sleep 1  # 인코더 워밍업

# 조작 시나리오 실행(실패해도 녹화는 마무리).
maestro test --env "APPLANG=$LANG_CODE" --env "APP_ID=$APP_ID" "$FLOW" || \
  echo "::warning::reel 플로우 실패(녹화는 저장): $NAME"

# on-device screenrecord 에 SIGINT → mp4 정상 flush(kill -9 면 파일 깨짐).
adb shell pkill -INT screenrecord >/dev/null 2>&1 || true
sleep 2
wait "$REC_PID" 2>/dev/null || true

# 러너로 회수.
adb pull "$DEV_MP4" "$REELS/${NAME}.mp4" >/dev/null 2>&1 && echo "  ↳ 저장: $REELS/${NAME}.mp4" \
  || echo "::warning::mp4 회수 실패: $NAME"
adb shell rm -f "$DEV_MP4" >/dev/null 2>&1 || true
