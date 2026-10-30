const test = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../api.js');

const users = {
  tAdmin: { id: 'ad1', name: 'مدير', email: 'boss@x.com', roles: ['admin'] },
  tTher: { id: 'th1', name: 'د. معالج', email: 'th@x.com', roles: ['user'] },
  tPat: { id: 'p1', name: 'مريض', email: 'p@x.com', roles: ['user'] },
  tPat2: { id: 'p2', name: 'مريض ٢', email: 'p2@x.com', roles: ['user'] },
  tMkt: { id: 'm1', name: 'مسوّق', email: 'mkt@x.com', roles: ['user'] },
  tFin: { id: 'f1', name: 'محاسب', email: 'fin@x.com', roles: ['user'] },
  tMgr: { id: 'g1', name: 'مساعد', email: 'mgr@x.com', roles: ['user'] },
};
let base, srv;
test.before(async () => {
  const { server } = createApp({ getUser: async (t) => users[t] || null, lk: { key: 'k', secret: 's', url: 'wss://x' } });
  srv = server; await new Promise((r) => server.listen(0, r)); base = 'http://127.0.0.1:' + server.address().port;
});
test.after(() => srv.close());
const call = async (m, p, tok, body) => { const r = await fetch(base + p, { method: m, headers: { 'Content-Type': 'application/json', ...(tok ? { Authorization: 'Bearer ' + tok } : {}) }, body: body ? JSON.stringify(body) : undefined }); return { s: r.status, j: await r.json().catch(() => null) }; };
const inMin = (m) => new Date(Date.now() + m * 60000).toISOString();

test('الصلاحيات والمسوّق والمالية والقسائم والعمولة 15%', async () => {
  // تهيئة: معالج موثّق بسعر 5000 وموعدان
  await call('POST', '/api/therapist/apply', 'tTher', { name: 'د. معالج', licenseNo: 'L1', priceDzd: 5000 });
  await call('POST', '/api/therapist/cert', 'tTher', { data: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB', 'base64').toString('base64') });
  await call('POST', '/api/admin/therapists/th1/status', 'tAdmin', { status: 'verified' });
  const s1 = (await call('POST', '/api/therapist/slots', 'tTher', { start: inMin(300) })).j, s2 = (await call('POST', '/api/therapist/slots', 'tTher', { start: inMin(400) })).j;
  for (const t of ['tPat', 'tPat2', 'tMkt', 'tFin', 'tMgr']) await call('GET', '/api/me', t);

  // غير المخوَّل ممنوع
  for (const p of ['/api/admin/stats', '/api/admin/users', '/api/admin/appointments', '/api/admin/staff', '/api/growth', '/api/finance/summary']) assert.equal((await call('GET', p, 'tPat')).s, 403, p);
  assert.equal((await call('GET', '/api/admin/stats', 'tAdmin')).j.users >= 5, true);

  // إضافة أعضاء الإدارة بأدوارهم
  assert.equal((await call('POST', '/api/admin/staff', 'tPat', { email: 'mkt@x.com', role: 'marketer' })).s, 403);
  assert.equal((await call('POST', '/api/admin/staff', 'tAdmin', { email: 'mkt@x.com', role: 'marketer' })).j.perms.includes('growth'), true);
  await call('POST', '/api/admin/staff', 'tAdmin', { email: 'FIN@x.com', role: 'finance' });
  assert.equal((await call('POST', '/api/admin/staff', 'tAdmin', { email: 'mkt@x.com', role: 'marketer' })).s, 409);
  assert.equal((await call('GET', '/api/me', 'tMkt')).j.user.perms.includes('growth'), true);

  // المسوّق: أرقام وقسائم فقط
  const g = await call('GET', '/api/growth', 'tMkt'); assert.equal(g.s, 200); assert.equal(g.j.daily.length, 14); assert.equal(JSON.stringify(g.j).includes('p@x.com'), false);
  for (const p of ['/api/admin/users', '/api/admin/appointments', '/api/finance/summary', '/api/admin/staff']) assert.equal((await call('GET', p, 'tMkt')).s, 403, 'المسوّق: ' + p);
  assert.equal((await call('POST', '/api/vouchers', 'tMkt', { code: 'welcome20', percent: 20, maxUses: 1 })).s, 200);
  assert.equal((await call('POST', '/api/vouchers', 'tMkt', { code: 'bad code', percent: 20 })).s, 400);

  // القسيمة عند الحجز
  assert.equal((await call('GET', '/api/vouchers/check?code=nope', 'tPat')).s, 404);
  const b1 = await call('POST', '/api/appointments', 'tPat', { slotId: s1.id, voucher: 'welcome20' });
  assert.equal(b1.j.priceDzd, 4000); assert.equal(b1.j.discountDzd, 1000);
  assert.equal((await call('POST', '/api/appointments', 'tPat2', { slotId: s2.id, voucher: 'WELCOME20' })).s, 410, 'نفدت القسيمة');
  const b2 = await call('POST', '/api/appointments', 'tPat2', { slotId: s2.id }); assert.equal(b2.j.priceDzd, 5000);

  // المالية: لا هويات مرضى، عمولة 15%، تسجيل الدفع مرة واحدة
  const f0 = await call('GET', '/api/finance/summary', 'tFin'); assert.equal(f0.j.gross, 0); assert.equal(f0.j.outstanding, 9000);
  const apts = (await call('GET', '/api/finance/appointments?paid=0', 'tFin')).j; assert.equal(apts.length, 2); assert.equal(JSON.stringify(apts).includes('مريض'), false);
  assert.equal((await call('POST', `/api/finance/appointments/${b1.j.id}/paid`, 'tMkt', {})).s, 403);
  assert.equal((await call('POST', `/api/finance/appointments/${b1.j.id}/paid`, 'tFin', { method: 'baridimob' })).s, 200);
  assert.equal((await call('POST', `/api/finance/appointments/${b1.j.id}/paid`, 'tFin', {})).s, 409);
  const f1 = (await call('GET', '/api/finance/summary', 'tFin')).j; assert.equal(f1.gross, 4000); assert.equal(f1.platformFee, 600); assert.equal(f1.therapistsPayable, 3400);
  assert.equal((await call('POST', '/api/finance/payouts', 'tFin', { therapistId: 'th1', amount: 1000 })).s, 200);
  assert.equal((await call('GET', '/api/finance/summary', 'tFin')).j.therapists[0].balance, 2400);
  assert.equal((await call('GET', '/api/finance/export', 'tMkt')).s, 403, 'المسوّق لا يصدّر المالية');
  const ex = (await call('GET', '/api/finance/export?kind=sessions', 'tFin')).j; assert.equal(ex.count, 2); assert.ok(ex.csv.startsWith('\ufeff')); assert.ok(ex.csv.includes('بريدي موب')); assert.ok(ex.csv.includes(',600,3400')); assert.equal(ex.csv.includes('مريض'), false);
  const exp = (await call('GET', '/api/finance/export?kind=payouts', 'tFin')).j; assert.equal(exp.count, 1); assert.ok(exp.csv.includes(',1000,'));
  assert.equal((await call('GET', '/api/finance/export?kind=sessions&from=2020-01-01&to=2020-01-02', 'tFin')).j.count, 0, 'فلتر التاريخ');
  assert.equal((await call('GET', '/api/wallet', 'tPat2')).j.due, 5000);

  // الموعد المدفوع لا يُلغى، وإلغاء غير المدفوع يُرجع القسيمة
  assert.equal((await call('POST', `/api/appointments/${b1.j.id}/cancel`, 'tPat')).s, 409);
  await call('POST', '/api/vouchers', 'tMkt', { code: 'ONCE', percent: 10, maxUses: 1 });
  const s3 = (await call('POST', '/api/therapist/slots', 'tTher', { start: inMin(500) })).j;
  const b3 = await call('POST', '/api/appointments', 'tPat2', { slotId: s3.id, voucher: 'once' }); assert.equal(b3.j.priceDzd, 4500);
  assert.equal((await call('POST', `/api/appointments/${b3.j.id}/cancel`, 'tPat2')).s, 200);
  assert.equal((await call('GET', '/api/vouchers', 'tMkt')).j.find((v) => v.code === 'ONCE').used, 0);
});

test('منع تصعيد الصلاحيات وإيقاف الحساب وحذف النفس', async () => {
  await call('POST', '/api/admin/staff', 'tAdmin', { email: 'mgr@x.com', role: 'marketer', perms: ['growth', 'staff'] });
  // المساعد يملك staff لكنه لا يملك finance فلا يمنحها
  const r = await call('POST', '/api/admin/staff', 'tMgr', { email: 'x@y.com', role: 'finance', perms: ['finance', 'growth'] });
  assert.deepEqual(r.j.perms, ['growth']);
  assert.equal((await call('DELETE', '/api/admin/staff/mgr%40x.com', 'tMgr')).s, 400, 'لا يحذف نفسه');
  assert.equal((await call('DELETE', '/api/admin/staff/x%40y.com', 'tMgr')).s, 200);
  // إيقاف مستخدم
  assert.equal((await call('POST', '/api/admin/users/p2/suspend', 'tPat', { suspended: true })).s, 403);
  assert.equal((await call('POST', '/api/admin/users/p2/suspend', 'tAdmin', { suspended: true })).s, 200);
  assert.equal((await call('GET', '/api/me', 'tPat2')).s, 403);
  assert.equal((await call('POST', '/api/admin/users/p2/suspend', 'tAdmin', { suspended: false })).s, 200);
  assert.equal((await call('GET', '/api/me', 'tPat2')).s, 200);
});
