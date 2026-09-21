#!/usr/bin/env bash
# scripts/capture/make_cards.sh — 인스타 카드뉴스(9:16) 굽기.
#
# 릴스 슬롯에 올리는 다중 이미지 포스트용. 규격은 영상과 같은 1080x1920 이라
# 같은 계정에서 영상과 카드가 한 몸으로 보인다.
#
# 화면은 지어내지 않는다 — 흐름 녹화본(reels/flows/*.mp4)에서 비트 시각의
# 프레임을 그대로 뽑아 쓴다. 자막이 없는 판이라 카드 문구와 겹치지 않는다.
#
# 사용법:
#   scripts/capture/make_cards.sh                 # 전체
#   SETS='discover' scripts/capture/make_cards.sh # 한 세트만
#
# 산출: marketing-assets/cards/<세트>/01.png … (넘기는 순서대로)
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
# 브랜드 팔레트 — lib/theme.dart 와 동일해야 앱·영상·카드가 한 몸으로 보인다.
C_YELLOW='#FAC710'; C_DARK='#4E342E'; C_BROWN='#8D6E63'; C_BG='#FFF8E1'

# 비트 시각 그대로 뽑으면 전환 애니메이션 중간이 잡힌다(시트가 반쯤 올라온 프레임).
# 화면이 가라앉을 때까지 기다렸다 뽑는다.
SETTLE="${SETTLE:-1.0}"

log()  { printf '\033[1;33m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[0;35m! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg 가 없습니다."
IM=convert; command -v magick >/dev/null 2>&1 && IM="magick"
command -v "$IM" >/dev/null 2>&1 || die "ImageMagick 이 없습니다."
[ -f "$FONT" ] || die "폰트가 없습니다: $FONT"
[ -f "$CARDS_FILE" ] || die "카드 스크립트가 없습니다: $CARDS_FILE"
[ -d "$SRC_DIR" ] || die "녹화본이 없습니다: $SRC_DIR (먼저 local_capture.sh)"

# 폰 화면이 프레임 어디에 놓이는지 — 정규화 단계가 남긴다.
FRAME="$SRC_DIR/frame.txt"
if [ -s "$FRAME" ]; then
  read -r FX0 FY0 FW FH _ _ < "$FRAME"
else
  warn "frame.txt 가 없어 화면이 프레임을 꽉 채운다고 본다."
  FX0=0; FY0=0; FW=$W; FH=$H
fi

lines_for() { # lines_for <세트> → "종류|출처|ko1|ko2|en" (주석·빈 줄 제거)
  awk -F'|' -v s="$1" '
    /^[[:space:]]*#/ || NF<2 { next }
    { g=$1; gsub(/[ \t]/,"",g); if (g!=s) next; print $2 "|" $3 "|" $4 "|" $5 "|" $6 }
  ' "$CARDS_FILE"
}

beat_at() { # beat_at <비트파일> <라벨>
  [ -s "$1" ] || return 0
  awk -v l="$2" '$1==l {print $2; exit}' "$1"
}

# 흐름 녹화본에서 비트 시각의 폰 화면을 오려낸다(좌우 크림 여백 제거).
# 구간(:0.45-1.0)을 주면 화면 세로에서 그 띠만 잘라 크게 키운다 — 카드뉴스는
# 폰에서 읽히는 게 전부라, 시트가 주인공인 화면을 폰 통째로 넣으면 글씨가
# 손톱만 해진다.
grab() { # grab <흐름@비트[:위-아래]> <출력>
  local ref="$1" out="$2" band="" t y0 bh
  case "$ref" in *:*) band="${ref##*:}"; ref="${ref%%:*}" ;; esac
  local flow="${ref%%@*}" label="${ref#*@}"
  local mp4="$SRC_DIR/${flow}_${LANG_TAG}.mp4"
  [ -s "$mp4" ] || { warn "녹화본 없음: $mp4"; return 1; }
  t="$(beat_at "$SRC_DIR/${flow}_beats.txt" "$label")"
  [ -n "$t" ] || { warn "비트 없음: $flow/$label"; return 1; }
  t="$(awk -v a="$t" -v b="$SETTLE" 'BEGIN{printf "%.2f", a+b}')"
  y0="$FY0"; bh="$FH"
  if [ -n "$band" ]; then
    y0="$(awk -v a="${band%%-*}" -v y="$FY0" -v h="$FH" 'BEGIN{printf "%d", y + a*h}')"
    bh="$(awk -v a="${band%%-*}" -v b="${band##*-}" -v h="$FH" 'BEGIN{printf "%d", (b-a)*h}')"
  fi
  ffmpeg -y -v error -ss "$t" -i "$mp4" -frames:v 1 \
    -vf "crop=${FW}:${bh}:${FX0}:${y0}" "$out" || return 1
}

# 화면 조각: 둥근 모서리 + 옅은 그림자. 주어진 상자 안에 비율 그대로 채운다.
mock() { # mock <화면png> <상자폭> <상자높이> <출력>
  local src="$1" bw="$2" bh="$3" out="$4" r=30
  "$IM" "$src" -resize "${bw}x${bh}" \
    \( +clone -alpha extract -draw "fill black polygon 0,0 0,$r $r,0 fill white circle $r,$r $r,0" \
       \( +clone -flip \) -compose Multiply -composite \
       \( +clone -flop \) -compose Multiply -composite \) \
    -alpha off -compose CopyOpacity -composite "$out.rc.png"
  # 그림자: 같은 실루엣을 어둡게 깔고 살짝 내려 흐린다.
  "$IM" "$out.rc.png" \
    \( +clone -background "rgba(78,52,46,0.35)" -shadow 55x24+0+14 \) \
    +swap -background none -layers merge +repage "$out"
  rm -f "$out.rc.png"
}

# ── 카드 3종 ─────────────────────────────────────────────────
cover_card() { # cover_card <ko1> <ko2> <en> <출력>
  local l1="$1" l2="$2" en="$3" out="$4"
  "$IM" -size ${W}x${H} xc:"$C_BG" "$out.b.png"
  [ -f "$LOGO" ] && "$IM" "$out.b.png" \( "$LOGO" -resize 300x300 \) \
    -gravity north -geometry +0+250 -composite "$out.b.png"
  "$IM" "$out.b.png" -font "$FONT" -gravity north \
    -fill "$C_BROWN" -stroke "$C_BROWN" -strokewidth 2 -pointsize 76 -annotate +0+660 "$l1" \
    -fill "$C_DARK"  -stroke "$C_DARK"  -strokewidth 4 -pointsize 110 -annotate +0+790 "$l2" \
    -fill "$C_YELLOW" -stroke none -draw "roundrectangle $((W/2-90)),960 $((W/2+90)),970 5,5" \
    -fill "$C_BROWN" -stroke none -pointsize 42 -annotate +0+1010 "$en" \
    -fill "$C_BROWN" -stroke none -pointsize 40 -annotate +0+1700 "넘겨보세요  ›" \
    "$out"
  rm -f "$out.b.png"
}

step_card() { # step_card <번호> <화면png> <ko1> <ko2> <en> <출력>
  local n="$1" shot="$2" l1="$3" l2="$4" en="$5" out="$6"
  local bx=90 by=120 bw=104 bh=104
  "$IM" -size ${W}x${H} xc:"$C_BG" \
    -fill "$C_YELLOW" -stroke none \
    -draw "roundrectangle $bx,$by $((bx+bw)),$((by+bh)) 30,30" \
    -font "$FONT" -fill "$C_DARK" -stroke "$C_DARK" -strokewidth 2 \
    -gravity northwest -pointsize 52 -annotate +$((bx+32))+$((by+26)) "$n" \
    "$out.b.png"
  local y=280 a=(-font "$FONT" -gravity north)
  if [ -n "$l2" ]; then
    a+=(-fill "$C_BROWN" -stroke "$C_BROWN" -strokewidth 1 -pointsize 52 -annotate +0+$y "$l1")
    y=$(( y + 78 ))
    a+=(-fill "$C_DARK" -stroke "$C_DARK" -strokewidth 3 -pointsize 76 -annotate +0+$y "$l2")
    y=$(( y + 108 ))
  else
    a+=(-fill "$C_DARK" -stroke "$C_DARK" -strokewidth 3 -pointsize 76 -annotate +0+$y "$l1")
    y=$(( y + 108 ))
  fi
  [ -n "$en" ] && a+=(-fill "$C_BROWN" -stroke none -pointsize 36 -annotate +0+$y "$en")
  "$IM" "$out.b.png" "${a[@]}" "$out.t.png"
  if [ -s "$shot" ]; then
    # 상자: 가로 900(좌우 여백 90), 세로 1180(문구 아래 ~ 카드 아래 여백 80).
    mock "$shot" 900 1180 "$out.m.png"
    "$IM" "$out.t.png" "$out.m.png" -gravity north -geometry +0+660 -composite "$out"
  else
    mv -f "$out.t.png" "$out"
  fi
  rm -f "$out.b.png" "$out.t.png" "$out.m.png"
}

end_card() { # end_card <ko1> <ko2> <en> <출력>
  local l1="$1" l2="$2" en="$3" out="$4"
  "$IM" -size ${W}x${H} xc:"$C_BG" "$out.b.png"
  [ -f "$LOGO" ] && "$IM" "$out.b.png" \( "$LOGO" -resize 460x460 \) \
    -gravity center -geometry +0-220 -composite "$out.b.png"
  "$IM" "$out.b.png" -font "$FONT" -gravity center \
    -fill "$C_DARK" -stroke "$C_DARK" -strokewidth 3 -pointsize 104 -annotate +0+130 "$l1" \
    -fill "$C_YELLOW" -stroke none \
      -draw "roundrectangle $((W/2-90)),$((H/2+215)) $((W/2+90)),$((H/2+223)) 4,4" \
    -fill "$C_BROWN" -stroke none -pointsize 52 -annotate +0+300 "$l2" \
    -fill "$C_BROWN" -stroke none -pointsize 34 -annotate +0+375 "$en" \
    "$out"
  rm -f "$out.b.png"
}

# ── 세트별로 굽기 ────────────────────────────────────────────
SETS="${SETS:-$(awk -F'|' '!/^[[:space:]]*#/ && NF>=2 {g=$1; gsub(/[ \t]/,"",g); if (!(g in s)) {s[g]=1; printf "%s ", g}}' "$CARDS_FILE")}"
made=0
for set in $SETS; do
  OUT="$OUT_ROOT/$set"; rm -rf "$OUT"; mkdir -p "$OUT"
  n=0; step=0
  while IFS='|' read -r kind src l1 l2 en; do
    n=$((n+1))
    printf -v idx '%02d' "$n"
    out="$OUT/$idx.png"
    case "$kind" in
      cover) cover_card "$l1" "$l2" "$en" "$out" ;;
      end)   end_card   "$l1" "$l2" "$en" "$out" ;;
      step)
        step=$((step+1))
        shot="$OUT/.shot_$idx.png"
        grab "$src" "$shot" || shot=""
        printf -v sn '%02d' "$step"
        step_card "$sn" "$shot" "$l1" "$l2" "$en" "$out"
        rm -f "$OUT/.shot_$idx.png"
        ;;
      *) warn "모르는 종류: $kind"; n=$((n-1)); continue ;;
    esac
  done < <(lines_for "$set")
  [ "$n" -gt 0 ] && { log "◆ $set — ${n}장 → cards/$set/"; made=$((made+1)); } \
                 || warn "카드 없음: $set"
done
log "완료. ${made}세트 → $OUT_ROOT"
