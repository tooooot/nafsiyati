#!/usr/bin/env python3
"""تصميم v3 لفيديوهات «صحتي النفسية»: نص كبير متحرك + رسم توضيحي مرسوم بالكود (بلا لقطات تطبيق ولا إطار هاتف ولا بيانات تجريبية).
كل جملة صوتية = مشهد: عنوان ضخم تظهر كلماته تباعاً، ورسم بسيط يتحرك بنعومة. الألوان والشعار من هوية التطبيق.
الأمر: nafs_scenes.py compose <k>  ثم  nafs_videos.py final <k>. التوقيت من nafs_timing.json."""
import json, math, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import nafs_videos as nv, build_videos as V

W, H, FPS = 1080, 1920, 24
INK, GREEN, WHITE, LILAC, MINT = (67, 48, 143), (21, 183, 136), (255, 255, 255), (196, 185, 245), (194, 239, 201)
HEAD_Y = 330   # مركز العنوان


def ease(u): u = max(0.0, min(1.0, u)); return 1 - (1 - u) ** 3
def back(u):
    u = max(0.0, min(1.0, u)); c = 1.70158; return 1 + (c + 1) * (u - 1) ** 3 + c * (u - 1) ** 2


def bg():
    a = np.linspace(0, 1, H)[:, None, None]
    top, bot = np.array([70, 50, 146]), np.array([34, 24, 100])
    im = Image.fromarray(np.repeat((top * (1 - a) + bot * a).astype(np.uint8), W, axis=1), 'RGB').convert('RGBA')
    lg = Image.open(nv.LOGO).convert('RGBA'); lg = lg.resize((1000, int(lg.height * 1000 / lg.width)), Image.LANCZOS)
    lg.putalpha(lg.getchannel('A').point(lambda v: int(v * .06))); im.alpha_composite(lg, ((W - 1000) // 2, 1380)); return im


def text_c(d, xy, s, size, fill, bold='ExtraBold', anchor='mm'):
    d.text(xy, s, font=V.font(size, bold), fill=fill, anchor=anchor, **V.RTL)


def headline(layer, lines, t, t0):
    """lines: [(نص، لون، ثانية ظهوره بعد بدء المشهد)]. يظهر كل سطر بارتفاع+شفافية."""
    n = len(lines); lh = 150; top = HEAD_Y - lh * n // 2 + lh // 2
    for i, (s, col, at) in enumerate(lines):
        u = ease((t - t0 - at) / 0.5)
        if u <= 0: continue
        tmp = Image.new('RGBA', (W, 200), (0, 0, 0, 0)); d = ImageDraw.Draw(tmp)
        size = 112
        while V.tw(d, s, V.font(size)) > 960 and size > 70: size -= 4
        text_c(d, (W // 2, 100), s, size, col)
        tmp.putalpha(tmp.getchannel('A').point(lambda v: int(v * u)))
        layer.alpha_composite(tmp, (0, int(top + lh * i - 100 + 40 * (1 - u))))


def rr(d, box, r, fill, outline=None, w=0): d.rounded_rectangle(box, r, fill=fill, outline=outline, width=w)


def glow(layer, cx, cy, r, col, alpha):
    g = Image.new('RGBA', (r * 2, r * 2), (0, 0, 0, 0)); ImageDraw.Draw(g).ellipse((0, 0, r * 2 - 1, r * 2 - 1), fill=col + (alpha,))
    layer.alpha_composite(g.filter(ImageFilter.GaussianBlur(r // 3)), (cx - r, cy - r))


def lotus_small(layer, cx, cy, size):
    lg = Image.open(nv.LOGO).convert('RGBA'); lg = lg.resize((size, int(lg.height * size / lg.width)), Image.LANCZOS); layer.alpha_composite(lg, (cx - lg.width // 2, cy - lg.height // 2))


# ---------- المشهد 1: رخصة بلا عيادة ----------
def s1(layer, t):
    d = ImageDraw.Draw(layer); u = back(t / 0.7); cx, cy = W // 2, int(1000 + 14 * math.sin(t * 2.2))
    glow(layer, cx, cy, 380, LILAC, 70)
    w, h = int(640 * u), int(400 * u)
    if w > 10:
        card = Image.new('RGBA', (640, 400), (0, 0, 0, 0)); c = ImageDraw.Draw(card); rr(c, (0, 0, 639, 399), 36, WHITE)
        lotus_small(card, 130, 120, 150); rr(c, (260, 78, 590, 100), 11, (226, 222, 245)); rr(c, (260, 122, 520, 142), 10, (226, 222, 245))
        rr(c, (50, 250, 590, 268), 9, (236, 234, 248)); rr(c, (50, 290, 430, 308), 9, (236, 234, 248)); rr(c, (50, 330, 350, 348), 9, (236, 234, 248))
        s = ease((t - 0.9) / 0.4); r = int(54 * s)
        if r > 4: c.ellipse((520 - r, 330 - r, 520 + r, 330 + r), fill=GREEN); c.line([(496, 332), (514, 350), (546, 312)], fill=WHITE, width=9, joint='curve')
        card = card.resize((w, h), Image.LANCZOS); layer.alpha_composite(card, (cx - w // 2, cy - h // 2 - 150))
    # العيادة الفارغة بخط متقطع + علامة استفهام (تظهر مع الشطر الثاني)
    q = ease((t - 1.5) / 0.5)
    if q > 0:
        x0, y0, x1, y1 = 240, 1290 - int(30 * (1 - q)), 840, 1560 - int(30 * (1 - q)); ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); o = ImageDraw.Draw(ov)
        for i in range(0, 600, 36): o.line([(x0 + i, y0), (min(x0 + i + 20, x1), y0)], fill=LILAC + (255,), width=6); o.line([(x0 + i, y1), (min(x0 + i + 20, x1), y1)], fill=LILAC + (255,), width=6)
        for i in range(0, 270, 36): o.line([(x0, y0 + i), (x0, min(y0 + i + 20, y1))], fill=LILAC + (255,), width=6); o.line([(x1, y0 + i), (x1, min(y0 + i + 20, y1))], fill=LILAC + (255,), width=6)
        text_c(o, (W // 2, (y0 + y1) // 2), '؟', 170, LILAC + (255,))
        ov.putalpha(ov.getchannel('A').point(lambda v: int(v * q))); layer.alpha_composite(ov)


# ---------- المشهد 2: العيادة على الجوال ----------
def s2(layer, t):
    d = ImageDraw.Draw(layer); u = back(t / 0.6); cx, cy = W // 2, 1030
    W0, H0 = int(560 * u), int(900 * u)
    glow(layer, cx, cy, 420, GREEN, 40)
    if W0 < 20: return
    ph = Image.new('RGBA', (560, 900), (0, 0, 0, 0)); p = ImageDraw.Draw(ph); rr(p, (0, 0, 559, 899), 64, (24, 18, 66), (235, 232, 250), 8)
    # شاشة الفيديو: تدرّج بنفسجي + أفاتار لوتس + نبضات
    rr(p, (24, 24, 535, 700), 44, (86, 66, 168))
    for k in range(3):
        ph_t = (t * 0.8 + k / 3) % 1; r = int(110 + 130 * ph_t); a = int(110 * (1 - ph_t))
        ring = Image.new('RGBA', (560, 900), (0, 0, 0, 0)); ImageDraw.Draw(ring).ellipse((280 - r, 330 - r, 280 + r, 330 + r), outline=LILAC + (a,), width=6); ph.alpha_composite(ring)
    p.ellipse((280 - 110, 330 - 110, 280 + 110, 330 + 110), fill=(196, 185, 245)); lotus_small(ph, 280, 335, 150)
    rr(p, (360, 520, 515, 680), 26, (60, 44, 130), WHITE, 4); p.ellipse((412, 566, 462, 616), fill=LILAC); rr(p, (392, 628, 482, 646), 9, LILAC)   # صورتك الصغيرة
    # أزرار التحكم
    for i, (cx2, col) in enumerate([(150, (60, 44, 130)), (280, (230, 70, 80)), (410, (60, 44, 130))]):
        p.ellipse((cx2 - 46, 760, cx2 + 46, 852), fill=col)
    p.rounded_rectangle((132, 790, 168, 822), 8, outline=WHITE, width=5); p.line([(262, 806), (298, 806)], fill=WHITE, width=9)
    p.polygon([(388, 792), (420, 806), (388, 820)], fill=WHITE); rr(p, (398, 794, 432, 818), 4, WHITE)
    ph = ph.resize((W0, H0), Image.LANCZOS); layer.alpha_composite(ph, (cx - W0 // 2, cy - H0 // 2))
    # شارة «من أي مكان»
    b = ease((t - 1.2) / 0.5)
    if b > 0:
        ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); o = ImageDraw.Draw(ov); y = 1530 - int(25 * (1 - b)); rr(o, (270, y, 810, y + 100), 50, GREEN + (255,)); text_c(o, (W // 2, y + 50), 'من أي مكان', 56, WHITE)
        ov.putalpha(ov.getchannel('A').point(lambda v: int(v * b))); layer.alpha_composite(ov)


# ---------- المشهد 3: المواعيد والسعر بيدك ----------
def s3(layer, t):
    d = ImageDraw.Draw(layer); days = ['الأحد  ٠٩:٠٠', 'الاثنين  ١٤:٠٠', 'الثلاثاء  ١١:٠٠']
    for i, s in enumerate(days):
        u = back((t - 0.15 - i * 0.28) / 0.55)
        if u <= 0: continue
        x = int(-700 + (W // 2 + 0 + 700) * 0) ; dx = int((1 - u) * 520)
        card = Image.new('RGBA', (820, 150), (0, 0, 0, 0)); c = ImageDraw.Draw(card); rr(c, (0, 0, 819, 149), 36, WHITE)
        c.ellipse((680, 40, 760, 110), fill=MINT); c.line([(698, 76), (712, 92), (742, 56)], fill=GREEN, width=8)
        text_c(c, (400, 75), s, 54, INK)
        card.putalpha(card.getchannel('A').point(lambda v: int(v * min(1, u)))); layer.alpha_composite(card, (130 + dx, 700 + i * 178))
    p = ease((t - 1.4) / 0.5)
    if p > 0:
        ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); o = ImageDraw.Draw(ov); y = 1290 - int(30 * (1 - p))
        rr(o, (130, y, 950, y + 190), 40, (255, 255, 255, 255)); text_c(o, (790, y + 52), 'سعر جلستك', 40, (120, 110, 160), 'Bold')
        rr(o, (180, y + 90, 520, y + 160), 22, (240, 238, 250)); text_c(o, (350, y + 126), 'دج', 40, INK)
        if int(t * 2) % 2 == 0: o.rectangle((470, y + 102, 476, y + 148), fill=GREEN)
        rr(o, (620, y + 92, 900, y + 160), 34, GREEN); text_c(o, (760, y + 126), 'أنت تحدده', 38, WHITE)
        ov.putalpha(ov.getchannel('A').point(lambda v: int(v * p))); layer.alpha_composite(ov)


# ---------- المشهد 4: التوثيق ----------
def s4(layer, t):
    d = ImageDraw.Draw(layer); u = back(t / 0.6); cx, cy = W // 2, 1060
    card = Image.new('RGBA', (760, 760), (0, 0, 0, 0)); c = ImageDraw.Draw(card); rr(c, (0, 0, 759, 759), 56, WHITE)
    c.ellipse((280, 70, 480, 270), fill=LILAC); lotus_small(card, 380, 175, 130)
    rr(c, (190, 320, 570, 350), 15, (226, 222, 245)); rr(c, (250, 375, 510, 400), 12, (236, 234, 248))
    for i in range(3): rr(c, (110 + i * 200, 460, 290 + i * 200, 515), 27, (240, 238, 250))
    rr(c, (110, 560, 650, 590), 15, (236, 234, 248)); rr(c, (110, 615, 520, 640), 12, (236, 234, 248))
    # العدسة تمسح ثم تُختم علامة «موثّق»
    sc = ease((t - 0.1) / 0.6); W0 = int(760 * sc)
    if W0 > 20:
        glow(layer, cx, cy, 420, LILAC, 60); cardr = card.resize((W0, W0), Image.LANCZOS); layer.alpha_composite(cardr, (cx - W0 // 2, cy - W0 // 2))
    sweep = (t - 0.9) / 1.6
    if 0 < sweep < 1:
        yy = int(cy - 380 + 760 * sweep); ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); ImageDraw.Draw(ov).rectangle((cx - 380, yy - 6, cx + 380, yy + 6), fill=GREEN + (230,)); layer.alpha_composite(ov.filter(ImageFilter.GaussianBlur(3)))
    st = back((t - 2.1) / 0.55)
    if st > 0:
        bw = int(330 * st); ov = Image.new('RGBA', (500, 150), (0, 0, 0, 0)); o = ImageDraw.Draw(ov); rr(o, (0, 0, 499, 149), 75, GREEN); o.ellipse((22, 22, 128, 128), fill=WHITE); o.line([(44, 76), (68, 100), (110, 50)], fill=GREEN, width=12, joint='curve'); text_c(o, (305, 75), 'موثّق', 70, WHITE)
        if bw > 10: ov = ov.resize((max(2, int(500 * st)), max(2, int(150 * st))), Image.LANCZOS); layer.alpha_composite(ov, (cx + 120 - ov.width // 2, cy + 250 - ov.height // 2))


SCENES = [s1, s2, s3, s4]


def end_card(t0, t):
    u = ease((t - t0) / 0.5)
    if u <= 0: return None
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    lotus_small(im, W // 2, 560, 380); text_c(d, (W // 2, 880), 'صحتي النفسية', 124, WHITE)
    text_c(d, (W // 2, 1030), 'سجّل الآن من الرابط', 60, LILAC, 'Bold')
    rr(d, (170, 1150, W - 170, 1290), 70, GREEN); text_c(d, (W // 2, 1220), 'nafsiyati.wardyat.net', 56, WHITE, 'Bold', 'mm')
    text_c(d, (W // 2, 1760), 'خدمة غير مخصصة للحالات الطارئة', 38, LILAC, 'Bold')
    im.putalpha(im.getchannel('A').point(lambda v: int(v * u))); return im


def compose(k, preview=None):
    tm = json.load(open(nv.TIMING))[k]; ph = nv.P[k]; st = tm['starts'] + [tm['end']]; DUR = tm['dur']; n = int(DUR * FPS)
    heads = [[(ph[0][0].split('،')[0], WHITE, 0.0), ('وما عندك عيادة؟', GREEN, 1.4)],
             [('عيادتك', WHITE, 0.0), ('على جوالك', MINT, 0.5)],
             [('مواعيدك', WHITE, 0.0), ('وسعر جلستك', MINT, 0.5), ('بيدك', GREEN, 1.3)],
             [('نتحقق من رخصتك', WHITE, 0.0), ('فتظهر بعلامة «موثّق»', GREEN, 1.6)]]
    base = bg(); os.makedirs(nv.WORK, exist_ok=True); out = f'{nv.WORK}/nafs_{k}.mp4'
    p = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out], stdin=subprocess.PIPE) if preview is None else None
    for f in range(n) if preview is None else [int(preview * FPS)]:
        t = f / FPS; frame = base.copy()
        for i in range(4):
            a, z = st[i], st[i + 1] + (0.3 if i < 3 else 0.0)
            if not (a <= t < z): continue
            vis = min(1, (t - a) / 0.25) * (1 if i == 3 or t < z - 0.3 else max(0, (z - t) / 0.3)) if t < tm['end'] else 0
            if t >= tm['end']: vis = max(0, 1 - (t - tm['end']) / 0.4)
            lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); headline(lay, heads[i], t, a); SCENES[i](lay, t - a)
            lay.putalpha(lay.getchannel('A').point(lambda v: int(v * vis))); frame.alpha_composite(lay)
        ec = end_card(tm['end'], t)
        if ec: frame.alpha_composite(ec)
        if preview is not None: frame.convert('RGB').save(f'{nv.WORK}/pv_{k}_{preview}.png'); return
        p.stdin.write(np.asarray(frame.convert('RGB'), dtype=np.uint8).tobytes())
    p.stdin.close(); p.wait(); print(out, flush=True)


if __name__ == '__main__':
    k = sys.argv[2]
    if sys.argv[1] == 'preview': compose(k, preview=float(sys.argv[3]))
    else: compose(k)
