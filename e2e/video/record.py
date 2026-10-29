# تسجيل شاشة التطبيق الحقيقي لفيديو كل دور. كل مشهد: إجراء ثم انتظار بمقدار مدة التعليق الصوتي (durations.json).
import os, json, time
from playwright.sync_api import sync_playwright
BASE = 'https://nafsiyati.wardyat.net/'
DUR = json.load(open('e2e/video/durations.json'))
TOK = {'patient': os.environ['DEV_PATIENT'], 'therapist': os.environ['DEV_THERAPIST'], 'staff': os.environ['DEV_ADMIN']}
os.makedirs('vid', exist_ok=True)

def enable(pg):
    for _ in range(10):
        pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()"); pg.wait_for_timeout(1000)
        if pg.get_by_role('button').count() > 0: break

def clk(pg, name, last=False):
    loc = pg.get_by_role('button', name=name, exact=True)
    if loc.count() == 0: loc = pg.get_by_role('button', name=name)
    if loc.count() == 0: loc = pg.get_by_role('tab', name=name)
    if loc.count() == 0: loc = pg.locator('flt-semantics').filter(has_text=name)
    (loc.last if last else loc.first).click(timeout=30000, force=True)
    pg.wait_for_timeout(1500)

# (دور، مقطع، هل برمز دخول، [(مفتاح المشهد، إجراء)])
SEGMENTS = {
 'patient': [
  ('A', False, [('welcome', None), ('login', lambda pg: clk(pg, 'ابدأ'))]),
  ('B', True, [('list', None), ('profile', lambda pg: clk(pg, 'أمينة')), ('sessions', lambda pg: (clk(pg, 'رجوع', True), clk(pg, 'جلساتي'))), ('wallet', lambda pg: (clk(pg, 'حسابي'), clk(pg, 'محفظتي')))]),
  ('C', False, [('end', None)]),
 ],
 'therapist': [
  ('A', False, [('welcome', None)]),
  ('B', True, [('panel', None), ('sessions', lambda pg: clk(pg, 'جلساتي')), ('notes', lambda pg: clk(pg, 'ملاحظات')), ('end', lambda pg: (clk(pg, 'رجوع', True), clk(pg, 'مواعيدي')))]),
 ],
 'staff': [
  ('B', True, [('hub', lambda pg: (clk(pg, 'حسابي'), clk(pg, 'لوحات العمل'))), ('admin', lambda pg: clk(pg, 'لوحة الإدارة')),
               ('growth', lambda pg: (clk(pg, 'رجوع', True), clk(pg, 'لوحة التسويق'))), ('finance', lambda pg: (clk(pg, 'رجوع', True), clk(pg, 'لوحة المالية'))),
               ('staff', lambda pg: (clk(pg, 'رجوع', True), clk(pg, 'لوحة الإدارة'), clk(pg, 'أعضاء الإدارة والصلاحيات')))]),
 ],
}
timeline = {}
with sync_playwright() as p:
    b = p.chromium.launch()
    for role, segs in SEGMENTS.items():
        for seg, logged, scenes in segs:
            ctx = b.new_context(viewport={'width': 390, 'height': 844}, locale='ar-SA', record_video_dir='vid', record_video_size={'width': 390, 'height': 844})
            ctx.add_init_script("try{localStorage.setItem('flutter.quiz','true')}catch(e){}")
            t0 = time.time(); pg = ctx.new_page()
            url = BASE + (f"?dev={TOK[role]}&role={'therapist' if role == 'therapist' else 'patient'}" if logged else '')
            pg.goto(url, wait_until='load', timeout=90000); pg.wait_for_timeout(12000); enable(pg)
            ready = time.time() - t0
            tl = {'ready': ready, 'scenes': []}
            for key, action in scenes:
                s = time.time() - t0
                if action: action(pg)
                tl['scenes'].append({'key': f'{role}_{key}', 'at': s})
                pg.wait_for_timeout(int((DUR[f'{role}_{key}'] + 0.9) * 1000) - int((time.time() - t0 - s) * 1000))
            tl['end'] = time.time() - t0
            path = pg.video.path(); ctx.close()
            name = f'{role}_{seg}.webm'; os.replace(path, f'vid/{name}'); timeline[name] = tl
            print('segment', name, round(tl['end']), flush=True)
    b.close()
json.dump(timeline, open('vid/timeline.json', 'w'), indent=1)
print('RECORD_OK')
