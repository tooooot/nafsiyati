const test = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../api.js');

const users = {
  tAdmin: { id: 'ad1', name: 'مدير', email: 'boss@x.com', roles: ['admin'] },
  tMkt: { id: 'm1', name: 'مسوّق', email: 'mkt@x.com', roles: ['user'] },
  tPat: { id: 'p1', name: 'مريض', email: 'p@x.com', roles: ['user'] },
  tDoc: { id: 'd1', name: 'د. مكتب', email: 'doc@x.com', roles: ['user'] },
};
const places = [{ id: 'P1', displayName: { text: 'عيادة النور' }, internationalPhoneNumber: '+213 550 12 34 56', rating: 4.5, businessStatus: 'OPERATIONAL' }, { id: 'P2', displayName: { text: 'مغلقة' }, businessStatus: 'CLOSED_PERMANENTLY' }];
let base, srv;
test.before(async () => {
  const { server } = createApp({ getUser: async (t) => users[t] || null, lk: { key: 'k', secret: 's', url: 'wss://x' }, placesKey: 'KEY',
    placesFetch: async () => ({ ok: true, json: async () => ({ places }) }) });
  srv = server; await new Promise((r) => server.listen(0, r)); base = 'http://127.0.0.1:' + server.address().port;
});
test.after(() => srv.close());
const call = async (m, p, tok, body) => { const r = await fetch(base + p, { method: m, headers: { 'Content-Type': 'application/json', ...(tok ? { Authorization: 'Bearer ' + tok } : {}) }, body: body ? JSON.stringify(body) : undefined }); return { s: r.status, j: await r.json() }; };

test('مسار التجنيد: من الاكتشاف إلى الإطلاق مع إشعار لكل مرحلة', async () => {
  await call('GET', '/api/me', 'tMkt'); await call('GET', '/api/me', 'tPat');
  await call('POST', '/api/admin/staff', 'tAdmin', { email: 'mkt@x.com', role: 'marketer' });
  assert.equal((await call('GET', '/api/recruit/targets', 'tPat')).s, 403);       // المريض ممنوع
  assert.equal((await call('POST', '/api/recruit/discover', 'tMkt', { country: 'dz', city: 'باريس' })).s, 400);
  const d = await call('POST', '/api/recruit/discover', 'tMkt', { country: 'dz', city: 'وهران' });
  assert.equal(d.j.added, 1);                                                      // المغلقة تُتجاهل، والمكرر لا يتضاعف
  assert.equal((await call('POST', '/api/recruit/discover', 'tMkt', { country: 'dz', city: 'وهران' })).j.added, 0);
  const t = (await call('GET', '/api/recruit/targets', 'tMkt')).j[0];
  assert.equal(t.stage, 'found'); assert.equal(t.phone, '213550123456');

  const sent = await call('POST', `/api/recruit/targets/${t.id}/sent`, 'tMkt');
  assert.match(sent.j.wa, /^https:\/\/wa\.me\/213550123456\?text=/);
  const tok = new URL(sent.j.link).searchParams.get('t');

  assert.equal((await call('GET', '/api/join/' + tok)).j.name, 'عيادة النور');      // فتح الصفحة (عامة)
  assert.equal((await call('GET', '/api/join/خطأ')).s, 404);
  let done; for (const s of ['intro', 'register', 'license', 'slots', 'session', 'notes', 'wallet']) done = (await call('POST', `/api/join/${tok}/step`, null, { step: s })).j.done;
  assert.equal(done.length, 7);

  await call('POST', '/api/therapist/apply', 'tDoc', { name: 'د. مكتب', licenseNo: 'L9', priceDzd: 4000, invite: tok });
  await call('POST', '/api/admin/therapists/d1/status', 'tAdmin', { status: 'verified' });
  await call('POST', '/api/therapist/slots', 'tDoc', { start: new Date(Date.now() + 9e6).toISOString() });

  const v = (await call('GET', '/api/recruit/targets', 'tMkt')).j[0];
  assert.equal(v.stage, 'launched'); assert.equal(v.next, null);
  const f = (await call('GET', '/api/recruit/funnel', 'tMkt')).j;
  assert.deepEqual(f.stages.map((x) => x.count), [1, 1, 1, 1, 1, 1, 1]);
  const n = (await call('GET', '/api/recruit/notifications', 'tMkt')).j;
  assert.equal(n.unread, 6);                                                       // مرسلة، فتح، سجّل، تعليم، توثيق، إطلاق
  await call('POST', '/api/recruit/notifications/read', 'tMkt');
  assert.equal((await call('GET', '/api/recruit/notifications', 'tMkt')).j.unread, 0);
});
