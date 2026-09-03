#!/usr/bin/env bash
# scripts/capture/compose_motion.sh — 스틸(stills/)로 앱 시연 영상을 만든다.
#
# 왜 스틸인가: CI 러너엔 GPU가 없어 에뮬이 SwiftShader(CPU 렌더링)로 돌고,
# 하드웨어 대비 10~20배 느려 지도 앱 실시간 녹화는 렉·타일로딩·빈화면으로
# 마케팅 품질이 구조적으로 안 나온다. 반면 스크린샷은 항상 정확하다.
# → 정확한 UI 상태 스틸을 찍고, 그 사이를 **앱의 실제 전환**으로 재현한다.
#
# 원칙: 앱이 실제로 하는 동작만 재현한다. 카메라 줌(Ken Burns) 같은
# '앱이 하지 않는 모션'은 넣지 않는다 — 즉시 가짜로 보인다.
#
# 모션 상수는 Flutter 기본값에 맞춘다:
#   · 바텀시트 진입 250ms / 이탈 200ms, decelerate 커브
#   · 모달 스크림 black54 (54%)
#   · 중앙 다이얼로그(도시락·프로필): 300~340ms 페이드 + 스프링 스케일
#
# 입력: $ART/stills/NN_name.png (1080×2400)
# 출력: $ART/motion/<story>_<lang>.mp4 (1080×1920, 60fps, 무음)
set -euo pipefail

# ── ImageMagick 호출 정규화 (Windows/Git Bash 안전) ──────────────
# IM7 의 실행파일은 `magick` 이다. Windows 에서 `convert` 는 **OS 기본 디스크 변환
# 유틸(C:\Windows\System32\convert.exe)** 과 이름이 겹쳐, Git Bash 에서 그쪽이
# 먼저 잡히면 이미지가 아니라 볼륨 변환을 시도한다(치명적).
# magick 이 있으면 전부 magick 경유로 강제한다. Linux IM6 에서는 원래 바이너리 사용.
if command -v magick >/dev/null 2>&1; then
  convert()  { magick "$@"; }
  identify() { magick identify "$@"; }
  montage()  { magick montage "$@"; }
  compare()  { magick compare "$@"; }
  IM_ARGV0="magick"; IM_ARGV1=""
else
  IM_ARGV0="convert"; IM_ARGV1=""
fi
export IM_ARGV0 IM_ARGV1


ART="${ARTIFACTS_DIR:-marketing-assets}"
STILLS="$ART/stills"
OUT="$ART/motion"
WORK="$OUT/.w"
LANG_TAG="${CAP_LANG:-ko}"
mkdir -p "$OUT" "$WORK"

W=1080; H=1920; FPS=60
# 9:16 크롭은 **소스 해상도에서 비율로** 계산한다. 실기기는 1080x2400 이 아닐 수 있고
# (1080x2340, 1440x3120 …) 좌표를 하드코딩하면 화면이 잘리거나 어긋난다.
# 기준: 1080x2400 에서 위 390px 를 덜어내면 상태바·검색바만 빠지고 바텀시트 하단
# 버튼은 살아남는다(실제 캡처 6화면으로 검증) → 390/2400 = 0.1625.
# 상단 크롬(상태바+검색바)은 **dp 기반**이라 화면이 길어져도 픽셀 높이가 그대로다.
# 같은 dp 폭(411dp)의 폰들은 dpr 이 폭에 비례하므로 **폭 기준으로 스케일**하는 게 맞다.
# (높이 비율로 잡으면 세로로 긴 폰에서 필요 이상으로 잘려 칩 줄까지 먹는다 —
#  Z 플립 6(1080x2640) 에서 429px vs 390px 로 39px 더 잘릴 뻔했다.)
CROP_TOP_AT_1080="${CROP_TOP_AT_1080:-390}"
_probe="$(ls "$STILLS"/*.png 2>/dev/null | head -1)"
if [ -n "$_probe" ]; then
  SRC_W="$(identify -format '%w' "$_probe")"
  SRC_H="$(identify -format '%h' "$_probe")"
else
  SRC_W=1080; SRC_H=2400
fi
# 크롭 창: 소스 폭 그대로, 높이는 9:16. 시작 y 는 비율로.
CROP_H="$(awk -v w="$SRC_W" 'BEGIN{printf "%d", int(w*16/9/2)*2}')"
CROP_Y="$(awk -v h="$SRC_H" -v ch="$CROP_H" -v w="$SRC_W" -v t="$CROP_TOP_AT_1080" \
  'BEGIN{y=int(t*w/1080); if (y+ch>h) y=h-ch; if (y<0) y=0; printf "%d", y}')"
# 소스 px → 출력 px 환산(시트 좌표 보정용)
SCALE_Y="$(awk -v ch="$CROP_H" -v oh="$H" 'BEGIN{printf "%.6f", oh/ch}')"
echo "▶ 소스 ${SRC_W}x${SRC_H} → 크롭 ${SRC_W}x${CROP_H}+0+${CROP_Y} → 출력 ${W}x${H}"
ENC=(-c:v libx264 -preset medium -profile:v high -pix_fmt yuv420p -r $FPS -an)

log() { echo "▶ $*"; }
warn() { echo "::warning::$*"; }

have() { [ -s "$STILLS/$1.png" ]; }
# 9:16 로 정규화한 작업본
prep() { # prep <name>
  local n="$1"
  [ -s "$WORK/$n.png" ] && return 0
  have "$n" || { warn "스틸 없음: $n"; return 1; }
  convert "$STILLS/$n.png" -crop ${SRC_W}x${CROP_H}+0+${CROP_Y} +repage \
    -resize ${W}x${H}! "$WORK/$n.png"
}

# ── 좌표 자동 추출 ────────────────────────────────────────────
# 배경 쌍(오버레이 없음/있음)의 차이 영역이 곧 오버레이 rect 다.
# 앱에서 위젯 rect 를 덤프할 필요가 없다 — 쌍만 있으면 이미지가 알려준다.
diff_top() { # diff_top <bg> <overlay>  → 시트 상단 y (없으면 빈 값)
  local a="$WORK/$1.png" b="$WORK/$2.png"
  [ -s "$a" ] && [ -s "$b" ] || return 1
  # 주의: 시트가 열리면 스크림이 **화면 전체**를 덮어 차이가 y=0 부터 생긴다.
  # 따라서 '차이가 있는 첫 행'을 찾으면 항상 0 이 나온다(실측 확인).
  # 시트는 '큰 차이가 바닥까지 이어지는 띠'다 → 그 띠의 시작 행을 찾는다.
  python3 - "$a" "$b" <<'PY'
import subprocess,sys
a,b=sys.argv[1],sys.argv[2]
import os
# bash 함수는 subprocess 에 안 잡힌다 → 실제 바이너리를 env 로 받는다(Windows 안전).
IM=[os.environ.get("IM_ARGV0","convert")]
out=subprocess.run(IM+[a,b,"-compose","difference","-composite",
                    "-colorspace","Gray","-resize","1x1920!","-depth","8","txt:-"],
                   capture_output=True,text=True).stdout
vals=[]
for line in out.splitlines()[1:]:
    if "gray(" in line:
        try: vals.append(int(line.split("gray(")[1].split(")")[0].split(",")[0]))
        except Exception: pass
if len(vals) < 100:
    print(""); raise SystemExit
mx=max(vals)
if mx < 12:
    print(""); raise SystemExit
thr=mx*0.5                      # 딤(작은 차이)과 시트(큰 차이)를 가르는 선
# 바닥에서 위로 올라가며 연속으로 thr 을 넘는 구간의 시작을 찾는다.
top=len(vals)
i=len(vals)-1
run=0
while i >= 0:
    if vals[i] > thr:
        run += 1
        top = i
    else:
        if run >= 120:          # 충분히 두꺼운 띠면 그게 시트
            break
        run = 0
        top = len(vals)
    i -= 1
print(top if run >= 120 and top < len(vals)-40 else "")
PY
}

ease() { echo "(min(t/$1,1)*min(t/$1,1)*(3-2*min(t/$1,1)))"; }

# ── 세그먼트 빌더 ─────────────────────────────────────────────
# 정지 홀드
hold() { # hold <name> <dur> <out>
  ffmpeg -y -loglevel error -loop 1 -t "$2" -i "$WORK/$1.png" \
    -vf "fps=$FPS,setsar=1" "${ENC[@]}" "$3"
}

# 바텀시트 슬라이드업: 깨끗한 배경 위로 시트가 올라오고 스크림이 함께 짙어진다.
sheet_in() { # sheet_in <bg> <overlay> <sheet_top> <dur> <out>
  local bg="$1" ov="$2" top="$3" dur="$4" out="$5"
  local sh="$WORK/.sheet_${ov}.png"
  convert "$WORK/$ov.png" -crop ${W}x$((H-top))+0+${top} +repage "$sh"
  # 진입 250ms(Flutter 기본), 스크림 black54
  ffmpeg -y -loglevel error \
    -loop 1 -t "$dur" -i "$WORK/$bg.png" -loop 1 -t "$dur" -i "$sh" \
    -f lavfi -t "$dur" -i "color=black:s=${W}x${H}" \
    -filter_complex "
    [0:v]scale=$W:$H,fps=$FPS,setsar=1[b];
    [2:v]fps=$FPS,format=rgba,colorchannelmixer=aa=0.54,fade=t=in:st=0:d=0.25:alpha=1[d];
    [b][d]overlay=0:0[bd];
    [1:v]fps=$FPS,format=rgba,setsar=1[s];
    [bd][s]overlay=x=0:y='$H-($H-$top)*$(ease 0.25)'[v]" \
    -map "[v]" "${ENC[@]}" "$out"
}

# 바텀시트 슬라이드다운(이탈 200ms)
sheet_out() { # sheet_out <bg> <overlay> <sheet_top> <dur> <out>
  local bg="$1" ov="$2" top="$3" dur="$4" out="$5"
  local sh="$WORK/.sheet_${ov}.png"
  convert "$WORK/$ov.png" -crop ${W}x$((H-top))+0+${top} +repage "$sh"
  ffmpeg -y -loglevel error \
    -loop 1 -t "$dur" -i "$WORK/$bg.png" -loop 1 -t "$dur" -i "$sh" \
    -f lavfi -t "$dur" -i "color=black:s=${W}x${H}" \
    -filter_complex "
    [0:v]scale=$W:$H,fps=$FPS,setsar=1[b];
    [2:v]fps=$FPS,format=rgba,colorchannelmixer=aa=0.54,fade=t=out:st=0:d=0.20:alpha=1[d];
    [b][d]overlay=0:0[bd];
    [1:v]fps=$FPS,format=rgba,setsar=1[s];
    [bd][s]overlay=x=0:y='$top+($H-$top)*$(ease 0.20)'[v]" \
    -map "[v]" "${ENC[@]}" "$out"
}

# 중앙 모달(도시락·프로필): 스크림 페이드 + 스프링 등장을 근사(300ms)
dialog_in() { # dialog_in <bg> <overlay> <dur> <out>
  ffmpeg -y -loglevel error \
    -loop 1 -t "$3" -i "$WORK/$1.png" -loop 1 -t "$3" -i "$WORK/$2.png" \
    -filter_complex "
    [0:v]scale=$W:$H,fps=$FPS,setsar=1[b];
    [1:v]scale=$W:$H,fps=$FPS,setsar=1,format=rgba,fade=t=in:st=0:d=0.30:alpha=1[o];
    [b][o]overlay=0:0[v]" \
    -map "[v]" "${ENC[@]}" "$4"
}

# 화면 전환(네임카드 등 페이지 push): 오른쪽에서 슬라이드 인
page_in() { # page_in <from> <to> <dur> <out>
  ffmpeg -y -loglevel error \
    -loop 1 -t "$3" -i "$WORK/$1.png" -loop 1 -t "$3" -i "$WORK/$2.png" \
    -filter_complex "
    [0:v]scale=$W:$H,fps=$FPS,setsar=1[b];
    [1:v]scale=$W:$H,fps=$FPS,setsar=1[o];
    [b][o]overlay=x='$W-$W*$(ease 0.30)':y=0[v]" \
    -map "[v]" "${ENC[@]}" "$4"
}

# 콘텐츠 갱신(지도 필터 반영처럼 앱이 '다시 그리는' 순간): 짧은 크로스디졸브
dissolve() { # dissolve <a> <b> <dur> <out>
  ffmpeg -y -loglevel error \
    -loop 1 -t "$3" -i "$WORK/$1.png" -loop 1 -t "$3" -i "$WORK/$2.png" \
    -filter_complex "
    [0:v]scale=$W:$H,fps=$FPS,setsar=1[a];
    [1:v]scale=$W:$H,fps=$FPS,setsar=1,format=rgba,fade=t=in:st=0:d=$3:alpha=1[b];
    [a][b]overlay=0:0[v]" \
    -map "[v]" "${ENC[@]}" "$4"
}

concat_to() { # concat_to <out> <seg...>
  local out="$1"; shift
  local lst="$WORK/.l.txt"; : > "$lst"
  for s in "$@"; do [ -s "$s" ] && echo "file '$(basename "$s")'" >> "$lst"; done
  [ -s "$lst" ] || { warn "세그먼트 없음: $out"; return 1; }
  ( cd "$WORK" && ffmpeg -y -loglevel error -f concat -safe 0 -i .l.txt -c copy "$out" )
}

# ── 스틸 준비 ─────────────────────────────────────────────────
for n in 01_map 02_filter_open 03_filter_set 04_map_filtered 05_club_bg 06_club_sheet \
         07_lunchbox_bg 08_lunchbox 09_lunchbox_diet 10_profile_bg 11_profile \
         12_namecard 13_share_bg 14_share; do
  prep "$n" || true
done

# ── 시트 상단 y ───────────────────────────────────────────────
# 1순위: 앱이 남긴 정확한 좌표(stills/rects.txt) — 렌더 트리에서 읽은 값이라 정확하다.
# 2순위: 이미지 휴리스틱(아래) — 스크림이 전면을 덮고 시트 내부 대비도 케이스마다
#        달라 신뢰할 수 없음이 확인됐다. 좌표가 없을 때만 쓰는 안전망.
RECTS="$STILLS/rects.txt"
rect_of() { # rect_of <st_cmd> → 크롭 보정된 y (없으면 빈 값)
  [ -s "$RECTS" ] || return 0
  local v
  v="$(awk -v k="$1" '$1==k {print $2}' "$RECTS" | tail -1)"
  [ -n "${v:-}" ] && [ "$v" != "-1" ] || return 0
  # 앱은 소스 화면 좌표로 준다 → 크롭만큼 빼고 출력 배율로 환산.
  awk -v y="$v" -v c="$CROP_Y" -v s="$SCALE_Y" \
    'BEGIN{ d=(y-c)*s; if (d<0) d=0; print int(d) }'
}
FT="$(rect_of st_filter_open)"; [ -n "$FT" ] || FT="$(diff_top 01_map 02_filter_open 2>/dev/null || true)"; FT="${FT:-620}"
DT="$(rect_of st_club_sheet)"; [ -n "$DT" ] || DT="$(diff_top 05_club_bg 06_club_sheet 2>/dev/null || true)"; DT="${DT:-1180}"
# 공유 UI 는 바텀시트가 아니라 화면 중앙에 뜨는 다이얼로그다. 좌표를 받아 슬라이드
# 시키면 안 된다 — 게다가 앱이 st_share 에 대해 보고하는 값은 다이얼로그가 아니라
# 그 뒤에 남아 있는 상세 패널의 상단(1531)이라 완전히 엉뚱한 구간이 밀려 올라온다.
# 실제 앱 동작(페이드 인)과 같은 dialog_in 을 쓰므로 좌표 자체가 필요 없다.
if [ -s "$RECTS" ]; then log "시트 상단(앱 좌표): filter=$FT detail=$DT"
else warn "rects.txt 없음 — 휴리스틱 폴백: filter=$FT detail=$DT"; fi

# ── ① 찾기 ────────────────────────────────────────────────────
log "① 찾기"
hold      01_map 2.0                       "$WORK/a1.mp4"
sheet_in  01_map 02_filter_open "$FT" 1.2  "$WORK/a2.mp4"
hold      02_filter_open 1.4               "$WORK/a3.mp4"
dissolve  02_filter_open 03_filter_set 0.5 "$WORK/a4.mp4"   # 칩 선택
hold      03_filter_set 2.0                "$WORK/a5.mp4"
sheet_out 04_map_filtered 03_filter_set "$FT" 1.0 "$WORK/a6.mp4"
hold      04_map_filtered 1.6              "$WORK/a7.mp4"
dissolve  04_map_filtered 05_club_bg 0.5   "$WORK/a8.mp4"   # 마커로 이동
sheet_in  05_club_bg 06_club_sheet "$DT" 1.2 "$WORK/a9.mp4"
hold      06_club_sheet 3.2                "$WORK/a10.mp4"
concat_to "discover_${LANG_TAG}.mp4" "$WORK"/a{1,2,3,4,5,6,7,8,9,10}.mp4 || true

# ── ② 담고 관리 ───────────────────────────────────────────────
log "② 담고 관리"
hold      06_club_sheet 1.6                "$WORK/b1.mp4"
sheet_out 07_lunchbox_bg 06_club_sheet "$DT" 1.0 "$WORK/b2.mp4"
dialog_in 07_lunchbox_bg 08_lunchbox 1.0   "$WORK/b3.mp4"
hold      08_lunchbox 2.4                  "$WORK/b4.mp4"
dissolve  08_lunchbox 09_lunchbox_diet 0.5 "$WORK/b5.mp4"   # 식단표 펼침
hold      09_lunchbox_diet 3.4             "$WORK/b6.mp4"
concat_to "save_${LANG_TAG}.mp4" "$WORK"/b{1,2,3,4,5,6}.mp4 || true

# ── ③ 자랑하기 ────────────────────────────────────────────────
log "③ 자랑하기"
dialog_in 10_profile_bg 11_profile 1.0     "$WORK/c1.mp4"
hold      11_profile 2.4                   "$WORK/c2.mp4"
page_in   11_profile 12_namecard 1.0       "$WORK/c3.mp4"
hold      12_namecard 3.4                  "$WORK/c4.mp4"
dissolve  12_namecard 13_share_bg 0.5      "$WORK/c5.mp4"
dialog_in 13_share_bg 14_share 1.0        "$WORK/c6.mp4"
hold      14_share 2.6                     "$WORK/c7.mp4"
concat_to "share_${LANG_TAG}.mp4" "$WORK"/c{1,2,3,4,5,6,7}.mp4 || true

# ── 풀 투어 ───────────────────────────────────────────────────
for f in discover save share; do
  [ -s "$WORK/${f}_${LANG_TAG}.mp4" ] && mv "$WORK/${f}_${LANG_TAG}.mp4" "$OUT/"
done
TL="$WORK/.tour.txt"; : > "$TL"
for f in discover save share; do
  [ -s "$OUT/${f}_${LANG_TAG}.mp4" ] && echo "file '../${f}_${LANG_TAG}.mp4'" >> "$TL"
done
if [ -s "$TL" ]; then
  ( cd "$WORK" && ffmpeg -y -loglevel error -f concat -safe 0 -i .tour.txt -c copy "../full_tour_${LANG_TAG}.mp4" )
  log "  ↳ motion/full_tour_${LANG_TAG}.mp4"
fi

# ── 검증 몬타주(로그 육안확인) ────────────────────────────────
echo "===== MOTION FINGERPRINT ====="
for f in discover save share full_tour; do
  m="$OUT/${f}_${LANG_TAG}.mp4"
  [ -s "$m" ] || { echo "MONTAGE_MISSING motion_$f"; continue; }
  dur="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$m")"
  echo "VID motion_$f dur=${dur%%.*}s dim=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$m")"
  td="$(mktemp -d)"
  fps="$(awk -v d="${dur:-20}" 'BEGIN{printf "%.4f", 12.0/d}')"
  ffmpeg -y -loglevel error -i "$m" -vf "fps=${fps},scale=270:-1" -frames:v 12 "$td/f_%02d.png" 2>/dev/null
  if ls "$td"/f_*.png >/dev/null 2>&1; then
    montage "$td"/f_*.png -tile 4x3 -geometry +3+3 -background '#FFF8E1' "$td/m.png" 2>/dev/null
    echo "MONTAGE_BEGIN motion_$f"
    convert "$td/m.png" -resize 1100x -quality 72 jpg:- 2>/dev/null | base64 -w0
    echo ""
    echo "MONTAGE_END motion_$f"
  fi
  rm -rf "$td"
done
echo "===== END MOTION FINGERPRINT ====="

rm -rf "$WORK"
log "완료. motion=$(ls -1 "$OUT" 2>/dev/null | wc -l)편"
