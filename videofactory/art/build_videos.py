#!/usr/bin/env python3
"""فيديوهات معلم (9:16) تُصنع بالكود. التصميم المعتمد من المالك (٢٠٢٦-١٠-٢٧، الترتيب مع اللوحات): عنوان على لوحة، ثم الرسم في قلب الخلفية بحركة تقريب بطيئة (يذوب في لونها بلا إطار)، ثم الخطوات 1 2 3 على لوحات؛ ثم بطاقة الختام.\nالنسخ القديمة محفوظة: design_second_fullbleed_outline.py.bak. الوصف التالي قديم:
عنوان بلا لوحة (حروف بيضاء بحدّ كحلي) في الأعلى، وثلاث خطوات على لوحات بيضاء تظهر تباعاً في الأسفل، وشعار معلم في الزاوية، وبطاقة ختام بشعار معلم وشارتي المتجرين.
(جُرّب تصميم «الرسم داخل مربع» ورفضه المالك: لا تعد إليه.)
النصوص من build_voice.P (عمود الشاشة)، والتوقيت من timing.json (مبني على طول الصوت). المخرج يُكتب في WORK ثم يركّبه build_voice.py final مع الصوت.
APPSTORE_LIVE=1 يزيل وسم «قريباً» عن شارة آب ستور (فقط بعد اعتماد التطبيق هناك).
الاستخدام: build_videos.py [اسم ...]   (بلا وسائط = كل الفيديوهات)"""
import json, os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_voice as bv

IN = os.environ.get('ADS_IN', '/root/strategy-game/assets/incoming')
WORK = '/tmp/dalleni_vidwork'
FONTS = os.environ.get('ADS_FONTS', '/root/fanni/assets/fonts')
HERE = os.path.dirname(os.path.abspath(__file__))
BR = os.path.join(HERE, 'brand')
W, H, FPS = 1080, 1920, 24
NAVY, GOLD, SOFT, WHITE = (27, 42, 94), (245, 183, 0), (244, 245, 250), (255, 255, 255)
APPLE_LIVE = os.environ.get('APPSTORE_LIVE', '1') == '1'   # بقرار المالك 2026-10-27: بلا «قريباً» (APPSTORE_LIVE=0 يعيد الوسم)
RTL = dict(direction='rtl', language='ar')


def font(sz, bold='ExtraBold'):
    return ImageFont.truetype(f'{FONTS}/Tajawal-{bold}.ttf', sz, layout_engine=ImageFont.Layout.RAQM)


def tw(d, t, f):
    return d.textlength(t, font=f, **RTL)


def wrap(d, text, f, maxw):
    lines, cur = [], ''
    for w in text.split():
        t = (cur + ' ' + w).strip()
        if tw(d, t, f) <= maxw or not cur: cur = t
        else: lines.append(cur); cur = w
    return lines + [cur]


def fit(path, w, alpha=1.0):
    im = Image.open(os.path.join(BR, path)).convert('RGBA'); im = im.resize((w, int(im.height * w / im.width)), Image.LANCZOS)
    if alpha < 1: im.putalpha(im.getchannel('A').point(lambda v: int(v * alpha)))
    return im


def panel(text, size, fill, fg, pad=44, maxw=880, badge=None, radius=44):
    """لوحة نص عربي مستديرة (RGBA)."""
    f = font(size); tmp = ImageDraw.Draw(Image.new('RGBA', (10, 10)))
    lines = wrap(tmp, text, f, maxw - 2 * pad - (110 if badge else 0))
    lh = int(size * 1.35); h = lh * len(lines) + 2 * pad
    wd = max(int(tw(tmp, l, f)) for l in lines) + 2 * pad + (110 if badge else 0); wd = max(wd, 360)
    im = Image.new('RGBA', (wd, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, wd - 1, h - 1), radius, fill=fill)
    right = wd - pad
    if badge:
        cx, cy, r = wd - pad - 40, h // 2, 40
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=GOLD); d.text((cx, cy - 2), badge, font=font(46), fill=NAVY, anchor='mm', **RTL)
        right = wd - pad - 110
    for i, l in enumerate(lines): d.text((right, pad + lh * i + lh // 2), l, font=f, fill=fg, anchor='rm', **RTL)
    return im


def headline(text):
    """العنوان بلا لوحة: حروف بيضاء كبيرة بحدّ كحلي وظل ناعم ليُقرأ فوق أي رسم."""
    d0 = ImageDraw.Draw(Image.new('RGBA', (10, 10)))
    for sz in (104, 94, 84, 74):
        f = font(sz); ls = wrap(d0, text, f, 900)
        if len(ls) <= 2: break
    lh = int(sz * 1.3); pad = 30
    im = Image.new('RGBA', (W, lh * len(ls) + 2 * pad), (0, 0, 0, 0)); sh = Image.new('RGBA', im.size, (0, 0, 0, 0))
    for i, l in enumerate(ls):
        xy = (W // 2, pad + lh * i + lh // 2)
        ImageDraw.Draw(sh).text((xy[0], xy[1] + 8), l, font=f, fill=(0, 0, 0, 140), anchor='mm', stroke_width=12, stroke_fill=(0, 0, 0, 140), **RTL)
    from PIL import ImageFilter
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(7))); d = ImageDraw.Draw(im)
    for i, l in enumerate(ls): d.text((W // 2, pad + lh * i + lh // 2), l, font=f, fill=WHITE, anchor='mm', stroke_width=10, stroke_fill=NAVY, **RTL)
    return im


def end_card(line1, line2):
    im = Image.new('RGBA', (W, H), NAVY + (255,)); d = ImageDraw.Draw(im)
    lg = fit('logo.png', 380); im.alpha_composite(lg, ((W - lg.width) // 2, 230))
    d.text((W // 2, 720), 'دليل ثقة للصيانة', font=font(62, 'Bold'), fill=WHITE, anchor='mm', **RTL)
    d.text((W // 2, 850), line1, font=font(78), fill=GOLD, anchor='mm', **RTL)
    gp = fit('gplay_c.png', 600); im.alpha_composite(gp, ((W - gp.width) // 2, 970))
    ap = fit('appstore_c.png', 540, 1.0 if APPLE_LIVE else 0.5); ay = 970 + gp.height + 50; im.alpha_composite(ap, ((W - ap.width) // 2, ay))
    if not APPLE_LIVE:
        px = (W + ap.width) // 2 - 210; d.rounded_rectangle((px, ay - 34, px + 190, ay + 26), 30, fill=GOLD)
        d.text((px + 95, ay - 5), 'قريباً', font=font(40), fill=NAVY, anchor='mm', **RTL)
    d.text((W // 2, ay + ap.height + 110), line2, font=font(58, 'Bold'), fill=WHITE, anchor='mm', **RTL)
    return im


Z = 1.25   # الخلفية تُجهَّز أكبر بهذه النسبة لتتحرك بالتقريب البطيء


def cover(path):
    im = Image.open(os.path.join(IN, path)).convert('RGB')
    s = max(W * Z / im.width, H * Z / im.height)
    im = im.resize((int(im.width * s) + 1, int(im.height * s) + 1), Image.LANCZOS)
    l, t = (im.width - int(W * Z)) // 2, (im.height - int(H * Z)) // 2
    return im.crop((l, t, l + int(W * Z), t + int(H * Z)))


def on_soft(path, crop, top, wpx=1000):
    """رسم مربع على خلفية فاتحة ملء الشاشة (للصورتين غير الطوليتين)."""
    g = Image.open(os.path.join(IN, path)).convert('RGB').crop(crop)
    g = g.resize((wpx, int(g.height * wpx / g.width)), Image.LANCZOS)
    bg = Image.new('RGB', (W, H), SOFT); bg.paste(g, ((W - wpx) // 2, top))
    return bg.resize((int(W * Z), int(H * Z)), Image.LANCZOS)


BG = {
    'tech': lambda: cover('dalleni_ad_story_tech.png'),
    'shop': lambda: cover('dalleni_ad_story_shop.png'),
    'partner': lambda: on_soft('dalleni_ad_post_partner.png', (380, 560, 1680, 1325), 480),
    'customer_trust': lambda: on_soft('dalleni_ad_post_review.png', (350, 520, 1700, 1195), 480),
    'customer_ac': lambda: cover('dalleni_ad_story_ac.png'),
    'customer_plumbing': lambda: cover('dalleni_ad_story_plumbing.png'),
}


def closing(k):
    t = bv.P[k][4][0]
    if t.startswith('حمّل'): return t.split(' الرابط')[0], 'الرابط في البايو'
    return t, 'الرابط في البايو'


TOP_STEPS = ('tech', 'customer_ac', 'customer_plumbing')


def layers_for(k):
    """طبقات النص: لوحة كحلية للعنوان في الأعلى + ثلاث لوحات بيضاء مدمجة للخطوات (سطر واحد لكل خطوة) تتراكم من أسفل الشاشة.
    مدمجة عمداً كي تغطي أقل ما يمكن من الرسم؛ تبقى على الأرضية/الخريطة/الأريكة ولا تلامس الموضوع الرئيسي."""
    ph = bv.P[k]; out = []
    hp = panel(ph[0][0], 80, NAVY + (236,), WHITE, maxw=940, pad=30, radius=40); out.append((hp, (W - hp.width) // 2, 150))
    ps = [panel(ph[i + 1][0], 42, (255, 255, 255, 235), NAVY, pad=18, maxw=990, badge=str(i + 1), radius=32) for i in range(3)]
    gap = 12
    if k in TOP_STEPS: y = 150 + hp.height + 16                      # الرسم فارغ في الأعلى: الخطوات تحت العنوان بدل أن تغطي الموضوع
    elif k in ('partner', 'customer_trust'): y = 1180
    else: y = 1600 - (sum(p.height for p in ps) + 2 * gap)           # المحلات: فوق الخريطة السفلية لا فوق المحل
    for p in ps: out.append((p, (W - p.width) // 2, y)); y += p.height + gap
    return out


# ---- التخطيط المعتمد من المالك (2026-10-27): عنوان على لوحة، ثم الصورة في قلب الخلفية (تذوب في لونها بلا إطار)، ثم الخطوات 1 2 3 على لوحات ----
import numpy as np
CANVAS = {'tech': NAVY, 'shop': SOFT, 'partner': SOFT, 'customer_trust': SOFT, 'customer_ac': SOFT, 'customer_plumbing': SOFT}
SRC = {'tech': ('dalleni_ad_story_tech.png', 1000), 'shop': ('dalleni_ad_story_shop.png', 430), 'customer_ac': ('dalleni_ad_story_ac.png', 900), 'customer_plumbing': ('dalleni_ad_story_plumbing.png', 880)}
ART_Y, ART_H = 410, 900
HH = {'tech': 1000, 'customer_ac': 1000}   # رسمان أطول: نافذة أكبر ليظهر العامل كاملاً والأريكة كاملة


def art_zone(k):
    h = HH.get(k, ART_H)
    if k in SRC:
        f, y0 = SRC[k]; src = Image.open(os.path.join(IN, f)).convert('RGB'); ch = round(src.width * h / W)
        win = src.crop((0, y0, src.width, y0 + ch)).resize((W, h), Image.LANCZOS)
    else:
        win = BG[k]().resize((W, H)).crop((0, 440, W, 440 + h))
    a = np.ones(h); e = 90
    a[:e] = np.linspace(0, 1, e); a[-e:] = np.minimum(a[-e:], np.linspace(1, 0, e))
    return win, Image.fromarray((np.tile(a[:, None], (1, W)) * 255).astype('uint8'))


def base_image(k):
    """الخلفية الثابتة بلا نص: لون اللوحة + نافذة الرسم بحواف ناعمة."""
    im = Image.new('RGBA', (W, H), CANVAS[k] + (255,)); win, m = art_zone(k); w = win.convert('RGBA'); w.putalpha(m); im.alpha_composite(w, (0, ART_Y))
    return im


def text_layers(k):
    ph = bv.P[k]; dark = CANVAS[k] == NAVY
    hp = panel(ph[0][0], 80, (44, 66, 140, 255) if dark else NAVY + (255,), WHITE, maxw=940, pad=30, radius=40)
    out = [(hp, (W - hp.width) // 2, 130 + (270 - hp.height) // 2)]; y = ART_Y + HH.get(k, ART_H) + 20
    for i in range(3):
        p = panel(ph[i + 1][0], 42, (255, 255, 255, 255) if dark else (226, 231, 246, 255), NAVY, pad=18, maxw=990, badge=str(i + 1), radius=32)
        out.append((p, (W - p.width) // 2, y)); y += p.height + 12
    return out


def ordered_still(k):
    im = base_image(k)
    for l, x, y in text_layers(k): im.alpha_composite(l, (x, y))
    return im.convert('RGB')


def build(k):
    name = f'dalleni_vid_{k}.mp4'; tm = json.load(open(os.path.join(HERE, 'timing.json')))[name]
    DUR, st = tm['dur'], tm['starts']; ph = bv.P[k]
    with tempfile.TemporaryDirectory() as w:
        def save(im, n): p = os.path.join(w, n); im.save(p); return p
        bg = save(base_image(k).convert('RGB').resize((int(W * Z), int(H * Z)), Image.LANCZOS), 'bg.png')
        layers = [(save(im, f'l{i}.png'), x, y, st[i]) for i, (im, x, y) in enumerate(text_layers(k))]   # (png, x, y, بداية الظهور)
        l1, l2 = closing(k); end = save(end_card(l1, l2), 'end.png')
        cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-i', bg]
        for p in [l[0] for l in layers] + [end]: cmd += ['-loop', '1', '-framerate', str(FPS), '-t', str(DUR), '-i', p]
        n = int(DUR * FPS)
        f = [f"[0]zoompan=z='1+0.0006*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={n}:s={W}x{H}:fps={FPS}[v0]"]; cur = 'v0'
        for i, (p, x, y, s) in enumerate(layers, 1):
            f.append(f"[{i}:v]format=rgba,fade=t=in:st={s}:d=0.45:alpha=1[l{i}]")
            f.append(f"[{cur}][l{i}]overlay=x={x}:y='{y}+36*(1-clip((t-{s})/0.5,0,1))':eval=frame[v{i}]"); cur = f'v{i}'
        f.append(f"[{len(layers) + 1}:v]format=rgba,fade=t=in:st={tm['end']}:d=0.5:alpha=1[e]")
        f.append(f"[{cur}][e]overlay=0:0,format=yuv420p[out]")
        os.makedirs(WORK, exist_ok=True); out = os.path.join(WORK, name)
        cmd += ['-filter_complex', ';'.join(f), '-map', '[out]', '-t', str(DUR), '-r', str(FPS), '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20', '-movflags', '+faststart', out]
        subprocess.run(cmd, check=True)
    return out


if __name__ == '__main__':
    for k in bv.P:
        if not sys.argv[1:] or any(a in k for a in sys.argv[1:]): print(build(k), flush=True)
