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

cap_card() { # cap_card <한글윗줄> <한글아랫줄> <영문> <출력>
  local l1="$1" l2="$2" en="$3" out="$4"
  local cw=936 pad=38 hs=44 hb=62 he=32 th y
  if [ -n "$l2" ]; then th=$(( pad*2 + hs + 14 + hb )); else th=$(( pad*2 + hb )); fi
  [ -n "$en" ] && th=$(( th + 16 + he ))
  convert -size ${cw}x${th} xc:none \
    -fill "$C_BG" -draw "roundrectangle 0,0 $((cw-1)),$((th-1)) 28,28" "$out.bg.png"
  local a=(-font "$FONT" -gravity north)
  y=$pad
  if [ -n "$l2" ]; then
    a+=(-fill "$C_BROWN" -stroke "$C_BROWN" -strokewidth 1 -pointsize $hs -annotate +0+$y "$l1")
    y=$(( y + hs + 14 ))
    a+=(-fill "$C_DARK" -stroke "$C_DARK" -strokewidth 2 -pointsize $hb -annotate +0+$y "$l2")
    y=$(( y + hb + 16 ))
  else
    a+=(-fill "$C_DARK" -stroke "$C_DARK" -strokewidth 2 -pointsize $hb -annotate +0+$y "$l1")
    y=$(( y + hb + 16 ))
  fi
  # 영문은 한글 아래 작은 글씨 — 읽는 사람을 늘리되 한글의 위계를 깨지 않는다.
  [ -n "$en" ] && a+=(-fill "$C_BROWN" -stroke none -pointsize $he -annotate +0+$y "$en")
  convert "$out.bg.png" "${a[@]}" "$out"
  rm -f "$out.bg.png"
}

hook_card() { # hook_card <한글윗줄> <한글아랫줄> <영문> <출력>
  local l1="$1" l2="$2" en="$3" out="$4"
  # 첫 1초가 전부다 — 작게 넣으면 그냥 넘어간다. 화면 폭을 꽉 쓰고,
  # 옅은 지도 위에서도 읽히도록 스크림을 진하게 깐다.
  # 스크림: 위 660px 은 단색, 그 아래 480px 만 페이드. 순수 그라데이션으로 하면
  # 글자가 놓이는 y=330~600 구간에서 이미 반투명해져 지도와 섞인다(검증됨).
  convert -size ${W}x${H} xc:none \
    \( -size ${W}x660 xc:"rgba(62,40,35,0.82)" \) -geometry +0+0 -composite \
    \( -size ${W}x480 gradient:"rgba(62,40,35,0.82)"-none \) -geometry +0+660 -composite \
    -font "$FONT" -gravity north \
    -fill "$C_YELLOW" -stroke "$C_YELLOW" -strokewidth 3 -pointsize 104 -annotate +0+300 "$l1" \
    -fill white -stroke white -strokewidth 4 -pointsize 128 -annotate +0+450 "$l2" \
    -fill "$C_YELLOW" -stroke none \
      -draw "roundrectangle $((W/2-70)),620 $((W/2+70)),630 5,5" \
    -fill "#F2E6E0" -stroke none -pointsize 44 -annotate +0+672 "$en" \
    "$out"
}

outro_card() { # outro_card <한글윗줄> <한글아랫줄> <영문> <출력>
  local l1="$1" l2="$2" en="$3" out="$4"
  convert -size ${W}x${H} xc:"$C_BG" "$out.base.png"
  if [ -f "$LOGO" ]; then
    convert "$out.base.png" \( "$LOGO" -resize 460x460 \) \
      -gravity center -geometry +0-220 -composite "$out.base.png"
  fi
  convert "$out.base.png" -font "$FONT" -gravity center \
    -fill "$C_DARK" -stroke "$C_DARK" -strokewidth 3 -pointsize 104 -annotate +0+130 "$l1" \
    -fill "$C_YELLOW" -stroke none \
      -draw "roundrectangle $((W/2-90)),$((H/2+215)) $((W/2+90)),$((H/2+223)) 4,4" \
    -fill "$C_BROWN" -stroke none -pointsize 52 -annotate +0+300 "$l2" \
    -fill "$C_BROWN" -stroke none -pointsize 34 -annotate +0+375 "$en" \
    "$out"
  rm -f "$out.base.png"
}

# ── 나레이션(한국어 TTS) ─────────────────────────────────────
# 영문은 자막 전용이고 음성은 한국어만 읽는다. 엔진이 없으면 무음으로 진행한다.
TTS="${TTS:-auto}"   # auto | off
narrate() { # narrate <출력.mp3> <읽을 텍스트> → 성공 시 0
  [ "$TTS" = "off" ] && return 1
  [ -n "$2" ] || return 1
  bash "$HERE/tts.sh" "$1" "$2" >/dev/null 2>&1
}

# 음성이 자막 구간보다 길면 **다음 줄 음성과 겹쳐 두 목소리가 동시에 난다.**
# 문구를 일일이 맞추는 대신 살짝 빠르게 재생해 구간에 맞춘다(atempo).
# 1.22배까지만 — 한국어 TTS 는 그 이상 빨라지면 급하게 들린다. 그래도 넘치면
# 문구를 줄이거나 앱의 _hold 를 늘리라고 알린다(진짜 원인은 화면이 짧은 것이다).
NAR_GAP=0.15   # 다음 나레이션과의 최소 간격
fit_narration() { # fit_narration <mp3> <시작> <끝> <라벨>
  local f="$1" st="$2" en="$3" label="$4" d win r
  d="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f" 2>/dev/null)"
  [ -n "$d" ] || return 0
  win="$(awk -v s="$st" -v e="$en" -v g="$NAR_GAP" 'BEGIN{printf "%.3f", e-s-g}')"
  awk -v w="$win" 'BEGIN{exit !(w > 0.5)}' || return 0
  r="$(awk -v d="$d" -v w="$win" 'BEGIN{printf "%.4f", (d>w ? d/w : 1)}')"
  awk -v r="$r" 'BEGIN{exit !(r > 1.01)}' || return 0
  local capped
  capped="$(awk -v r="$r" 'BEGIN{printf "%.4f", (r>1.22 ? 1.22 : r)}')"
  if ffmpeg -y -loglevel error -i "$f" -filter:a "atempo=$capped" \
      -c:a libmp3lame -q:a 4 "$f.fit.mp3" 2>/dev/null && [ -s "$f.fit.mp3" ]; then
    mv -f "$f.fit.mp3" "$f"
    awk -v r="$r" -v c="$capped" -v l="$label" -v d="$d" -v w="$win" 'BEGIN{
      if (r > 1.225)
        printf "  ! \"%s\" 음성이 너무 깁니다(%.1fs > %.1fs). %.2f배로 줄였지만 여전히 넘칩니다 — 문구를 줄이세요.\n", l, d, w, c
      else
        printf "  · \"%s\" 음성 %.2f배로 구간에 맞춤(%.1fs → %.1fs)\n", l, c, d, w
    }'
  fi
  rm -f "$f.fit.mp3"
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
lines_for() { # lines_for <파일> <flow> <kind> → "앵커|한글윗줄|한글아랫줄|영문"
  awk -F'|' -v f="$2" -v k="$3" '
    /^#/ || NF<6 { next }
    $1==f && $2==k { print $3 "|" $4 "|" $5 "|" $6 }
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
  NAR_T=(); NAR_F=()   # 나레이션 (시작초, 파일)

  # 훅
  if [ -n "$HOOK" ]; then
    h="${HOOK#*|}"; hk1="${h%%|*}"; h2="${h#*|}"; hk2="${h2%%|*}"; hken="${h2#*|}"
    hook_card "$hk1" "$hk2" "$hken" "$WORK/${flow}_hook.png"
    INPUTS+=(-loop 1 -t "$DUR" -i "$WORK/${flow}_hook.png")
    FC+="[${idx}:v]format=rgba,fade=t=out:st=$(awk -v d="$HOOK_D" 'BEGIN{printf "%.2f", d-0.4}'):d=0.4:alpha=1[hk];"
    FC+="${CUR}[hk]overlay=0:0:enable='lt(t,$HOOK_D)'[v${idx}];"
    CUR="[v${idx}]"; idx=$((idx+1))
    if narrate "$WORK/${flow}_n_hook.mp3" "$hk1 $hk2"; then
      # 훅 음성도 첫 자막 음성과 겹치면 두 목소리가 동시에 난다(실측으로 확인).
      # 첫 자막이 시작하는 시각까지가 훅의 구간이다.
      hk_end="$(awk -v b="${BOUNDS[0]}" -v h="$HOOK_D" 'BEGIN{printf "%.2f", (b<h?h:b)+0.1}')"
      fit_narration "$WORK/${flow}_n_hook.mp3" 0.30 "$hk_end" "$hk1"
      NAR_T+=(0.30); NAR_F+=("$WORK/${flow}_n_hook.mp3")
    fi
  fi

  # 본문 자막 — 훅이 끝난 뒤부터
  n=0
  for cap in "${CAPS[@]}"; do
    rest="${cap#*|}"                 # 앵커 제거
    l1="${rest%%|*}"; r2="${rest#*|}"
    l2="${r2%%|*}";  cen="${r2#*|}"
    st="${BOUNDS[$n]}"; en="${BOUNDS[$((n+1))]}"
    # 훅과 겹치지 않게 밀어준다.
    st="$(awk -v s="$st" -v h="$HOOK_D" 'BEGIN{printf "%.2f", (s<h?h:s)+0.1}')"
    en="$(awk -v e="$en" 'BEGIN{printf "%.2f", e-0.15}')"
    awk -v s="$st" -v e="$en" 'BEGIN{exit !(e-s > 0.7)}' || { n=$((n+1)); continue; }
    cap_card "$l1" "$l2" "$cen" "$WORK/${flow}_c${n}.png"
    INPUTS+=(-loop 1 -t "$DUR" -i "$WORK/${flow}_c${n}.png")
    FC+="[${idx}:v]format=rgba,fade=t=in:st=${st}:d=$CAP_FADE:alpha=1,fade=t=out:st=$(awk -v e="$en" -v f="$CAP_FADE" 'BEGIN{printf "%.2f", e-f}'):d=$CAP_FADE:alpha=1[c${n}];"
    FC+="${CUR}[c${n}]overlay=(W-w)/2:$CAP_Y:enable='between(t,${st},${en})'[v${idx}];"
    CUR="[v${idx}]"; idx=$((idx+1))
    # 음성은 한국어 두 줄만 읽는다(영문은 자막 전용). 자막이 뜨는 순간에 맞춘다.
    if narrate "$WORK/${flow}_n${n}.mp3" "$l1 $l2"; then
      fit_narration "$WORK/${flow}_n${n}.mp3" "$st" "$en" "$l1"
      NAR_T+=("$st"); NAR_F+=("$WORK/${flow}_n${n}.mp3")
    fi
    n=$((n+1))
  done

  FC+="${CUR}fps=$FPS,scale=$W:$H,setsar=1,format=yuv420p[body]"

  ffmpeg -y -loglevel error "${INPUTS[@]}" -filter_complex "$FC" -map "[body]" \
    -c:v libx264 -preset medium -profile:v high -crf 20 \
    -threads "${X264_THREADS:-4}" -an "$WORK/${flow}_body.mp4"

  # ── 나레이션 믹스 ──────────────────────────────────────────
  # 각 음성을 자막이 뜨는 시각으로 지연(adelay)시켜 하나의 트랙으로 합친다.
  # normalize=0 이 아니면 amix 가 입력 수만큼 볼륨을 나눠 소리가 작아진다.
  HAS_AUDIO=0
  if [ "${#NAR_T[@]}" -gt 0 ]; then
    AIN=(); AFC=""; MIXIN=""
    for i in "${!NAR_T[@]}"; do
      AIN+=(-i "${NAR_F[$i]}")
      ms="$(awk -v t="${NAR_T[$i]}" 'BEGIN{printf "%d", t*1000}')"
      AFC+="[$((i+1)):a]adelay=${ms}|${ms}[n$i];"
      MIXIN+="[n$i]"
    done
    AFC+="${MIXIN}amix=inputs=${#NAR_T[@]}:normalize=0:dropout_transition=0,aformat=sample_rates=44100:channel_layouts=stereo,apad[aout]"
    if ffmpeg -y -loglevel error -i "$WORK/${flow}_body.mp4" "${AIN[@]}" \
        -filter_complex "$AFC" -map 0:v -map "[aout]" \
        -c:v copy -c:a aac -b:a 128k -shortest "$WORK/${flow}_body_a.mp4" 2>/dev/null; then
      mv -f "$WORK/${flow}_body_a.mp4" "$WORK/${flow}_body.mp4"
      HAS_AUDIO=1
      log "  나레이션 ${#NAR_T[@]}줄 삽입"
    else
      warn "  나레이션 믹스 실패 — 무음으로 진행"
    fi
  else
    [ "$TTS" = "off" ] || warn "  TTS 엔진 없음 — 무음(pip install edge-tts 로 활성화)"
  fi

  # ── 아웃트로 붙이기 ────────────────────────────────────────
  if [ -n "$OUTRO" ]; then
    o="${OUTRO#*|}"; o1="${o%%|*}"; o2r="${o#*|}"; o2="${o2r%%|*}"; oen="${o2r#*|}"
    outro_card "$o1" "$o2" "$oen" "$WORK/${flow}_outro.png"
    ffmpeg -y -loglevel error -loop 1 -t "$OUTRO_D" -i "$WORK/${flow}_outro.png" \
      -vf "fps=$FPS,scale=$W:$H,setsar=1,format=yuv420p,fade=t=in:st=0:d=0.35" \
      -c:v libx264 -preset medium -profile:v high -crf 20 \
      -threads "${X264_THREADS:-4}" -an "$WORK/${flow}_outro.mp4"
    # concat 은 두 파일의 스트림 구성이 같아야 한다 — 본문에 소리가 있으면
    # 아웃트로에도 오디오 트랙을 붙인다(나레이션이 없으면 무음 트랙).
    if [ "$HAS_AUDIO" = 1 ]; then
      if narrate "$WORK/${flow}_n_outro.mp3" "$o1 $o2"; then
        ffmpeg -y -loglevel error -i "$WORK/${flow}_outro.mp4" -i "$WORK/${flow}_n_outro.mp3" \
          -filter_complex "[1:a]adelay=250|250,aformat=sample_rates=44100:channel_layouts=stereo,apad[aout]" -map 0:v -map "[aout]" \
          -c:v copy -c:a aac -b:a 128k -shortest "$WORK/${flow}_outro_a.mp4" 2>/dev/null \
          && mv -f "$WORK/${flow}_outro_a.mp4" "$WORK/${flow}_outro.mp4"
      else
        ffmpeg -y -loglevel error -i "$WORK/${flow}_outro.mp4" \
          -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
          -map 0:v -map 1:a -c:v copy -c:a aac -b:a 128k -shortest \
          "$WORK/${flow}_outro_a.mp4" 2>/dev/null \
          && mv -f "$WORK/${flow}_outro_a.mp4" "$WORK/${flow}_outro.mp4"
      fi
    fi
    printf "file '%s'\nfile '%s'\n" "${flow}_body.mp4" "${flow}_outro.mp4" > "$WORK/${flow}.txt"
    ACODEC=(-an); [ "$HAS_AUDIO" = 1 ] && ACODEC=(-c:a aac -b:a 128k)
    ( cd "$WORK" && ffmpeg -y -loglevel error -f concat -safe 0 -i "${flow}.txt" \
        -c:v libx264 -preset medium -profile:v high -crf 20 \
        -threads "${X264_THREADS:-4}" "${ACODEC[@]}" "$OUT_DIR/${flow}_${LANG_TAG}.mp4" )
  else
    cp "$WORK/${flow}_body.mp4" "$OUT_DIR/${flow}_${LANG_TAG}.mp4"
  fi

  FD="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT_DIR/${flow}_${LANG_TAG}.mp4" 2>/dev/null)"
  log "  ↳ final/${flow}_${LANG_TAG}.mp4 (${FD%.*}s)"
  made=$((made+1))
done

log "완료. 최종 ${made}편 → $OUT_DIR"
