#!/usr/bin/env python3
"""scripts/capture/make_cards.py — 손글씨 주석 카드뉴스 굽기(인스타 3:4, 1080x1440).

한 편 = 기능 하나. 실제 앱 화면을 둥근 카드로 잘라 도트 노트 종이 위에 붙이고,
그 위에 손으로 필기한 듯 사용법을 적는다(제목 검정 펜글씨 · 설명 파랑 ·
누를 곳 빨간 동그라미 · 키워드 노란 형광펜). 편 정의는 handnote.<lang>.txt.

모든 장이 같은 틀을 쓴다 — 위아래·좌우 여백이 장마다 흔들리지 않게:
  제목      top 52
  파란 설명 top 190 (최대 2줄)
  화면 카드 x 54~1026, y 400~1300 (972x900)
  페이지    오른쪽 아래

화면은 지어내지 않는다 — 스틸과 흐름 녹화본(CAPTURE_BEAT 시각)에서 뽑아 폭 1080 으로
맞춘다. 정의 파일의 좌표(y0, 동그라미)는 전부 그 폭 1080 기준이다.
HTML/CSS 로 짜고 헤드리스 크롬으로 렌더한다. 마커 질감은 handnote.js.

필요: Python 3.8+(표준 라이브러리만), ffmpeg, 크롬 또는 엣지.

사용법:
  python scripts/capture/make_cards.py            # 전 편 → marketing-assets/cards/handnote/<편>/01..NN.png
  POSTS=collect python scripts/capture/make_cards.py
  CHROME=/path/to/chrome python ...
  KEEP_BUILD=1 python ...                          # 중간물(slides.html 등) 남기기

환경변수: ARTIFACTS_DIR, CAP_LANG(ko), CARDS_SCRIPT, POSTS, SETTLE(1.0), CHROME, KEEP_BUILD
"""
import glob
import html
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:  # Git Bash / cp949 콘솔에서 ▶·✗ 때문에 죽지 않게
    sys.stdout.reconfigure(errors="replace")
    sys.stderr.reconfigure(errors="replace")
except AttributeError:
    pass

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
ART = Path(os.environ.get("ARTIFACTS_DIR") or ROOT / "marketing-assets")
LANG_TAG = os.environ.get("CAP_LANG", "ko")
CARDS_FILE = Path(os.environ.get("CARDS_SCRIPT") or HERE / f"handnote.{LANG_TAG}.txt")
ONLY = [p for p in os.environ.get("POSTS", "").replace(",", " ").split() if p]
STILLS = ART / "stills"
FLOWS = ART / "reels" / "flows"
OUT_ROOT = ART / "cards" / "handnote"
FONTS = ROOT / "assets" / "fonts"
FONT_FILES = ("NanumPenScript-Regular.ttf", "NanumBrushScript-Regular.ttf", "PoorStory-Regular.ttf")
JS = HERE / "handnote.js"
SETTLE = float(os.environ.get("SETTLE", "1.0"))  # 전환 애니메이션이 가라앉을 시간

SW, SH, GAP = 1080, 1440, 40                 # 한 장, 렌더 시 장 사이 간격
CX0, CX1, CT, CH = 54, 1026, 400, 900        # 화면 카드 틀(전 장 공통)


def log(m): print(f"\033[1;33m▶ {m}\033[0m", flush=True)
def warn(m): print(f"\033[0;35m! {m}\033[0m", file=sys.stderr, flush=True)
def die(m):
    print(f"\033[1;31m✗ {m}\033[0m", file=sys.stderr, flush=True)
    sys.exit(1)


# ── 도구 ─────────────────────────────────────────────────────
def find_chrome():
    env = os.environ.get("CHROME")
    if env:
        return env
    cands = []
    for base in (os.environ.get("PROGRAMFILES"), os.environ.get("PROGRAMFILES(X86)"),
                 os.environ.get("LOCALAPPDATA"), r"C:\Program Files", r"C:\Program Files (x86)"):
        if base:
            cands += [os.path.join(base, "Google", "Chrome", "Application", "chrome.exe"),
                      os.path.join(base, "Microsoft", "Edge", "Application", "msedge.exe")]
    cands += ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"]
    for c in cands:
        if os.path.isfile(c):
            return c
    for n in ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser",
              "chrome", "msedge"):
        p = shutil.which(n)
        if p:
            return p
    pw = os.environ.get("PLAYWRIGHT_BROWSERS_PATH", "/opt/pw-browsers")
    for p in sorted(glob.glob(os.path.join(pw, "chromium-*", "chrome-*", "chrome")), reverse=True):
        return p
    return None


def ffmpeg(*args):
    r = subprocess.run(["ffmpeg", "-y", "-v", "error", *args],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if r.returncode != 0:
        die("ffmpeg 실패: " + r.stderr.decode("utf-8", "replace").strip()[-400:])


# ── 편 정의 ──────────────────────────────────────────────────
def load_posts():
    if not CARDS_FILE.is_file():
        die(f"카드 정의가 없습니다: {CARDS_FILE}")
    posts, cur = [], None
    for ln in CARDS_FILE.read_text(encoding="utf-8").splitlines():
        if not ln.strip() or ln.lstrip().startswith("#"):
            continue
        f = [x.strip() for x in ln.split("|")]
        kind = f[0]
        if kind == "post":
            cur = {"id": f[1], "slides": []}
            posts.append(cur)
            continue
        need = {"cover": 6, "step": 5}.get(kind)
        if need is None or len(f) < need or cur is None:
            die(f"형식 오류: {ln}")
        f += [""] * (8 - len(f))
        if kind == "cover":
            _, src, y0, kick, title, side, marks = f[:7]
            cur["slides"].append(dict(kind=kind, src=src, y0=int(y0), kick=kick,
                                      title=title, side=side, marks=marks))
        else:
            _, src, y0, title, cap, marks = f[:6]
            cur["slides"].append(dict(kind=kind, src=src, y0=int(y0), title=title,
                                      cap=cap, marks=marks))
    if ONLY:
        posts = [p for p in posts if p["id"] in ONLY]
    if not posts:
        die(f"만들 편이 없습니다: {CARDS_FILE}" + (f" (POSTS={' '.join(ONLY)})" if ONLY else ""))
    return posts


_seed = [0]
def txt(s):
    """문구 → HTML. \\n 은 줄바꿈, [말] 은 형광펜."""
    def hl(m):
        _seed[0] += 1
        return f'<span class=hl data-seed={_seed[0] * 4 + 3}>{m.group(1)}</span>'
    return re.sub(r"\[(.+?)\]", hl, html.escape(s)).replace("\\n", "<br>")


# ── 화면 추출(폭 1080 으로) ──────────────────────────────────
def read_frame():
    """frame.txt: '<x0> <y0> <폭> <높이> ...' — 녹화본 안에서 폰 화면 위치."""
    fp = FLOWS / "frame.txt"
    if fp.is_file():
        v = fp.read_text().split()
        if len(v) >= 4:
            return tuple(int(float(x)) for x in v[:4])
    return None


def beat_at(flow, label):
    bf = FLOWS / f"{flow}_beats.txt"
    if not bf.is_file():
        return None
    for ln in bf.read_text(encoding="utf-8", errors="replace").splitlines():
        p = ln.split()
        if len(p) >= 2 and p[0] == label:
            return float(p[1])
    return None


def grab(src, out):
    scale = "scale=1080:-2:flags=lanczos"
    if src.startswith("still:"):
        p = STILLS / f"{src[6:]}.png"
        if not p.is_file():
            die(f"스틸 없음: {p}")
        ffmpeg("-i", str(p), "-frames:v", "1", "-vf", scale, str(out))
        return
    m = re.fullmatch(r"([\w-]+)@([\w.-]+?)(?:\+([\d.]+))?", src)
    if not m:
        die(f"화면 출처 형식 오류: {src}")
    flow, label, extra = m.group(1), m.group(2), float(m.group(3) or 0)
    mp4 = FLOWS / f"{flow}_{LANG_TAG}.mp4"
    if not mp4.is_file():
        die(f"녹화본 없음: {mp4} (먼저 local_capture.sh)")
    if re.fullmatch(r"[\d.]+", label):
        t = float(label) + extra
    else:
        b = beat_at(flow, label)
        if b is None:
            die(f"비트 없음: {flow}/{label} ({FLOWS / (flow + '_beats.txt')})")
        t = b + SETTLE + extra
    frame = read_frame()
    vf = (f"crop={frame[2]}:{frame[3]}:{frame[0]}:{frame[1]}," if frame else "") + scale
    ffmpeg("-ss", f"{t:.2f}", "-i", str(mp4), "-frames:v", "1", "-vf", vf, str(out))


# ── 슬라이드 HTML ────────────────────────────────────────────
def marks_html(marks, y0, base_seed):
    """'circle x y w h [pad]; word 여기! x y' → 측정용 표식(원본 좌표 → 슬라이드 좌표)."""
    out = []
    for i, m in enumerate(x.strip() for x in marks.split(";") if x.strip()):
        p = m.split()
        seed = base_seed * 10 + i + 1
        if p[0] == "circle" and len(p) >= 5:
            x, y, w, h = map(int, p[1:5])
            pad = int(p[5]) if len(p) > 5 else 20
            out.append(f'<i class=t data-mark=circle data-seed={seed} data-pad={pad} '
                       f'style="left:{x}px;top:{CT + y - y0}px;width:{w}px;height:{h}px"></i>')
        elif p[0] == "word" and len(p) >= 4:
            word, x, y = p[1], int(p[2]), int(p[3])
            out.append(f'<div class="hw red" data-mark=word style="left:{x}px;top:{CT + y - y0}px;'
                       f'transform:rotate(-4deg)">{html.escape(word)}</div>')
        else:
            die(f"표시 형식 오류: {m}")
    return "".join(out)


def slide_html(i, n, s):
    card = (f'<div class=card style="background-image:url(img/{i:02d}.png);'
            f'background-position:-{CX0}px -{s["y0"]}px"></div>')
    page = f'<div class="hw page">{i}/{n}</div>'
    marks = marks_html(s["marks"], s["y0"], i)
    if s["kind"] == "cover":
        body = (f'<div class="hw red kick">{txt(s["kick"])}</div>'
                f'<div class="hw cover">{txt(s["title"])}</div>'
                + (f'<div class="hw note side">{txt(s["side"])}</div>' if s["side"] else ""))
    else:
        body = (f'<div class="hw title">{txt(s["title"])}</div>'
                f'<div class="hw note cap">{txt(s["cap"])}</div>')
    return f'<section class=slide>{card}{body}{marks}{page}</section>'


CSS = """
@font-face{font-family:PenScript;src:url(NanumPenScript-Regular.ttf)}
@font-face{font-family:Brush;src:url(NanumBrushScript-Regular.ttf)}
@font-face{font-family:PoorStory;src:url(PoorStory-Regular.ttf)}
:root{--red:#E0463A;--blue:#2F4DA8;--ink:#1F1F22;--hl:#FFE45C;--bg:#FBF8F1}
*{box-sizing:border-box;margin:0;padding:0}
body{background:#888}
/* 도트 노트 종이 */
.slide{position:relative;width:1080px;height:1440px;overflow:hidden;margin:0 0 __GAP__px;
 background:radial-gradient(circle,rgba(141,110,99,.22) 1.6px,transparent 2px) 18px 18px/36px 36px,var(--bg)}
/* 화면 카드 — 전 장 같은 자리. 라운드는 앱 패널 모서리보다 커서 뒤 배경이 안 비친다 */
.card{position:absolute;left:__CX0__px;top:__CT__px;width:__CW__px;height:__CH__px;
 background-size:1080px auto;background-repeat:no-repeat;border-radius:70px;
 box-shadow:0 8px 32px rgba(93,64,55,.15),0 1px 3px rgba(93,64,55,.12)}
i.t{position:absolute;display:block}
svg.layer{position:absolute;inset:0;width:1080px;height:1440px;pointer-events:none}
svg.under{mix-blend-mode:multiply;z-index:2}
.hw{position:absolute;z-index:3;white-space:nowrap}
svg.over{z-index:4;mix-blend-mode:multiply}
.title{font-family:PenScript;color:var(--ink);font-size:104px;line-height:1;left:56px;top:52px;transform:rotate(-1.2deg);transform-origin:left}
.note{font-family:PoorStory;color:var(--blue);font-size:54px;line-height:1.25;letter-spacing:-1px}
.cap{left:72px;top:190px;transform:rotate(-1.5deg);transform-origin:left}
.red{font-family:Brush;color:var(--red);font-size:74px;line-height:1}
.kick{left:64px;top:44px;font-size:60px;transform:rotate(-3deg)}
.cover{font-family:PenScript;color:var(--ink);font-size:124px;line-height:1.02;left:66px;top:112px;transform:rotate(-2deg);transform-origin:left}
.side{left:640px;top:300px;font-size:48px;transform:rotate(-3deg)}
.page{font-family:PenScript;color:var(--ink);font-size:58px;right:52px;bottom:40px;opacity:.75}
"""


def build_html(slides):
    css = (CSS.replace("__GAP__", str(GAP)).replace("__CX0__", str(CX0)).replace("__CT__", str(CT))
           .replace("__CW__", str(CX1 - CX0)).replace("__CH__", str(CH)))
    n = len(slides)
    body = "\n".join(slide_html(i + 1, n, s) for i, s in enumerate(slides))
    return (f"<!doctype html><html lang=ko><head><meta charset=utf-8><style>{css}</style></head>"
            f"<body>{body}<script src=handnote.js></script></body></html>")


# ── 렌더 ─────────────────────────────────────────────────────
def render(chrome, html_path, png_path, height):
    prof = html_path.parent / "chrome-profile"   # 켜져 있는 크롬과 프로필이 안 엉키게
    # 헤드리스 창은 실제 그려지는 영역이 창 크기보다 조금 작다 → 여유를 둔다
    cmd = [chrome, "--headless", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
           "--no-first-run", "--no-default-browser-check", f"--user-data-dir={prof}",
           "--allow-file-access-from-files", "--force-device-scale-factor=1",
           "--virtual-time-budget=5000", f"--window-size={SW},{height + 200}",
           f"--screenshot={png_path}", html_path.as_uri()]
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=str(html_path.parent))
    if not png_path.is_file() or png_path.stat().st_size == 0:
        die("크롬 렌더 실패 (CHROME 로 경로를 지정해 보세요):\n"
            + r.stderr.decode("utf-8", "replace").strip()[-600:])


def make_post(chrome, post, work):
    slides = post["slides"]
    n = len(slides)
    d = work / post["id"]
    d.mkdir()
    for f in FONT_FILES:
        shutil.copyfile(FONTS / f, d / f)
    shutil.copyfile(JS, d / "handnote.js")
    (d / "img").mkdir()
    for i, s in enumerate(slides, 1):
        log(f"{post['id']} {i:02d} 화면 ← {s['src']}")
        grab(s["src"], d / "img" / f"{i:02d}.png")
    html_path = d / "slides.html"
    html_path.write_text(build_html(slides), encoding="utf-8")
    strip = d / "strip.png"
    render(chrome, html_path, strip, n * (SH + GAP))
    out = OUT_ROOT / post["id"]
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.png"):
        old.unlink()
    for i in range(n):
        ffmpeg("-i", str(strip), "-frames:v", "1",
               "-vf", f"crop={SW}:{SH}:0:{i * (SH + GAP)}", str(out / f"{i + 1:02d}.png"))
    log(f"{post['id']}: {n}장 → {out}")


def main():
    if not shutil.which("ffmpeg"):
        die("ffmpeg 가 없습니다.")
    chrome = find_chrome()
    if not chrome:
        die("크롬/엣지를 못 찾았습니다. CHROME=<실행파일 경로> 로 지정하세요.")
    for p in [FONTS / f for f in FONT_FILES] + [JS]:
        if not p.is_file():
            die(f"에셋이 없습니다: {p}")
    posts = load_posts()
    log(f"{len(posts)}편 · {CARDS_FILE.name} · 크롬: {chrome}")
    work = Path(tempfile.mkdtemp(prefix="handnote_"))
    try:
        for post in posts:
            make_post(chrome, post, work)
        log(f"완료 → {OUT_ROOT}")
    finally:
        if os.environ.get("KEEP_BUILD"):
            log(f"중간물: {work}")
        else:
            shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
