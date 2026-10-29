# اللوحات من الواجهة: المدير يتنقل بين لوحاته، والمريض يفتح محفظته. يتحقق من النصوص الظاهرة.
import os, json, urllib.request
from playwright.sync_api import sync_playwright
BASE = 'https://nafsiyati.wardyat.net/'
ADMIN, PAT = os.environ['DEV_ADMIN'], os.environ['DEV_PATIENT']
QUIZ = ['نعم', 'امرأة', 'أقل من 30', 'نعم', 'داعم ومشجّع', 'بالتعاطف']

def api(path, tok, body=None, method=None):
    r = urllib.request.Request(BASE + 'api' + path, method=method, headers={'Authorization': 'Bearer ' + tok, 'User-Agent': 'Mozilla/5.0 e2e', 'Content-Type': 'application/json'}, data=json.dumps(body).encode() if body is not None else None)
    return json.load(urllib.request.urlopen(r, timeout=30))

def clk(pg, name):
    loc = pg.get_by_role('button', name=name, exact=True)
    if loc.count() == 0: loc = pg.get_by_role('button', name=name)
    if loc.count() == 0: loc = pg.get_by_role('tab', name=name)
    if loc.count() == 0: loc = pg.locator('flt-semantics').filter(has_text=name)
    try:
        try: loc.first.click(timeout=15000)
        except Exception: pg.wait_for_timeout(3000); loc.first.click(timeout=30000, force=True)
    except Exception:
        print('CLKFAIL', name, [x.strip() for x in pg.locator('flt-semantics').all_inner_texts()][:30], flush=True); pg.screenshot(path='fail.png', timeout=60000); raise
    pg.wait_for_timeout(2500)

def texts(pg):
    inner = [x.strip().replace('\n', ' ') for x in pg.locator('flt-semantics').all_inner_texts()]
    labels = [(x.get_attribute('aria-label') or '').replace('\n', ' ') for x in pg.locator('flt-semantics[aria-label]').all()]
    return ' | '.join(inner + labels)

def must(pg, *words):
    for _ in range(12):  # قد تتأخر البيانات بعد ظهور الشاشة
        t = texts(pg)
        if all(w in t for w in words): return
        pg.wait_for_timeout(1000)
    pg.screenshot(path='must_fail.png', timeout=60000)
    print('LABELS', [x.get_attribute('aria-label') for x in pg.locator('flt-semantics[aria-label]').all()][:30], flush=True)
    for w in words:
        assert w in t, f'لم يظهر «{w}»: {t[:400]}'

def boot(b, tok, role='patient'):
    pg = b.new_context(viewport={'width': 390, 'height': 844}, locale='ar-SA').new_page()
    pg.goto(f'{BASE}?dev={tok}&role={role}', wait_until='load', timeout=90000); pg.wait_for_timeout(13000)
    for _ in range(10):
        pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()"); pg.wait_for_timeout(1200)
        if pg.get_by_role('button').count() > 0: break
    for a in QUIZ: clk(pg, a)
    return pg

try: api('/vouchers', ADMIN, {'code': 'UIDEMO', 'percent': 10, 'maxUses': 5})
except Exception as e: print('voucher exists?', e)
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = boot(b, ADMIN)
    clk(pg, 'حسابي'); clk(pg, 'لوحات العمل'); must(pg, 'لوحة الإدارة', 'لوحة التسويق', 'لوحة المالية'); pg.screenshot(path='dash0_hub.png', timeout=120000)
    clk(pg, 'لوحة التسويق'); must(pg, 'مسار المستخدم', 'UIDEMO', 'قسيمة جديدة'); pg.screenshot(path='dash1_growth.png', timeout=120000)
    clk(pg, 'رجوع')
    clk(pg, 'لوحة المالية'); must(pg, 'عمولة المنصة 15%', 'أرصدة المعالجين'); pg.screenshot(path='dash2_finance.png', timeout=120000)
    clk(pg, 'رجوع')
    clk(pg, 'لوحة الإدارة'); must(pg, 'مستخدمون', 'توثيق المعالجين', 'أعضاء الإدارة والصلاحيات'); pg.screenshot(path='dash3_admin.png', timeout=120000)
    clk(pg, 'أعضاء الإدارة والصلاحيات'); must(pg, 'إضافة عضو'); pg.screenshot(path='dash4_staff.png', timeout=120000)
    clk(pg, 'رجوع'); clk(pg, 'المستخدمون'); must(pg, 'ابحث'); pg.screenshot(path='dash5_users.png', timeout=120000)
    pw = boot(b, PAT)
    clk(pw, 'حسابي'); must(pw, 'محفظتي'); must(pw, 'لوحات العمل') if False else None
    assert 'لوحات العمل' not in texts(pw), 'المريض رأى لوحات العمل'
    clk(pw, 'محفظتي'); must(pw, 'مستحق الدفع', 'سجل الجلسات'); pw.screenshot(path='dash6_wallet.png', timeout=120000)
    b.close()
try: api('/vouchers/UIDEMO/toggle', ADMIN, {'active': False})
except Exception: pass
print('DASH_UI_OK')
