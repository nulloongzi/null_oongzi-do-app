#!/usr/bin/env bash
# scripts/capture/edit_reels.sh — 실기기 녹화본(raw)에 편집·디자인을 얹어
# 인스타 릴스 / 유튜브 쇼츠에 그대로 올릴 수 있는 완성본을 만든다.
#
# 입력 : marketing-assets/reels/flows/<flow>_<lang>.mp4   (1080x1920, 앱 실제 화면)
# 출력 : marketing-assets/reels/final/<flow>_<lang>.mp4
#
# 왜 이 구조인가 (레이어 3층):
#   1층 푸티지 — local_capture.sh 가 실기기에서 뽑는다(이미 완료)
#   2층 편집   — 훅(첫 1.6초) · 장면별 자막 · 브랜드 아웃트로  ← 이 스크립트
#   3층 디자인 — 브랜드 색/서체/여백 규칙                      ← 이 스크립트
#
# 자막 타이밍은 **장면 전환을 자동 감지**해서 붙인다. 앱의 _hold() 값을 바꿔도
# 자막 스크립트를 안 고쳐도 되게 하려는 것 — 하드코딩한 초는 금방 어긋난다.
#
# 사용법:
#   scripts/capture/edit_reels.sh              # 전부
#   FLOWS="discover" scripts/capture/edit_reels.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

if command -v magick >/dev/null 2>&1; then convert() { magick "$@"; }; fi

ART="${ARTIFACTS_DIR:-$ROOT/marketing-assets}"
LANG_TAG="${CAP_LANG:-ko}"
SRC_DIR="$ART/reels/flows"
OUT_DIR="$ART/reels/final"
WORK="$ART/reels/.edit"
SCRIPT_FILE="${REELS_SCRIPT:-$HERE/reels.$LANG_TAG.txt}"
FONT="$ROOT/assets/fonts/PretendardVariable.ttf"
LOGO="$ROOT/assets/nulloongzido logo_without bg.png"

W=1080; H=1920; FPS=30
# 브랜드 팔레트 — lib/theme.dart 와 동일해야 앱과 영상이 한 몸으로 보인다.
C_YELLOW='#FAC710'; C_DARK='#4E342E'; C_BROWN='#8D6E63'; C_BG='#FFF8E1'

HOOK_D=1.6      # 훅 노출 시간
OUTRO_D=2.2     # 아웃트로 카드 길이
CAP_FADE=0.25   # 자막 페이드
# 자막을 화면 위쪽에 둔다. 아래쪽은 앱의 바텀시트(핵심 콘텐츠)와 인스타 UI가 겹친다.
CAP_Y=168

log()  { printf '\033[1;33m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[0;35m! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg 가 없습니다."
[ -f "$FONT" ] || die "폰트가 없습니다: $FONT"
[ -f "$SCRIPT_FILE" ] || die "자막 스크립트가 없습니다: $SCRIPT_FILE"
[ -d "$SRC_DIR" ] || die "녹화본이 없습니다: $SRC_DIR (먼저 local_capture.sh)"

rm -rf "$WORK"; mkdir -p "$WORK" "$OUT_DIR"

# ── 텍스트 카드 렌더 ─────────────────────────────────────────
# ffmpeg drawtext 대신 ImageMagick 으로 PNG 를 굽는다: 한글 폰트 경로 이스케이프
# (윈도우 드라이브 콜론) 문제를 피하고, 둥근 모서리·그림자·2단 조판을 제대로 짤 수 있다.
# Pretendard 는 가변 폰트라 IM 이 굵기를 못 고른다 → stroke 로 굵기를 낸다(2px 검증됨).

cap_card() { # cap_card <윗줄> <아랫줄> <출력>
  local l1="$1" l2="$2" out="$3"
  local cw=936 pad=40
  local h1=46 h2=62
  local th=$(( pad*2 + h1 + 18 + h2 ))
  [ -z "$l2" ] && th=$(( pad*2 + h2 ))
  convert -size ${cw}x${th} xc:none \
    -fill "$C_BG" -draw "roundrectangle 0,0 $((cw-1)),$((th-1)) 28,28" \
    -font "$FONT" -gravity north \
    \( -clone 0 -alpha extract -blur 0x12 -shade 0x0 \) -delete 1 \
    "$out.bg.png" 2>/dev/null
  if [ -n "$l2" ]; then
    convert "$out.bg.png" -font "$FONT" -gravity north \
      -fill "$C_BROWN" -stroke "$C_BROWN" -strokewidth 1 -pointsize $h1 -annotate +0+$pad "$l1" \
      -fill "$C_DARK"  -stroke "$C_DARK"  -strokewidth 2 -pointsize $h2 -annotate +0+$(( pad + h1 + 18 )) "$l2" \
      "$out"
  else
    convert "$out.bg.png" -font "$FONT" -gravity north \
      -fill "$C_DARK" -stroke "$C_DARK" -strokewidth 2 -pointsize $h2 -annotate +0+$pad "$l1" \
      "$out"
  fi
  rm -f "$out.bg.png"
}

hook_card() { # hook_card <윗줄> <아랫줄> <출력>
  # 훅은 카드가 아니라 화면 전체를 덮는 그라데이션 스크림 + 큰 글씨.
  # 첫 프레임부터 영상이 움직이는 게 중요해서(정지 타이틀은 넘겨진다) 배경을 가리지 않는다.
  local l1="$1" l2="$2" out="$3"
  # 첫 1초가 전부다 — 작게 넣으면 그냥 넘어간다. 화면 폭을 꽉 쓰고,
  # 옅은 지도 위에서도 읽히도록 스크림을 진하게 깐다.
  # 스크림: 위 660px 은 단색, 그 아래 480px 만 페이드. 순수 그라데이션으로 하면
  # 글자가 놓이는 y=330~600 구간에서 이미 반투명해져 지도와 섞인다(검증됨).
  convert -size ${W}x${H} xc:none \
    \( -size ${W}x660 xc:"rgba(62,40,35,0.82)" \) -geometry +0+0 -composite \
    \( -size ${W}x480 gradient:"rgba(62,40,35,0.82)"-none \) -geometry +0+660 -composite \
    -font "$FONT" -gravity north \
    -fill "$C_YELLOW" -stroke "$C_YELLOW" -strokewidth 3 -pointsize 104 -annotate +0+330 "$l1" \
    -fill white -stroke white -strokewidth 4 -pointsize 128 -annotate +0+480 "$l2" \
    -fill "$C_YELLOW" -stroke none \
      -draw "roundrectangle $((W/2-70)),700 $((W/2+70)),710 5,5" \
    "$out"
}

outro_card() { # outro_card <윗줄> <아랫줄> <출력>
  local l1="$1" l2="$2" out="$3"
  convert -size ${W}x${H} xc:"$C_BG" "$out.base.png"
  if [ -f "$LOGO" ]; then
    convert "$out.base.png" \( "$LOGO" -resize 460x460 \) \
      -gravity center -geometry +0-220 -composite "$out.base.png"
  fi
  convert "$out.base.png" -font "$FONT" -gravity center \
    -fill "$C_DARK" -stroke "$C_DARK" -strokewidth 3 -pointsize 104 -annotate +0+130 "$l1" \
    -fill "$C_YELLOW" -stroke "$C_YELLOW" -strokewidth 1 \
      -draw "roundrectangle $((W/2-90)),$((H/2+215)) $((W/2+90)),$((H/2+223)) 4,4" \
    -fill "$C_BROWN" -stroke none -pointsize 52 -annotate +0+300 "$l2" \
    "$out"
  rm -f "$out.base.png"
}

# ── 장면 전환 감지 ───────────────────────────────────────────
# 자막을 초 단위로 하드코딩하면 앱의 _hold() 를 조금만 건드려도 어긋난다.
# 영상 자체에서 전환 지점을 뽑아 그 구간마다 자막을 하나씩 배정한다.
scene_cuts() { # scene_cuts <mp4> <dur> → 정렬된 컷 시각 목록
  local mp4="$1" dur="$2"
  ffmpeg -hide_banner -i "$mp4" -filter:v "select='gt(scene,0.22)',showinfo" \
    -f null - 2>&1 | grep -o 'pts_time:[0-9.]*' | cut -d: -f2 | sort -n | \
  awk -v d="$dur" '
    # 시트 슬라이드 한 번이 여러 프레임에서 감지된다 → 1.2초 안쪽은 하나로 묶는다.
    # 시작 직후(딥링크 로딩)와 끝자락은 자막을 나눌 지점이 아니다.
    $1 > 1.0 && $1 < d-1.6 { if ($1 - last >= 1.2) { print $1; last=$1 } }
  '
}

# ── 자막 스크립트 읽기 ───────────────────────────────────────
# 행: <흐름>|<종류>|<앵커>|<윗줄>|<아랫줄>
lines_for() { # lines_for <파일> <flow> <kind> → "앵커|윗줄|아랫줄"
  awk -F'|' -v f="$2" -v k="$3" '
    /^#/ || NF<4 { next }
    $1==f && $2==k { print $3 "|" $4 "|" $5 }
  ' "$1"
}

# 앱이 남긴 비트(라벨 초) 조회. 없으면 빈 값.
beat_at() { # beat_at <beats파일> <라벨>
  [ -s "$1" ] || return 0
  awk -v l="$2" '$1==l {print $2; exit}' "$1"
}

FLOWS="${FLOWS:-discover save share}"
made=0
for flow in $FLOWS; do
  SRC="$SRC_DIR/${flow}_${LANG_TAG}.mp4"
  [ -s "$SRC" ] || { warn "원본 없음, 건너뜀: $SRC"; continue; }

  DUR="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$SRC")"
  DUR="${DUR%.*}"; [ -n "$DUR" ] && [ "$DUR" -gt 0 ] || { warn "길이를 못 읽음: $flow"; continue; }
  log "◆ $flow (${DUR}s)"

  mapfile -t CAPS < <(lines_for "$SCRIPT_FILE" "$flow" cap)
  HOOK="$(lines_for "$SCRIPT_FILE" "$flow" hook | head -1)"
  OUTRO="$(lines_for "$SCRIPT_FILE" "$flow" outro | head -1)"
  [ "${#CAPS[@]}" -gt 0 ] || { warn "자막 없음, 건너뜀: $flow"; continue; }

  # ── 자막 시작 시각 정하기 (정확한 순서대로 시도) ──────────
  # 1) 앱이 남긴 비트: 언제 무엇을 보여주는지 앱이 가장 정확히 안다
  # 2) 장면 전환 감지: 구버전 앱으로 찍은 녹화본용 폴백
  # 3) 균등 분할: 그래도 안 되면 최소한 결과는 나오게
  BEATS="$SRC_DIR/${flow}_beats.txt"
  BOUNDS=(); SRC_OF_TIMING="비트"
  if [ -s "$BEATS" ]; then
    for cap in "${CAPS[@]}"; do
      anchor="${cap%%|*}"
      t="$(beat_at "$BEATS" "$anchor")"
      [ -n "$t" ] || { BOUNDS=(); break; }
      BOUNDS+=("$t")
    done
    [ "${#BOUNDS[@]}" -eq "${#CAPS[@]}" ] || {
      warn "  비트에 없는 앵커가 있어 폴백"; BOUNDS=(); }
  fi
  if [ "${#BOUNDS[@]}" -eq 0 ]; then
    mapfile -t CUTS < <(scene_cuts "$SRC" "$DUR")
    if [ "${#CUTS[@]}" -ge "$(( ${#CAPS[@]} - 1 ))" ] && [ "${#CUTS[@]}" -gt 0 ]; then
      SRC_OF_TIMING="장면 전환"
      BOUNDS=(0)
      for i in $(seq 0 $(( ${#CAPS[@]} - 2 ))); do BOUNDS+=("${CUTS[$i]}"); done
    else
      SRC_OF_TIMING="균등 분할"
      BOUNDS=()
      for i in $(seq 0 $(( ${#CAPS[@]} - 1 ))); do
        BOUNDS+=("$(awk -v d="$DUR" -v i="$i" -v n="${#CAPS[@]}" 'BEGIN{printf "%.2f", d*i/n}')")
      done
    fi
  fi
  BOUNDS+=("$DUR")
  log "  자막 타이밍($SRC_OF_TIMING): ${BOUNDS[*]}"

  # ── 오버레이 입력 굽기 ─────────────────────────────────────
  INPUTS=(-i "$SRC")
  FC=""; CUR="[0:v]"
  idx=1

  # 훅
  if [ -n "$HOOK" ]; then
    h="${HOOK#*|}"; hook_card "${h%%|*}" "${h#*|}" "$WORK/${flow}_hook.png"
    INPUTS+=(-loop 1 -t "$DUR" -i "$WORK/${flow}_hook.png")
    FC+="[${idx}:v]format=rgba,fade=t=out:st=$(awk -v d="$HOOK_D" 'BEGIN{printf "%.2f", d-0.4}'):d=0.4:alpha=1[hk];"
    FC+="${CUR}[hk]overlay=0:0:enable='lt(t,$HOOK_D)'[v${idx}];"
    CUR="[v${idx}]"; idx=$((idx+1))
  fi

  # 본문 자막 — 훅이 끝난 뒤부터
  n=0
  for cap in "${CAPS[@]}"; do
    rest="${cap#*|}"          # 앵커 제거
    l1="${rest%%|*}"; l2="${rest#*|}"
    st="${BOUNDS[$n]}"; en="${BOUNDS[$((n+1))]}"
    # 훅과 겹치지 않게 밀어준다.
    st="$(awk -v s="$st" -v h="$HOOK_D" 'BEGIN{printf "%.2f", (s<h?h:s)+0.1}')"
    en="$(awk -v e="$en" 'BEGIN{printf "%.2f", e-0.15}')"
    awk -v s="$st" -v e="$en" 'BEGIN{exit !(e-s > 0.7)}' || { n=$((n+1)); continue; }
    cap_card "$l1" "$l2" "$WORK/${flow}_c${n}.png"
    INPUTS+=(-loop 1 -t "$DUR" -i "$WORK/${flow}_c${n}.png")
    FC+="[${idx}:v]format=rgba,fade=t=in:st=${st}:d=$CAP_FADE:alpha=1,fade=t=out:st=$(awk -v e="$en" -v f="$CAP_FADE" 'BEGIN{printf "%.2f", e-f}'):d=$CAP_FADE:alpha=1[c${n}];"
    FC+="${CUR}[c${n}]overlay=(W-w)/2:$CAP_Y:enable='between(t,${st},${en})'[v${idx}];"
    CUR="[v${idx}]"; idx=$((idx+1))
    n=$((n+1))
  done

  FC+="${CUR}fps=$FPS,scale=$W:$H,setsar=1,format=yuv420p[body]"

  ffmpeg -y -loglevel error "${INPUTS[@]}" -filter_complex "$FC" -map "[body]" \
    -c:v libx264 -preset medium -profile:v high -crf 20 \
    -threads "${X264_THREADS:-4}" -an "$WORK/${flow}_body.mp4"

  # ── 아웃트로 붙이기 ────────────────────────────────────────
  if [ -n "$OUTRO" ]; then
    o="${OUTRO#*|}"; outro_card "${o%%|*}" "${o#*|}" "$WORK/${flow}_outro.png"
    ffmpeg -y -loglevel error -loop 1 -t "$OUTRO_D" -i "$WORK/${flow}_outro.png" \
      -vf "fps=$FPS,scale=$W:$H,setsar=1,format=yuv420p,fade=t=in:st=0:d=0.35" \
      -c:v libx264 -preset medium -profile:v high -crf 20 \
      -threads "${X264_THREADS:-4}" -an "$WORK/${flow}_outro.mp4"
    printf "file '%s'\nfile '%s'\n" "${flow}_body.mp4" "${flow}_outro.mp4" > "$WORK/${flow}.txt"
    ( cd "$WORK" && ffmpeg -y -loglevel error -f concat -safe 0 -i "${flow}.txt" \
        -c:v libx264 -preset medium -profile:v high -crf 20 \
        -threads "${X264_THREADS:-4}" -an "$OUT_DIR/${flow}_${LANG_TAG}.mp4" )
  else
    cp "$WORK/${flow}_body.mp4" "$OUT_DIR/${flow}_${LANG_TAG}.mp4"
  fi

  FD="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT_DIR/${flow}_${LANG_TAG}.mp4" 2>/dev/null)"
  log "  ↳ final/${flow}_${LANG_TAG}.mp4 (${FD%.*}s)"
  made=$((made+1))
done

log "완료. 최종 ${made}편 → $OUT_DIR"
