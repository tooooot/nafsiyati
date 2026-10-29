# اختبار طرف لطرف: متصفحان يدخلان نفس الغرفة عبر https://nafsiyati.wardyat.net
from playwright.sync_api import sync_playwright
URL = 'https://nafsiyati.wardyat.net/'
ARGS = ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream', '--autoplay-policy=no-user-gesture-required']
QUIZ = ['نعم', 'امرأة', 'أقل من 30', 'نعم', 'داعم ومشجّع', 'بالتعاطف']

def btn(pg, name, exact=False):
    pg.get_by_role('button', name=name, exact=exact).first.click(timeout=20000)
    pg.wait_for_timeout(900)

def run():
    with sync_playwright() as p:
        b = p.chromium.launch(args=ARGS)
        pages = []
        for i in range(2):
            c = b.new_context(viewport={'width': 390, 'height': 844}, locale='ar-SA', permissions=['camera', 'microphone'])
            pg = c.new_page()
            pg.on('console', lambda m, i=i: print(f'P{i}:', m.text[:300]) if any(k in m.text.lower() for k in ('exception', 'null check', 'livekit', 'ice', 'fail')) else None)
            pg.goto(URL, wait_until='load', timeout=90000)
            pg.wait_for_timeout(12000)
            pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
            pg.wait_for_timeout(1500)
            btn(pg, 'ابدأ'); btn(pg, 'Google')
            for a in QUIZ: btn(pg, a)
            btn(pg, 'جلساتي', exact=False)
            pg.get_by_role('textbox').first.fill('probe' + 'e2e42')
            btn(pg, 'ادخل الجلسة')
            pages.append(pg)
        pages[0].wait_for_timeout(25000)
        for i, pg in enumerate(pages):
            pg.screenshot(path=f'call{i}.png', timeout=120000)
        b.close()

if __name__ == '__main__':
    run()
