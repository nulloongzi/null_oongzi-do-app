#!/usr/bin/env bash
# scripts/capture/tts.sh — 한국어 나레이션 한 줄을 오디오 파일로 만든다.
#
#   tts.sh <출력.mp3> <읽을 텍스트>
#
# 백엔드는 있는 것부터 쓴다:
#   1) edge-tts  — 마이크로소프트 신경망 음성(ko-KR-SunHiNeural). 무료·API 키 불필요.
#                  `pip install edge-tts` 만 하면 되고 품질이 가장 좋다.
#   2) Windows SAPI — 오프라인 폴백. 한국어 Windows 에 기본 탑재된 음성(Heami)을 쓴다.
#                  기계음에 가깝지만 네트워크 없이 된다.
# 둘 다 없으면 1을 반환한다(호출자가 무음으로 진행).
set -uo pipefail

OUT="${1:?출력 경로 필요}"
TEXT="${2:?텍스트 필요}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOICE="${TTS_VOICE:-ko-KR-SunHiNeural}"
RATE="${TTS_RATE:-+8%}"   # 릴스는 조금 빠른 편이 붙는다

if command -v edge-tts >/dev/null 2>&1; then
  if edge-tts --voice "$VOICE" --rate="$RATE" --text "$TEXT" --write-media "$OUT" >/dev/null 2>&1 \
     && [ -s "$OUT" ]; then
    exit 0
  fi
  echo "::warning::edge-tts 실패 — SAPI 폴백 시도" >&2
fi

# Windows SAPI: 한글을 인자로 넘기면 코드페이지 때문에 깨진다 → UTF-8 파일로 넘긴다.
PS="$(command -v powershell.exe || command -v powershell || true)"
if [ -n "$PS" ] && [ -f "$HERE/tts_sapi.ps1" ]; then
  tmp_txt="$(mktemp).txt"; tmp_wav="$(mktemp).wav"
  printf '%s' "$TEXT" > "$tmp_txt"
  "$PS" -NoProfile -ExecutionPolicy Bypass -File "$HERE/tts_sapi.ps1" \
    -TextFile "$tmp_txt" -OutWav "$tmp_wav" >/dev/null 2>&1
  if [ -s "$tmp_wav" ]; then
    ffmpeg -y -loglevel error -i "$tmp_wav" -c:a libmp3lame -q:a 4 "$OUT" 2>/dev/null
    rm -f "$tmp_txt" "$tmp_wav"
    [ -s "$OUT" ] && exit 0
  fi
  rm -f "$tmp_txt" "$tmp_wav"
fi

exit 1
