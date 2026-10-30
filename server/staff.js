// لوحات الإدارة والتسويق والمالية: صلاحيات دقيقة، والخادم هو من يفرضها (المسوّق والمالية لا يريان بيانات سريرية ولا هويات المرضى).
const FEE_PERCENT = 15; // عمولة المنصة من سعر الجلسة (قرار المالك 2026-10-29)
const ALL = ['stats', 'users', 'appointments', 'therapists', 'staff', 'vouchers', 'growth', 'finance', 'payments'];
const ROLE_PERMS = { admin: ALL, marketer: ['growth', 'vouchers'], support: ['growth'], finance: ['finance', 'payments', 'stats'] };
const fee = (price) => Math.round((price || 0) * FEE_PERCENT / 100);

function schema(db) {
  db.exec(`
    create table if not exists seen_users(id text primary key, email text, name text, quiz integer default 0, suspended integer default 0, created text, last_seen text);
    create table if not exists staff(email text primary key, role text, perms text, added_by text, created text);
    create table if not exists vouchers(code text primary key, percent integer, max_uses integer default 0, used integer default 0, expires text, active integer default 1, created_by text, created text);
    create table if not exists voucher_use(code text, user_id text, appointment_id text, primary key(code, user_id));
    create table if not exists payments(id text primary key, appointment_id text, amount integer, method text, note text, created_by text, created text);
    create table if not exists payouts(id text primary key, therapist_id text, amount integer, note text, created_by text, created text);
  `);
  for (const col of ['voucher text', 'discount_dzd integer default 0']) { try { db.exec('alter table appointments add column ' + col); } catch { /* موجود */ } }
}

function register({ R, q, all, run, E, uid, iso }) {
  const staffRow = (u) => u && u.email ? q('select * from staff where email=?', String(u.email).toLowerCase()) : null;
  const perms = (u) => {
    if (!u) return [];
    if ((u.roles || []).includes('admin') || (u.roles || []).includes('owner')) return ALL;
    const s = staffRow(u); return s ? JSON.parse(s.perms || '[]') : [];
  };
  const can = (u, p) => perms(u).includes(p);
  const need = (c, p) => { c.need(); if (!can(c.user, p)) throw E(403, 'لا تملك هذه الصلاحية'); };

  // ---- المدير ----
  R('GET', '/api/admin/stats', async (c) => {
    need(c, 'stats');
    const n = (s, ...a) => q(s, ...a).n;
    return {
      users: n('select count(*) n from seen_users'),
      therapists: { pending: n("select count(*) n from therapists where status='pending'"), verified: n("select count(*) n from therapists where status='verified'"), rejected: n("select count(*) n from therapists where status='rejected'") },
      appointments: { booked: n("select count(*) n from appointments where status='booked'"), cancelled: n("select count(*) n from appointments where status='cancelled'"), upcoming: n("select count(*) n from appointments where status='booked' and start>?", iso()) },
    };
  });
  R('GET', '/api/admin/users', async (c) => {
    need(c, 'users'); const t = '%' + String(c.query.q || '').trim().toLowerCase() + '%';
    return all('select id,email,name,suspended,created,last_seen from seen_users where lower(coalesce(name,\'\')) like ? or lower(coalesce(email,\'\')) like ? order by created desc limit 100', t, t).map((u) => ({ ...u, suspended: !!u.suspended }));
  });
  R('POST', '/api/admin/users/:id/suspend', async (c) => {
    need(c, 'users'); if (c.p.id === c.user.id) throw E(400, 'لا يمكنك إيقاف حسابك');
    const r = run('update seen_users set suspended=? where id=?', c.body.suspended ? 1 : 0, c.p.id); if (!r.changes) throw E(404, 'غير موجود'); return { ok: 1 };
  });
  R('GET', '/api/admin/appointments', async (c) => {
    need(c, 'appointments');
    return all('select a.id,a.start,a.minutes,a.status,a.price_dzd,a.paid,a.patient_name,t.name therapist from appointments a left join therapists t on t.user_id=a.therapist_id order by a.start desc limit 200')
      .map((a) => ({ id: a.id, start: a.start, minutes: a.minutes, status: a.status, priceDzd: a.price_dzd, paid: !!a.paid, patient: a.patient_name, therapist: a.therapist }));
  });

  // ---- أعضاء الإدارة والصلاحيات ----
  const staffOut = (s) => ({ email: s.email, role: s.role, perms: JSON.parse(s.perms || '[]'), created: s.created });
  const cleanPerms = (actor, want) => { const mine = perms(actor); return [...new Set((want || []).map(String))].filter((p) => ALL.includes(p)).filter((p) => mine.includes(p)); };
  R('GET', '/api/admin/staff', async (c) => { need(c, 'staff'); return { all: ALL, roles: ROLE_PERMS, staff: all('select * from staff order by created').map(staffOut) }; });
  R('POST', '/api/admin/staff', async (c) => {
    need(c, 'staff'); const email = String(c.body.email || '').trim().toLowerCase(), role = String(c.body.role || '');
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw E(400, 'البريد غير صالح'); if (!ROLE_PERMS[role]) throw E(400, 'دور غير معروف');
    if (q('select 1 x from staff where email=?', email)) throw E(409, 'العضو مضاف مسبقاً');
    const p = cleanPerms(c.user, c.body.perms || ROLE_PERMS[role]);
    run('insert into staff values(?,?,?,?,?)', email, role, JSON.stringify(p), c.user.email || c.user.id, iso()); return staffOut(q('select * from staff where email=?', email));
  });
  R('PUT', '/api/admin/staff/:email', async (c) => {
    need(c, 'staff'); const email = decodeURIComponent(c.p.email).toLowerCase(); const s = q('select * from staff where email=?', email); if (!s) throw E(404, 'غير موجود');
    if (email === String(c.user.email || '').toLowerCase()) throw E(400, 'لا تعدّل صلاحياتك بنفسك');
    run('update staff set perms=? where email=?', JSON.stringify(cleanPerms(c.user, c.body.perms)), email); return staffOut(q('select * from staff where email=?', email));
  });
  R('DELETE', '/api/admin/staff/:email', async (c) => {
    need(c, 'staff'); const email = decodeURIComponent(c.p.email).toLowerCase();
    if (email === String(c.user.email || '').toLowerCase()) throw E(400, 'لا يمكنك حذف نفسك'); run('delete from staff where email=?', email); return { ok: 1 };
  });

  // ---- التسويق: أرقام مجمّعة فقط (لا أسماء ولا بيانات سريرية) + القسائم ----
  R('GET', '/api/growth', async (c) => {
    need(c, 'growth'); const n = (s, ...a) => q(s, ...a).n, since = new Date(Date.now() - 13 * 864e5).toISOString().slice(0, 10);
    const days = {}; for (let i = 13; i >= 0; i--) days[new Date(Date.now() - i * 864e5).toISOString().slice(0, 10)] = 0;
    for (const r of all('select substr(created,1,10) d, count(*) n from seen_users where substr(created,1,10)>=? group by d', since)) days[r.d] = r.n;
    return {
      daily: Object.entries(days).map(([date, count]) => ({ date, count })),
      funnel: { users: n('select count(*) n from seen_users'), quiz: n('select count(*) n from seen_users where quiz=1'), booked: n("select count(distinct patient_id) n from appointments where status!='cancelled'"), paid: n('select count(distinct patient_id) n from appointments where paid=1') },
      therapists: { verified: n("select count(*) n from therapists where status='verified'"), pending: n("select count(*) n from therapists where status='pending'") },
    };
  });
  R('GET', '/api/vouchers', async (c) => { need(c, 'vouchers'); return all('select * from vouchers order by created desc').map((v) => ({ code: v.code, percent: v.percent, maxUses: v.max_uses, used: v.used, expires: v.expires, active: !!v.active })); });
  R('POST', '/api/vouchers', async (c) => {
    need(c, 'vouchers'); const code = String(c.body.code || '').trim().toUpperCase(), percent = parseInt(c.body.percent, 10), max = Math.max(0, parseInt(c.body.maxUses, 10) || 0);
    if (!/^[A-Z0-9]{3,20}$/.test(code)) throw E(400, 'الكود 3–20 حرفاً إنجليزياً أو رقماً'); if (!(percent >= 1 && percent <= 100)) throw E(400, 'النسبة بين 1 و100');
    const exp = c.body.expires ? new Date(c.body.expires) : null; if (exp && isNaN(exp)) throw E(400, 'تاريخ غير صالح');
    if (q('select 1 x from vouchers where code=?', code)) throw E(409, 'الكود مستعمل');
    run('insert into vouchers(code,percent,max_uses,expires,created_by,created) values(?,?,?,?,?,?)', code, percent, max, exp ? exp.toISOString() : null, c.user.id, iso()); return { ok: 1, code };
  });
  R('POST', '/api/vouchers/:code/toggle', async (c) => { need(c, 'vouchers'); const r = run('update vouchers set active=? where code=?', c.body.active ? 1 : 0, c.p.code.toUpperCase()); if (!r.changes) throw E(404, 'غير موجود'); return { ok: 1 }; });
  // معاينة قسيمة للمريض قبل الحجز
  R('GET', '/api/vouchers/check', async (c) => { c.need(); const v = voucherFor(String(c.query.code || ''), c.user.id); return { code: v.code, percent: v.percent }; });

  function voucherFor(raw, userId) {
    const v = q('select * from vouchers where code=?', String(raw).trim().toUpperCase());
    if (!v || !v.active) throw E(404, 'القسيمة غير صالحة');
    if (v.expires && new Date(v.expires) < new Date()) throw E(410, 'القسيمة منتهية');
    if (v.max_uses && v.used >= v.max_uses) throw E(410, 'استُنفدت القسيمة');
    if (q('select 1 x from voucher_use where code=? and user_id=?', v.code, userId)) throw E(409, 'استعملتَ هذه القسيمة من قبل');
    return v;
  }

  // ---- المالية: لا هويات مرضى ولا بيانات سريرية ----
  R('GET', '/api/finance/summary', async (c) => {
    need(c, 'finance');
    const paid = all('select a.therapist_id, a.price_dzd from appointments a where a.paid=1');
    const unpaid = all("select price_dzd from appointments where paid=0 and status='booked'");
    const by = {};
    for (const a of paid) { const t = (by[a.therapist_id] ||= { gross: 0, fee: 0 }); t.gross += a.price_dzd; t.fee += fee(a.price_dzd); }
    const out = Object.entries(by).map(([id, v]) => {
      const out = q('select coalesce(sum(amount),0) n from payouts where therapist_id=?', id).n, name = (q('select name from therapists where user_id=?', id) || {}).name || id;
      return { therapistId: id, name, gross: v.gross, fee: v.fee, payable: v.gross - v.fee, paidOut: out, balance: v.gross - v.fee - out };
    });
    const gross = paid.reduce((s, a) => s + a.price_dzd, 0), feeTotal = paid.reduce((s, a) => s + fee(a.price_dzd), 0);
    return { feePercent: FEE_PERCENT, gross, platformFee: feeTotal, therapistsPayable: gross - feeTotal, outstanding: unpaid.reduce((s, a) => s + a.price_dzd, 0), unpaidCount: unpaid.length, therapists: out };
  });
  R('GET', '/api/finance/appointments', async (c) => {
    need(c, 'finance'); const st = String(c.query.paid || '');
    return all(`select a.id,a.start,a.status,a.price_dzd,a.discount_dzd,a.voucher,a.paid,t.name therapist from appointments a left join therapists t on t.user_id=a.therapist_id ${st === '0' ? "where a.paid=0 and a.status='booked'" : st === '1' ? 'where a.paid=1' : ''} order by a.start desc limit 200`)
      .map((a) => ({ id: a.id, start: a.start, status: a.status, priceDzd: a.price_dzd, discountDzd: a.discount_dzd || 0, voucher: a.voucher, fee: fee(a.price_dzd), paid: !!a.paid, therapist: a.therapist }));
  });
  R('POST', '/api/finance/appointments/:id/paid', async (c) => {
    need(c, 'payments'); const a = q('select * from appointments where id=?', c.p.id); if (!a) throw E(404, 'غير موجود');
    if (a.status !== 'booked') throw E(409, 'الموعد ملغى'); if (a.paid) throw E(409, 'مسجّل كمدفوع مسبقاً');
    const method = ['cash', 'baridimob', 'bank'].includes(c.body.method) ? c.body.method : 'cash';
    run('insert into payments values(?,?,?,?,?,?,?)', uid(), a.id, a.price_dzd, method, String(c.body.note || '').slice(0, 200), c.user.id, iso()); run('update appointments set paid=1 where id=?', a.id); return { ok: 1 };
  });
  R('POST', '/api/finance/payouts', async (c) => {
    need(c, 'payments'); const amount = parseInt(c.body.amount, 10); if (!(amount > 0)) throw E(400, 'مبلغ غير صالح');
    if (!q('select 1 x from therapists where user_id=?', String(c.body.therapistId || ''))) throw E(404, 'معالج غير موجود');
    run('insert into payouts values(?,?,?,?,?,?)', uid(), c.body.therapistId, amount, String(c.body.note || '').slice(0, 200), c.user.id, iso()); return { ok: 1 };
  });

  // ---- المريض: محفظتي (مدفوعاتي وقسائمي) ----
  R('GET', '/api/wallet', async (c) => {
    c.need();
    const rows = all('select a.id,a.start,a.status,a.price_dzd,a.discount_dzd,a.voucher,a.paid,t.name therapist from appointments a left join therapists t on t.user_id=a.therapist_id where a.patient_id=? order by a.start desc limit 100', c.user.id)
      .map((a) => ({ id: a.id, start: a.start, status: a.status, priceDzd: a.price_dzd, discountDzd: a.discount_dzd || 0, voucher: a.voucher, paid: !!a.paid, therapist: a.therapist }));
    return { due: rows.filter((r) => r.status === 'booked' && !r.paid).reduce((s, r) => s + r.priceDzd, 0), items: rows };
  });

  // ---- تسجيل المستخدمين وإنهاء الاستبيان ----
  R('POST', '/api/me/quiz', async (c) => { c.need(); run('update seen_users set quiz=1 where id=?', c.user.id); return { ok: 1 }; });
  return { can, perms, voucherFor, fee, staffRow };
}
module.exports = { schema, register, FEE_PERCENT, ALL, ROLE_PERMS, fee };
