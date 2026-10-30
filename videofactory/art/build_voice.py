#!/usr/bin/env python3
"""تعليق صوتي لفيديوهات معلم (ElevenLabs فقط بأمر المالك؛ ممنوع Microsoft/edge-tts).
المشكلة المعالَجة: القارئ الآلي ينطق آخر حرف في الجملة بحركة إعراب (منكَ، مجاناً) والمفروض الوقف بالسكون (منكْ، مجانا).
لذلك لكل جملة نسختان: «plain» كما في الشاشة، و«waqf» مشكولة بالسكون على آخر حرف مع تحويل تنوين الفتح لألف وتاء التأنيث لهاء ساكنة.
كل جملة تُنطق مقطعاً مستقلاً (وقفة حقيقية بعدها) ثم تُوضع على الفيديو.
الأوامر: clips (يولّد المقاطع ويكتب timing.json) ثم، بعد إعادة بناء الفيديوهات، mux (يركّب الصوت: ينتج 4 نسخ لكل فيديو)."""
import asyncio, hashlib, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
IN = os.environ.get('ADS_IN', '/root/strategy-game/assets/incoming')
CLIPS = os.environ.get('ADS_CLIPS', '/tmp/dalleni_voice_clips')
OUT = IN   # يقرؤه /api/ads/vid/ (أسماء dalleni_vid_* و dalleni_aud_*)
# أصوات عربية سعودية من حساب المالك (تُحلّ بالاسم من /v1/voices): عبدالرحمن (رجل)، نورة (امرأة)
VOICES = {'abdulrahman': 'Abdulrahman'}   # الصوت المعتمد بقرار المالك 2026-10-26
KEY = None


def eleven_key():
    global KEY
    if KEY is None:
        for ln in open('/root/env/.env'):
            if ln.startswith('ELEVENLABS_API_KEY='): KEY = ln.split('=', 1)[1].strip().strip('"\'')
    return KEY


def voice_ids():
    import requests
    vs = requests.get('https://api.elevenlabs.io/v1/voices', headers={'xi-api-key': eleven_key()}, timeout=30).json()['voices']
    return {k: next(v['voice_id'] for v in vs if v['name'].startswith(n)) for k, n in VOICES.items()}
SK = 'ْ'

# (الشاشة، السكون): عنوان، ثلاث خطوات، سطر الختام
P = {
    'tech': [('فني وتبغى شغل قريب منك؟', 'فني وتبغى شغل قريب منكْ؟'), ('سجّل في معلم مجاناً', 'سجّل في مْعلّمْ مجّانا'),
             ('وثّق هويتك', 'وثّق هويّتكْ'), ('اضغط «متصل» فتصلك طلبات حيّك', 'اضغط متّصلْ علشان توصلك طلبات حيّكْ'), ('حمّل التطبيق الرابط في البايو', 'حمّل التطبيقْ، الرابط في البايوْ')],
    'shop': [('عندك محل صيانة أو مواد بناء؟', 'عندك محلْ صيانهْ أو مواد بناءْ؟ وتبغا زيادهْ في المبيعاتْ'), ('طلبات حيّك تصلك أنت أولاً', 'طلبات حيّك تصلك أنت أولا'),
             ('فريقك يستقبلها من لوحة خاصة بمحلك', 'فريقك يستقبلها من لوحة خاصّة بمحلّكْ'), ('نعتمد محلك بعد التحقق', 'نعتمد محلّك بعد التحقّقْ'), ('راسلنا لتسجيل محلك', 'راسلنا لتسجيل محلّكْ')],
    'partner': [('اكفل فنييك وتابعهم', 'اكفل فنيّيك وتابعهمْ'), ('يصلهم رابط واحد', 'يصلهم رابط واحدْ'),
                ('يسجّلون تحت كفالتك', 'يسجّلون تحت كفالتكْ'), ('تتابعهم كلهم من لوحة خاصة بك', 'تتابعهم كلّهم من لوحة خاصّة بكْ'), ('راسلنا لنفعّل لوحتك', 'راسلنا لنفعّل لوحتكْ')],
    'customer_trust': [('اعرف من يدخل بيتك', 'اعرف من يدخل بيتكْ'), ('تشوف اسمه وتقييمه', 'تشوف اسمه وتقييمهْ'),
                       ('هويته موثّقة', 'هويّته موثّقهْ'), ('وتتبّعه حتى يصلك', 'وتتبّعه حتى يصلكْ'), ('حمّل تطبيق معلم الرابط في البايو', 'حمّل تطبيق مْعلّمْ، الرابط في البايوْ')],
    'customer_ac': [('المكيف خربان؟', 'المُكَيِّف خَرْبانْ؟'), ('افتح معلم', 'افتح مْعلّمْ'), ('اختر «تكييف»', 'اختر تكييفْ'),
                    ('شوف الفنيين الموثّقين القريبين منك', 'شوف الفنيّين الموثّقين القريبين منكْ'), ('حمّل تطبيق معلم الرابط في البايو', 'حمّل تطبيق مْعلّمْ، الرابط في البايوْ')],
    'customer_plumbing': [('تسريب؟', 'تسريبْ؟'), ('اطلب سبّاكا موثّق الهوية', 'اطلب سبّاكْ موثّق الهويّهْ'),
                          ('قريب منك على الخريطة', 'قريب منّك على الخَريطَهْ'), ('والسعر يتضح قبل التنفيذ', 'والسعر يتّضح قبل التنفيذْ'), ('حمّل تطبيق معلم الرابط في البايو', 'حمّل تطبيق مْعلّمْ، الرابط في البايوْ')],
}
MODES = {'waqf': 1}   # بأمر المالك: خمسة خيارات فقط (خمسة أصوات بنص السكون)؛ النسخة «عادي» أُلغيت
P = {k: v for k, v in P.items() if k in os.environ.get('VOICE_VIDEOS', ','.join(P)).split(',')}   # العيّنة على فيديو واحد حتى يُختار الصوت


def clip_path(voice, text):
    return f'{CLIPS}/{voice}_{hashlib.md5(text.encode()).hexdigest()[:12]}.mp3'


def dur(p):
    return float(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', p]))


def trim(p):
    # يحذف الصمت في طرفي المقطع (قد يضيف المولّد صمتاً قصيراً) كي تتطابق الأزمنة مع الكلام الفعلي
    if os.path.exists(p + '.ok'): return
    t = p + '.tmp.mp3'
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', p, '-af',
                    'silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse',
                    t], check=True)
    os.replace(t, p); open(p + '.ok', 'w').close()


IDS = {}


def gen(voice, text, path):
    import requests, time
    for i in range(3):
        r = requests.post(f'https://api.elevenlabs.io/v1/text-to-speech/{IDS[voice]}?output_format=mp3_44100_128',
                          headers={'xi-api-key': eleven_key()}, timeout=120,
                          json={'text': text, 'model_id': 'eleven_multilingual_v2', 'voice_settings': {'stability': 0.55, 'similarity_boost': 0.8, 'style': 0.15}})
        if r.status_code == 200 and len(r.content) > 500:
            open(path, 'wb').write(r.content); return
        print('retry', r.status_code, r.text[:120], flush=True); time.sleep(3)
    raise SystemExit(f'فشل توليد: {voice} {text}')


def clips():
    os.makedirs(CLIPS, exist_ok=True)
    jobs = [(v, t) for ph in P.values() for pair in ph for t in pair for v in VOICES]
    IDS.update(voice_ids())
    for v, t in jobs:
        p = clip_path(v, t)
        if not (os.path.exists(p) and os.path.getsize(p) > 500): gen(v, t, p)
    for v, t in jobs: trim(clip_path(v, t))
    timing = {}
    for k, ph in P.items():
        mx = [max(dur(clip_path(v, pair[m])) for v in VOICES for m in MODES.values()) for pair in ph]
        starts = [0.3]
        for d in mx[:3]: starts.append(round(starts[-1] + d + 0.4, 2))
        end = round(starts[-1] + mx[3] + 0.5, 2)
        timing[f'dalleni_vid_{k}.mp4'] = {'starts': starts, 'end': end, 'dur': round(end + 0.3 + mx[4] + 0.9, 2), 'speech': [0.3] + starts[1:] + [round(end + 0.3, 2)]}
        print(k, timing[f'dalleni_vid_{k}.mp4'], flush=True)
    json.dump(timing, open(f'{HERE}/timing.json', 'w'), ensure_ascii=False, indent=1)


def mux():
    timing = json.load(open(f'{HERE}/timing.json')); os.makedirs(OUT, exist_ok=True)
    for k, ph in P.items():
        name = f'dalleni_vid_{k}.mp4'; tm = timing[name]
        for v in VOICES:
            for mname, mi in MODES.items():
                cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-i', f'{IN}/{name}']; f = []
                for i, pair in enumerate(ph):
                    cmd += ['-i', clip_path(v, pair[mi])]
                    ms = int(tm['speech'][i] * 1000)
                    f.append(f'[{i + 1}:a]adelay={ms}|{ms},volume=1.6[a{i}]')
                f.append(''.join(f'[a{i}]' for i in range(len(ph))) + f'amix=inputs={len(ph)}:normalize=0,apad[a]')
                out = f'{OUT}/dalleni_vid_vt_{k}_{v}_{mname}.mp4'
                cmd += ['-filter_complex', ';'.join(f), '-map', '0:v', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '128k', '-t', str(tm['dur']), '-movflags', '+faststart', out]
                subprocess.run(cmd, check=True); print(out, flush=True)
        for v in VOICES:
            for mname, mi in MODES.items():
                for i, pair in enumerate(ph):
                    subprocess.run(['cp', clip_path(v, pair[mi]), f'{OUT}/dalleni_aud_{k}_{i}_{v}_{mname}.mp3'], check=True)


def final():
    # المخرج الصامت من build_videos.py (WORK) يُركَّب عليه الصوت فيُكتب الملف الأساسي بالصوت دفعة واحدة؛ والصامت يُحفظ باسم dalleni_vid_silent_<k>.mp4
    WORK = '/tmp/dalleni_vidwork'; timing = json.load(open(f'{HERE}/timing.json'))
    for k, ph in P.items():
        name = f'dalleni_vid_{k}.mp4'; tm = timing[name]; src = f'{WORK}/{name}'; dst = f'{IN}/{name}'
        v = 'abdulrahman'; cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-i', src]; f = []
        for i, pair in enumerate(ph):
            cmd += ['-i', clip_path(v, pair[1])]; ms = int(tm['speech'][i] * 1000)
            f.append(f'[{i + 1}:a]adelay={ms}|{ms},volume=1.6[a{i}]')
        f.append(''.join(f'[a{i}]' for i in range(len(ph))) + f'amix=inputs={len(ph)}:normalize=0,apad[a]')
        cmd += ['-filter_complex', ';'.join(f), '-map', '0:v', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '128k', '-t', str(tm['dur']), '-movflags', '+faststart', dst + '.tmp.mp4']
        subprocess.run(cmd, check=True); os.replace(dst + '.tmp.mp4', dst)
        subprocess.run(['cp', src, f'{IN}/dalleni_vid_silent_{k}.mp4'], check=True); print(dst, flush=True)


if __name__ == '__main__':
    {'clips': clips, 'mux': mux, 'final': final}[sys.argv[1]]()
