#!/usr/bin/env python3
"""scripts/capture/make_cards.py — 인스타 캐러셀(카드뉴스) 굽기.

한 편을 1080x1920 × N장이 이어진 긴 띠(1080N x 1920) 하나로 디자인하고 장 단위로
자른다. 배경의 배구 코트(평면 오블리크, 좌측 낮은 사선, 네트는 전체에 하나)가
장 경계를 넘어 이어져서 넘길 때 화면이 끊기지 않는다. 폰 화면은 경계를 넘지 않는다.

디자인은 웹앱 디자인 시스템(null_oongzi-do/docs/design-system.md)을 따른다:
크림 배경 · 노랑은 포인트/CTA만 · 브라운 톤 그림자(검정 금지) · Pretendard 800.
HTML/CSS 로 짜고 헤드리스 크롬으로 렌더한다. 화면은 지어내지 않는다 — 스틸과
흐름 녹화본(CAPTURE_BEAT 시각)에서 뽑아 일반 폰 비율(9:19.5)로 자른다.

필요: Python 3.8+(표준 라이브러리만), ffmpeg, 크롬 또는 엣지.

사용법:
  python scripts/capture/make_cards.py            # → marketing-assets/cards/carousel/01..NN.png
  CHROME=/path/to/chrome python scripts/capture/make_cards.py
  KEEP_BUILD=1 python ...                          # 중간물(strip.html 등) 남기기

환경변수: ARTIFACTS_DIR, CAP_LANG(ko), CARDS_SCRIPT, SETTLE(1.0), CHROME, KEEP_BUILD
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
CARDS_FILE = Path(os.environ.get("CARDS_SCRIPT") or HERE / f"carousel.{LANG_TAG}.txt")
STILLS = ART / "stills"
FLOWS = ART / "reels" / "flows"
OUT = ART / "cards" / "carousel"
FONT = ROOT / "assets" / "fonts" / "PretendardVariable.ttf"
LOGO = ROOT / "assets" / "nulloongzido logo_without bg.png"
SETTLE = float(os.environ.get("SETTLE", "1.0"))  # 전환 애니메이션이 가라앉을 시간

SW, SH = 1080, 1920          # 한 장
PHONE_RATIO = 19.5 / 9       # 일반 폰(Z 플립 9:22 아님)


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


# ── 슬라이드 정의 ────────────────────────────────────────────
def load_slides():
    if not CARDS_FILE.is_file():
        die(f"슬라이드 정의가 없습니다: {CARDS_FILE}")
    slides = []
    for ln in CARDS_FILE.read_text(encoding="utf-8").splitlines():
        if not ln.strip() or ln.lstrip().startswith("#"):
            continue
        f = [x.strip() for x in ln.split("|")]
        kind = f[0]
        need = {"cover": 5, "step": 8, "end": 4}.get(kind)
        if need is None or len(f) < need:
            die(f"형식 오류: {ln}")
        slides.append(f)
    if not slides:
        die(f"슬라이드가 없습니다: {CARDS_FILE}")
    return slides


def txt(s):
    """정의 파일 문구 → HTML (\\n 은 줄바꿈)."""
    return html.escape(s).replace("\\n", "<br>")


# ── 화면 추출 ────────────────────────────────────────────────
def read_frame():
    """frame.txt: '<x0> <y0> <폭> <높이> ...' — 녹화본 안에서 폰 화면 위치."""
    fp = FLOWS / "frame.txt"
    if fp.is_file():
        v = fp.read_text().split()
        if len(v) >= 4:
            return tuple(int(float(x)) for x in v[:4])
    warn("frame.txt 없음 — 화면이 프레임을 꽉 채운다고 본다.")
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


def phone_crop(top, bot=None):
    scale = ",scale=1080:-2:flags=lanczos"
    if bot is not None:
        # 위아래를 둘 다 정하면(상태바·아래 군더더기 둘 다 뺄 때) 그 높이에 맞춰
        # 양옆을 가운데 기준으로 살짝 걷어내 9:19.5 를 지킨다.
        return (f"crop=w=trunc(oh/{PHONE_RATIO:.6f}/2)*2:h=trunc(ih*{bot - top:.4f}/2)*2"
                f":x=(iw-ow)/2:y=trunc(ih*{top})" + scale)
    # 폭은 그대로, 높이는 폭×19.5/9. 위에서 top 비율만큼 버리되 아래로 넘치지 않게.
    h = f"min(ih\\,trunc(iw*{PHONE_RATIO:.6f}/2)*2)"
    return f"crop=iw:{h}:0:min(trunc(ih*{top})\\,ih-{h})" + scale


def grab(src, top, bot, out, frame):
    if src.startswith("still:"):
        p = STILLS / f"{src[6:]}.png"
        if not p.is_file():
            die(f"스틸 없음: {p}")
        ffmpeg("-i", str(p), "-frames:v", "1", "-vf", phone_crop(top, bot), str(out))
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
    vf = phone_crop(top, bot)
    if frame:
        x0, y0, fw, fh = frame
        vf = f"crop={fw}:{fh}:{x0}:{y0}," + vf
    ffmpeg("-ss", f"{t:.2f}", "-i", str(mp4), "-frames:v", "1", "-vf", vf, str(out))


# ── 배구 코트(평면 오블리크 · 좌측 낮은 사선) ────────────────
# 표지·마무리 장은 비우고 본문 구간에만 깐다. 네트는 전체에 하나 — 여정 한가운데,
# 슬라이드 경계에 걸쳐서 넘길 때 이어지게. 폭 방향 선은 평행이라 장을 넘어도 연속.
def court_svg(n):
    W, H = SW * n, SH
    yN, yF, dx, netH, period, LW = 1800, 1330, 250, 230, 2160, 7
    X0, X1 = SW, W - SW
    NETX = (X0 + X1) // 2 - 100            # 경계에서 살짝 비껴 걸치게
    ORG = NETX - 1080                      # 라인 패턴 원점(네트가 어택라인 사이 가운데)
    FLOOR, ZONE, MESH, POST = "#EACB93", "#E0BC7E", "#C4A06A", "#8D6E63"

    def L(x1, y1, x2, y2, w, c="#fff", op=1.0):
        return (f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}" stroke="{c}" '
                f'stroke-width="{w}" opacity="{op}" stroke-linecap="round"/>')

    def cross(x):
        return (x, yN, x + dx, yF)

    el = [f'<rect x="{X0}" y="{yF}" width="{X1 - X0}" height="{yN - yF}" fill="{FLOOR}"/>']
    a1, a2 = NETX - 360, NETX + 360        # 네트 앞 존(어택라인 사이)만 한 톤 진하게
    el.append(f'<polygon points="{a1},{yN} {a2},{yN} {a2 + dx},{yF} {a1 + dx},{yF}" fill="{ZONE}"/>')
    el.append(L(X0, yF, X1, yF, LW, op=.9))
    el.append(L(X0, yN, X1, yN, LW, op=.9))
    k = -(ORG - X0) // period - 2
    while ORG + k * period <= X1 + period:
        for off in (0, 720, 1440):
            el.append(L(*cross(ORG + k * period + off), LW, op=.85))
        k += 1
    bx1, by1, bx2, by2 = cross(NETX)
    el.append(f'<polygon points="{bx1},{by1} {bx2},{by2} {bx2},{by2 - netH} {bx1},{by1 - netH}" '
              f'fill="#ffffff" opacity="0.85"/>')
    for i in range(21):                    # 세로 그물
        t = i / 20
        mx, my = bx1 + (bx2 - bx1) * t, by1 + (by2 - by1) * t
        el.append(L(mx, my, mx, my - netH, 2, MESH, 0.5))
    for h in range(0, netH + 1, 22):       # 가로 그물
        el.append(L(bx1, by1 - h, bx2, by2 - h, 2, MESH, 0.5))
    el.append(L(bx1, by1 - netH, bx2, by2 - netH, 8, "#fff"))
    el.append(L(bx1, by1 + 6, bx1, by1 - netH - 34, 10, POST))
    el.append(L(bx2, by2 + 6, bx2, by2 - netH - 34, 10, POST))
    return (f'<svg class=court viewBox="0 0 {W} {H}" preserveAspectRatio="none">'
            f'<defs><clipPath id=cc><rect x="{X0}" y="0" width="{X1 - X0}" height="{H}"/></clipPath></defs>'
            f'<g clip-path="url(#cc)">' + "".join(el) + "</g></svg>")


CSS = """
@font-face{font-family:'P';src:url('pretendard.ttf');font-weight:45 920;font-display:block}
*{margin:0;padding:0;box-sizing:border-box;-webkit-font-smoothing:antialiased}
:root{--y:#FAC710;--br:#8D6E63;--dk:#4E342E;--bg:#FFF8E1;--sh:0 22px 60px rgba(93,64,55,.28)}
html,body{width:__W__px;height:1920px}
body{font-family:'P';background:var(--bg);position:relative;overflow:hidden}
svg.court{position:absolute;inset:0;width:__W__px;height:1920px;z-index:0}
.slide{position:absolute;top:0;width:1080px;height:1920px;padding:120px 96px;z-index:2}
.foot{position:absolute;top:128px;right:96px;display:flex;align-items:center;gap:12px}
.foot img{width:52px;height:52px}.foot b{font-weight:800;font-size:28px;color:var(--dk)}
mark{background:linear-gradient(transparent 55%,var(--y) 55% 93%,transparent 93%);color:inherit;padding:0 .04em}
.cv,.ed{display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;height:100%;padding-bottom:260px}
.cv .logo{width:300px;margin-bottom:44px;filter:drop-shadow(0 16px 40px rgba(93,64,55,.30))}
.cv .kick{font-weight:800;font-size:33px;color:#c39c00;letter-spacing:.14em;margin-bottom:26px}
.cv h1{font-weight:800;font-size:104px;line-height:1.2;letter-spacing:-.02em;color:var(--dk)}
.cv .sub{margin-top:38px;font-weight:500;font-size:37px;color:var(--br);line-height:1.5}
.cv .sw{margin-top:64px;font-weight:700;font-size:30px;color:var(--br)}
.ct .num{font-weight:800;font-size:112px;line-height:.86;color:var(--y);letter-spacing:-.03em;filter:drop-shadow(0 6px 14px rgba(93,64,55,.18))}
.ct .num small{display:block;font-weight:800;font-size:28px;color:var(--br);letter-spacing:.16em;margin-top:8px}
.ct h2{margin-top:18px;font-weight:800;font-size:68px;line-height:1.24;letter-spacing:-.02em;color:var(--dk)}
.ct .desc{margin-top:14px;font-weight:500;font-size:30px;line-height:1.45;color:var(--br);max-width:880px}
.ct .ph{position:absolute;left:50%;transform:translateX(-50%) rotate(-2deg);top:520px;width:560px;border:9px solid #fff;border-radius:44px;overflow:hidden;box-shadow:var(--sh);background:#fff}
.ct .ph img{width:100%;display:block}
.ed .logo{width:260px;margin-bottom:40px;filter:drop-shadow(0 16px 40px rgba(93,64,55,.30))}
.ed h1{font-weight:800;font-size:96px;line-height:1.2;color:var(--dk)}
.ed .cta{margin-top:40px;background:var(--y);color:var(--dk);font-weight:800;font-size:40px;padding:26px 56px;border-radius:18px;box-shadow:var(--sh)}
.ed .url{margin-top:30px;font-weight:700;font-size:34px;color:var(--br)}
"""

FOOT = "<div class=foot><img src=logo.png><b>누룽지도</b></div>"


def build_html(slides):
    n = len(slides)
    out = []
    for i, s in enumerate(slides):
        x = i * SW
        if s[0] == "cover":
            _, kick, h1, sub, sw = s[:5]
            out.append(f'<div class="slide cv" style="left:{x}px"><img class=logo src=logo.png>'
                       f'<div class=kick>{txt(kick)}</div><h1>{txt(h1)}</h1>'
                       f'<div class=sub>{txt(sub)}</div><div class=sw>{txt(sw)}</div></div>')
        elif s[0] == "end":
            _, h1, cta, url = s[:4]
            out.append(f'<div class="slide ed" style="left:{x}px"><img class=logo src=logo.png>'
                       f'<h1>{txt(h1)}</h1><div class=cta>{txt(cta)}</div>'
                       f'<div class=url>{txt(url)}</div></div>')
        else:
            _, num, lab, h1, h2, desc = s[:6]
            out.append(f'<div class="slide ct" style="left:{x}px"><div class=num>{txt(num)}'
                       f'<small>{txt(lab)}</small></div><h2>{txt(h1)}<br><mark>{txt(h2)}</mark></h2>'
                       f'<div class=desc>{txt(desc)}</div>'
                       f'<div class=ph><img src="img/{i:02d}.png"></div>{FOOT}</div>')
    css = CSS.replace("__W__", str(SW * n))
    return (f"<!doctype html><meta charset=utf-8><style>{css}</style>"
            + court_svg(n) + "".join(out))


# ── 렌더 ─────────────────────────────────────────────────────
def render(chrome, html_path, png_path, width):
    prof = html_path.parent / "chrome-profile"   # 켜져 있는 크롬과 프로필이 안 엉키게
    cmd = [chrome, "--headless", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
           "--no-first-run", "--no-default-browser-check", f"--user-data-dir={prof}",
           "--allow-file-access-from-files", "--force-device-scale-factor=1",
           "--virtual-time-budget=5000", f"--window-size={width},{SH}",
           f"--screenshot={png_path}", html_path.as_uri()]
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=str(html_path.parent))
    if not png_path.is_file() or png_path.stat().st_size == 0:
        die("크롬 렌더 실패 (CHROME 로 경로를 지정해 보세요):\n"
            + r.stderr.decode("utf-8", "replace").strip()[-600:])


def main():
    if not shutil.which("ffmpeg"):
        die("ffmpeg 가 없습니다.")
    chrome = find_chrome()
    if not chrome:
        die("크롬/엣지를 못 찾았습니다. CHROME=<실행파일 경로> 로 지정하세요.")
    for p in (FONT, LOGO):
        if not p.is_file():
            die(f"에셋이 없습니다: {p}")
    slides = load_slides()
    n = len(slides)
    log(f"슬라이드 {n}장 · {CARDS_FILE.name} · 크롬: {chrome}")

    work = Path(tempfile.mkdtemp(prefix="carousel_"))
    try:
        (work / "img").mkdir()
        shutil.copyfile(FONT, work / "pretendard.ttf")
        shutil.copyfile(LOGO, work / "logo.png")
        frame = read_frame()
        for i, s in enumerate(slides):
            if s[0] == "step":
                src, top = s[6], float(s[7] or 0)
                bot = float(s[8]) if len(s) > 8 and s[8] else None
                log(f"{i + 1:02d} 화면 ← {src}")
                grab(src, top, bot, work / "img" / f"{i:02d}.png", frame)

        html_path = work / "strip.html"
        html_path.write_text(build_html(slides), encoding="utf-8")
        strip = work / "strip.png"
        log(f"렌더 {SW * n}x{SH}")
        render(chrome, html_path, strip, SW * n)

        OUT.mkdir(parents=True, exist_ok=True)
        for old in OUT.glob("*.png"):
            old.unlink()
        for i in range(n):
            ffmpeg("-i", str(strip), "-frames:v", "1",
                   "-vf", f"crop={SW}:{SH}:{i * SW}:0", str(OUT / f"{i + 1:02d}.png"))
        shutil.copyfile(strip, OUT.parent / "carousel_strip.png")
        log(f"완료 → {OUT} ({n}장, 전체 띠: {OUT.parent / 'carousel_strip.png'})")
    finally:
        if os.environ.get("KEEP_BUILD"):
            log(f"중간물: {work}")
        else:
            shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
