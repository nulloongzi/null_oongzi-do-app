#!/usr/bin/env bash
# scripts/capture/compose_videos.sh — 원본 화면녹화(raw)를 마케팅 완성본으로 후반합성한다.
# 에뮬레이터 밖(러너 호스트)에서 ffmpeg/ImageMagick 으로 실행된다. 산출:
#   · reels/promo/<feat>_<lang>.mp4  — 기능별 홍보 릴스(9:16, 크림 캔버스+한/영 자막+CTA)
#   · reels/app_intro_<lang>.mp4     — 앱 소개 영상(인트로 카드 + 기능 세그먼트 + CTA 아웃트로)
#
# 입력: reels/raw/<feat>_<lang>.mp4 (앱 1080×2400 화면녹화). run_capture.sh 가 생성.
# 무음(텍스트/모션 중심), 1080×1920 h264 yuv420p 30fps 로 통일.
#
# SELFTEST=1: 에뮬 없이 가짜 raw 클립을 합성해 전체 파이프라인을 검증(빠른 CI 자기점검).
# 아티팩트 다운로드가 프록시에 막히므로, 각 산출 영상의 프레임 몬타주를 base64 로 로그에 남긴다.
set -uo pipefail

ART="${ARTIFACTS_DIR:-marketing-assets}"
REELS="$ART/reels"
RAW="$REELS/raw"
PROMO="$REELS/promo"
CARDS="$REELS/.cards"
SEG="$REELS/.seg"
LANGS="${CAP_LANGS:-ko en}"
SELFTEST="${SELFTEST:-0}"
mkdir -p "$RAW" "$PROMO" "$CARDS" "$SEG"

log() { echo "▶ $*"; }
warn() { echo "::warning::$*"; }

# ── 리소스: 폰트 & 로고 ──────────────────────────────────────
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# NanumGothic(Bold) 우선 — 스토어 합성본과 타이포 일치. Coding(등폭)·Square 변형은 배제.
pick_font() { # pick_font <bold|reg>
  local nd=/usr/share/fonts/truetype/nanum
  if [ "$1" = bold ]; then
    for p in "$nd/NanumGothicBold.ttf" "$nd/NanumGothicExtraBold.ttf"; do [ -e "$p" ] && { echo "$p"; return; }; done
    fc-list 2>/dev/null | grep -i nanumgothic | grep -i bold | grep -iv coding | head -1 | cut -d: -f1 | xargs
  else
    for p in "$nd/NanumGothic.ttf"; do [ -e "$p" ] && { echo "$p"; return; }; done
    fc-list 2>/dev/null | grep -i nanumgothic | grep -iv -e bold -e coding | head -1 | cut -d: -f1 | xargs
  fi
}
FONT_MAIN="$(pick_font bold)"; FONT_SUB="$(pick_font reg)"
[ -z "$FONT_MAIN" ] && FONT_MAIN="/usr/share/fonts/truetype/nanum/NanumGothicBold.ttf"
[ -z "$FONT_SUB" ] && FONT_SUB="/usr/share/fonts/truetype/nanum/NanumGothic.ttf"
LOGO="$ROOT/assets/nulloongzido logo_without bg.png"
log "font_main=$FONT_MAIN"
log "font_sub=$FONT_SUB"
[ -e "$LOGO" ] || warn "로고 없음: $LOGO (인트로/아웃트로 로고 생략)"

# 팔레트
CREAM="#FFF8E1"; YELLOW="#FAC710"; DARK="#4E342E"; BROWN="#8D6E63"; FRAME="#3A2C26"

# ── 캡션 카피(기능 × 언어) ───────────────────────────────────
# 순서 = 앱 소개 영상 세그먼트 순서(임팩트 순).
FEATURES=(map filter pickup detail lunchbox share profile)
# sub|main (main 아래 옐로 언더라인). textfile 로 넘겨 이스케이프 회피.
declare -A KO_SUB KO_MAIN EN_SUB EN_MAIN
KO_SUB[map]="전국 배구 동호회";       KO_MAIN[map]="지도 한 눈에"
KO_SUB[filter]="지역·요일·대상으로";   KO_MAIN[filter]="딱 맞는 팀 찾기"
KO_SUB[pickup]="오늘 당장 뛸";         KO_MAIN[pickup]="픽업 게임"
KO_SUB[detail]="일정·회비·위치 확인";  KO_MAIN[detail]="바로 연락"
KO_SUB[lunchbox]="마음에 든 팀은";     KO_MAIN[lunchbox]="‘도시락’에 찜"
KO_SUB[share]="카톡·인스타로";         KO_MAIN[share]="우리 팀 자랑"
KO_SUB[profile]="나만의";              KO_MAIN[profile]="‘밥이름’ 닉네임"
EN_SUB[map]="Volleyball clubs";        EN_MAIN[map]="all on one map"
EN_SUB[filter]="Region · day · type";  EN_MAIN[filter]="find your fit"
EN_SUB[pickup]="Play today";           EN_MAIN[pickup]="pickup games"
EN_SUB[detail]="Schedule · fee · spot"; EN_MAIN[detail]="tap to contact"
EN_SUB[lunchbox]="Save your favorites"; EN_MAIN[lunchbox]="to the lunchbox"
EN_SUB[share]="Kakao · Instagram";     EN_MAIN[share]="show off your team"
EN_SUB[profile]="Your own";            EN_MAIN[profile]="‘rice-name’ nickname"

# 인트로/아웃트로 카피
declare -A INTRO_TITLE INTRO_TAG OUTRO_TOP OUTRO_CTA
INTRO_TITLE[ko]="누룽지도";  INTRO_TAG[ko]="배구 동호회·픽업, 지도 한 눈에"
INTRO_TITLE[en]="누룽지도";  INTRO_TAG[en]="Volleyball clubs & pickup, one map"
OUTRO_TOP[ko]="지금 만나보세요";        OUTRO_CTA[ko]="Play 스토어에서 ‘누룽지도’ 검색"
OUTRO_TOP[en]="Start playing today";    OUTRO_CTA[en]="Search ‘누룽지도’ on Google Play"

sub_of() { local l="$1" f="$2"; if [ "$l" = ko ]; then echo "${KO_SUB[$f]}"; else echo "${EN_SUB[$f]}"; fi; }
main_of() { local l="$1" f="$2"; if [ "$l" = ko ]; then echo "${KO_MAIN[$f]}"; else echo "${EN_MAIN[$f]}"; fi; }

# ── 브랜드 카드(PNG) 생성: ImageMagick ───────────────────────
make_card() { # make_card <out.png> <top_text> <big_text> <sub_text>
  local out="$1" top="$2" big="$3" sub="$4"
  # 크림 캔버스 + 상단 top(브라운) + 중앙 big(다크) + 옐로 언더라인 + 하단 sub(브라운)
  convert -size 1080x1920 xc:"$CREAM" \
    -font "$FONT_SUB"  -fill "$BROWN" -pointsize 52 -gravity north    -annotate +0+300 "$top" \
    -font "$FONT_MAIN" -fill "$DARK"  -pointsize 118 -gravity center  -annotate +0-40 "$big" \
    -fill "$YELLOW" -draw "roundrectangle 390,1075 690,1091 8,8" \
    -font "$FONT_SUB"  -fill "$BROWN" -pointsize 46 -gravity center   -annotate +0+90 "$sub" \
    "$out" 2>/dev/null || { warn "카드 생성 실패: $out"; return 1; }
  # 로고 합성(중앙 상단). 있으면.
  if [ -e "$LOGO" ]; then
    convert "$out" \( "$LOGO" -resize 240x240 \) -gravity north -geometry +0+40 -composite "$out" 2>/dev/null || true
  fi
}

# ── PNG → n초 클립(.ts, 통일 규격) ───────────────────────────
ENC=(-c:v libx264 -preset veryfast -profile:v high -pix_fmt yuv420p -r 30 -an)
png_to_ts() { # png_to_ts <png> <secs> <out.ts>
  ffmpeg -y -loglevel error -loop 1 -t "$2" -i "$1" \
    -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,fps=30" \
    "${ENC[@]}" -f mpegts "$3" 2>&1 | tail -2 || warn "png_to_ts 실패: $1"
}

# ── raw 앱녹화 → 브랜디드 9:16 클립 ──────────────────────────
# 크림 캔버스 위에 폰 화면(다크 테두리) + 상단 2줄 자막 + 옐로 언더라인 + 하단 워드마크.
brand_clip() { # brand_clip <raw.mp4> <lang> <feat> <out.mp4>
  local raw="$1" lang="$2" feat="$3" out="$4"
  local subf="$CARDS/.sub_${feat}_${lang}.txt" mainf="$CARDS/.main_${feat}_${lang}.txt"
  printf '%s' "$(sub_of "$lang" "$feat")" > "$subf"
  printf '%s' "$(main_of "$lang" "$feat")" > "$mainf"
  # 폰: 높이 1360 로 스케일(1080×2400→612폭) + 6px 다크 테두리, 크림 위 y=360 배치.
  # 자막: 상단 sub(y=140)/main(y=196) + main 아래 옐로 언더라인.
  ffmpeg -y -loglevel error -i "$raw" -filter_complex "
    color=c=${CREAM}:s=1080x1920:r=30[bg];
    [0:v]scale=-2:1360,pad=iw+12:ih+12:6:6:${FRAME}[ph];
    [bg][ph]overlay=(W-w)/2:360:shortest=1[v0];
    [v0]drawbox=x=(iw-300)/2:y=300:w=300:h=8:color=${YELLOW}:t=fill[v1];
    [v1]drawtext=fontfile='${FONT_SUB}':textfile='${subf}':fontcolor=${BROWN}:fontsize=50:x=(w-tw)/2:y=150[v2];
    [v2]drawtext=fontfile='${FONT_MAIN}':textfile='${mainf}':fontcolor=${DARK}:fontsize=76:x=(w-tw)/2:y=205[v3];
    [v3]drawtext=fontfile='${FONT_MAIN}':text='누룽지도':fontcolor=${BROWN}:fontsize=40:x=(w-tw)/2:y=1836[v4]
  " -map "[v4]" "${ENC[@]}" "$out" 2>&1 | tail -3
  [ -s "$out" ] || { warn "brand_clip 실패: $feat/$lang"; return 1; }
}

# ── 영상 검증: 프레임 몬타주 base64(로그 육안확인) ───────────
video_montage() { # video_montage <mp4> <label>
  local mp4="$1" label="$2" d
  [ -s "$mp4" ] || { echo "MONTAGE_MISSING $label"; return; }
  d="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$mp4" 2>/dev/null | cut -d. -f1)"
  local dim; dim="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$mp4" 2>/dev/null)"
  echo "VID $label dur=${d}s dim=$dim"
  local td; td="$(mktemp -d)"
  # 6프레임 균등 추출 → 3×2 몬타주 → 폭 720 → base64
  ffmpeg -y -loglevel error -i "$mp4" -vf "select='not(mod(n\,15))',scale=360:-1" -frames:v 6 "$td/f_%02d.png" 2>/dev/null
  if ls "$td"/f_*.png >/dev/null 2>&1; then
    montage "$td"/f_*.png -tile 3x2 -geometry +4+4 -background "$CREAM" "$td/m.png" 2>/dev/null
    echo "MONTAGE_BEGIN $label"
    convert "$td/m.png" -resize 720x -quality 72 jpg:- 2>/dev/null | base64 -w0
    echo ""
    echo "MONTAGE_END $label"
  fi
  rm -rf "$td"
}

# ── SELFTEST: 가짜 raw 클립 생성(에뮬 대체) ──────────────────
make_fake_raw() { # make_fake_raw <feat> <lang>
  local feat="$1" lang="$2"
  local out="$RAW/${feat}_${lang}.mp4"
  # 앱 화면 흉내: 옅은 파랑 배경 + 이동하는 옐로 박스 + 기능명 텍스트(1080×2400, 8s)
  ffmpeg -y -loglevel error -f lavfi -i "color=c=#EAF2FB:s=1080x2400:d=8:r=30" \
    -vf "drawbox=x='100+mod(t*120\,800)':y=500:w=200:h=200:color=${YELLOW}:t=fill,
         drawtext=text='${feat} / ${lang}':fontfile='${FONT_MAIN}':fontcolor=#222222:fontsize=90:x=(w-tw)/2:y=200,
         drawtext=text='NULOONGZIDO APP SCREEN':fontfile='${FONT_SUB}':fontcolor=#888888:fontsize=40:x=(w-tw)/2:y=2200" \
    "${ENC[@]}" "$out" 2>&1 | tail -1
}

# ══════════════════════════════════════════════════════════════
if [ "$SELFTEST" = "1" ]; then
  log "SELFTEST: 가짜 raw 클립 생성(${FEATURES[*]} × ${LANGS})"
  for l in $LANGS; do for f in "${FEATURES[@]}"; do make_fake_raw "$f" "$l"; done; done
fi

# ── 1) 브랜드 카드 → 클립 ────────────────────────────────────
for l in $LANGS; do
  make_card "$CARDS/intro_$l.png" "" "${INTRO_TITLE[$l]}" "${INTRO_TAG[$l]}"
  make_card "$CARDS/outro_$l.png" "${OUTRO_TOP[$l]}" "🏐" "${OUTRO_CTA[$l]}"
  png_to_ts "$CARDS/intro_$l.png" 2.2 "$SEG/intro_$l.ts"
  png_to_ts "$CARDS/outro_$l.png" 2.8 "$SEG/outro_$l.ts"
done

# ── 2) 기능별 브랜디드 클립 + 홍보 릴스(클립+CTA) ────────────
for l in $LANGS; do
  for f in "${FEATURES[@]}"; do
    raw="$RAW/${f}_${l}.mp4"
    [ -s "$raw" ] || { warn "raw 없음, 스킵: ${f}_${l}"; continue; }
    brand="$SEG/brand_${f}_${l}.mp4"
    brand_clip "$raw" "$l" "$f" "$brand" || continue
    # 홍보 릴스 = 브랜디드 클립 + CTA 아웃트로
    ffmpeg -y -loglevel error -i "$brand" "${ENC[@]}" -f mpegts "$SEG/brand_${f}_${l}.ts" 2>/dev/null
    printf "file '%s'\nfile '%s'\n" "$SEG/brand_${f}_${l}.ts" "$SEG/outro_$l.ts" > "$SEG/list_${f}_${l}.txt"
    ffmpeg -y -loglevel error -f concat -safe 0 -i "$SEG/list_${f}_${l}.txt" -c copy "$PROMO/${f}_${l}.mp4" 2>/dev/null
    log "  ✅ promo/${f}_${l}.mp4"
  done
done

# ── 3) 앱 소개 영상: 인트로 + 각 기능(5s 트림) + 아웃트로 ─────
for l in $LANGS; do
  list="$SEG/intro_list_$l.txt"; : > "$list"
  echo "file '$SEG/intro_$l.ts'" >> "$list"
  for f in "${FEATURES[@]}"; do
    brand="$SEG/brand_${f}_${l}.mp4"
    [ -s "$brand" ] || continue
    seg="$SEG/seg_${f}_${l}.ts"
    ffmpeg -y -loglevel error -t 5 -i "$brand" "${ENC[@]}" -f mpegts "$seg" 2>/dev/null
    echo "file '$seg'" >> "$list"
  done
  echo "file '$SEG/outro_$l.ts'" >> "$list"
  ffmpeg -y -loglevel error -f concat -safe 0 -i "$list" -c copy "$REELS/app_intro_$l.mp4" 2>/dev/null
  log "  ✅ app_intro_$l.mp4"
done

# ── 4) 검증 몬타주(로그) ─────────────────────────────────────
echo "===== VIDEO FINGERPRINT ====="
for l in $LANGS; do
  video_montage "$REELS/app_intro_$l.mp4" "app_intro_$l"
  for f in "${FEATURES[@]}"; do
    video_montage "$PROMO/${f}_${l}.mp4" "promo_${f}_${l}"
  done
done
echo "===== END VIDEO FINGERPRINT ====="

# 중간 산출물 정리(아티팩트 슬림)
rm -rf "$SEG" "$CARDS"
log "완료. promo=$(ls -1 "$PROMO" 2>/dev/null | wc -l)편, app_intro=$(ls -1 "$REELS"/app_intro_*.mp4 2>/dev/null | wc -l)편."
