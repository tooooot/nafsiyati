# اختبار واجهة المدير: يفتح «إدارة المعالجين» ويوثّق طلباً معلّقاً بالنقر، ثم يتحقق عبر الـAPI.
import os, json, urllib.request
from playwright.sync_api import sync_playwright
BASE = 'https://nafsiyati.wardyat.net/'
TOK = os.environ['DEV_ADMIN']
QUIZ = ['نعم', 'امرأة', 'أقل من 30', 'نعم', 'داعم ومشجّع', 'بالتعاطف']

def api(path):
    r = urllib.request.Request(BASE + 'api' + path, headers={'Authorization': 'Bearer ' + TOK})
    return json.load(urllib.request.urlopen(r, timeout=30))

def clk(pg, name):
    loc = pg.get_by_role('button', name=name)
    if loc.count() == 0: loc = pg.get_by_role('tab', name=name)
    if loc.count() == 0: loc = pg.locator('flt-semantics').filter(has_text=name)
    try:
        loc.first.click(timeout=30000)
    except Exception:
        print('CLKFAIL', name, [x.strip() for x in pg.locator('flt-semantics').all_inner_texts()][:25], flush=True)
        pg.screenshot(path='fail.png', timeout=60000); raise
    pg.wait_for_timeout(2500)

pending = api('/admin/therapists?status=pending')
print('PENDING_BEFORE', [t['name'] for t in pending], flush=True)
assert pending, 'لا طلب معلّق للاختبار'
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_context(viewport={'width': 390, 'height': 844}, locale='ar-SA').new_page()
    pg.goto(f'{BASE}?dev={TOK}&role=patient', wait_until='load', timeout=90000); pg.wait_for_timeout(13000)
    for _ in range(10):
        pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()"); pg.wait_for_timeout(1200)
        if pg.get_by_role('button').count() > 0: break
    for a in QUIZ: clk(pg, a)
    clk(pg, 'حسابي'); pg.screenshot(path='admin0_account.png', timeout=120000)
    clk(pg, 'إدارة المعالجين'); pg.wait_for_timeout(2500); pg.screenshot(path='admin1_list.png', timeout=120000)
    clk(pg, 'توثيق'); pg.wait_for_timeout(2500); pg.screenshot(path='admin2_after.png', timeout=120000)
    b.close()
after = api('/admin/therapists?status=pending')
ver = [t['name'] for t in api('/admin/therapists?status=verified')]
print('PENDING_AFTER', len(after), 'VERIFIED', ver, flush=True)
assert len(after) == len(pending) - 1, 'التوثيق بالنقر لم يغيّر الحالة'
print('ADMIN_UI_OK')
