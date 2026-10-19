#!/usr/bin/env python3
"""scripts/capture/make_grid.py — 인스타 프로필 3분할(고정 게시물 3개) 굽기.

가로 3240x1440 한 장을 1080x1440(3:4) 세 장으로 잘라, 프로필 맨 윗줄에 고정하면
한 장으로 이어져 보이게 한다. 2025년부터 프로필 그리드 썸네일이 3:4 라 이 크기다.

산출물 (marketing-assets/grid/<이름>/):
  panorama.png          자르기 전 원본 3240x1440
  1_upload_first_R.png  오른쪽 조각 — 가장 먼저 올리고, 가장 먼저 고정
  2_upload_second_M.png 가운데 조각
  3_upload_last_L.png   왼쪽 조각 — 마지막에 올리고, 마지막에 고정
  preview.png           프로필 화면 미리보기(칸 사이 틈 · 고정 핀 표시)
  feed.png              홈 피드에 한 장씩 뜬 모습(올린 순서대로) — 조각마다 혼자서도 표지가 되는지 확인
그리고 marketing-assets/grid/guide.png — 직접 디자인할 때 깔고 쓰는 안전 영역 가이드.

안전 영역 (각 조각 기준):
  - 오른쪽 위 170x170 비우기: 고정 게시물엔 핀 아이콘이 여기 뜬다.
  - 이음매 좌우 40px 안에는 글자를 두지 않기: 프로필 칸 사이 흰 틈에 글자가 끊긴다.
  - 홈 피드에선 조각이 한 장씩 따로 보인다. 그렇다고 세 장에 같은 틀(제목·설명·화면)을
    찍으면 카드 세 장으로 보여 한 장면 맛이 죽는다 → 조각마다 역할을 달리한다
    (글자 / 물건 / 장면). 글자는 한 조각에만. 이음매는 배경(지도·강·큰길)만 넘고,
    글자·물건은 반으로 잘리지 않게 조각 안에서 끝낸다.

사용법:
  python scripts/capture/make_grid.py                  # 누룽지도 기본 시안(pinned) + guide
  python scripts/capture/make_grid.py split my.png     # 직접 만든 3240x1440 이미지를 자르기만
  CHROME=/path/to/chrome python ...

필요: Python 3.8+(표준 라이브러리만), ffmpeg, 크롬 또는 엣지. 크롬 찾기는 make_cards.py 와 같다.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_cards import ART, FONTS, ROOT, SHOTS, die, ffmpeg, find_chrome, log  # noqa: E402

TW, TH = 1080, 1440            # 조각 한 장(3:4)
PW = TW * 3                    # 파노라마 폭
OUT_ROOT = ART / "grid"
PIN = 170                      # 핀 아이콘 자리(오른쪽 위)
SEAM = 40                      # 이음매 양옆 글자 금지 폭
TILES = (("3_upload_last_L", 0), ("2_upload_second_M", 1), ("1_upload_first_R", 2))

BASE_CSS = """
@font-face{font-family:Pretendard;src:url(PretendardVariable.ttf);font-weight:100 900}
*{margin:0;padding:0;box-sizing:border-box}
html,body{background:#FFF8E1}
body{font-family:Pretendard,sans-serif;color:#4E342E;-webkit-font-smoothing:antialiased}
"""


# ── 렌더 ─────────────────────────────────────────────────────
def render(chrome, html_path, png_path, w, h):
    prof = html_path.parent / "chrome-profile"
    cmd = [chrome, "--headless", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
           "--no-first-run", "--no-default-browser-check", f"--user-data-dir={prof}",
           "--allow-file-access-from-files", "--force-device-scale-factor=1",
           "--virtual-time-budget=5000", f"--window-size={w},{h + 200}",
           f"--screenshot={png_path}", html_path.as_uri()]
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=str(html_path.parent))
    if not png_path.is_file() or png_path.stat().st_size == 0:
        die("크롬 렌더 실패 (CHROME 로 경로를 지정해 보세요):\n"
            + r.stderr.decode("utf-8", "replace").strip()[-600:])
    # 헤드리스 창 여유분(+200)을 잘라낸다
    tmp = png_path.with_suffix(".full.png")
    png_path.rename(tmp)
    ffmpeg("-i", str(tmp), "-frames:v", "1", "-vf", f"crop={w}:{h}:0:0", str(png_path))
    tmp.unlink()


def page(work, name, css, body, w, h, chrome):
    html_path = work / f"{name}.html"
    html_path.write_text(f"<!doctype html><html lang=ko><head><meta charset=utf-8><style>{BASE_CSS}"
                         f"html,body{{width:{w}px;height:{h}px;overflow:hidden}}{css}</style></head>"
                         f"<body>{body}</body></html>", encoding="utf-8")
    out = work / f"{name}.png"
    render(chrome, html_path, out, w, h)
    return out


def split(pano, out):
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*_upload_*.png"):
        old.unlink()
    for name, i in TILES:
        ffmpeg("-i", str(pano), "-frames:v", "1", "-vf", f"crop={TW}:{TH}:{i * TW}:0",
               str(out / f"{name}.png"))


# ── 누룽지도 기본 시안 ───────────────────────────────────────
# 큰 지도 한 장 위에 세 조각이 서로 다른 일을 한다 — 같은 틀을 세 번 찍지 않는다.
#   왼쪽  글자(브랜드)  : 글자는 여기에만 둔다
#   가운데 물건(앱 화면): 지도 위에 놓인 폰
#   오른쪽 장면(지도)   : 마커가 모여 있는 동네 — 앱 말풍선 하나
# 이어 주는 건 지도(강·큰길)이고, 마커·폰·글자는 조각 안에서 끝난다.
import random  # noqa: E402

MAP_SEED = 7


def map_svg():
    rnd = random.Random(MAP_SEED)
    out = [f"<svg class=map width={PW} height={TH} viewBox='0 0 {PW} {TH}'>"]
    for _ in range(9):  # 공원
        x, y, r = rnd.randint(0, PW), rnd.randint(0, TH), rnd.randint(70, 170)
        out.append(f"<ellipse cx={x} cy={y} rx={r} ry={int(r * .7)} fill='#E3EDCF' "
                   f"transform='rotate({rnd.randint(0, 180)} {x} {y})'/>")
    # 골목 — 540x480 칸마다 기울기가 다른 격자(칸 밖으로 안 넘치게 잘라서 겹침 없이)
    out.append("<defs>")
    cells = [(c * 540, r * 480) for r in range(3) for c in range(6)]
    for i, (x, y) in enumerate(cells):
        out.append(f"<clipPath id=c{i}><rect x={x} y={y} width=540 height=480/></clipPath>")
    out.append("</defs>")
    for i, (x, y) in enumerate(cells):
        cx, cy = x + 270, y + 240
        ang, step = rnd.randint(-18, 18), rnd.randint(95, 130)
        lines = []
        for k in range(-5, 6):
            lines.append(f"M {cx - 500} {cy + k * step} L {cx + 500} {cy + k * step}")
            lines.append(f"M {cx + k * step} {cy - 500} L {cx + k * step} {cy + 500}")
        out.append(f"<g clip-path='url(#c{i})'><path d='{' '.join(lines)}' stroke='#FFFFFF' stroke-width=6 "
                   f"fill=none opacity=.8 transform='rotate({ang} {cx} {cy})'/></g>")
    river = "M -120 1010 C 520 1180, 900 640, 1500 760 S 2400 1180, 2900 900 S 3300 640, 3400 700"
    out.append(f"<path d='{river}' stroke='#CFE8F2' stroke-width=190 fill=none stroke-linecap=round/>")
    out.append(f"<path d='{river}' stroke='#B9DDEC' stroke-width=150 fill=none stroke-linecap=round/>")
    roads = []
    for y0 in (180, 470, 1290):  # 큰길 — 세 조각을 가로지른다
        pts = [(x, y0 + rnd.randint(-90, 90)) for x in range(-100, PW + 600, 540)]
        roads.append("M " + " L ".join(f"{x} {y}" for x, y in pts))
    for x0 in (420, 1250, 2050, 2780):  # 세로 큰길
        roads.append(f"M {x0} -60 C {x0 + 160} 500, {x0 - 160} 900, {x0 + 60} 1500")
    d = " ".join(roads)
    out.append(f"<path d='{d}' stroke='#EBC872' stroke-width=26 fill=none stroke-linejoin=round/>")
    out.append(f"<path d='{d}' stroke='#F8E3A2' stroke-width=17 fill=none stroke-linejoin=round/>")
    out.append("</svg>")
    # HTML 파서는 따옴표 없는 값 뒤의 '/>' 를 값에 붙여 읽는다(round/ → 안 닫힘) — 띄워 둔다
    return "".join(out).replace("/>", " />")


PINNED_CSS = """
.pano{position:relative;width:3240px;height:1440px;overflow:hidden;background:#F7EFD9}
.map{position:absolute;inset:0}
/* 왼쪽: 지도 위에 크림을 덮어 글자 자리를 만든다. 이음매 전에 완전히 걷힌다 */
.veil{position:absolute;left:0;top:0;width:1000px;height:1440px;
  background:linear-gradient(90deg,rgba(255,248,225,.97) 0,rgba(255,248,225,.93) 52%,rgba(255,248,225,0) 100%)}
.logo{position:absolute;left:96px;top:110px;width:132px;height:132px;border-radius:36px;
  background:#fff url(logo.png) center/118% no-repeat;box-shadow:0 14px 34px rgba(78,52,46,.16)}
.kick{position:absolute;left:100px;top:470px;font-size:44px;font-weight:800;color:#8D6E63;letter-spacing:.04em}
.name{position:absolute;left:86px;top:530px;font-size:250px;font-weight:900;line-height:.96;letter-spacing:-.05em;color:#4E342E}
.name .y{color:#FAC710}
.tag{position:absolute;left:100px;top:1060px;font-size:58px;font-weight:800;line-height:1.4;letter-spacing:-.02em;color:#4E342E}
.hl{background:linear-gradient(transparent 58%,#FAC710 58%,#FAC710 92%,transparent 92%);padding:0 6px}
/* 가운데: 폰 */
.phone{position:absolute;left:1325px;top:150px;width:590px;height:1180px;border-radius:84px;
  border:20px solid #3A2C26;background:#3A2C26 url(01_map.jpg) center top/100% auto no-repeat;
  transform:rotate(-4deg);box-shadow:0 60px 110px rgba(78,52,46,.35),0 0 0 2px rgba(255,255,255,.4)}
/* 오른쪽: 동네 장면 */
.mk{position:absolute;width:118px;filter:drop-shadow(0 10px 10px rgba(78,52,46,.25))}
.cl{position:absolute;display:grid;place-items:center;border-radius:50%;background:#FAC710;
  border:7px solid #fff;color:#4E342E;font-weight:900;box-shadow:0 10px 22px rgba(78,52,46,.22)}
.me{position:absolute;width:44px;height:44px;border-radius:50%;background:#2F80ED;border:9px solid #fff;
  box-shadow:0 0 0 26px rgba(47,128,237,.18)}
.toast{position:absolute;padding:28px 36px;border-radius:34px;background:rgba(255,248,225,.96);
  box-shadow:0 18px 40px rgba(78,52,46,.22);font-size:38px;font-weight:800;color:#4E342E;line-height:1.35}
.toast small{display:block;font-size:30px;font-weight:700;color:#8D6E63}
.toast b{color:#D84315}
"""


def pinned_body():
    R = 2160
    scene = (
        f"<img class=mk src=marker_yellow.png style='left:{R + 170}px;top:330px'>"
        f"<img class=mk src=marker_red.png style='left:{R + 640}px;top:520px'>"
        f"<img class=mk src=marker_yellow.png style='left:{R + 420}px;top:860px'>"
        f"<img class=mk src=marker_yellow.png style='left:{R + 820}px;top:1080px'>"
        f"<div class=cl style='left:{R + 470}px;top:250px;width:130px;height:130px;font-size:54px'>3</div>"
        f"<div class=cl style='left:{R + 160}px;top:1060px;width:160px;height:160px;font-size:62px'>12</div>"
        f"<div class=me style='left:{R + 560}px;top:760px'></div>"
        f"<div class=toast style='left:{R + 300}px;top:600px'>🔥 <b>게스트 급구</b> · 토 19:00"
        "<small>센터 1명 · 여자 레프트 1명</small></div>")
    return ("<div class=pano>" + map_svg() + "<div class=veil></div>"
            "<div class=logo></div><div class=kick>전국 배구 동호회 지도</div>"
            "<div class=name>누룽<br><span class=y>지도</span></div>"
            "<div class=tag>우리 동네 배구,<br><span class=hl>지도 한 눈에</span></div>"
            "<div class=phone></div>" + scene + "</div>")


def stage_assets(work):
    shutil.copyfile(FONTS / "PretendardVariable.ttf", work / "PretendardVariable.ttf")
    shutil.copyfile(ROOT / "assets" / "nulloongzido logo_without bg.png", work / "logo.png")
    for c in ("yellow", "red"):
        shutil.copyfile(ROOT / "assets" / "markers" / f"marker_{c}.png", work / f"marker_{c}.png")
    shutil.copyfile(SHOTS / "01_map.jpg", work / "01_map.jpg")


# ── 가이드 · 미리보기 ────────────────────────────────────────
def guide_body():
    parts = ["<div style='position:relative;width:3240px;height:1440px;background:#fff'>"]
    labels = ("③ 왼쪽 · 마지막에 업로드/고정", "② 가운데", "① 오른쪽 · 가장 먼저 업로드/고정")
    for i in range(3):
        x = i * TW
        parts.append(f"<div style='position:absolute;left:{x}px;top:0;width:{TW}px;height:{TH}px;"
                     f"outline:4px solid #4E342E;outline-offset:-2px'>"
                     f"<div style='position:absolute;left:{SEAM}px;right:{SEAM}px;top:60px;bottom:60px;"
                     f"border:4px dashed #43A047'></div>"
                     f"<div style='position:absolute;right:0;top:0;width:{PIN}px;height:{PIN}px;"
                     f"background:rgba(229,57,53,.18);border:4px solid #E53935;display:grid;place-items:center;"
                     f"font-size:30px;font-weight:800;color:#C62828;text-align:center'>핀<br>자리</div>"
                     f"<div style='position:absolute;left:{SEAM + 30}px;bottom:100px;font-size:46px;font-weight:800'>"
                     f"{labels[i]}</div>"
                     f"<div style='position:absolute;left:{SEAM + 30}px;bottom:50px;font-size:32px;color:#8D6E63'>"
                     f"x {x}–{x + TW} · 1080×1440 (3:4)</div></div>")
    for i in (1, 2):
        parts.append(f"<div style='position:absolute;left:{i * TW - SEAM}px;top:0;width:{SEAM * 2}px;"
                     f"height:{TH}px;background:repeating-linear-gradient(45deg,rgba(229,57,53,.22) 0 12px,"
                     f"transparent 12px 24px)'></div>")
    parts.append("<div style='position:absolute;left:0;right:0;top:620px;text-align:center;font-size:40px;"
                 "color:#8D6E63;font-weight:700;line-height:1.6'>3240 × 1440 · 빨간 빗금 = 이음매(글자 금지) · "
                 "빨간 칸 = 고정 핀 아이콘 · 초록 점선 = 글자 안전 영역</div></div>")
    return "".join(parts)


def preview_body(tiles):
    # 폰 화면 비율로 줄인 프로필 — 칸 사이 틈(실제 약 2px @ 390pt)과 핀 아이콘을 그대로 흉내 낸다
    W, gap = 1170, 6
    cw = (W - gap * 2) / 3
    ch = cw * 4 / 3
    pin = ("<svg width=44 height=44 viewBox='0 0 24 24' style='position:absolute;right:16px;top:16px;"
           "filter:drop-shadow(0 1px 2px rgba(0,0,0,.5))'><path fill=#fff d='M16 3l5 5-3 1-4 4 1 5-2 2-4-4-5 5-1-1 "
           "5-5-4-4 2-2 5 1 4-4z'/></svg>")
    cells = []
    for name in ("3_upload_last_L", "2_upload_second_M", "1_upload_first_R"):
        cells.append(f"<div class=c style='background-image:url({tiles[name]})'>{pin}</div>")
    cells += ["<div class='c e'></div>"] * 6
    return (f"<div style='width:{W}px;background:#fff;padding-bottom:40px'>"
            "<div style='display:flex;align-items:center;gap:56px;padding:48px 44px 28px'>"
            "<div style='width:240px;height:240px;border-radius:50%;background:#fff url(logo.png) center/120%;"
            "border:2px solid #ddd'></div><div style='display:flex;gap:70px;font-size:40px;text-align:center'>"
            "<div><b>48</b><br>게시물</div><div><b>1,204</b><br>팔로워</div><div><b>96</b><br>팔로잉</div></div></div>"
            "<div style='padding:0 44px 20px;font-size:38px;line-height:1.45'><b>누룽지도</b><br>"
            "전국 배구 동호회, 지도 한 눈에 🏐<br><span style='color:#00376B'>nulloongzido.app</span></div>"
            "<div style='display:flex;border-top:1px solid #ddd;margin-top:16px'>"
            "<div style='flex:1;text-align:center;padding:26px;border-bottom:3px solid #000;font-size:36px'>▦</div>"
            "<div style='flex:1;text-align:center;padding:26px;font-size:36px;color:#999'>▶</div>"
            "<div style='flex:1;text-align:center;padding:26px;font-size:36px;color:#999'>☺</div></div>"
            f"<div style='display:grid;grid-template-columns:repeat(3,{cw}px);gap:{gap}px'>"
            + "".join(cells) + "</div></div>"), f".c{{position:relative;height:{ch}px;background:#eee center/cover}}" \
        ".e{background:repeating-linear-gradient(45deg,#f2f2f2 0 20px,#e9e9e9 20px 40px)}"


def feed_body(tiles):
    # 홈 피드에선 조각이 각자 한 게시물로 뜬다 — 혼자서도 표지 노릇을 하는지 보는 용도
    posts = []
    for name in ("1_upload_first_R", "2_upload_second_M", "3_upload_last_L"):
        posts.append("<div class=p><div class=h><i></i><b>nulloongzido</b><span>···</span></div>"
                     f"<img src={tiles[name]}><div class=a>♡ &nbsp;💬 &nbsp;➤<span>🔖</span></div></div>")
    css = (".w{display:flex;gap:48px;padding:48px;background:#e9e9e9}"
           ".p{width:720px;background:#fff;border-radius:18px;overflow:hidden}"
           ".h{display:flex;align-items:center;gap:16px;padding:20px 22px;font-size:28px}"
           ".h i{width:56px;height:56px;border-radius:50%;border:2px solid #ddd;background:#fff url(logo.png) center/125%}"
           ".h span,.a span{margin-left:auto}.p img{display:block;width:720px;height:960px}"
           ".a{display:flex;padding:20px 24px 28px;font-size:36px}")
    return f"<div class=w>{''.join(posts)}</div>", css


def finish(chrome, work, pano, out):
    split(pano, out)
    tiles = {}
    for name, _ in TILES:
        shutil.copyfile(out / f"{name}.png", work / f"{name}.png")
        tiles[name] = f"{name}.png"
    body, css = preview_body(tiles)
    shutil.copyfile(page(work, "preview", css, body, 1170, 2300, chrome), out / "preview.png")
    body, css = feed_body(tiles)
    shutil.copyfile(page(work, "feed", css, body, 2400, 1200, chrome), out / "feed.png")
    log(f"→ {out}")


def main():
    if not shutil.which("ffmpeg"):
        die("ffmpeg 가 없습니다.")
    chrome = find_chrome()
    if not chrome:
        die("크롬/엣지를 못 찾았습니다. CHROME=<실행파일 경로> 로 지정하세요.")
    args = sys.argv[1:]
    work = Path(tempfile.mkdtemp(prefix="grid_"))
    try:
        stage_assets(work)
        OUT_ROOT.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(page(work, "guide", "", guide_body(), PW, TH, chrome), OUT_ROOT / "guide.png")
        if args[:1] == ["split"]:
            if len(args) < 2:
                die("사용법: make_grid.py split <3240x1440 이미지>")
            src = Path(args[1]).resolve()
            out = OUT_ROOT / src.stem
            out.mkdir(parents=True, exist_ok=True)
            pano = out / "panorama.png"
            ffmpeg("-i", str(src), "-frames:v", "1", "-vf", f"scale={PW}:{TH}", str(pano))
        else:
            out = OUT_ROOT / "pinned"
            out.mkdir(parents=True, exist_ok=True)
            pano = out / "panorama.png"
            shutil.copyfile(page(work, "pano", PINNED_CSS, pinned_body(), PW, TH, chrome), pano)
        finish(chrome, work, pano, out)
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
