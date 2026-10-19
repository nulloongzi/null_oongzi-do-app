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
그리고 marketing-assets/grid/guide.png — 직접 디자인할 때 깔고 쓰는 안전 영역 가이드.

안전 영역 (각 조각 기준):
  - 오른쪽 위 170x170 비우기: 고정 게시물엔 핀 아이콘이 여기 뜬다.
  - 이음매 좌우 40px 안에는 글자를 두지 않기: 프로필 칸 사이 흰 틈에 글자가 끊긴다.
  - 홈 피드에선 조각이 한 장씩 따로 보인다 → 조각마다 혼자서도 말이 되게.

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
PINNED_CSS = """
.pano{position:relative;width:3240px;height:1440px;overflow:hidden;
  background:radial-gradient(900px 700px at 1620px 640px,#FFE9A3 0%,rgba(255,233,163,0) 70%),#FFF8E1}
.dots{position:absolute;inset:0;background-image:radial-gradient(#E9DDB6 2.4px,transparent 2.6px);
  background-size:44px 44px;opacity:.55}
.arc{position:absolute;inset:0}
.net{position:absolute;left:0;right:0;top:1196px;height:132px;
  background:
   repeating-linear-gradient(90deg,rgba(78,52,46,.16) 0 3px,transparent 3px 44px),
   repeating-linear-gradient(0deg,rgba(78,52,46,.16) 0 3px,transparent 3px 44px);
  border-top:16px solid #4E342E;border-bottom:6px solid rgba(78,52,46,.35)}
.floor{position:absolute;left:0;right:0;top:1334px;bottom:0;background:#F5E6B8}
.tile{position:absolute;top:0;width:1080px;height:1440px}
.t0{left:0}.t1{left:1080px}.t2{left:2160px}

/* 왼쪽 — 브랜드 */
.logo{position:absolute;left:96px;top:120px;width:150px;height:150px;border-radius:40px;
  background:#fff url(logo.png) center/118% no-repeat;box-shadow:0 14px 34px rgba(78,52,46,.16)}
.kick{position:absolute;left:100px;top:330px;font-size:44px;font-weight:800;color:#8D6E63;letter-spacing:.04em}
.name{position:absolute;left:88px;top:392px;font-size:236px;font-weight:900;line-height:.98;letter-spacing:-.045em}
.name .y{color:#FAC710}
.tag{position:absolute;left:100px;top:880px;font-size:64px;font-weight:800;line-height:1.36;letter-spacing:-.02em}
.hl{background:linear-gradient(transparent 58%,#FAC710 58%,#FAC710 92%,transparent 92%);padding:0 6px}

/* 가운데 — 앱 화면 */
.phone{position:absolute;left:285px;top:96px;width:510px;height:1050px;border-radius:72px;
  border:18px solid #3A2C26;background:#3A2C26 url(map.jpg) center top/100% auto no-repeat;
  box-shadow:0 40px 80px rgba(78,52,46,.28)}
.mk{position:absolute;width:112px}
.badge{position:absolute;padding:20px 34px;border-radius:999px;background:#fff;
  border:4px solid #EAD9A0;font-size:42px;font-weight:800;box-shadow:0 12px 26px rgba(78,52,46,.12)}

/* 오른쪽 — 행동 유도 */
.cta-k{position:absolute;left:110px;top:440px;font-size:44px;font-weight:800;color:#8D6E63;letter-spacing:.04em}
.cta{position:absolute;left:104px;top:500px;font-size:104px;font-weight:900;line-height:1.14;letter-spacing:-.04em}
.steps{position:absolute;left:110px;top:780px;display:flex;flex-direction:column;gap:22px}
.step{display:flex;align-items:center;gap:28px;font-size:48px;font-weight:800}
.step b{display:grid;place-items:center;width:76px;height:76px;border-radius:50%;
  background:#4E342E;color:#FAC710;font-size:42px;font-weight:900}
.link{position:absolute;left:110px;top:1068px;padding:22px 40px;border-radius:999px;background:#FAC710;
  font-size:46px;font-weight:900;box-shadow:0 10px 0 #E0A800}
.ball{position:absolute;left:95px;top:225px;width:150px;height:150px;border-radius:50%;
  background:radial-gradient(circle at 34% 28%,#fff,#FAC710 70%,#F0B800);
  box-shadow:0 18px 30px rgba(216,67,21,.25)}
.ball::before,.ball::after{content:"";position:absolute;inset:0;border-radius:50%;border:4px solid #E0A800;opacity:.55}
.ball::before{transform:scaleX(.4)}.ball::after{transform:scaleY(.4)}
"""

PINNED_BODY = """
<div class=pano>
  <div class=dots></div>
  <div class=floor></div>
  <div class=net></div>
  <!-- 세 조각을 가로지르는 공 궤적: 이음매를 넘는 요소가 있어야 한 장으로 읽힌다 -->
  <svg class=arc width=3240 height=1440 viewBox="0 0 3240 1440">
    <path d="M 560 1150 Q 1500 -150, 2330 300" fill=none stroke="#E0A800"
          stroke-width=12 stroke-linecap=round stroke-dasharray="4 34" opacity=.9 />
  </svg>

  <div class="tile t0">
    <div class=logo></div>
    <div class=kick>전국 배구 동호회 지도</div>
    <div class=name>누룽<br><span class=y>지도</span></div>
    <div class=tag>배구할 팀,<br><span class=hl>지도 한 눈에</span></div>
  </div>

  <div class="tile t1">
    <div class=phone></div>
    <img class=mk src=marker_yellow.png style="left:120px;top:430px;transform:rotate(-10deg)">
    <img class=mk src=marker_red.png style="left:850px;top:720px;transform:rotate(8deg)">
    <div class=badge style="left:96px;top:880px">동호회</div>
    <div class=badge style="left:760px;top:330px">픽업</div>
  </div>

  <div class="tile t2">
    <div class=cta-k>지금 시작하기</div>
    <div class=cta>우리 팀도<br>지도에 올려요</div>
    <div class=steps>
      <div class=step><b>1</b>앱 받기</div>
      <div class=step><b>2</b>팀 등록</div>
      <div class=step><b>3</b>모집 글 올리기</div>
    </div>
    <div class=link>프로필 링크에서 다운로드</div>
    <div class=ball></div>
  </div>
</div>
"""


def stage_assets(work):
    shutil.copyfile(FONTS / "PretendardVariable.ttf", work / "PretendardVariable.ttf")
    shutil.copyfile(ROOT / "assets" / "nulloongzido logo_without bg.png", work / "logo.png")
    for c in ("yellow", "red"):
        shutil.copyfile(ROOT / "assets" / "markers" / f"marker_{c}.png", work / f"marker_{c}.png")
    shutil.copyfile(SHOTS / "01_map.jpg", work / "map.jpg")


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


def finish(chrome, work, pano, out):
    split(pano, out)
    tiles = {}
    for name, _ in TILES:
        shutil.copyfile(out / f"{name}.png", work / f"{name}.png")
        tiles[name] = f"{name}.png"
    body, css = preview_body(tiles)
    shutil.copyfile(page(work, "preview", css, body, 1170, 2300, chrome), out / "preview.png")
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
            shutil.copyfile(page(work, "pano", PINNED_CSS, PINNED_BODY, PW, TH, chrome), pano)
        finish(chrome, work, pano, out)
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
