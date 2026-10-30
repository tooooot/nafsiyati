#!/usr/bin/env python3
"""بقية فيديوهات «صحتي النفسية» بتصميم v3 المعتمد (عيّنة recruit_why): عنوان ضخم + رسم مرسوم بالكود بلا بيانات تجريبية.
الأوامر: nafs_scenes2.py compose <k ...>   (ثم nafs_videos.py final <k> لتركيب الصوت). التوقيت من nafs_timing.json."""
import json, math, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import nafs_videos as nv
from nafs_scenes import (W, H, FPS, INK, GREEN, WHITE, LILAC, MINT, ease, back, bg, headline, rr, text_c, glow, lotus_small)

RED, GREY, PALE, DIM = (230, 70, 80), (226, 222, 245), (240, 238, 250), (120, 110, 160)


def put(layer, im, x, y, a=1.0):
    if a <= 0: return
    if a < 1: im = im.copy(); im.putalpha(im.getchannel('A').point(lambda v: int(v * a)))
    layer.alpha_composite(im, (int(x), int(y)))


def card(w, h, r=36, fill=WHITE):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im); rr(d, (0, 0, w - 1, h - 1), r, fill); return im, d


def scaled(im, s):
    s = max(0.02, s); return im.resize((max(2, int(im.width * s)), max(2, int(im.height * s))), Image.LANCZOS)


def pop(layer, im, cx, cy, u, a=None):
    """يظهر الرسم بقفزة ناعمة حول المركز."""
    if u <= 0: return
    im2 = scaled(im, back(u)); put(layer, im2, cx - im2.width // 2, cy - im2.height // 2, min(1, u * 2) if a is None else a)


def tick(d, cx, cy, r, col=GREEN, w=None):
    w = w or max(6, r // 5); d.line([(cx - r * .45, cy + r * .02), (cx - r * .1, cy + r * .38), (cx + r * .5, cy - r * .35)], fill=col, width=w, joint='curve')


def check_badge(d, cx, cy, r=40): d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=GREEN); tick(d, cx, cy, r, WHITE)


def ripple(layer, cx, cy, t, t0, col=GREEN):
    u = (t - t0) / 0.7
    if not 0 < u < 1: return
    ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); r = int(30 + 90 * u); ImageDraw.Draw(ov).ellipse((cx - r, cy - r, cx + r, cy + r), outline=col + (int(230 * (1 - u)),), width=8); layer.alpha_composite(ov)


def person(d, cx, cy, s, col):
    d.ellipse((cx - 30 * s, cy - 70 * s, cx + 30 * s, cy - 10 * s), fill=col); d.pieslice((cx - 55 * s, cy, cx + 55 * s, cy + 110 * s), 180, 360, fill=col)


def padlock(d, cx, cy, s, col=INK, body=None):
    d.arc((cx - 28 * s, cy - 62 * s, cx + 28 * s, cy + 2 * s), 180, 360, fill=col, width=int(10 * s)); rr(d, (cx - 40 * s, cy - 8 * s, cx + 40 * s, cy + 52 * s), int(12 * s), body or col)
    d.ellipse((cx - 7 * s, cy + 12 * s, cx + 7 * s, cy + 26 * s), fill=WHITE)


def profile_card(badge=True):
    im, c = card(760, 760, 56); c.ellipse((280, 70, 480, 270), fill=LILAC); lotus_small(im, 380, 175, 130)
    rr(c, (190, 320, 570, 350), 15, GREY); rr(c, (250, 375, 510, 400), 12, (236, 234, 248))
    for i in range(3): rr(c, (110 + i * 200, 460, 290 + i * 200, 515), 27, PALE)
    rr(c, (110, 560, 650, 590), 15, (236, 234, 248)); rr(c, (110, 615, 520, 640), 12, (236, 234, 248)); return im


def slot_row(txt, w=820, h=140, on=False, tag=None):
    im, c = card(w, h, 34, MINT if on else WHITE); text_c(c, (w // 2 + 40, h // 2), txt, 52, INK)
    if tag: rr(c, (30, 35, 230, h - 35), (h - 70) // 2, GREEN); text_c(c, (130, h // 2), tag, 38, WHITE)
    else: c.ellipse((w - 100, 35, w - 30, 105), fill=MINT if not on else WHITE); tick(c, w - 65, 70, 32)
    return im


# ---------------- المشاهد ----------------
def s_timer(layer, t):
    glow(layer, 540, 1050, 380, LILAC, 60); ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov); u = ease(t / 2.4)
    d.ellipse((290, 800, 790, 1300), outline=(255, 255, 255, 50), width=26); d.arc((290, 800, 790, 1300), -90, -90 + 360 * u, fill=GREEN + (255,), width=26)
    text_c(d, (540, 1020), '٢', 220, WHITE); text_c(d, (540, 1170), 'دقيقتان', 64, LILAC, 'Bold'); put(layer, ov, 0, 0, min(1, t / 0.4))


def s_google(layer, t):
    u = back(t / 0.6); im, c = card(840, 170, 85); c.ellipse((40, 30, 150, 140), fill=(244, 245, 250)); text_c(c, (95, 82), 'G', 80, (66, 133, 244)); text_c(c, (500, 85), 'المتابعة بحساب Google', 50, INK)
    pop(layer, im, 540, 1010, u); ripple(layer, 760, 1030, t, 1.3)
    k = ease((t - 1.6) / 0.4)
    if k > 0: ov = Image.new('RGBA', (160, 160), (0, 0, 0, 0)); check_badge(ImageDraw.Draw(ov), 80, 80, 70); pop(layer, ov, 540, 1260, k)


def s_roles(layer, t):
    for i, (txt, sel) in enumerate([('معالج', True), ('مريض', False)]):
        im, c = card(400, 480, 48, WHITE if not sel else MINT)
        person(c, 200, 190, 1.7, INK if sel else (170, 165, 200)); text_c(c, (200, 400), txt, 62, INK if sel else DIM)
        if sel and t > 1.2: rr(c, (0, 0, 399, 479), 48, None, GREEN, 10); check_badge(c, 330, 70, 36)
        pop(layer, im, 290 + i * 500, 1040, (t - 0.1 * i) / 0.55 if not (sel and t > 1.2) else 1)
    ripple(layer, 290, 1040, t, 1.0)


def s_form(layer, t):
    items = [('التخصص', 24), ('رقم الترخيص', 16), ('صورة الشهادة', 0)]
    for i, (lab, n) in enumerate(items):
        a = ease((t - 0.2 - i * 0.5) / 0.45); im, c = card(840, 190, 34); text_c(c, (780, 50), lab, 38, DIM, 'Bold')
        if n: w = int(n * 20 * ease((t - 0.7 - i * 0.5) / 1.0)); rr(c, (800 - w, 100, 800, 130), 14, GREY)
        else:
            rr(c, (40, 90, 800, 165), 20, PALE, (190, 180, 235), 4); text_c(c, (420, 128), 'ارفع صورة الشهادة', 38, INK, 'Bold')
            if t > 3.0: check_badge(c, 740, 128, 28)
        put(layer, im, 120, 760 + i * 215 + 30 * (1 - a), a)


def s_badge(layer, t):
    glow(layer, 540, 1060, 420, LILAC, 60); pop(layer, profile_card(), 540, 1060, t / 0.6)
    st = back((t - 0.9) / 0.55)
    if st > 0: ov, o = card(500, 150, 75, GREEN); o.ellipse((22, 22, 128, 128), fill=WHITE); tick(o, 75, 75, 52); text_c(o, (305, 75), 'موثّق', 70, WHITE); pop(layer, ov, 660, 1310, st)


def s_doc_send(layer, t):
    u = ease((t - 0.4) / 1.4); doc, c = card(300, 380, 30)
    rr(c, (40, 50, 200, 74), 11, GREY); rr(c, (40, 100, 260, 122), 10, PALE); rr(c, (40, 146, 240, 168), 10, PALE); c.ellipse((190, 270, 270, 350), fill=MINT); tick(c, 230, 310, 36)
    x = 760 - 480 * u; y = 1060 - 30 * math.sin(u * math.pi) * 3
    sh = Image.new('RGBA', (460, 520), (0, 0, 0, 0)); s = ImageDraw.Draw(sh); s.polygon([(230, 0), (440, 90), (420, 330), (230, 520), (40, 330), (20, 90)], fill=(86, 66, 168)); padlock(s, 230, 240, 2.0, WHITE, WHITE)
    pop(layer, sh, 330, 1060, t / 0.5)
    if u < 1: put(layer, scaled(doc, 1 - 0.35 * u), x - 150 * (1 - 0.35 * u) + 30, y - 190 * (1 - 0.35 * u), 1 - max(0, (u - .85) / .15))
    if u >= 1: ov = Image.new('RGBA', (140, 140), (0, 0, 0, 0)); check_badge(ImageDraw.Draw(ov), 70, 70, 64); pop(layer, ov, 330, 1370, (t - 1.9) / 0.4)


def s_review(layer, t):
    doc, c = card(520, 620, 40)
    for i in range(6): rr(c, (50, 70 + i * 70, 470 - (i % 3) * 70, 96 + i * 70), 12, GREY if i == 0 else PALE)
    pop(layer, doc, 380, 1050, t / 0.5)
    m = ease((t - 0.5) / 1.6); mx, my = 300 + 180 * m, 880 + 260 * math.sin(m * math.pi * 1.2)
    ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov); d.ellipse((mx - 80, my - 80, mx + 80, my + 80), outline=GREEN + (255,), width=14); d.line([(mx + 56, my + 56), (mx + 130, my + 130)], fill=GREEN + (255,), width=18); put(layer, ov, 0, 0, min(1, t / 0.5))
    b, bc = card(420, 180, 60, GREEN); [bc.ellipse((90 + i * 90, 75, 130 + i * 90, 115), fill=WHITE) for i in range(3)]
    pop(layer, b, 770, 1260, (t - 2.0) / 0.5)


def s_list_badge(layer, t, sel=1):
    for i in range(3):
        on = i == sel; im, c = card(840, 190, 44, WHITE if (on and t > 1.0) else (236, 233, 250))
        c.ellipse((680, 35, 800, 155), fill=LILAC); lotus_small(im, 740, 95, 80); rr(c, (260, 60, 640, 88), 14, GREY); rr(c, (400, 110, 640, 132), 11, PALE)
        if on and t > 1.0: rr(c, (30, 50, 220, 140), 45, GREEN); c.ellipse((40, 60, 120, 130), fill=WHITE); tick(c, 80, 95, 34); text_c(c, (165, 95), 'موثّق', 38, WHITE)
        pop(layer, im, 540, 790 + i * 250, (t - 0.12 * i) / 0.5)


def s_calm(layer, t):
    glow(layer, 540, 1050, 420, LILAC, 70); ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    for k in range(3):
        p = (t * 0.45 + k / 3) % 1; r = int(200 + 250 * p); d.ellipse((540 - r, 1050 - r, 540 + r, 1050 + r), outline=LILAC + (int(110 * (1 - p)),), width=6)
    put(layer, ov, 0, 0, min(1, t / 0.5)); lg = Image.open(nv.LOGO).convert('RGBA'); sc = (1 + 0.06 * math.sin(t * 2.4)) * 520 / lg.width; lg = lg.resize((int(lg.width * sc), int(lg.height * sc)), Image.LANCZOS)
    put(layer, lg, 540 - lg.width // 2, 1050 - lg.height // 2, ease(t / 0.6))


def s_slots(layer, t, pick=1, tag=None):
    for i, s in enumerate(['الأحد  09:00', 'الاثنين  14:00', 'الثلاثاء  11:00']):
        on = i == pick and t > 1.3; u = back((t - 0.15 - i * 0.28) / 0.55); im = slot_row(s, on=on, tag=tag if on else None)
        if u > 0: put(layer, im, 130 + int((1 - u) * 520), 760 + i * 190, min(1, u))
    if tag: ripple(layer, 540, 760 + pick * 190 + 70, t, 1.1)


def s_start_btn(layer, t):
    u = back(t / 0.6); im, c = card(780, 220, 110, GREEN); text_c(c, (440, 110), 'ادخل الجلسة', 80, WHITE); c.polygon([(100, 70), (160, 110), (100, 150)], fill=WHITE)
    glow(layer, 540, 1060, 360, GREEN, 50); pop(layer, im, 540, 1060, u); ripple(layer, 540, 1060, t, 1.3); ripple(layer, 540, 1060, t, 1.6)
    k = ease((t - 2.0) / 0.4)
    if k > 0: tx, c2 = card(560, 120, 60, WHITE); text_c(c2, (280, 60), 'قبل الموعد بدقائق', 44, INK); put(layer, tx, 260, 1260, k)


def s_notes(layer, t):
    im, c = card(760, 640, 50); text_c(c, (380, 80), 'ملاحظاتي', 56, INK)
    for i in range(5): w = int(560 * ease((t - 0.3 - i * 0.25) / 0.5)); rr(c, (700 - w, 170 + i * 76, 700, 196 + i * 76), 13, GREY if i % 2 == 0 else PALE)
    pop(layer, im, 540, 1040, t / 0.5); k = back((t - 1.6) / 0.5)
    if k > 0: lk = Image.new('RGBA', (260, 260), (0, 0, 0, 0)); ld = ImageDraw.Draw(lk); ld.ellipse((0, 0, 259, 259), fill=GREEN); padlock(ld, 130, 120, 1.8, WHITE, WHITE); ld.ellipse((123, 132, 137, 146), fill=GREEN); pop(layer, lk, 800, 1360, k)


def s_checklist(layer, t):
    for i, s in enumerate(['ملفك موثّق', 'مواعيدك جاهزة']):
        im, c = card(840, 200, 50); check_badge(c, 740, 100, 52); text_c(c, (390, 100), s, 66, INK); pop(layer, im, 540, 900 + i * 260, (t - 0.3 - 0.7 * i) / 0.55)
    glow(layer, 540, 1400, 200, GREEN, 40)


def s_booking(layer, t):
    for i, s in enumerate(['الأحد  09:00', 'الاثنين  14:00']):
        on = i == 1 and t > 1.4; im = slot_row(s, on=on, tag='محجوز' if on else None); u = back((t - 0.2 * i) / 0.55)
        if u > 0: put(layer, im, 130, 800 + i * 190 + 40 * (1 - min(1, u)), min(1, u))
    ripple(layer, 540, 1000, t, 1.2)
    pb, c = card(330, 180, 60, WHITE); person(c, 165, 90, 0.8, INK); pop(layer, pb, 780, 1310, (t - 0.9) / 0.5)


def s_wallet(layer, t, title='محفظتي'):
    im, c = card(780, 520, 56, (86, 66, 168)); text_c(c, (390, 80), title, 60, WHITE)
    for i, hh in enumerate([160, 250, 200, 330]): hh2 = int(hh * ease((t - 0.5 - i * 0.2) / 0.6)); rr(c, (120 + i * 160, 440 - hh2, 220 + i * 160, 440), 18, LILAC if i < 3 else GREEN)
    pop(layer, im, 540, 1040, t / 0.55)
    k = back((t - 1.6) / 0.5)
    if k > 0: coin = Image.new('RGBA', (170, 170), (0, 0, 0, 0)); cd = ImageDraw.Draw(coin); cd.ellipse((0, 0, 169, 169), fill=(255, 200, 70)); text_c(cd, (85, 85), 'دج', 62, WHITE); pop(layer, coin, 880, 770, k)


def s_bubble(layer, t):
    im, c = card(640, 400, 90, WHITE); c.polygon([(120, 380), (220, 380), (110, 470)], fill=WHITE); text_c(c, (320, 200), '؟', 230, GREEN)
    bob = int(14 * math.sin(t * 3)); pop(layer, im, 540, 1000 + bob, t / 0.6)
    for i in range(3): d = ease((t - 0.9 - i * 0.2) / 0.4); r = int(24 * d); ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); ImageDraw.Draw(ov).ellipse((420 + i * 120 - r, 1330 - r, 420 + i * 120 + r, 1330 + r), fill=LILAC + (255,)); layer.alpha_composite(ov)


def s_shield(layer, t):
    glow(layer, 540, 1060, 400, GREEN, 50); sh = Image.new('RGBA', (520, 600), (0, 0, 0, 0)); s = ImageDraw.Draw(sh)
    s.polygon([(260, 0), (500, 100), (480, 380), (260, 600), (40, 380), (20, 100)], fill=GREEN); padlock(s, 260, 270, 2.4, WHITE, WHITE); s.ellipse((250, 285, 270, 305), fill=GREEN)
    ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    for k in range(3): p = (t * 0.5 + k / 3) % 1; r = int(300 + 160 * p); d.ellipse((540 - r, 1060 - r, 540 + r, 1060 + r), outline=MINT + (int(90 * (1 - p)),), width=5)
    put(layer, ov, 0, 0, min(1, t / 0.5)); pop(layer, sh, 540, 1060, t / 0.6)


def s_call(layer, t, chip=None, rec=False, lock=False):
    u = back(t / 0.6); glow(layer, 540, 1030, 420, GREEN, 40)
    if u <= 0.04: return
    ph, p = card(560, 900, 64, (24, 18, 66)); rr(p, (0, 0, 559, 899), 64, None, (235, 232, 250), 8); rr(p, (24, 24, 535, 700), 44, (86, 66, 168))
    for k in range(3):
        q = (t * 0.8 + k / 3) % 1; r = int(110 + 130 * q); ring = Image.new('RGBA', (560, 900), (0, 0, 0, 0)); ImageDraw.Draw(ring).ellipse((280 - r, 330 - r, 280 + r, 330 + r), outline=LILAC + (int(110 * (1 - q)),), width=6); ph.alpha_composite(ring)
    p.ellipse((170, 220, 390, 440), fill=LILAC); lotus_small(ph, 280, 335, 150); rr(p, (360, 520, 515, 680), 26, (60, 44, 130), WHITE, 4); p.ellipse((412, 566, 462, 616), fill=LILAC); rr(p, (392, 628, 482, 646), 9, LILAC)
    for cx2, col in [(150, (60, 44, 130)), (280, RED), (410, (60, 44, 130))]: p.ellipse((cx2 - 46, 760, cx2 + 46, 852), fill=col)
    p.line([(262, 806), (298, 806)], fill=WHITE, width=9)
    if rec and t > 0.9: p.ellipse((60, 60, 100, 100), fill=RED); text_c(p, (150, 80), 'REC', 34, WHITE); p.line([(40, 40), (260, 120)], fill=WHITE, width=10); p.line([(40, 120), (260, 40)], fill=WHITE, width=0)
    pop(layer, ph, 540, 1030, u)
    if lock:
        k = back((t - 1.0) / 0.5)
        if k > 0: lk = Image.new('RGBA', (220, 220), (0, 0, 0, 0)); ld = ImageDraw.Draw(lk); ld.ellipse((0, 0, 219, 219), fill=GREEN); padlock(ld, 110, 100, 1.6, WHITE, WHITE); ld.ellipse((103, 112, 117, 126), fill=GREEN); pop(layer, lk, 800, 1370, k)
    if chip:
        b = ease((t - 1.2) / 0.5)
        if b > 0: ov, o = card(560, 100, 50, GREEN); text_c(o, (280, 50), chip, 54, WHITE); put(layer, ov, 260, 1530 - 25 * (1 - b), b)


def s_noeye(layer, t):
    im, c = card(760, 500, 50); text_c(c, (380, 70), 'بيانات صحية', 52, INK)
    for i in range(3): rr(c, (80, 150 + i * 90, 680 - i * 80, 180 + i * 90), 14, GREY)
    pop(layer, im, 540, 960, t / 0.5); e = ease((t - 0.5) / 0.5)
    if e > 0:
        ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov); d.ellipse((320, 1280, 760, 1480), fill=WHITE + (255,)); d.ellipse((470, 1290, 610, 1470), fill=INK + (255,)); d.ellipse((520, 1340, 560, 1380), fill=WHITE + (255,))
        k = ease((t - 1.3) / 0.4)
        if k > 0: d.line([(300, 1300), (300 + 480 * k, 1300 + 190 * k)], fill=RED + (255,), width=26)
        put(layer, ov, 0, 0, e)


def s_roles4(layer, t):
    for i, s in enumerate(['مدير', 'مسوّق', 'دعم', 'مالية']):
        im, c = card(400, 340, 50, WHITE); person(c, 200, 140, 1.2, INK if i == 0 else (130, 115, 200)); text_c(c, (200, 290), s, 56, INK)
        pop(layer, im, 290 + (i % 2) * 500, 860 + (i // 2) * 420, (t - 0.25 * i) / 0.55)


def s_perms(layer, t):
    for i, s in enumerate(['التوثيق', 'المستخدمون', 'المالية']):
        im, c = card(820, 170, 44, WHITE); text_c(c, (640, 85), s, 60, INK); on = t > 0.8 + i * 0.5
        rr(c, (40, 50, 190, 120), 35, GREEN if on else (210, 205, 230)); c.ellipse((140 if on else 50, 58, 182 if on else 92, 112), fill=WHITE) if on else c.ellipse((50, 58, 104, 112), fill=WHITE)
        pop(layer, im, 540, 840 + i * 215, (t - 0.15 * i) / 0.5)


def s_pipeline(layer, t):
    names = ['اكتشاف', 'رسالة', 'تسجيل', 'إطلاق']; ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov); y = 1040; xs = [900 - i * 240 for i in range(4)]
    d.line([(xs[0], y), (xs[3], y)], fill=LILAC + (120,), width=12); prog = min(3, max(0, (t - 0.4) / 0.7)); d.line([(xs[0], y), (xs[0] + (xs[3] - xs[0]) * prog / 3, y)], fill=GREEN + (255,), width=12)
    for i, x in enumerate(xs):
        on = prog >= i - 0.01; d.ellipse((x - 46, y - 46, x + 46, y + 46), fill=(GREEN if on else (86, 66, 168)) + (255,), outline=WHITE + (255,), width=6)
        if on: tick(d, x, y, 46, WHITE)
        text_c(d, (x, y + 110), names[i], 44, WHITE, 'Bold')
    put(layer, ov, 0, 0, min(1, t / 0.4))


def mk(fn, **kw): return lambda layer, t: fn(layer, t, **kw)


W_, G_, M_ = WHITE, GREEN, MINT
SPEC = {
    'recruit_signup': [([('التسجيل', W_, 0), ('يستغرق دقيقتين', G_, 0.7)], s_timer), ([('تابع', W_, 0), ('بحساب Google', M_, 0.5)], s_google), ([('اختر تبويب', W_, 0), ('«معالج»', G_, 0.7)], s_roles), ([('أدخل تخصصك', W_, 0), ('ورقم رخصتك وصورتها', M_, 0.7)], s_form)],
    'recruit_verify': [([('ملفك الموثّق', W_, 0), ('يبني الثقة', G_, 0.7)], s_badge), ([('تصل رخصتك', W_, 0), ('إلى الإدارة', M_, 0.7)], s_doc_send), ([('تراجعها', W_, 0), ('وتتواصل معك إن لزم', M_, 0.8)], s_review), ([('ثم يظهر ملفك للمرضى', W_, 0), ('بعلامة «موثّق»', G_, 1.2)], s_list_badge)],
    'recruit_start': [([('جلستك الأولى', W_, 0), ('بلا ارتباك', G_, 0.7)], s_calm), ([('أضف', W_, 0), ('مواعيدك المتاحة', M_, 0.5)], mk(s_slots, pick=-1)), ([('عند الموعد اضغط', W_, 0), ('«ادخل الجلسة»', G_, 0.9)], s_start_btn), ([('بعد الجلسة دوّن', W_, 0), ('ملاحظاتك السرية', M_, 0.9)], s_notes)],
    'recruit_launch': [([('حان وقت', W_, 0), ('ظهورك للناس', G_, 0.6)], s_badge), ([('ملفك موثّق', W_, 0), ('ومواعيدك جاهزة', M_, 0.8)], s_checklist), ([('المرضى يرون مواعيدك', W_, 0), ('ويحجزون', G_, 1.0)], s_booking), ([('وتتابع جلساتك', W_, 0), ('القادمة من التطبيق', M_, 0.8)], mk(s_slots, pick=0))],
    'patient_first': [([('هل تحتاج إلى', W_, 0), ('التحدث مع مختص؟', G_, 0.8)], s_bubble), ([('اختر معالجاً', W_, 0), ('موثّق الرخصة', G_, 0.8)], s_list_badge), ([('احجز موعداً', W_, 0), ('يناسبك', M_, 0.7)], mk(s_slots, pick=1, tag='احجز')), ([('جلسة فيديو خاصة', W_, 0), ('لا تُسجَّل', G_, 1.2)], mk(s_call, lock=True))],
    'patient_privacy': [([('خصوصيتك', W_, 0), ('أولاً', G_, 0.7)], s_shield), ([('جلساتك', W_, 0), ('لا تُسجَّل', G_, 0.7)], mk(s_call, rec=True)), ([('ملاحظات المعالج', W_, 0), ('سرّية', G_, 0.9)], s_notes), ([('الجلسة داخل التطبيق', W_, 0), ('ولا تُخزَّن', G_, 1.0)], mk(s_call, lock=True))],
    'therapist_pocket': [([('ركّز على مرضاك', W_, 0), ('ونتولى الباقي', G_, 1.0)], s_calm), ([('مواعيدك', W_, 0), ('في مكان واحد', M_, 0.6)], mk(s_slots, pick=-1)), ([('جلسة الفيديو', W_, 0), ('من التطبيق مباشرة', M_, 0.7)], mk(s_call, chip='بدون برامج إضافية')), ([('وملاحظاتك السرية', W_, 0), ('بعد كل جلسة', M_, 0.8)], s_notes)],
    'staff_roles': [([('فريق واحد', W_, 0), ('ولكل دوره', G_, 0.8)], s_roles4), ([('المدير يوثّق', W_, 0), ('ويحدد الصلاحيات', M_, 0.9)], s_perms), ([('التسويق وخدمة العملاء', W_, 0), ('يتابعون كل مكتب', M_, 0.9), ('مرحلة بمرحلة', G_, 1.8)], s_pipeline), ([('والمالية', W_, 0), ('تتابع العمولة والتحويلات', M_, 0.7)], mk(s_wallet, title='المالية'))],
}


def end_card(line, t0, t):
    u = ease((t - t0) / 0.5)
    if u <= 0: return None
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im); lotus_small(im, W // 2, 560, 380); text_c(d, (W // 2, 880), 'صحتي النفسية', 124, WHITE)
    text_c(d, (W // 2, 1030), line, 60, LILAC, 'Bold'); rr(d, (170, 1150, W - 170, 1290), 70, GREEN); text_c(d, (W // 2, 1220), 'nafsiyati.wardyat.net', 56, WHITE, 'Bold'); text_c(d, (W // 2, 1760), 'خدمة غير مخصصة للحالات الطارئة', 38, LILAC, 'Bold')
    im.putalpha(im.getchannel('A').point(lambda v: int(v * u))); return im


def compose(k, preview=None):
    tm = json.load(open(nv.TIMING))[k]; ph = nv.P[k]; st = tm['starts'] + [tm['end']]; DUR = tm['dur']; n = int(DUR * FPS); spec = SPEC[k]
    base = bg(); os.makedirs(nv.WORK, exist_ok=True); out = f'{nv.WORK}/nafs_{k}.mp4'
    p = None if preview is not None else subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out], stdin=subprocess.PIPE)
    for f in range(n) if preview is None else [int(preview * FPS)]:
        t = f / FPS; frame = base.copy()
        for i in range(4):
            a, z = st[i], st[i + 1] + (0.3 if i < 3 else 0.0)
            if not (a <= t < z): continue
            vis = min(1, (t - a) / 0.25) * (1 if i == 3 or t < z - 0.3 else max(0, (z - t) / 0.3))
            if t >= tm['end']: vis = max(0, 1 - (t - tm['end']) / 0.4)
            heads, fn = spec[i]; lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); headline(lay, heads, t, a); fn(lay, t - a)
            lay.putalpha(lay.getchannel('A').point(lambda v: int(v * vis))); frame.alpha_composite(lay)
        ec = end_card(ph[4][0], tm['end'], t)
        if ec: frame.alpha_composite(ec)
        if preview is not None: frame.convert('RGB').save(f'{nv.WORK}/pv_{k}_{preview}.png'); return
        p.stdin.write(np.asarray(frame.convert('RGB'), dtype=np.uint8).tobytes())
    p.stdin.close(); p.wait(); print(out, flush=True)


if __name__ == '__main__':
    cmd, names = sys.argv[1], sys.argv[2:]
    if cmd == 'preview': compose(names[0], preview=float(names[1]))
    else:
        for k in (names or SPEC): compose(k)
