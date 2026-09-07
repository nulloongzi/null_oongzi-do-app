#!/usr/bin/env bash
# scripts/capture/renorm_flows.sh — 재촬영 없이 9:16 정규화만 다시 한다.
#
# reels/raw/ 에는 폰 화면 그대로의 원본(예: 1080x2640)이 남아 있다. 크롭/맞춤
# 방식만 바꾸는 변경은 이 원본에서 다시 뽑으면 되므로, 12분짜리 재촬영이 필요 없다.
# 비트 파일(_beats.txt)은 시간 정보라 그대로 유효하다.
#
#   scripts/capture/renorm_flows.sh              # fit(기본)
#   FIT_MODE=crop scripts/capture/renorm_flows.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

ART="${ARTIFACTS_DIR:-$ROOT/marketing-assets}"
LANG_TAG="${CAP_LANG:-ko}"
RAW="$ART/reels/raw"
OUT="$ART/reels/flows"
FIT_MODE="${FIT_MODE:-fit}"
OUT_W=1080; OUT_H=1920

say() { printf '\033[1;33m▶ %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

[ -d "$RAW" ] || die "원본이 없습니다: $RAW (먼저 local_capture.sh)"
mkdir -p "$OUT"

n=0
for f in "$RAW"/flow_*_"${LANG_TAG}".mp4; do
  [ -e "$f" ] || continue
  b="$(basename "$f")"; name="${b#flow_}"; name="${name%_${LANG_TAG}.mp4}"
  W="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$f")"
  H="$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$f")"
  [ -n "$W" ] && [ -n "$H" ] || { echo "::warning::해상도를 못 읽음: $b"; continue; }

  if [ "$FIT_MODE" = "crop" ]; then
    ch="$(awk -v w="$W" 'BEGIN{printf "%d", int(w*16/9/2)*2}')"
    cy="$(awk -v h="$H" -v ch="$ch" -v w="$W" \
      'BEGIN{y=int(390*w/1080); if (y+ch>h) y=h-ch; if (y<0) y=0; printf "%d", y}')"
    VF="crop=${W}:${ch}:0:${cy},scale=${OUT_W}:${OUT_H}:flags=lanczos"
    say "$name: 크롭 ${W}x${ch}@y=${cy}"
  else
    tt="$(awk -v w="$W" 'BEGIN{printf "%d", int(120*w/1080/2)*2}')"
    tb="$(awk -v w="$W" 'BEGIN{printf "%d", int(60*w/1080/2)*2}')"
    ih=$(( H - tt - tb ))
    VF="crop=${W}:${ih}:0:${tt},scale=-2:$(( OUT_H - 6 )):flags=lanczos,"
    VF+="pad=iw+6:ih+6:3:3:color=0x3A2C26,pad=${OUT_W}:${OUT_H}:(ow-iw)/2:0:color=0xFFF8E1"
    say "$name: 상태바/제스처바만 제거 후 세로 맞춤 (잘림 없음)"
  fi

  ffmpeg -y -loglevel error -i "$f" -vf "$VF" \
    -c:v libx264 -preset medium -profile:v high -crf 20 \
    -threads "${X264_THREADS:-4}" -an "$OUT/${name}_${LANG_TAG}.mp4"
  n=$((n+1))
done

[ "$n" -gt 0 ] || die "변환할 원본이 없습니다."

# 풀 투어 재생성(있던 경우에만)
TL="$OUT/.tour.txt"; : > "$TL"
for x in discover save share; do
  [ -s "$OUT/${x}_${LANG_TAG}.mp4" ] && echo "file '${x}_${LANG_TAG}.mp4'" >> "$TL" || true
done
if [ -s "$TL" ]; then
  ( cd "$OUT" && ffmpeg -y -loglevel error -f concat -safe 0 -i .tour.txt \
      -c copy "full_tour_${LANG_TAG}.mp4" ) || echo "::warning::풀 투어 이어붙이기 실패"
fi
rm -f "$TL"

say "완료 ${n}편 → $OUT  (이어서 edit_reels.sh 를 실행하세요)"
