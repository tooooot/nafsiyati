# اختبار طرف لطرف عبر الواجهتين: مريض (حجز قائم) ومعالج يدخلان الجلسة من «جلساتي».
import os
from playwright.sync_api import sync_playwright
BASE = 'https://nafsiyati.wardyat.net/'
ARGS = ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream', '--autoplay-policy=no-user-gesture-required']
QUIZ = ['نعم', 'امرأة', 'أقل من 30', 'نعم', 'داعم ومشجّع', 'بالتعاطف']

def clk(pg, name):
    loc = pg.get_by_role('button', name=name)
    if loc.count() == 0: loc = pg.get_by_role('tab', name=name)
    if loc.count() == 0: loc = pg.locator('flt-semantics').filter(has_text=name)
    loc.first.click(timeout=30000); pg.wait_for_timeout(1200)

def open_as(b, token, role):
    c = b.new_context(viewport={'width': 390, 'height': 844}, locale='ar-SA', permissions=['camera', 'microphone'])
    pg = c.new_page()
    pg.on('console', lambda m: print(role, ':', m.text[:300]) if any(k in m.text.lower() for k in ('exception', 'null check', 'livekit', 'fail')) else None)
    pg.goto(f'{BASE}?dev={token}&role={role}', wait_until='load', timeout=90000); pg.wait_for_timeout(13000)
    for _ in range(10):
        pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()"); pg.wait_for_timeout(1200)
        if pg.get_by_role('button').count() > 0: break
    if role == 'patient':
        for a in QUIZ: clk(pg, a)
    clk(pg, 'جلساتي'); pg.wait_for_timeout(2500)
    clk(pg, 'ادخل الجلسة')
    return pg

with sync_playwright() as p:
    b = p.chromium.launch(args=ARGS)
    pages = [open_as(b, os.environ['DEV_PATIENT'], 'patient'), open_as(b, os.environ['DEV_THERAPIST'], 'therapist')]
    pages[0].wait_for_timeout(25000)
    for i, pg in enumerate(pages): pg.screenshot(path=f'sess{i}.png', timeout=120000)
    b.close()
