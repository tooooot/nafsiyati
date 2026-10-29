# اختبار نموذج «انضم كمعالج» من الواجهة ثم ظهور الطلب عند المدير ثم توثيقه وظهور المعالج للمرضى.
import os, json, urllib.request
from playwright.sync_api import sync_playwright
BASE = 'https://nafsiyati.wardyat.net/'
APPLY, ADMIN = os.environ['DEV_APPLY'], os.environ['DEV_ADMIN']

def api(path, tok, body=None):
    r = urllib.request.Request(BASE + 'api' + path, headers={'Authorization': 'Bearer ' + tok, 'User-Agent': 'Mozilla/5.0 e2e', 'Content-Type': 'application/json'}, data=json.dumps(body).encode() if body is not None else None)
    return json.load(urllib.request.urlopen(r, timeout=30))

def clk(pg, name):
    loc = pg.get_by_role('button', name=name)
    if loc.count() == 0: loc = pg.get_by_role('tab', name=name)
    if loc.count() == 0: loc = pg.locator('flt-semantics').filter(has_text=name)
    try: loc.first.click(timeout=30000)
    except Exception:
        print('CLKFAIL', name, [x.strip() for x in pg.locator('flt-semantics').all_inner_texts()][:25], flush=True); pg.screenshot(path='fail.png', timeout=60000); raise
    pg.wait_for_timeout(2000)

with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_context(viewport={'width': 390, 'height': 844}, locale='ar-SA').new_page()
    pg.goto(f'{BASE}?dev={APPLY}&role=therapist', wait_until='load', timeout=90000); pg.wait_for_timeout(13000)
    for _ in range(10):
        pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()"); pg.wait_for_timeout(1200)
        if pg.get_by_role('button').count() > 0 or pg.get_by_role('textbox').count() > 0: break
    pg.screenshot(path='apply0_form.png', timeout=120000)
    vals = [('الاسم الكامل', 'د. اختبار الواجهة'), ('التخصص', 'أخصائي نفسي'), ('رقم الترخيص', 'DZ-UI-77'), ('سعر الجلسة', '4500'), ('المجالات', 'القلق، النوم'), ('نبذة', 'نبذة اختبار')]
    for label, v in vals:
        tb = pg.get_by_role('textbox', name=label)
        if tb.count() == 0: tb = pg.locator('flt-semantics').filter(has_text=label)
        tb.first.click(timeout=30000); pg.wait_for_timeout(500); pg.keyboard.type(v, delay=20); pg.wait_for_timeout(300)
    pg.screenshot(path='apply1_filled.png', timeout=120000)
    clk(pg, 'أرسل للمراجعة'); pg.wait_for_timeout(2500)
    pg.screenshot(path='apply2_sent.png', timeout=120000)
    b.close()
pend = api('/admin/therapists?status=pending', ADMIN)
mine = [t for t in pend if t['licenseNo'] == 'DZ-UI-77']
print('PENDING', [(t['name'], t['licenseNo'], t['priceDzd'], t['topics']) for t in mine], flush=True)
assert len(mine) == 1 and mine[0]['priceDzd'] == 4500, 'الطلب لم يصل الخادم من النموذج'
tid = mine[0]['id']
assert not any(t['id'] == tid for t in json.load(urllib.request.urlopen(urllib.request.Request(BASE + 'api/therapists', headers={'User-Agent': 'Mozilla/5.0'})))), 'غير الموثّق ظهر للمرضى'
api(f'/admin/therapists/{tid}/status', ADMIN, {'status': 'verified'})
assert any(t['id'] == tid for t in json.load(urllib.request.urlopen(urllib.request.Request(BASE + 'api/therapists', headers={'User-Agent': 'Mozilla/5.0'})))), 'الموثّق لم يظهر'
api(f'/admin/therapists/{tid}/status', ADMIN, {'status': 'rejected'})
print('APPLY_UI_OK')
