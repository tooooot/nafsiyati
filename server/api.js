// خادم صحتي النفسية (بلا اعتماديات، node:sqlite). الدخول والأدوار من wardyat-core؛ هنا المجال: معالجون، مواعيد، حجز، فيديو.
const http = require('http');
const crypto = require('crypto');
const staffMod = require('./staff.js');
const recruitMod = require('./recruit.js');
const { DatabaseSync } = require('node:sqlite');

const E = (code, msg) => Object.assign(new Error(msg), { code });
const b64 = (o) => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');
const iso = () => new Date().toISOString();
const uid = () => crypto.randomBytes(8).toString('hex');

/** يبني الخادم. getUser(token) → {id,name,email,roles}|null قابلة للحقن للاختبار. */
function createApp({ dbPath = ':memory:', getUser, lk, social, siteUrl = 'https://nafsiyati.wardyat.net', placesKey = '', placesFetch }) {
  const db = new DatabaseSync(dbPath);
  db.exec(`
    create table if not exists therapists(user_id text primary key, name text, title text, bio text, topics text, languages text,
      price_dzd integer, license_no text, status text default 'pending', created text);
    create table if not exists slots(id text primary key, therapist_id text, start text, minutes integer default 50, booked integer default 0);
    create table if not exists appointments(id text primary key, therapist_id text, patient_id text, patient_name text, slot_id text,
      start text, minutes integer, price_dzd integer, status text default 'booked', paid integer default 0, created text);
    create table if not exists notes(appointment_id text primary key, therapist_id text, body text, updated text);
    create table if not exists therapist_certs(user_id text primary key, mime text, data blob, created text);
    create index if not exists ix_slots_t on slots(therapist_id, start);
    create index if not exists ix_apt_p on appointments(patient_id);
    create index if not exists ix_apt_t on appointments(therapist_id);
  `);
  staffMod.schema(db);
  recruitMod.schema(db);
  const q = (s, ...a) => db.prepare(s).get(...a);
  const all = (s, ...a) => db.prepare(s).all(...a);
  const run = (s, ...a) => db.prepare(s).run(...a);

  const th = (r) => r && ({ id: r.user_id, name: r.name, title: r.title, bio: r.bio, topics: JSON.parse(r.topics || '[]'), languages: JSON.parse(r.languages || '[]'), priceDzd: r.price_dzd, status: r.status, hasCert: !!q('select 1 from therapist_certs where user_id=?', r.user_id) });

  function livekitToken({ room, identity, name, ttl = 1800 }) {
    const now = Math.floor(Date.now() / 1000), head = b64({ alg: 'HS256', typ: 'JWT' });
    const body = b64({ iss: lk.key, sub: identity, name, nbf: now - 5, exp: now + ttl, video: { room, roomJoin: true, canPublish: true, canSubscribe: true, canPublishData: true } });
    return head + '.' + body + '.' + crypto.createHmac('sha256', lk.secret).update(head + '.' + body).digest('base64url');
  }

  const hits = new Map();
  const limited = (ip) => { const m = Math.floor(Date.now() / 60000), k = ip + m; hits.set(k, (hits.get(k) || 0) + 1); if (hits.size > 5000) for (const x of hits.keys()) if (!x.endsWith(String(m))) hits.delete(x); return hits.get(k) > 60; };

  const routes = [];
  const R = (m, p, fn) => routes.push({ m, re: new RegExp('^' + p.replace(/:(\w+)/g, '(?<$1>[^/]+)') + '$'), fn });

  const S = staffMod.register({ R, q, all, run, E, uid, iso });
  const RC = recruitMod.register({ R, q, all, run, E, uid, iso, can: S.can, siteUrl, placesKey, fetchImpl: placesFetch });

  // ---- عام ----
  R('GET', '/api/health', async () => ({ ok: 1 }));

  R('GET', '/api/therapists', async () => {
    const now = iso();
    return all("select * from therapists where status='verified' order by name").map((t) => ({ ...th(t), slots: all('select id,start,minutes from slots where therapist_id=? and booked=0 and start>? order by start limit 6', t.user_id, now) }));
  });
  R('GET', '/api/therapists/:id', async (c) => {
    const t = q("select * from therapists where user_id=? and status='verified'", c.p.id); if (!t) throw E(404, 'غير موجود');
    return { ...th(t), slots: all('select id,start,minutes from slots where therapist_id=? and booked=0 and start>? order by start limit 60', t.user_id, iso()) };
  });

  // ---- الدخول: يمرّر رمز Google/Apple إلى wardyat-core (المفتاح عند الخادم فقط) ----
  const login = (provider) => async (c) => {
    const t = String(c.body.id_token || ''); if (t.length < 20 || t.length > 8000) throw E(400, 'رمز غير صالح');
    const r = await social(provider, t); if (!r) throw E(401, 'تعذّر الدخول'); return { token: r.token, user: r.user };
  };
  R('POST', '/api/auth/google', login('google'));
  R('POST', '/api/auth/apple', login('apple'));
  // آبل تُعيد المستخدم بـPOST نموذجي؛ نحوّله إلى التطبيق والرمز في الجزء بعد # (لا يصل للخوادم)
  R('POST', '/api/auth/apple/callback', async (c) => {
    const st = c.body.state === 'therapist' ? 'therapist' : 'patient', t = String(c.body.id_token || '');
    return { redirect: siteUrl + '/#' + (t && !c.body.error ? 'apple_id_token=' + encodeURIComponent(t) + '&' : '') + 'state=' + st };
  });

  R('GET', '/api/me', async (c) => { c.need(); const t = q('select * from therapists where user_id=?', c.user.id); return { user: { id: c.user.id, name: c.user.name, email: c.user.email, isAdmin: S.can(c.user, 'therapists'), perms: S.perms(c.user) }, therapist: t ? { ...th(t), licenseNo: t.license_no } : null }; });

  // ---- المعالج ----
  R('POST', '/api/therapist/apply', async (c) => {
    c.need(); const b = c.body, name = String(b.name || '').trim();
    if (!name || !b.licenseNo) throw E(400, 'الاسم ورقم الترخيص مطلوبان');
    const price = Math.max(0, Math.min(200000, parseInt(b.priceDzd, 10) || 0));
    run(`insert into therapists values(?,?,?,?,?,?,?,?, 'pending', ?) on conflict(user_id) do update set name=excluded.name,title=excluded.title,bio=excluded.bio,topics=excluded.topics,languages=excluded.languages,price_dzd=excluded.price_dzd,license_no=excluded.license_no`,
      c.user.id, name.slice(0, 80), String(b.title || '').slice(0, 80), String(b.bio || '').slice(0, 600), JSON.stringify((b.topics || []).slice(0, 8).map(String)), JSON.stringify((b.languages || []).slice(0, 5).map(String)), price, String(b.licenseNo).slice(0, 60), iso());
    if (b.invite) RC.registered(b.invite, c.user.id);
    return { ok: 1, status: q('select status from therapists where user_id=?', c.user.id).status };
  });
  R('GET', '/api/therapist/me', async (c) => { c.need(); const t = q('select * from therapists where user_id=?', c.user.id); if (!t) throw E(404, 'لا ملف معالج'); return { ...th(t), licenseNo: t.license_no, slots: all('select id,start,minutes,booked from slots where therapist_id=? and start>? order by start', c.user.id, iso()) }; });
  const verifiedTherapist = (c) => { c.need(); const t = q("select * from therapists where user_id=? and status='verified'", c.user.id); if (!t) throw E(403, 'حساب المعالج غير موثّق بعد'); return t; };
  R('POST', '/api/therapist/slots', async (c) => {
    verifiedTherapist(c); const start = new Date(c.body.start), minutes = Math.max(20, Math.min(120, parseInt(c.body.minutes, 10) || 50));
    if (isNaN(start) || start < new Date()) throw E(400, 'موعد غير صالح');
    const s = start.toISOString();
    if (q('select 1 x from slots where therapist_id=? and start=?', c.user.id, s)) throw E(409, 'الموعد مضاف مسبقاً');
    const id = uid(); run('insert into slots(id,therapist_id,start,minutes) values(?,?,?,?)', id, c.user.id, s, minutes); RC.byUser(c.user.id, 'launched'); return { id, start: s, minutes };
  });
  R('DELETE', '/api/therapist/slots/:id', async (c) => { verifiedTherapist(c); const r = run('delete from slots where id=? and therapist_id=? and booked=0', c.p.id, c.user.id); if (!r.changes) throw E(409, 'لا يمكن حذف موعد محجوز أو غير موجود'); return { ok: 1 }; });

  // ---- الحجز ----
  R('POST', '/api/appointments', async (c) => {
    c.need(); const s = q('select * from slots where id=?', String(c.body.slotId || '')); if (!s) throw E(404, 'الموعد غير موجود');
    const t = q("select * from therapists where user_id=? and status='verified'", s.therapist_id); if (!t) throw E(404, 'المعالج غير متاح');
    if (t.user_id === c.user.id) throw E(400, 'لا يمكنك حجز موعد عند نفسك');
    if (new Date(s.start) < new Date()) throw E(400, 'الموعد انتهى');
    let price = t.price_dzd, discount = 0, vcode = null, v = null;
    if (c.body.voucher) { v = S.voucherFor(c.body.voucher, c.user.id); vcode = v.code; discount = Math.round(price * v.percent / 100); price -= discount; }
    const id = uid();
    db.exec('begin immediate');
    try {
      const r = run('update slots set booked=1 where id=? and booked=0', s.id);
      if (!r.changes) throw E(409, 'الموعد حُجز للتو، اختر موعداً آخر');
      run('insert into appointments(id,therapist_id,patient_id,patient_name,slot_id,start,minutes,price_dzd,created,voucher,discount_dzd) values(?,?,?,?,?,?,?,?,?,?,?)', id, s.therapist_id, c.user.id, String(c.user.name || '').slice(0, 60), s.id, s.start, s.minutes, price, iso(), vcode, discount);
      if (v) { const r2 = run('update vouchers set used=used+1 where code=? and (max_uses=0 or used<max_uses)', v.code); if (!r2.changes) throw E(410, 'استُنفدت القسيمة'); run('insert into voucher_use values(?,?,?)', v.code, c.user.id, id); }
      db.exec('commit');
    } catch (e) { db.exec('rollback'); throw e; }
    return { id, start: s.start, minutes: s.minutes, priceDzd: price, discountDzd: discount, therapist: th(t).name };
  });
  const aptOut = (a, viewer) => ({ id: a.id, start: a.start, minutes: a.minutes, status: a.status, priceDzd: a.price_dzd, paid: !!a.paid, therapistId: a.therapist_id, therapist: (q('select name from therapists where user_id=?', a.therapist_id) || {}).name, ...(viewer === a.therapist_id ? { patient: a.patient_name } : {}) });
  R('GET', '/api/appointments', async (c) => { c.need(); return all('select * from appointments where patient_id=? or therapist_id=? order by start desc limit 200', c.user.id, c.user.id).map((a) => aptOut(a, c.user.id)); });
  R('POST', '/api/appointments/:id/cancel', async (c) => {
    c.need(); const a = q('select * from appointments where id=?', c.p.id);
    if (!a || (a.patient_id !== c.user.id && a.therapist_id !== c.user.id)) throw E(404, 'غير موجود');
    if (a.status !== 'booked') throw E(409, 'لا يمكن إلغاء هذا الموعد');
    if (a.paid) throw E(409, 'الموعد مدفوع؛ تواصل مع الدعم لإلغائه');
    if (new Date(a.start) - Date.now() < 3600e3 && a.patient_id === c.user.id) throw E(409, 'الإلغاء قبل الموعد بأقل من ساعة غير متاح');
    run("update appointments set status='cancelled' where id=?", a.id); run('update slots set booked=0 where id=?', a.slot_id);
    if (a.voucher) { run('delete from voucher_use where code=? and appointment_id=?', a.voucher, a.id); run('update vouchers set used=max(used-1,0) where code=?', a.voucher); }
    return { ok: 1 };
  });

  // ---- الفيديو: توكن مربوط بالموعد (نافذة: قبله 10 دقائق حتى بعد نهايته 10 دقائق) ----
  R('POST', '/api/appointments/:id/video-token', async (c) => {
    c.need(); const a = q('select * from appointments where id=?', c.p.id);
    if (!a || (a.patient_id !== c.user.id && a.therapist_id !== c.user.id)) throw E(404, 'غير موجود');
    if (a.status !== 'booked') throw E(409, 'الموعد غير فعّال');
    const st = new Date(a.start).getTime(), now = Date.now();
    if (now < st - 10 * 60e3) throw E(425, 'الجلسة لم تبدأ بعد، يمكن الدخول قبلها بعشر دقائق');
    if (now > st + a.minutes * 60e3 + 10 * 60e3) throw E(410, 'انتهى وقت الجلسة');
    const ttl = Math.max(60, Math.floor((st + a.minutes * 60e3 + 10 * 60e3 - now) / 1000));
    return { url: lk.url, token: livekitToken({ room: 'apt-' + a.id, identity: c.user.id, name: c.user.name || 'مشارك', ttl }) };
  });
  if (lk.demo) R('POST', '/api/video/token', async (c) => { // غرف التجربة (للاختبار الآلي فقط)
    const room = String(c.body.room || ''); if (!/^demo-[a-z0-9]{4,32}$/.test(room)) throw E(403, 'الغرفة غير مسموحة');
    const identity = 'u-' + crypto.randomBytes(6).toString('hex'); return { url: lk.url, token: livekitToken({ room, identity, name: String(c.body.name || 'مستخدم').slice(0, 40) }), identity };
  });

  // ---- ملاحظات المعالج السرية (لا يراها المريض) ----
  R('GET', '/api/appointments/:id/notes', async (c) => { c.need(); const a = q('select * from appointments where id=? and therapist_id=?', c.p.id, c.user.id); if (!a) throw E(404, 'غير موجود'); const n = q('select body from notes where appointment_id=?', a.id); return { body: n ? n.body : '' }; });
  R('PUT', '/api/appointments/:id/notes', async (c) => { c.need(); const a = q('select * from appointments where id=? and therapist_id=?', c.p.id, c.user.id); if (!a) throw E(404, 'غير موجود'); run('insert into notes values(?,?,?,?) on conflict(appointment_id) do update set body=excluded.body, updated=excluded.updated', a.id, c.user.id, String(c.body.body || '').slice(0, 8000), iso()); return { ok: 1 }; });

  // صورة الشهادة: خاصة، تُحفظ في القاعدة وتُعرض للإدارة المخوّلة فقط
  R('POST', '/api/therapist/cert', async (c) => {
    c.need(); if (!q('select 1 from therapists where user_id=?', c.user.id)) throw E(400, 'قدّم ملفك أولاً ثم ارفع الشهادة');
    const buf = Buffer.from(String(c.body.data || ''), 'base64');
    const mime = buf.length > 8 && buf[0] === 0xff && buf[1] === 0xd8 ? 'image/jpeg' : buf.length > 8 && buf.subarray(1, 4).toString() === 'PNG' ? 'image/png' : '';
    if (!mime) throw E(400, 'الصورة يجب أن تكون JPG أو PNG');
    if (buf.length > 2_000_000) throw E(413, 'الصورة كبيرة (الحد 2 ميغابايت)');
    run('insert into therapist_certs values(?,?,?,?) on conflict(user_id) do update set mime=excluded.mime,data=excluded.data,created=excluded.created', c.user.id, mime, buf, iso());
    return { ok: 1 };
  });
  R('GET', '/api/admin/therapists/:id/cert', async (c) => {
    c.need(); if (!S.can(c.user, 'therapists')) throw E(403, 'للمدير فقط');
    const r = q('select mime,data from therapist_certs where user_id=?', c.p.id); if (!r) throw E(404, 'لا شهادة مرفوعة');
    return { mime: r.mime, data: Buffer.from(r.data).toString('base64') };
  });

  // ---- الإدارة: توثيق المعالجين ----
  R('GET', '/api/admin/therapists', async (c) => { c.need(); if (!S.can(c.user, 'therapists')) throw E(403, 'للمدير فقط'); return all('select * from therapists where status=? order by created', String(c.query.status || 'pending')).map((t) => ({ ...th(t), licenseNo: t.license_no, created: t.created })); });
  R('POST', '/api/admin/therapists/:id/status', async (c) => { c.need(); if (!S.can(c.user, 'therapists')) throw E(403, 'للمدير فقط'); const st = String(c.body.status); if (!['verified', 'rejected', 'pending'].includes(st)) throw E(400, 'حالة غير صالحة'); if (st === 'verified' && !q('select 1 from therapist_certs where user_id=?', c.p.id)) throw E(400, 'لا يمكن التوثيق قبل رفع صورة الشهادة'); const r = run('update therapists set status=? where user_id=?', st, c.p.id); if (!r.changes) throw E(404, 'غير موجود'); if (st === 'verified') RC.byUser(c.p.id, 'verified'); return { ok: 1 }; });

  const send = (res, code, obj) => { res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(obj)); };
  const server = http.createServer((req, res) => {
    const ip = (req.headers['cf-connecting-ip'] || req.socket.remoteAddress || '').toString();
    if (limited(ip)) return send(res, 429, { error: 'طلبات كثيرة' });
    const u = new URL(req.url, 'http://x'); let raw = '';
    req.on('data', (d) => { raw += d; if (raw.length > (u.pathname === '/api/therapist/cert' ? 3_000_000 : 20000)) req.destroy(); });
    req.on('end', async () => {
      try {
        let hit, p;
        for (const r of routes) { if (r.m !== req.method) continue; const m = r.re.exec(u.pathname); if (m) { hit = r; p = m.groups || {}; break; } }
        if (!hit) return send(res, 404, { error: 'غير موجود' });
        let body = {}; if (raw) { if (/x-www-form-urlencoded/.test(req.headers['content-type'] || '')) body = Object.fromEntries(new URLSearchParams(raw)); else { try { body = JSON.parse(raw); } catch { throw E(400, 'JSON غير صالح'); } } }
        const tok = (req.headers.authorization || '').replace(/^Bearer /, '');
        const user = tok ? await getUser(tok) : null;
        if (user) {
          run('insert into seen_users(id,email,name,created,last_seen) values(?,?,?,?,?) on conflict(id) do update set email=excluded.email,name=excluded.name,last_seen=excluded.last_seen', user.id, String(user.email || '').toLowerCase(), String(user.name || '').slice(0, 80), iso(), iso());
          if (q('select suspended from seen_users where id=?', user.id).suspended) throw E(403, 'الحساب موقوف');
        }
        const c = { p, body, query: Object.fromEntries(u.searchParams), user, need() { if (!user) throw E(401, 'سجّل الدخول أولاً'); } };
        const out = await hit.fn(c);
        if (out && out.redirect) { res.writeHead(302, { Location: out.redirect, 'Cache-Control': 'no-store' }); return res.end(); }
        send(res, 200, out);
      } catch (e) { send(res, e.code || 500, { error: e.code ? e.message : 'خطأ في الخادم' }); if (!e.code) console.error(e); }
    });
  });
  return { server, db };
}

// ---- التشغيل الفعلي ----
if (require.main === module) {
  const env = process.env;
  if (!env.LIVEKIT_API_KEY || !env.LIVEKIT_API_SECRET || !env.CORE_APP_KEY) { console.error('متغيرات البيئة ناقصة'); process.exit(1); }
  const cache = new Map();
  const getUser = async (token) => {
    const k = crypto.createHash('sha256').update(token).digest('hex'), hit = cache.get(k);
    if (hit && hit.exp > Date.now()) return hit.user;
    const r = await fetch('https://core.wardyat.net/v1/me', { headers: { Authorization: 'Bearer ' + token, 'X-App-Key': env.CORE_APP_KEY } });
    const user = r.ok ? (await r.json()).user : null;
    cache.set(k, { user, exp: Date.now() + 60000 }); if (cache.size > 2000) cache.clear();
    return user;
  };
  const social = async (provider, id_token) => {
    const r = await fetch('https://core.wardyat.net/v1/auth/' + provider, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-App-Key': env.CORE_APP_KEY }, body: JSON.stringify({ id_token }) });
    return r.ok ? r.json() : null;
  };
  const { server } = createApp({ dbPath: '/app/data/nafsiyati.db', getUser, social, placesKey: env.PLACES_API_KEY || '', lk: { key: env.LIVEKIT_API_KEY, secret: env.LIVEKIT_API_SECRET, url: env.LIVEKIT_URL || 'wss://lk.wardyat.net', demo: env.DEMO_VIDEO === '1' } });
  server.listen(3000, () => console.log('nafsiyati-api :3000'));
}
module.exports = { createApp };
