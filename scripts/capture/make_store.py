#!/usr/bin/env python3
"""scripts/capture/make_store.py — Play 스토어 폰 스크린샷 굽기(1080x1920).

크림 바탕 위 두 줄 문구(작은 갈색 윗줄 + 큰 진갈색 제목, 핵심어 노란 밑줄) 아래에
폰 한 대를 통째로 세운다. 화면은 지어내지 않는다 — make_cards 와 같은 card-shots/
고정본(실기기 캡처)을 쓰므로 git pull 만으로 어디서든 같은 그림이 나온다.

스틸은 맨 위 상태 표시줄(시각·알림 아이콘)이 찍혀 있고 흐름 녹화본은 잘려 있다.
둘 다 위 STATUS_CUT 만큼을 걷어 내고 깨끗한 상태 표시줄(9:41)을 그려 넣어 맞춘다.

필요: Python 3.8+(표준 라이브러리만), ffmpeg, 크롬 또는 엣지.

사용법:
  python scripts/capture/make_store.py      # → assets/store/screens/<lang>/01..NN.png
  CHROME=/path/to/chrome python ...

환경변수: CAP_LANG(ko), STORE_SCRIPT, STORE_OUT, CHROME, KEEP_BUILD
"""
import html
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import make_cards as mc  # noqa: E402  같은 도구(크롬 찾기·화면 뽑기·렌더)를 쓴다

LANG_TAG = mc.LANG_TAG
DEF_FILE = Path(os.environ.get("STORE_SCRIPT") or HERE / f"store.{LANG_TAG}.txt")
OUT = Path(os.environ.get("STORE_OUT") or mc.ROOT / "assets" / "store" / "screens" / LANG_TAG)
FONT = mc.FONTS / "PretendardVariable.ttf"

W, H, GAP = 1080, 1920, 40
SCR_W, SCR_H = 1080, 2555      # 폰 화면(원본 좌표): 상태 표시줄 95 + 내용 2460
STATUS_H = 95                  # 그려 넣는 상태 표시줄 높이
STATUS_CUT = {"still": 95, "flow": 0}   # 원본 맨 위에서 걷어 낼 높이(흐름 녹화본은 이미 잘려 있다)
PH_W = 640                     # 화면 폭(px) — 폰이 캔버스 아래 여백 안에 다 들어오는 크기
PH_TOP = 330


def load_defs():
    if not DEF_FILE.is_file():
        mc.die(f"정의가 없습니다: {DEF_FILE}")
    shots = []
    for ln in DEF_FILE.read_text(encoding="utf-8").splitlines():
        if not ln.strip() or ln.lstrip().startswith("#"):
            continue
        f = [x.strip() for x in ln.split("|")]
        if len(f) != 3 or not f[0]:
            mc.die(f"형식 오류(화면 | 윗줄 | 제목): {ln}")
        shots.append(dict(src=f[0], kick=f[1], title=f[2]))
    if not 2 <= len(shots) <= 8:
        mc.die(f"Play 폰 스크린샷은 2~8장입니다(지금 {len(shots)}장).")
    return shots


def hl(s):
    """[말] → 노란 밑줄."""
    return re.sub(r"\[(.+?)\]", r"<em>\1</em>", html.escape(s))


STATUS_SVG = (
    # 신호·와이파이·배터리 — 실제 폰 알림 아이콘 대신 중립적인 기본 모양
    '<svg viewBox="0 0 230 50" width="230" height="50">'
    '<g fill="#4E342E">'
    '<rect x="0" y="32" width="9" height="14" rx="2"/><rect x="14" y="24" width="9" height="22" rx="2"/>'
    '<rect x="28" y="15" width="9" height="31" rx="2"/><rect x="42" y="6" width="9" height="40" rx="2"/>'
    '<path d="M98 46 l-10 -12 a16 16 0 0 1 20 0z"/>'
    '<path d="M78 22 a30 30 0 0 1 40 0 l-5 6 a22 22 0 0 0 -30 0z"/>'
    '<path d="M70 13 a42 42 0 0 1 56 0 l-5 6 a34 34 0 0 0 -46 0z"/>'
    '<rect x="150" y="10" width="66" height="34" rx="9" fill="none" stroke="#4E342E" stroke-width="4"/>'
    '<rect x="156" y="16" width="46" height="22" rx="4"/><rect x="220" y="20" width="6" height="14" rx="2"/>'
    '</g></svg>')


def shot_html(i, s):
    kind = "still" if s["src"].startswith("still:") else "flow"
    k = PH_W / SCR_W
    cut = STATUS_CUT[kind]
    scr = (f'<div class=scr style="background-image:url(img/{i:02d}.png);'
           f'background-size:{PH_W}px auto;background-position:0 {(STATUS_H - cut) * k:.1f}px"></div>')
    return (f'<section class=s><div class=kick>{hl(s["kick"])}</div>'
            f'<div class=title>{hl(s["title"])}</div>'
            f'<div class=phone>{scr}<div class=bar><b>9:41</b>{STATUS_SVG}</div></div></section>')


def build_html(shots):
    k = PH_W / SCR_W
    css = f"""
@font-face{{font-family:Pretendard;src:url(PretendardVariable.ttf);font-weight:100 900}}
*{{box-sizing:border-box;margin:0;padding:0}}
body{{background:#888;font-family:Pretendard,sans-serif}}
.s{{position:relative;width:{W}px;height:{H}px;overflow:hidden;margin:0 0 {GAP}px;
 background:radial-gradient(ellipse 900px 700px at 50% 78%,#FFEFB8 0,rgba(255,239,184,0) 70%),#FFF8E1}}
.kick{{position:absolute;left:0;right:0;top:98px;text-align:center;color:#8D6E63;
 font-size:48px;font-weight:700;letter-spacing:-1px}}
.title{{position:absolute;left:0;right:0;top:162px;text-align:center;color:#4E342E;
 font-size:88px;font-weight:800;letter-spacing:-3px;line-height:1.1}}
em{{font-style:normal;background:linear-gradient(transparent 58%,#FAC710 58%,#FAC710 92%,transparent 92%);
 padding:0 6px}}
.kick em{{background:none;padding:0}}
.phone{{position:absolute;left:{(W - PH_W) / 2 - 16:.0f}px;top:{PH_TOP}px;width:{PH_W + 32}px;
 height:{SCR_H * k + 32:.0f}px;border-radius:78px;background:#3A2C26;padding:16px;
 box-shadow:0 30px 60px rgba(78,52,46,.22),0 4px 10px rgba(78,52,46,.18)}}
.scr{{position:absolute;inset:16px;border-radius:62px;background-color:#FFF8E1;background-repeat:no-repeat}}
.bar{{position:absolute;left:16px;right:16px;top:16px;height:{STATUS_H * k:.0f}px;border-radius:62px 62px 0 0;
 background:#FFF8E1;display:flex;align-items:center;justify-content:space-between;padding:0 46px 0 54px}}
.bar b{{font-size:{38 * k:.0f}px;font-weight:700;color:#4E342E}}
.bar svg{{width:{230 * k * .62:.0f}px;height:auto}}
"""
    body = "\n".join(shot_html(i + 1, s) for i, s in enumerate(shots))
    return (f"<!doctype html><html lang={LANG_TAG}><head><meta charset=utf-8><style>{css}</style>"
            f"</head><body>{body}</body></html>")


def main():
    if not shutil.which("ffmpeg"):
        mc.die("ffmpeg 가 없습니다.")
    chrome = mc.find_chrome()
    if not chrome:
        mc.die("크롬/엣지를 못 찾았습니다. CHROME=<실행파일 경로> 로 지정하세요.")
    if not FONT.is_file():
        mc.die(f"글꼴이 없습니다: {FONT}")
    shots = load_defs()
    mc.log(f"스토어 {len(shots)}장 · {DEF_FILE.name} · 크롬: {chrome}")
    work = Path(tempfile.mkdtemp(prefix="store_"))
    try:
        shutil.copyfile(FONT, work / FONT.name)
        (work / "img").mkdir()
        for i, s in enumerate(shots, 1):
            mc.log(f"{i:02d} 화면 ← {s['src']}")
            mc.grab(s["src"], work / "img" / f"{i:02d}.png")
        page = work / "store.html"
        page.write_text(build_html(shots), encoding="utf-8")
        strip = work / "strip.png"
        mc.render(chrome, page, strip, len(shots) * (H + GAP))
        OUT.mkdir(parents=True, exist_ok=True)
        for old in OUT.glob("*.png"):
            old.unlink()
        for i in range(len(shots)):
            mc.ffmpeg("-i", str(strip), "-frames:v", "1",
                      "-vf", f"crop={W}:{H}:0:{i * (H + GAP)}", str(OUT / f"{i + 1:02d}.png"))
        mc.log(f"완료 → {OUT}")
    finally:
        if os.environ.get("KEEP_BUILD"):
            mc.log(f"중간물: {work}")
        else:
            shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
