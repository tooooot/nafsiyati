const test = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../api.js');

const users = {
  tTher: { id: 'th1', name: 'د. اختبار', roles: ['user'] },
  tPat: { id: 'p1', name: 'مريض', roles: ['user'] },
  tPat2: { id: 'p2', name: 'مريض ثانٍ', roles: ['user'] },
  tAdmin: { id: 'ad1', name: 'مدير', roles: ['admin'] },
};
let base, srv;
test.before(async () => {
  const { server } = createApp({ getUser: async (t) => users[t] || null, lk: { key: 'k', secret: 's', url: 'wss://x', demo: true } });
  srv = server; await new Promise((r) => server.listen(0, r)); base = 'http://127.0.0.1:' + server.address().port;
});
test.after(() => srv.close());
const call = async (m, p, tok, body) => { const r = await fetch(base + p, { method: m, headers: { 'Content-Type': 'application/json', ...(tok ? { Authorization: 'Bearer ' + tok } : {}) }, body: body ? JSON.stringify(body) : undefined }); return { s: r.status, j: await r.json() }; };
const inMin = (m) => new Date(Date.now() + m * 60000).toISOString();

test('تدفق كامل: تقديم معالج ← توثيق ← موعد ← حجز ← فيديو', async () => {
  assert.equal((await call('POST', '/api/therapist/apply', null, { name: 'x', licenseNo: '1' })).s, 401);
  assert.equal((await call('POST', '/api/therapist/apply', 'tTher', { name: 'د. اختبار', licenseNo: 'DZ-1', priceDzd: 5000, topics: ['القلق'] })).j.status, 'pending');
  assert.equal((await call('GET', '/api/therapists')).j.length, 0, 'غير الموثّق لا يظهر');
  assert.equal((await call('POST', '/api/therapist/slots', 'tTher', { start: inMin(300) })).s, 403, 'غير الموثّق لا يضيف مواعيد');
  assert.equal((await call('GET', '/api/admin/therapists', 'tPat')).s, 403, 'غير المدير ممنوع');
  assert.equal((await call('POST', '/api/admin/therapists/th1/status', 'tAdmin', { status: 'verified' })).s, 200);
  assert.equal((await call('GET', '/api/therapists')).j.length, 1);
  const slot = (await call('POST', '/api/therapist/slots', 'tTher', { start: inMin(300) })).j;
  assert.equal((await call('POST', '/api/therapist/slots', 'tTher', { start: slot.start })).s, 409, 'تكرار الموعد');
  assert.equal((await call('POST', '/api/therapist/slots', 'tTher', { start: '2020-01-01T00:00:00Z' })).s, 400, 'موعد ماضٍ');
  assert.equal((await call('POST', '/api/appointments', 'tTher', { slotId: slot.id })).s, 400, 'لا يحجز عند نفسه');
  const apt = (await call('POST', '/api/appointments', 'tPat', { slotId: slot.id })).j;
  assert.ok(apt.id);
  assert.equal((await call('POST', '/api/appointments', 'tPat2', { slotId: slot.id })).s, 409, 'لا حجز مزدوج');
  assert.equal((await call('POST', `/api/appointments/${apt.id}/video-token`, 'tPat')).s, 425, 'مبكر جداً');
  assert.equal((await call('POST', `/api/appointments/${apt.id}/video-token`, 'tPat2')).s, 404, 'غريب لا يدخل');
  assert.equal((await call('GET', `/api/appointments/${apt.id}/notes`, 'tPat')).s, 404, 'المريض لا يرى الملاحظات');
  assert.equal((await call('PUT', `/api/appointments/${apt.id}/notes`, 'tTher', { body: 'سري' })).s, 200);
  assert.equal((await call('GET', `/api/appointments/${apt.id}/notes`, 'tTher')).j.body, 'سري');
  assert.equal((await call('GET', '/api/appointments', 'tPat')).j[0].patient, undefined, 'المريض لا يرى حقل المريض');
  assert.equal((await call('GET', '/api/appointments', 'tTher')).j[0].patient, 'مريض');
  assert.equal((await call('POST', `/api/appointments/${apt.id}/cancel`, 'tPat')).s, 200);
  const again = (await call('POST', '/api/appointments', 'tPat2', { slotId: slot.id }));
  assert.equal(again.s, 200, 'الموعد المُلغى يعود متاحاً');
});

test('/api/me: حالة المعالج والمدير', async () => {
  assert.equal((await call('GET', '/api/me')).s, 401);
  const m = (await call('GET', '/api/me', 'tTher')).j; assert.equal(m.therapist.status, 'verified'); assert.equal(m.user.isAdmin, false);
  assert.equal((await call('GET', '/api/me', 'tPat')).j.therapist, null);
  assert.equal((await call('GET', '/api/me', 'tAdmin')).j.user.isAdmin, true);
});

test('نافذة الفيديو: داخل 10 دقائق يُصدر توكناً، وبعد الانتهاء يُرفض', async () => {
  const slot = (await call('POST', '/api/therapist/slots', 'tTher', { start: inMin(5), minutes: 30 })).j;
  const apt = (await call('POST', '/api/appointments', 'tPat', { slotId: slot.id })).j;
  const t = await call('POST', `/api/appointments/${apt.id}/video-token`, 'tPat');
  assert.equal(t.s, 200); assert.equal(t.j.url, 'wss://x');
  const claims = JSON.parse(Buffer.from(t.j.token.split('.')[1], 'base64url'));
  assert.equal(claims.video.room, 'apt-' + apt.id); assert.equal(claims.sub, 'p1');
  assert.equal((await call('POST', `/api/appointments/${apt.id}/video-token`, 'tTher')).s, 200, 'المعالج أيضاً');
});

test('غرف التجربة: قالب الاسم فقط', async () => {
  assert.equal((await call('POST', '/api/video/token', null, { room: 'demo-abcd12' })).s, 200);
  assert.equal((await call('POST', '/api/video/token', null, { room: 'apt-abc' })).s, 403);
});
