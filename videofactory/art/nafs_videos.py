#!/usr/bin/env python3
"""فيديوهات «صحتي النفسية» (9:16) بنفس تصميم مصنع معلم المعتمد: عنوان على لوحة ← الرسم في الوسط ← خطوات 1 2 3 ← بطاقة ختام.
الفرق الوحيد: «الرسم» هنا لقطات التطبيق الحقيقي (nafs_shots.py) داخل إطار هاتف، والهوية بنفسجية. الصوت ElevenLabs عبدالرحمن بنص السكون
عبر نفس دوال build_voice. المخرجات تُسمّى dalleni_vid_nafs_<k>.mp4 وdalleni_aud_nafs_<k>_<i>.mp3 فتظهر في صفحة /voices للتعديل والتعليق على كل جملة.
الأوامر: clips (يولّد الأصوات ويكتب nafs_timing.json) ثم build ثم final (يركّب الصوت). الاستخدام: nafs_videos.py <أمر> [اسم ...]"""
import json, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import build_voice as bv, build_videos as V

W, H, FPS = V.W, V.H, V.FPS
INK, GREEN, SOFT, WHITE, PALE = (67, 48, 143), (21, 183, 136), (244, 245, 250), (255, 255, 255), (226, 231, 246)
SHOTS = os.path.join(HERE, 'nafs_shots'); WORK = '/tmp/nafs_vidwork'; TIMING = os.path.join(HERE, 'nafs_timing.json')
LOGO = os.environ.get('ADS_LOGO', '/root/nafsiyati/assets/logo.png'); IN = bv.IN
ART_Y, ART_H, ART_W = 410, 900, 640

# (الشاشة، السكون): الخطّاف، ثلاث لقطات، سطر الدعوة. نصوص مرغِّبة لا وعود فيها بدخل أو بمرضى، وبلا أرقام عمولة.
P = {
    'recruit_why': [('لديك رخصة؟ افتح عيادتك على جوالك', 'لديكَ رخصة؟ افتحْ عيادتَكَ على جوّالك'), ('استقبل مرضاك بالفيديو من أي مكان', 'استقبلْ مرضاكَ بالفيديو من أيِّ مكان'),
                  ('أنت تحدد مواعيدك وسعر جلستك', 'أنتَ تحدّدُ مواعيدَكَ وسعرَ جلستك'), ('نتحقق من رخصتك، فيظهر ملفك بعلامة موثّق', 'نتحقّقُ من رخصتك، فيظهرُ ملفُّكَ بعلامة موثّق'), ('سجّل الآن من الرابط', 'سجّلْ الآنَ من الرابط')],
    'recruit_signup': [('التسجيل في دقيقتين', 'التسجيل في دقيقتين'), ('تابع بحساب Google', 'تابعْ بحساب جوجل'),
                  ('اختر تبويب «معالج»', 'اخترْ تبويب: معالج'), ('أدخل تخصصك ورقم رخصتك، وارفع صورتها', 'أدخلْ تخصّصكَ ورقمَ رخصتك، وارفعْ صورتَها'), ('أرسل ملفك للمراجعة', 'أرسلْ ملفَّكَ للمراجعة')],
    'recruit_verify': [('ملفك الموثّق يبني الثقة', 'ملفُّكَ الموثّق يبني الثقة'), ('تصل رخصتك إلى الإدارة', 'تصل رخصتك إلى الإدارة'),
                  ('تراجعها الإدارة وتتواصل معك إن لزم', 'تراجعها الإدارة، وتتواصل معك إنْ لزم'), ('ثم يظهر ملفك للمرضى بعلامة «موثّق»', 'ثمّ يظهرُ ملفُّكَ للمرضى بعلامة موثّق'), ('نحمي سمعتك وسمعة المنصة', 'نحمي سمعتَكَ وسمعةَ المنصّة')],
    'recruit_start': [('جلستك الأولى بلا ارتباك', 'جلستُكَ الأولى بلا ارتباك'), ('أضف مواعيدك المتاحة', 'أضفْ مواعيدَكَ المتاحة'),
                  ('عند الموعد اضغط «ادخل الجلسة»', 'عندَ الموعد اضغطْ: ادخلِ الجلسة'), ('بعد الجلسة دوّن ملاحظاتك السرية', 'بعدَ الجلسة دوِّنْ ملاحظاتِكَ السرّية'), ('وأكمل خطوات التعليم لتكون جاهزاً', 'وأكمِلْ خطواتِ التعليم لتكونَ جاهزاً')],
    'recruit_launch': [('حان وقت ظهورك للناس', 'حانَ وقتُ ظهورِكَ للناس'), ('ملفك موثّق ومواعيدك جاهزة', 'ملفُّكَ موثّق، ومواعيدُكَ جاهزة'),
                  ('المرضى يرون مواعيدك ويحجزون', 'المرضى يرَوْنَ مواعيدَكَ ويحجزون'), ('وتتابع جلساتك القادمة من التطبيق', 'وتتابعُ جلساتِكَ القادمة من التطبيق'), ('أضف أول موعد اليوم', 'أضفْ أوّلَ موعدٍ اليوم')],
    'patient_first': [('هل تحتاج إلى التحدث مع مختص؟', 'هل تحتاجُ إلى التحدّثِ مع مختصّ؟'), ('اختر معالجاً موثّق الرخصة', 'اخترْ معالجاً موثّقَ الرخصة'),
                  ('احجز موعداً يناسبك', 'احجزْ موعداً يناسبك'), ('جلسة فيديو خاصة لا تُسجَّل', 'جلسةُ فيديو خاصّة، لا تُسجَّل'), ('صحتي النفسية: خطوتك الأولى بخصوصية', 'صحّتي النفسية، خطوتُكَ الأولى بخصوصية')],
    'patient_privacy': [('خصوصيتك قبل كل شيء', 'خصوصيّتُكَ قبلَ كلِّ شيء'), ('جلساتك لا تُسجَّل', 'جلساتُكَ لا تُسجَّل'),
                  ('ملاحظات المعالج سرّية', 'ملاحظاتُ المعالجِ سرّية'), ('الجلسة داخل التطبيق ولا تُخزَّن', 'الجلسةُ داخلَ التطبيق، ولا تُخزَّن'), ('تحدّث براحة', 'تحدّثْ براحة')],
    'therapist_pocket': [('ركّز على مرضاك، ونتولى الباقي', 'ركِّزْ على مرضاك، ونتولّى الباقي'), ('مواعيدك في مكان واحد', 'مواعيدُكَ في مكانٍ واحد'),
                    ('جلسة الفيديو من التطبيق مباشرة', 'جلسةُ الفيديو من التطبيق مباشرةً'), ('وملاحظاتك السرية بعد كل جلسة', 'وملاحظاتُكَ السرّية بعدَ كلِّ جلسة'), ('انضم إلى صحتي النفسية', 'انضمَّ إلى صحّتي النفسية')],
    'staff_roles': [('فريق واحد، ولكل دوره', 'فريقٌ واحد، ولكلٍّ دورُه'), ('المدير يوثّق ويحدد الصلاحيات', 'المديرُ يوثّقُ ويحدّدُ الصلاحيات'),
                ('التسويق وخدمة العملاء يتابعون كل مكتب مرحلة بمرحلة', 'التسويقُ وخدمةُ العملاء يتابعون كلَّ مكتبٍ مرحلةً بمرحلة'), ('والمالية تتابع العمولة والتحويلات', 'والماليّةُ تتابعُ العمولةَ والتحويلات'), ('لوحة لكل دور', 'لوحةٌ لكلِّ دور')],
}
NAMES = {'recruit_why': 'تجنيد ١: لماذا تنضم', 'recruit_signup': 'تجنيد ٢: التسجيل', 'recruit_verify': 'تجنيد ٣: التوثيق', 'recruit_start': 'تجنيد ٤: كيف تبدأ جلستك', 'recruit_launch': 'تجنيد ٥: الإطلاق للناس',
         'patient_first': 'مريض ١: الخطوة الأولى', 'patient_privacy': 'مريض ٢: الخصوصية', 'therapist_pocket': 'معالج: عيادتك في جيبك', 'staff_roles': 'الفريق: لوحة لكل دور'}
ART = {}
bv.P = P   # يستعمل مولّد الأصوات هذه الجمل (التعديلات من صفحة /voices تُطبَّق بتعديل P هنا)


def clips(names=()):
    os.makedirs(bv.CLIPS, exist_ok=True); bv.IDS.update(bv.voice_ids()); v = 'abdulrahman'
    for kk, ph in P.items():
        if names and kk not in names: continue
        for pair in ph:
            p = bv.clip_path(v, pair[1])
            if not (os.path.exists(p) and os.path.getsize(p) > 500): bv.gen(v, pair[1], p)
            bv.trim(p)
    timing = json.load(open(TIMING)) if os.path.exists(TIMING) else {}
    for k, ph in P.items():
        if names and k not in names: continue
        mx = [bv.dur(bv.clip_path(v, pair[1])) for pair in ph]
        starts = [0.3]
        for d in mx[:3]: starts.append(round(starts[-1] + d + 0.4, 2))
        end = round(starts[-1] + mx[3] + 0.5, 2)
        timing[k] = {'starts': starts, 'end': end, 'dur': round(end + 0.3 + mx[4] + 0.9, 2), 'speech': [0.3] + starts[1:] + [round(end + 0.3, 2)]}
        print(k, timing[k], flush=True)
    json.dump(timing, open(TIMING, 'w'), ensure_ascii=False, indent=1)


def panel(text, size, fill, fg, pad, maxw, badge=None, radius=40):
    f = V.font(size); tmp = ImageDraw.Draw(Image.new('RGBA', (10, 10))); bw = 110 if badge else 0
    lines = V.wrap(tmp, text, f, maxw - 2 * pad - bw); lh = int(size * 1.35); h = lh * len(lines) + 2 * pad
    wd = max(max(int(V.tw(tmp, l, f)) for l in lines) + 2 * pad + bw, 360)
    im = Image.new('RGBA', (wd, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im); d.rounded_rectangle((0, 0, wd - 1, h - 1), radius, fill=fill); right = wd - pad
    if badge:
        cx, cy, r = wd - pad - 40, h // 2, 40
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=GREEN); d.text((cx, cy - 2), badge, font=V.font(46), fill=WHITE, anchor='mm', **V.RTL); right = wd - pad - bw
    for i, l in enumerate(lines): d.text((right, pad + lh * i + lh // 2), l, font=f, fill=fg, anchor='rm', **V.RTL)
    return im


def art_layer(name):
    """لقطة التطبيق في إطار هاتف مستدير بظل ناعم، على طبقة بحجم الشاشة (شفافة)."""
    sh = Image.open(f'{SHOTS}/{name}.png').convert('RGB'); sc = ART_W / sh.width; ch = int(ART_H / sc)
    sh = sh.crop((0, 0, sh.width, min(ch, sh.height))).resize((ART_W, int(min(ch, sh.height) * sc)), Image.LANCZOS)
    card = Image.new('RGBA', (ART_W, ART_H), WHITE + (255,)); card.paste(sh, (0, 0))
    m = Image.new('L', card.size, 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, ART_W - 1, ART_H - 1), 44, fill=255); card.putalpha(m)
    lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); x = (W - ART_W) // 2
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0)); ImageDraw.Draw(shadow).rounded_rectangle((x, ART_Y + 14, x + ART_W, ART_Y + ART_H + 14), 44, fill=(30, 20, 70, 70))
    lay.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18))); lay.alpha_composite(card, (x, ART_Y))
    d = ImageDraw.Draw(lay); d.rounded_rectangle((x, ART_Y, x + ART_W, ART_Y + ART_H), 44, outline=(200, 205, 225, 255), width=3)
    return lay


def end_card(line1):
    im = Image.new('RGBA', (W, H), INK + (255,)); d = ImageDraw.Draw(im)
    lg = Image.open(LOGO).convert('RGBA'); lg = lg.resize((340, int(lg.height * 340 / lg.width)), Image.LANCZOS); im.alpha_composite(lg, ((W - lg.width) // 2, 330))
    d.text((W // 2, 800), 'صحتي النفسية', font=V.font(120), fill=WHITE, anchor='mm', **V.RTL)
    d.text((W // 2, 950), line1, font=V.font(56, 'Bold'), fill=(196, 185, 245), anchor='mm', **V.RTL)
    d.rounded_rectangle((200, 1120, W - 200, 1250), 65, fill=GREEN); d.text((W // 2, 1185), 'nafsiyati.wardyat.net', font=V.font(54, 'Bold'), fill=WHITE, anchor='mm')
    d.text((W // 2, 1400), 'على الويب والأندرويد', font=V.font(52, 'Bold'), fill=WHITE, anchor='mm', **V.RTL)
    d.text((W // 2, 1750), 'خدمة غير مخصصة للحالات الطارئة', font=V.font(38, 'Bold'), fill=(196, 185, 245), anchor='mm', **V.RTL)
    return im


def build(k):
    tm = json.load(open(TIMING))[k]; DUR, st, ph = tm['dur'], tm['starts'], P[k]
    with tempfile.TemporaryDirectory() as w:
        def save(im, n): p = os.path.join(w, n); im.save(p); return p
        bg = save(Image.new('RGB', (W, H), SOFT), 'bg.png')
        arts = [save(art_layer(n), f'a{i}.png') for i, n in enumerate(ART[k])]
        hp = panel(ph[0][0], 80, INK + (255,), WHITE, 30, 940); layers = [(save(hp, 'l0.png'), (W - hp.width) // 2, 130 + (270 - hp.height) // 2, st[0])]
        y = ART_Y + ART_H + 22
        for i in range(3):
            p = panel(ph[i + 1][0], 42, PALE + (255,), INK, 18, 990, badge=str(i + 1)); layers.append((save(p, f'l{i + 1}.png'), (W - p.width) // 2, y, st[i + 1])); y += p.height + 12
        end = save(end_card(ph[4][0]), 'end.png')
        cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-i', bg]
        for p in arts + [l[0] for l in layers] + [end]: cmd += ['-loop', '1', '-framerate', str(FPS), '-t', str(DUR), '-i', p]
        art_at = [0.2, st[2] - 0.1, st[3] - 0.1]; f = []; cur = '0'
        for i, a in enumerate(art_at, 1):
            f.append(f"[{i}:v]format=rgba,fade=t=in:st={a}:d=0.5:alpha=1[a{i}]"); f.append(f"[{cur}][a{i}]overlay=0:0:eval=frame[v{i}]"); cur = f'v{i}'
        for j, (p, x, yy, s) in enumerate(layers):
            n = 4 + j; f.append(f"[{n}:v]format=rgba,fade=t=in:st={s}:d=0.45:alpha=1[l{j}]")
            f.append(f"[{cur}][l{j}]overlay=x={x}:y='{yy}+36*(1-clip((t-{s})/0.5,0,1))':eval=frame[t{j}]"); cur = f't{j}'
        f.append(f"[{8}:v]format=rgba,fade=t=in:st={tm['end']}:d=0.5:alpha=1[e]"); f.append(f"[{cur}][e]overlay=0:0,format=yuv420p[out]")
        os.makedirs(WORK, exist_ok=True); out = os.path.join(WORK, f'nafs_{k}.mp4')
        cmd += ['-filter_complex', ';'.join(f), '-map', '[out]', '-t', str(DUR), '-r', str(FPS), '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20', '-movflags', '+faststart', out]
        subprocess.run(cmd, check=True)
    return out


def final(k):
    tm = json.load(open(TIMING))[k]; ph = P[k]; v = 'abdulrahman'; src = f'{WORK}/nafs_{k}.mp4'; dst = f'{IN}/dalleni_vid_nafs_{k}.mp4'
    cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-i', src]; f = []
    for i, pair in enumerate(ph):
        cmd += ['-i', bv.clip_path(v, pair[1])]; ms = int(tm['speech'][i] * 1000); f.append(f'[{i + 1}:a]adelay={ms}|{ms},volume=1.6[a{i}]')
        subprocess.run(['cp', bv.clip_path(v, pair[1]), f'{IN}/dalleni_aud_nafs_{k}_{i}.mp3'], check=True)
    f.append(''.join(f'[a{i}]' for i in range(len(ph))) + f'amix=inputs={len(ph)}:normalize=0,loudnorm=I=-16:TP=-1.5:LRA=9,apad[a]')
    cmd += ['-filter_complex', ';'.join(f), '-map', '0:v', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '128k', '-t', str(tm['dur']), '-movflags', '+faststart', dst + '.tmp.mp4']
    subprocess.run(cmd, check=True); os.replace(dst + '.tmp.mp4', dst); print(dst, flush=True)


if __name__ == '__main__':
    cmd, names = sys.argv[1], [a for a in sys.argv[2:]]
    if cmd == 'clips': clips(tuple(names))
    else:
        for k in P:
            if names and k not in names: continue
            if cmd == 'build': print(build(k), flush=True)
            elif cmd == 'final': final(k)
