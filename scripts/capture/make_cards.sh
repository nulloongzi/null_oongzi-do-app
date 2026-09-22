#!/usr/bin/env bash
# scripts/capture/make_cards.sh — 인스타 카드뉴스(9:16) 굽기 · 코치마크/스포트라이트 스타일.
#
# 릴스 슬롯에 올리는 다중 이미지 포스트용. 규격은 영상과 같은 1080x1920.
# 목업 프레임·크림 여백 없이 실제 화면을 풀블리드로 깔고, 딤 위에 누를 버튼만
# 원래 밝기로 남긴다(coach mark). 캡션은 노랑 솔리드 박스 + 검은 글씨.
#
# 화면은 지어내지 않는다 — 흐름 녹화본(reels/flows/*.mp4)에서 CAPTURE_BEAT
# 시각의 프레임을 그대로 뽑는다(자막 없는 판이라 카드 문구와 안 겹친다).
#
# 사용법:
#   scripts/capture/make_cards.sh                  # 전체
#   SETS='reels' scripts/capture/make_cards.sh     # 한 세트만
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
ART="${ARTIFACTS_DIR:-$ROOT/marketing-assets}"
LANG_TAG="${CAP_LANG:-ko}"
SRC_DIR="$ART/reels/flows"
OUT_ROOT="$ART/cards"
CARDS_FILE="${CARDS_SCRIPT:-$HERE/cards.$LANG_TAG.txt}"
FONT="$ROOT/assets/fonts/PretendardVariable.ttf"
LOGO="$ROOT/assets/nulloongzido logo_without bg.png"

W=1080; H=1920
# 브랜드 팔레트 — lib/theme.dart 와 동일. 강조 노랑만 더 쨍하게(#FFE600, 레퍼런스).
C_YELLOW='#FAC710'; C_DARK='#4E342E'; C_BROWN='#8D6E63'; C_BG='#FFF8E1'; C_HL='#FFE600'
# 딤은 반투명 검정 오버레이로 준다. -evaluate multiply 는 IM 버전(HDRI 등)에 따라
# 안 먹는 경우가 있어(실측: 사용자 IM7 에서 무효) 버전 안 타는 compose 로 고정.
DIM_SPOT="${DIM_SPOT:-0.66}"   # 스포트라이트 밖 딤 세기(0=원본, 1=완전 검정)
DIM_BASE="${DIM_BASE:-0.20}"   # 스포트라이트 안 / 버튼없는 카드(살짝만)
SETTLE="${SETTLE:-1.0}"        # 전환 애니메이션이 가라앉을 시간

log()  { printf '\033[1;33m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[0;35m! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg 가 없습니다."
IM=convert; IDENT=identify
command -v magick >/dev/null 2>&1 && { IM="magick"; IDENT="magick identify"; }
command -v "$IM" >/dev/null 2>&1 || die "ImageMagick 이 없습니다."
[ -f "$FONT" ] || die "폰트가 없습니다: $FONT"
[ -f "$CARDS_FILE" ] || die "카드 스크립트가 없습니다: $CARDS_FILE"
[ -d "$SRC_DIR" ] || die "녹화본이 없습니다: $SRC_DIR (먼저 local_capture.sh)"

FRAME="$SRC_DIR/frame.txt"
if [ -s "$FRAME" ]; then read -r FX0 FY0 FW FH _ _ < "$FRAME"
else warn "frame.txt 없음 — 화면이 프레임을 꽉 채운다고 본다."; FX0=0; FY0=0; FW=$W; FH=$H; fi

lines_for() { # lines_for <세트> → "종류|출처|ko1|ko2|en|스팟|포커스"
  awk -F'|' -v s="$1" '
    /^[[:space:]]*#/ || NF<2 { next }
    { g=$1; gsub(/[ \t]/,"",g); if (g!=s) next
      print $2"|"$3"|"$4"|"$5"|"$6"|"$7"|"$8 }
  ' "$CARDS_FILE"
}
beat_at() { [ -s "$1" ] || return 0; awk -v l="$2" '$1==l {print $2; exit}' "$1"; }

# 흐름 녹화본에서 비트 시각의 폰 화면을 풀블리드 1080x1920 으로.
# 화면(9:20.5)을 폭 1080 으로 키우고 세로는 포커스 지점 중심으로 크롭한다.
grab() { # grab <flow@beat[+delay]> <focus 0-1> <출력>
  local ref="$1" focus="${2:-0.5}" out="$3" extra=0 t
  case "$ref" in *+*) extra="${ref##*+}"; ref="${ref%%+*}" ;; esac
  local flow="${ref%%@*}" label="${ref#*@}"
  local mp4="$SRC_DIR/${flow}_${LANG_TAG}.mp4"
  [ -s "$mp4" ] || { warn "녹화본 없음: $mp4"; return 1; }
  t="$(beat_at "$SRC_DIR/${flow}_beats.txt" "$label")"
  [ -n "$t" ] || { warn "비트 없음: $flow/$label"; return 1; }
  t="$(awk -v a="$t" -v b="$SETTLE" -v c="$extra" 'BEGIN{printf "%.2f", a+b+c}')"
  ffmpeg -y -v error -ss "$t" -i "$mp4" -frames:v 1 \
    -vf "crop=${FW}:${FH}:${FX0}:${FY0}" "$out.scr.png" || return 1
  local sh oy
  sh="$(awk -v w="$FW" -v h="$FH" 'BEGIN{printf "%d", h*1080/w}')"   # 폭1080 스케일 후 높이
  oy="$(awk -v f="$focus" -v sh="$sh" 'BEGIN{o=int(f*sh-960); if(o<0)o=0; m=sh-1920; if(o>m)o=m; if(o<0)o=0; print o}')"
  "$IM" "$out.scr.png" -resize 1080x -gravity north -crop 1080x1920+0+${oy} +repage "$out"
  rm -f "$out.scr.png"
  printf '%s' "$sh:$oy"   # step_card 가 스팟 좌표를 매핑하는 데 쓴다
}

# ── 스텝 카드(코치마크) ──────────────────────────────────────
step_card() { # step_card <n> <flow@beat> <ko1> <ko2> <en> <spot x,y,r|-> <focus> <출력>
  local n="$1" src="$2" l1="$3" l2="$4" en="$5" spot="$6" focus="${7:-0.5}" out="$8"
  local meta sh oy
  meta="$(grab "$src" "$focus" "$out.full.png")" || { warn "화면 없음, 스킵: $src"; return 1; }
  sh="${meta%%:*}"; oy="${meta##*:}"

  # 딤 두 겹: base(살짝) / dark(많이). 반투명 검정 오버레이 — 버전 안 탄다.
  "$IM" "$out.full.png" \
    \( -size ${W}x${H} xc:"rgba(16,11,9,$DIM_BASE)" \) -compose over -composite "$out.base.png"
  if [ "$spot" != "-" ] && [ -n "$spot" ]; then
    local sx sy sr rest
    sx="$(awk -v x="${spot%%,*}" 'BEGIN{printf "%d", x*1080}')"
    rest="${spot#*,}"
    sy="$(awk -v y="${rest%%,*}" -v sh="$sh" -v oy="$oy" 'BEGIN{printf "%d", y*sh-oy}')"
    sr="${rest##*,}"
    # dark = 화면 전체를 많이 어둡게.
    "$IM" "$out.full.png" \
      \( -size ${W}x${H} xc:"rgba(16,11,9,$DIM_SPOT)" \) -compose over -composite "$out.dark.png"
    # 스포트라이트 마스크(흰 타원=밝게 남길 곳) → base 를 그 모양으로 오려 dark 위에.
    "$IM" -size ${W}x${H} xc:black -fill white \
      -draw "ellipse $sx,$sy $sr,$sr 0,360" -blur 0x55 "$out.mask.png"
    "$IM" "$out.base.png" "$out.mask.png" -alpha off -compose CopyOpacity -composite "$out.patch.png"
    "$IM" "$out.dark.png" "$out.patch.png" -compose over -composite "$out.bg.png"
    # 대상 강조: 옅은 흰 링.
    "$IM" "$out.bg.png" -fill none -stroke white -strokewidth 5 \
      -draw "ellipse $sx,$sy $((sr-6)),$((sr-6)) 0,360" "$out.bg2.png"
    mv -f "$out.bg2.png" "$out.bg.png"
    rm -f "$out.dark.png" "$out.mask.png" "$out.patch.png"
  else
    mv -f "$out.base.png" "$out.bg.png"
  fi
  rm -f "$out.full.png" "$out.base.png" 2>/dev/null || true

  # 캡션: 노랑 솔리드 박스 + 검은 800(스트로크로 굵기) + 살짝 -1.5° 회전.
  local BW=920 BH
  if [ -n "$l2" ]; then
    BH=310
    "$IM" -size ${BW}x${BH} xc:"$C_HL" -font "$FONT" -gravity north -fill black \
      -stroke black -strokewidth 2 -pointsize 92 \
      -annotate +0+34 "$l1" -annotate +0+164 "$l2" "$out.cap.png"
  else
    BH=190
    "$IM" -size ${BW}x${BH} xc:"$C_HL" -font "$FONT" -gravity north -fill black \
      -stroke black -strokewidth 2 -pointsize 92 \
      -annotate +0+44 "$l1" "$out.cap.png"
  fi
  "$IM" "$out.cap.png" -background none -rotate -1.5 "$out.capr.png"
  "$IM" "$out.bg.png" "$out.capr.png" -gravity north -geometry +0+300 -composite "$out.c1.png"
  # 영문: 박스 아래 작은 흰 글씨(스크린샷 위라 검정 스트로크로 가독).
  local eny=$(( 300 + BH + 34 ))
  "$IM" "$out.c1.png" -font "$FONT" -gravity north \
    -fill white -stroke black -strokewidth 3 -pointsize 38 -annotate +0+${eny} "$en" "$out.c2.png"
  # 큰 순번(좌상단) — 카드뉴스 관습, 이어보기 유도. 밝은 화면에 묻히지 않게
  # 좌상단 모서리에 옅은 어둠을 먼저 깐다.
  "$IM" "$out.c2.png" \
    \( -size 460x320 radial-gradient:"rgba(0,0,0,0.55)"-none \) \
    -gravity northwest -geometry -110-110 -compose over -composite "$out.c3.png"
  "$IM" "$out.c3.png" -font "$FONT" -gravity northwest \
    -fill white -stroke "$C_DARK" -strokewidth 3 -pointsize 150 -annotate +64+64 "$n" "$out"
  rm -f "$out.bg.png" "$out.cap.png" "$out.capr.png" "$out.c1.png" "$out.c2.png" "$out.c3.png"
}

# ── 표지 / 마무리(브랜드 크림) ───────────────────────────────
cover_card() { local l1="$1" l2="$2" en="$3" out="$4"
  "$IM" -size ${W}x${H} xc:"$C_BG" "$out.b.png"
  [ -f "$LOGO" ] && "$IM" "$out.b.png" \( "$LOGO" -resize 300x300 \) \
    -gravity north -geometry +0+250 -composite "$out.b.png"
  "$IM" "$out.b.png" -font "$FONT" -gravity north \
    -fill "$C_BROWN" -stroke "$C_BROWN" -strokewidth 2 -pointsize 76 -annotate +0+660 "$l1" \
    -fill "$C_DARK"  -stroke "$C_DARK"  -strokewidth 4 -pointsize 110 -annotate +0+790 "$l2" \
    -fill "$C_YELLOW" -stroke none -draw "roundrectangle $((W/2-90)),960 $((W/2+90)),970 5,5" \
    -fill "$C_BROWN" -stroke none -pointsize 42 -annotate +0+1010 "$en" \
    -fill "$C_BROWN" -stroke none -pointsize 40 -annotate +0+1700 "넘겨보세요  ›" "$out"
  rm -f "$out.b.png"
}
end_card() { local l1="$1" l2="$2" en="$3" out="$4"
  "$IM" -size ${W}x${H} xc:"$C_BG" "$out.b.png"
  [ -f "$LOGO" ] && "$IM" "$out.b.png" \( "$LOGO" -resize 460x460 \) \
    -gravity center -geometry +0-220 -composite "$out.b.png"
  "$IM" "$out.b.png" -font "$FONT" -gravity center \
    -fill "$C_DARK" -stroke "$C_DARK" -strokewidth 3 -pointsize 104 -annotate +0+130 "$l1" \
    -fill "$C_YELLOW" -stroke none \
      -draw "roundrectangle $((W/2-90)),$((H/2+215)) $((W/2+90)),$((H/2+223)) 4,4" \
    -fill "$C_BROWN" -stroke none -pointsize 52 -annotate +0+300 "$l2" \
    -fill "$C_BROWN" -stroke none -pointsize 34 -annotate +0+375 "$en" "$out"
  rm -f "$out.b.png"
}

SETS="${SETS:-$(awk -F'|' '!/^[[:space:]]*#/ && NF>=2 {g=$1; gsub(/[ \t]/,"",g); if(!(g in s)){s[g]=1; printf "%s ", g}}' "$CARDS_FILE")}"
made=0
for set in $SETS; do
  OUT="$OUT_ROOT/$set"; rm -rf "$OUT"; mkdir -p "$OUT"
  n=0; step=0
  while IFS='|' read -r kind src l1 l2 en spot focus; do
    n=$((n+1)); printf -v idx '%02d' "$n"; out="$OUT/$idx.png"
    case "$kind" in
      cover) cover_card "$l1" "$l2" "$en" "$out" ;;
      end)   end_card   "$l1" "$l2" "$en" "$out" ;;
      step)  step=$((step+1)); printf -v sn '%02d' "$step"
             step_card "$sn" "$src" "$l1" "$l2" "$en" "${spot:--}" "${focus:-0.5}" "$out" \
               || { n=$((n-1)); step=$((step-1)); } ;;
      *) warn "모르는 종류: $kind"; n=$((n-1)); continue ;;
    esac
  done < <(lines_for "$set")
  [ "$n" -gt 0 ] && { log "◆ $set — ${n}장 → cards/$set/"; made=$((made+1)); } || warn "카드 없음: $set"
done
log "완료. ${made}세트 → $OUT_ROOT"
