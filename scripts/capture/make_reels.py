#!/usr/bin/env python3
"""scripts/capture/make_reels.py — 사용법 릴스 굽기(9:16, 1080x1920, 30fps).

카드뉴스(make_cards.py)의 영상판이다. 한 편 = 카드 한 편:
  첫 1.9초  표지 제목 + 결과 화면(정지컷)
  단계마다  앱 화면이 가로 꽉 차게(1:1) 움직이고, 맨 위 종이 띠에 카드와 같은 손글씨
            제목·파란 설명. 누를 곳에 빨간 손글씨 동그라미가 누르기 전에 '그려진다'
  끝        다음 편 예고 카드
화면은 카드처럼 창 안에 넣지 않는다 — 릴스는 화면이 프레임을 꽉 채워야 '창 안의 창'으로
안 보인다. 종이 띠는 인스타 위쪽 아이콘(약 150px)을 피해 글씨가 그 아래에 오게 둔다.
문구·동그라미 좌표는 handnote.<lang>.txt 의 같은 편에서, 녹화 구간은 reels.handnote.<lang>.txt
에서 읽는다. 나레이션은 없다 — 자막(손글씨)과 음악만. 음악은 한 곡으로 통일(MUSIC).

필요: Python 3.8+(표준 라이브러리만), ffmpeg, 크롬 또는 엣지.

사용법:
  MUSIC=/path/to/tongtong.mp3 python scripts/capture/make_reels.py   # → marketing-assets/reels/handnote/<편>.mp4
  REELS=urgent python ...

환경변수: ARTIFACTS_DIR, CAP_LANG(ko), REELS, MUSIC, MUSIC_OFFSET(초), CHROME, KEEP_BUILD
"""
import html
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import make_cards as mc  # noqa: E402  같은 정의·도구(크롬·화면 뽑기)·글꼴·마커

LANG_TAG = mc.LANG_TAG
SPEC = Path(os.environ.get("REELS_SCRIPT") or HERE / f"reels.handnote.{LANG_TAG}.txt")
OUT = mc.ART / "reels" / "handnote"
ONLY = [p for p in os.environ.get("REELS", "").replace(",", " ").split() if p]
MUSIC = os.environ.get("MUSIC") or str(mc.ROOT / "assets" / "audio" / "tongtong_gayageum.mp3")
MUSIC_OFFSET = float(os.environ.get("MUSIC_OFFSET", "0"))
LOGO = mc.ROOT / "assets" / "nulloongzido logo_without bg.png"

W, H, FPS = 1080, 1920, 30
BAND = 440                                  # 맨 위 종이 띠 높이(제목·설명)
HOOK_BAND = 560                             # 첫 장면은 표지 제목이 커서 띠가 길다
WX, WY, WW, WH = 0, BAND, 1080, H - BAND    # 화면이 보이는 자리(띠 아래 전부)
SRC_W = 1080
K = 1.0                                     # 원본 1:1 — 줄이지 않는다
WIN_H = WH                                  # 1480 — 보이는 원본 높이(y0 은 0~980)
DRAW_STEPS = 9                              # 동그라미 그리기 단계(프레임 묶음)
DRAW_SEC = 0.36


# ── 정의 ─────────────────────────────────────────────────────
def load_spec():
    if not SPEC.is_file():
        mc.die(f"릴스 정의가 없습니다: {SPEC}")
    reels, cur = [], None
    for ln in SPEC.read_text(encoding="utf-8").splitlines():
        if not ln.strip() or ln.lstrip().startswith("#"):
            continue
        f = [x.strip() for x in ln.split("|")]
        if f[0] == "reel":
            cur = {"id": f[1], "hook": None, "segs": [], "outro": ""}
            reels.append(cur)
        elif cur is None:
            mc.die(f"reel 줄보다 먼저 나왔습니다: {ln}")
        elif f[0] == "hook":
            cur["hook"] = (float(f[1]), int(f[2]))
        elif f[0] == "seg":
            on = None
            if len(f) > 5 and f[5]:
                a, b = f[5].split("-")
                on = (float(a), float(b))
            cur["segs"].append(dict(step=int(f[1]), t0=float(f[2]), t1=float(f[3]), y0=int(f[4]), on=on))
        elif f[0] == "outro":
            cur["outro"] = f[1]
        else:
            mc.die(f"형식 오류: {ln}")
    return reels


def circles(marks):
    out = []
    for m in (x.strip() for x in marks.split(";") if x.strip()):
        p = m.split()
        if p[0] == "circle" and len(p) >= 5:
            out.append((*map(int, p[1:5]), int(p[5]) if len(p) > 5 else 20))
    return out


# ── 종이·글씨·동그라미 레이어(HTML → 크롬) ───────────────────
CSS = """
@font-face{font-family:PenScript;src:url(NanumPenScript-Regular.ttf)}
@font-face{font-family:Brush;src:url(NanumBrushScript-Regular.ttf)}
@font-face{font-family:PoorStory;src:url(PoorStory-Regular.ttf)}
:root{--red:#E0463A;--blue:#2F4DA8;--ink:#1F1F22;--hl:#FFE45C;--bg:#FBF8F1}
*{box-sizing:border-box;margin:0;padding:0}
html,body{background:transparent}
.slide{position:relative;width:1080px;height:1920px;overflow:hidden;margin:0 0 40px}
.band,.paper{background:radial-gradient(circle,rgba(141,110,99,.22) 1.6px,transparent 2px) 18px 18px/36px 36px,var(--bg)}
.band{position:absolute;left:0;top:0;width:1080px;border-radius:0 0 44px 44px;
 box-shadow:0 10px 28px rgba(93,64,55,.22),0 2px 4px rgba(93,64,55,.14)}
i.t{position:absolute;display:block}
svg.layer{position:absolute;inset:0;width:1080px;height:1920px;pointer-events:none}
svg.under{mix-blend-mode:multiply;z-index:2}
.hw{position:absolute;z-index:3;white-space:nowrap}
svg.over{z-index:4}
.title{font-family:PenScript;color:var(--ink);font-size:104px;line-height:1;left:56px;top:150px;transform:rotate(-1.2deg);transform-origin:left}
.note{font-family:PoorStory;color:var(--blue);font-size:54px;line-height:1.25;letter-spacing:-1px}
.cap{left:72px;top:282px;transform:rotate(-1.5deg);transform-origin:left}
.red{font-family:Brush;color:var(--red);font-size:74px;line-height:1}
.kick{left:64px;top:150px;font-size:60px;transform:rotate(-3deg)}
.cover{font-family:PenScript;color:var(--ink);font-size:118px;line-height:1.02;left:66px;top:222px;transform:rotate(-2deg);transform-origin:left}
.side{left:650px;top:440px;font-size:48px;transform:rotate(-3deg)}
.foot{font-family:PenScript;color:var(--red);font-size:42px;left:64px;top:92px;opacity:.8;transform:rotate(-2deg)}
.marks .hw,.marks .band{visibility:hidden}
.outro .logo{position:absolute;left:340px;top:560px;width:400px}
.outro .brand{font-family:PenScript;color:var(--ink);font-size:150px;left:0;right:0;top:1000px;text-align:center}
.outro .next{left:0;right:0;top:1200px;text-align:center}
.outro .link{left:0;right:0;top:1330px;text-align:center;font-size:46px}
"""


def win_mark(cx, cy, cw, ch, pad, y0, seed, extra=""):
    X = lambda x: WX + x * K
    Y = lambda y: WY + (y - y0) * K
    return (f'<i class=t data-mark=circle data-seed={seed} data-pad={pad} {extra}'
            f'style="left:{X(cx):.0f}px;top:{Y(cy):.0f}px;width:{cw * K:.0f}px;height:{ch * K:.0f}px"></i>')


def build_html(post, reel, num):
    steps = [s for s in post["slides"] if s["kind"] == "step"]
    cover = next(s for s in post["slides"] if s["kind"] == "cover")
    foot = f'<div class="hw foot">{html.escape(num)}</div>'
    pages, names = [], []
    # 표지(첫 장면)
    pages.append(f'<section class=slide><div class=band style="height:{HOOK_BAND}px"></div>'
                 f'<div class="hw red kick">{mc.txt(cover["kick"])}</div>'
                 f'<div class="hw cover">{mc.txt(cover["title"])}</div>'
                 + (f'<div class="hw note side">{mc.txt(cover["side"])}</div>' if cover["side"] else "")
                 + '</section>')
    names.append("hook")
    # 단계 종이
    for i, s in enumerate(steps, 1):
        pages.append(f'<section class=slide><div class=band style="height:{BAND}px"></div>'
                     f'<div class="hw title">{mc.txt(s["title"])}</div>'
                     f'<div class="hw note cap">{mc.txt(s["cap"])}</div>{foot}</section>')
        names.append(f"step{i}")
    # 동그라미 — 구간마다 그리는 중(1..DRAW_STEPS) 투명 레이어
    for j, seg in enumerate(reel["segs"]):
        if not seg["on"]:
            continue
        cs = circles(steps[seg["step"] - 1]["marks"])
        for k in range(1, DRAW_STEPS + 1):
            marks = "".join(win_mark(*c, seg["y0"], seed=seg["step"] * 10 + n + 1,
                                     extra=f'data-p="{k / DRAW_STEPS:.3f}" ')
                            for n, c in enumerate(cs))
            pages.append(f'<section class="slide marks">{marks}</section>')
            names.append(f"c{j}_{k}")
    # 끝 카드
    pages.append(f'<section class="slide paper outro"><img class=logo src="logo.png">'
                 f'<div class="hw brand">누룽지도</div>'
                 f'<div class="hw note next">{mc.txt(reel["outro"])}</div>'
                 f'<div class="hw note link">앱은 프로필 링크에서 👆</div></section>')
    names.append("outro")
    # 동그라미를 data-p 만큼만 그린다(두 획을 이어서 한 붓처럼)
    js = """<script src=handnote.js></script><script>
const t=setInterval(()=>{if(!document.body.dataset.ready)return;clearInterval(t);
document.querySelectorAll('.slide.marks').forEach(s=>{
 const p=+(s.querySelector('[data-p]')||{dataset:{p:1}}).dataset.p;
 const ps=[...s.querySelectorAll('svg.over path')];
 for(let i=0;i<ps.length;i+=2){const a=ps[i],b=ps[i+1],la=a.getTotalLength(),lb=b?b.getTotalLength():0,L=(la+lb)*p;
  a.style.strokeDasharray=la;a.style.strokeDashoffset=Math.max(0,la-L);
  if(b){b.style.strokeDasharray=lb;b.style.strokeDashoffset=Math.max(0,lb-Math.max(0,L-la));}}});
document.body.dataset.done=1},50)</script>"""
    body = "\n".join(pages)
    return (f"<!doctype html><html lang={LANG_TAG}><head><meta charset=utf-8><style>{CSS}</style></head>"
            f"<body>{body}{js}</body></html>"), names


def render_layers(chrome, page, n, d):
    prof = d / "chrome-profile"
    strip = d / "strip.png"
    cmd = [chrome, "--headless", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
           "--no-first-run", "--no-default-browser-check", f"--user-data-dir={prof}",
           "--allow-file-access-from-files", "--force-device-scale-factor=1",
           "--default-background-color=00000000", "--virtual-time-budget=8000",
           f"--window-size={W},{n * (H + 40) + 200}", f"--screenshot={strip}", page.as_uri()]
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=str(d))
    if not strip.is_file():
        mc.die("크롬 렌더 실패:\n" + r.stderr.decode("utf-8", "replace")[-600:])
    return strip


# ── 합성 ─────────────────────────────────────────────────────
def ff(*args):
    mc.ffmpeg(*args)


def flow_mp4(rid):
    p = mc.FLOWS / f"{rid}_{LANG_TAG}.mp4"
    if not p.is_file():
        mc.die(f"녹화본 없음: {p}")
    return p


def src_vf(y0):
    fr = mc.read_frame()
    crop = f"crop={fr[2]}:{fr[3]}:{fr[0]}:{fr[1]}," if fr else ""
    return f"{crop}scale={SRC_W}:-2:flags=lanczos,crop={SRC_W}:{WIN_H}:0:{y0},setsar=1"


def clip(top, video_args, vf, dur, circ_list, out):
    """크림 바탕 위에 화면(녹화본 구간, 띠 아래 꽉 채움) → 맨 위 종이 띠(top) → 동그라미."""
    inputs = ["-f", "lavfi", "-t", f"{dur:.3f}", "-i", f"color=0xFBF8F1:s={W}x{H}:r={FPS}",
              *video_args, "-loop", "1", "-t", f"{dur:.3f}", "-i", str(top)]
    fc = (f"[1:v]{vf},fps={FPS}[v];[0:v][v]overlay={WX}:{WY}:shortest=0[a];"
          f"[2:v]format=rgba[t];[a][t]overlay=0:0[b]")
    last = "[b]"
    if circ_list:
        inputs += ["-f", "concat", "-safe", "0", "-i", str(circ_list)]
        fc += f";[3:v]format=rgba[c];{last}[c]overlay=0:0:eof_action=pass[o]"
        last = "[o]"
    ff(*inputs, "-filter_complex", fc + f";{last}fps={FPS},format=yuv420p[out]", "-map", "[out]",
       "-t", f"{dur:.3f}", "-r", str(FPS), "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-an", str(out))


def circ_concat(d, j, on, t0, dur):
    """동그라미 타임라인 → ffmpeg concat 목록(빈 → 그리기 9장 → 다 그린 것 → 빈)."""
    blank = d / "blank.png"
    a, b = max(0.0, on[0] - t0), min(dur, on[1] - t0)
    step = DRAW_SEC / DRAW_STEPS
    rows = [(blank, a)] if a > 0 else []
    for k in range(1, DRAW_STEPS + 1):
        rows.append((d / f"c{j}_{k}.png", step))
    rows.append((d / f"c{j}_{DRAW_STEPS}.png", max(0.04, b - a - DRAW_SEC)))
    if dur - b > 0.01:
        rows.append((blank, dur - b))
    rows.append((rows[-1][0], 0.04))  # concat 은 마지막 duration 을 무시한다
    lst = d / f"c{j}.txt"
    lst.write_text("".join(f"file '{p.as_posix()}'\nduration {t:.4f}\n" for p, t in rows), encoding="utf-8")
    return lst


def make_reel(chrome, post, reel, d, num):
    steps = [s for s in post["slides"] if s["kind"] == "step"]
    for f in mc.FONT_FILES:
        shutil.copyfile(mc.FONTS / f, d / f)
    shutil.copyfile(mc.JS, d / "handnote.js")
    shutil.copyfile(LOGO, d / "logo.png")
    page_html, names = build_html(post, reel, num)
    page = d / "layers.html"
    page.write_text(page_html, encoding="utf-8")
    strip = render_layers(chrome, page, len(names), d)
    for i, nm in enumerate(names):
        ff("-i", str(strip), "-frames:v", "1", "-vf", f"crop={W}:{H}:0:{i * (H + 40)}", str(d / f"{nm}.png"))
    ff("-f", "lavfi", "-i", f"color=black@0.0:s={W}x{H},format=rgba", "-frames:v", "1", str(d / "blank.png"))
    mp4 = flow_mp4(reel["id"])
    parts = []
    beat = 60 / 129
    # 첫 장면 — 결과 화면 정지컷 4박
    ht, hy = reel["hook"]
    hook_dur = 4 * beat
    still = d / "hook_src.png"
    ff("-ss", f"{ht:.2f}", "-i", str(mp4), "-frames:v", "1", str(still))
    out = d / "p00.mp4"
    clip(d / "hook.png", ["-loop", "1", "-t", f"{hook_dur:.3f}", "-i", str(still)], src_vf(hy), hook_dur, None, out)
    parts.append(out)
    for j, seg in enumerate(reel["segs"]):
        dur = seg["t1"] - seg["t0"]
        lst = circ_concat(d, j, seg["on"], seg["t0"], dur) if seg["on"] else None
        out = d / f"p{j + 1:02d}.mp4"
        mc.log(f"{reel['id']} ③ 조각 {j + 1}: 단계 {seg['step']} · {seg['t0']}~{seg['t1']}초")
        clip(d / f"step{seg['step']}.png", ["-ss", f"{seg['t0']:.3f}", "-t", f"{dur:.3f}", "-i", str(mp4)],
             src_vf(seg["y0"]), dur, lst, out)
        parts.append(out)
    out = d / "p99.mp4"
    ff("-loop", "1", "-t", f"{4 * beat:.3f}", "-i", str(d / "outro.png"), "-vf", f"fps={FPS},format=yuv420p",
       "-c:v", "libx264", "-crf", "18", str(out))
    parts.append(out)
    lst = d / "parts.txt"
    lst.write_text("".join(f"file '{p.as_posix()}'\n" for p in parts), encoding="utf-8")
    silent = d / "silent.mp4"
    ff("-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(silent))
    OUT.mkdir(parents=True, exist_ok=True)
    final = OUT / f"{reel['id']}.mp4"
    if MUSIC and Path(MUSIC).is_file():
        total = hook_dur + sum(s["t1"] - s["t0"] for s in reel["segs"]) + 4 * beat
        ff("-i", str(silent), "-ss", f"{MUSIC_OFFSET:.3f}", "-i", MUSIC, "-map", "0:v", "-map", "1:a",
           "-af", f"afade=t=out:st={total - 1.2:.2f}:d=1.2,loudnorm=I=-16:TP=-1.5",
           "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-shortest", str(final))
    else:
        mc.warn(f"음악 없음(MUSIC={MUSIC}) — 무음으로 냅니다")
        shutil.copyfile(silent, final)
    mc.log(f"{reel['id']}: → {final}")


def main():
    if not shutil.which("ffmpeg"):
        mc.die("ffmpeg 가 없습니다.")
    chrome = mc.find_chrome()
    if not chrome:
        mc.die("크롬/엣지를 못 찾았습니다. CHROME=<실행파일 경로> 로 지정하세요.")
    posts = {p["id"]: (i + 1, p) for i, p in enumerate(mc.load_posts())}
    reels = [r for r in load_spec() if not ONLY or r["id"] in ONLY]
    work = Path(tempfile.mkdtemp(prefix="reels_"))
    try:
        for r in reels:
            if r["id"] not in posts:
                mc.die(f"카드 정의에 없는 편: {r['id']}")
            n, post = posts[r["id"]]
            d = work / r["id"]
            d.mkdir()
            make_reel(chrome, post, r, d, f"누룽지도 사용법 #{n}")
    finally:
        if os.environ.get("KEEP_BUILD"):
            mc.log(f"중간물: {work}")
        else:
            shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
