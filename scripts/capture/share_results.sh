#!/usr/bin/env bash
# scripts/capture/share_results.sh — 캡처 결과를 "리뷰용 경량 사본"으로 만들어 브랜치에 올린다.
#
# 왜: 원본은 스틸 PNG 14장(장당 1~3MB) + 흐름 mp4 3~4편(편당 30MB+)이라 레포에 넣기엔
# 무겁다. 화질 판단에 필요한 최소치만 남긴 프록시를 올려 원격에서 눈으로 확인한다.
#   · 스틸 → 폭 540 JPEG (구도·타일·시트 위치 판별용)
#   · 영상 → 360x640 h264 crf32 (전환·렉·잘림 판별용)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

if command -v magick >/dev/null 2>&1; then convert() { magick "$@"; }; fi

SRC="${ARTIFACTS_DIR:-$ROOT/marketing-assets}"
REV="$SRC/_review"
[ -d "$SRC" ] || { echo "✗ 캡처 결과가 없습니다: $SRC"; exit 1; }
rm -rf "$REV"; mkdir -p "$REV"

n=0
for f in "$SRC"/stills/*.png "$SRC"/screens/*.png; do
  [ -e "$f" ] || continue
  convert "$f" -resize 540x -quality 78 "$REV/$(basename "${f%.png}").jpg" 2>/dev/null || continue
  n=$((n+1))
done
echo "▶ 스틸 프록시 ${n}장"

# flows/ 와 motion/ 은 파일명이 같다(discover_ko.mp4 …). 그대로 복사하면 뒤에
# 처리되는 쪽이 앞을 덮어써서 절반만 올라간다 → 출처를 접두어로 붙인다.
v=0
for d in flows motion; do
  case "$d" in
    flows) src="$SRC/reels/flows" ;;
    motion) src="$SRC/motion" ;;
  esac
  for f in "$src"/*.mp4; do
    [ -e "$f" ] || continue
    ffmpeg -y -loglevel error -i "$f" -vf "scale=360:-2" -c:v libx264 -preset veryfast \
      -crf 32 -pix_fmt yuv420p -an "$REV/${d}_$(basename "${f%.mp4}").mp4" 2>/dev/null || continue
    v=$((v+1))
  done
done
echo "▶ 영상 프록시 ${v}편"

# 원본 목록·용량은 텍스트로 같이 올린다(프록시만 보면 원본 상태를 못 판단한다).
{
  echo "# 캡처 원본 목록 ($(date '+%Y-%m-%d %H:%M'))"
  echo "기기: $(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r') / $(adb shell wm size 2>/dev/null | tr -d '\r')"
  echo
  find "$SRC" -name '_review' -prune -o -type f \( -name '*.png' -o -name '*.mp4' \) -print0 2>/dev/null \
    | xargs -0 ls -l 2>/dev/null | awk '{print $5"\t"$9}' | sort -k2
  echo
  echo "# rects.txt"
  cat "$SRC/stills/rects.txt" 2>/dev/null || echo "(없음)"
} > "$REV/MANIFEST.txt"

BR="$(git rev-parse --abbrev-ref HEAD)"
git add -f "$REV"
git commit -q -m "chore(capture): 리뷰용 프록시 업로드 (스틸 ${n}장 / 영상 ${v}편)" || { echo "▶ 변경 없음"; exit 0; }
# 캡처가 도는 동안 원격에 커밋이 올라가 있는 경우가 잦다(스크립트 수정 등).
# 프록시는 신규 파일뿐이라 리베이스가 안전하다.
#
# 다만 flutter build 가 generated_plugin_registrant 류를 다시 써서 작업본이
# 더러워져 있는 일이 잦고("cannot pull with rebase: You have unstaged changes"),
# 그러면 리베이스가 막혀 푸시까지 거부된다 → 추적 파일 변경만 잠시 치운다.
# (-u 를 안 붙인다: marketing-assets 의 원본 PNG·MP4 수백 MB 까지 딸려간다)
STASHED=0
if ! git diff --quiet || ! git diff --cached --quiet; then
  git stash push -q -m "share_results-auto" && STASHED=1
fi
git pull --rebase -q origin "$BR" || echo "▶ 리베이스 실패 — 수동 확인 필요"
git push -u origin "$BR" || true
[ "$STASHED" = 1 ] && git stash pop -q || true
echo "✔ 업로드 완료 → $BR : marketing-assets/_review/"
