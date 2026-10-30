// تجنيد المعالجين: مستهدفون من خرائط Google ← رسالة ← صفحة تعليمية ← تسجيل ← توثيق ← إطلاق.
// كل مرحلة تُسجَّل تلقائياً وتصل المسوّق كإشعار (تغذية راجعة)، ولا إرسال آلي: المسوّق يضغط «إرسال» فتُفتح الرسالة جاهزة.
const crypto = require('crypto');

// بلدان الانطلاق: إضافة بلد = إضافة سطر هنا (لا حصر للجزائر)
const COUNTRIES = {
  dz: { name: 'الجزائر', region: 'DZ', dial: '213', cities: ['الجزائر العاصمة', 'وهران', 'قسنطينة', 'عنابة', 'سطيف', 'باتنة', 'البليدة', 'تلمسان', 'بجاية', 'تيزي وزو'] },
  tn: { name: 'تونس', region: 'TN', dial: '216', cities: ['تونس', 'صفاقس', 'سوسة'] },
  sa: { name: 'السعودية', region: 'SA', dial: '966', cities: ['الرياض', 'جدة', 'الدمام'] },
};
const QUERIES = ['عيادة نفسية', 'أخصائي نفساني', 'مركز علاج نفسي', 'psychologue cabinet'];
// المراحل بترتيبها؛ ما عدا «تم العثور» تُسجَّل كلها كأحداث مؤرّخة
const STAGES = ['found', 'sent', 'opened', 'registered', 'learned', 'verified', 'launched'];
const STAGE_AR = { found: 'تم العثور', sent: 'أُرسلت الدعوة', opened: 'فتح الصفحة', registered: 'سجّل', learned: 'أنهى التعليم', verified: 'تم التوثيق', launched: 'أُطلق للناس' };
const STEPS = ['intro', 'register', 'license', 'slots', 'session', 'notes', 'wallet'];

function schema(db) {
  db.exec(`
    create table if not exists rc_targets(id text primary key, place_id text unique, name text, phone text, website text, country text, city text, rating real, token text unique, user_id text, sent_by text, declined integer default 0, note text, steps text default '[]', created text);
    create table if not exists rc_events(target_id text, stage text, at text, by text, primary key(target_id, stage));
    create table if not exists rc_notes(id text primary key, target_id text, text text, created text, read integer default 0);
    create table if not exists rc_usage(day text primary key, n integer);
  `);
}

function register({ R, q, all, run, E, uid, iso, can, siteUrl, placesKey, fetchImpl }) {
  const need = (c) => { c.need(); if (!can(c.user, 'growth')) throw E(403, 'لا تملك هذه الصلاحية'); };
  const doFetch = fetchImpl || ((...a) => fetch(...a));
  const link = (t) => `${siteUrl}/join/?t=${t.token}`;
  const message = (t) => `السلام عليكم ورحمة الله،\nنعرض على ${t.name} الانضمام إلى «صحتي النفسية»: منصة جلسات نفسية بالفيديو بخصوصية عالية.\nفي الرابط فيديو تعريفي وشروط المنصة وتعليمات التسجيل والتوثيق وبدء الجلسة:\n${link(t)}`;
  const digits = (p) => String(p || '').replace(/\D/g, '');

  // يسجّل مرحلة مرة واحدة، ويُشعر المسوّق
  const mark = (t, stage, by) => {
    const r = run('insert or ignore into rc_events(target_id,stage,at,by) values(?,?,?,?)', t.id, stage, iso(), by || '');
    if (r.changes && stage !== 'found') run('insert into rc_notes(id,target_id,text,created) values(?,?,?,?)', uid(), t.id, `${t.name} — ${STAGE_AR[stage]}`, iso());
    return !!r.changes;
  };
  const byToken = (tok) => { const t = q('select * from rc_targets where token=?', String(tok)); if (!t) throw E(404, 'رابط غير صالح'); return t; };
  const reached = (id) => Object.fromEntries(all('select stage,at from rc_events where target_id=?', id).map((e) => [e.stage, e.at]));
  const view = (t) => {
    const ev = reached(t.id); const last = [...STAGES].reverse().find((s) => ev[s]);
    return { id: t.id, name: t.name, phone: t.phone, website: t.website, country: t.country, city: t.city, rating: t.rating, declined: !!t.declined, note: t.note || '', steps: JSON.parse(t.steps || '[]'), stage: last, stageAr: STAGE_AR[last], next: STAGES.find((s) => !ev[s]) || null, events: ev, link: link(t) };
  };

  // ---- المسوّق ----
  R('GET', '/api/recruit/countries', async (c) => { need(c); return COUNTRIES; });

  R('POST', '/api/recruit/discover', async (c) => {
    need(c); const co = COUNTRIES[String(c.body.country)], city = String(c.body.city || '');
    if (!co || !co.cities.includes(city)) throw E(400, 'بلد أو مدينة غير مدعومة');
    if (!placesKey) throw E(503, 'مفتاح خرائط Google غير مضبوط');
    const day = iso().slice(0, 10), cap = Number(process.env.RC_DAILY_CAP || 40);
    let added = 0, seen = 0;
    for (const qy of QUERIES) {
      const used = (q('select n from rc_usage where day=?', day) || { n: 0 }).n;
      if (used >= cap) { if (!seen) throw E(429, 'بلغ الحد اليومي لاستدعاءات الخرائط'); break; }
      run('insert into rc_usage(day,n) values(?,1) on conflict(day) do update set n=n+1', day);
      const r = await doFetch('https://places.googleapis.com/v1/places:searchText', {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': placesKey, 'x-goog-fieldmask': 'places.id,places.displayName,places.internationalPhoneNumber,places.websiteUri,places.rating,places.businessStatus' },
        body: JSON.stringify({ textQuery: `${qy} ${city}`, languageCode: 'ar', regionCode: co.region, maxResultCount: 20 }),
        signal: AbortSignal.timeout(15000),
      });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw E(502, (j.error && j.error.message) || 'تعذّر الاتصال بخرائط Google');
      for (const p of j.places || []) {
        if (p.businessStatus && p.businessStatus !== 'OPERATIONAL') continue;
        seen++;
        const id = uid(), tok = crypto.randomBytes(7).toString('base64url');
        const ins = run('insert or ignore into rc_targets(id,place_id,name,phone,website,country,city,rating,token,created) values(?,?,?,?,?,?,?,?,?,?)', id, p.id, (p.displayName && p.displayName.text) || '', digits(p.internationalPhoneNumber), p.websiteUri || '', String(c.body.country), city, p.rating || null, tok, iso());
        if (ins.changes) { added++; mark({ id, name: '' }, 'found', c.user.email); }
      }
    }
    return { added, seen };
  });

  R('GET', '/api/recruit/targets', async (c) => {
    need(c);
    const rows = all('select * from rc_targets order by created desc limit 500').map(view);
    const st = String(c.query.stage || ''), city = String(c.query.city || '');
    return rows.filter((t) => (!st || t.stage === st) && (!city || t.city === city));
  });

  // الهرم: كم مستهدف وصل كل مرحلة (التغطية الرجعية)، وكم تأخر عن المرحلة التالية
  R('GET', '/api/recruit/funnel', async (c) => {
    need(c);
    const total = q('select count(*) n from rc_targets').n;
    const stages = STAGES.map((s) => ({ stage: s, name: STAGE_AR[s], count: q('select count(*) n from rc_events where stage=?', s).n }));
    const stuck = all('select * from rc_targets where declined=0').map(view).filter((t) => t.next && t.stage !== 'found' && t.events[t.stage] && Date.now() - Date.parse(t.events[t.stage]) > 3 * 86400000).length;
    return { total, stages, stuck, declined: q('select count(*) n from rc_targets where declined=1').n };
  });

  R('POST', '/api/recruit/targets/:id/sent', async (c) => {
    need(c); const t = q('select * from rc_targets where id=?', c.p.id); if (!t) throw E(404, 'غير موجود');
    run('update rc_targets set sent_by=? where id=?', c.user.email || c.user.id, t.id); mark(t, 'sent', c.user.email);
    const wa = t.phone ? `https://wa.me/${t.phone}?text=${encodeURIComponent(message(t))}` : '';
    return { message: message(t), link: link(t), wa };
  });
  R('POST', '/api/recruit/targets/:id/note', async (c) => { need(c); const r = run('update rc_targets set note=?, declined=? where id=?', String(c.body.note || '').slice(0, 500), c.body.declined ? 1 : 0, c.p.id); if (!r.changes) throw E(404, 'غير موجود'); return { ok: 1 }; });

  R('GET', '/api/recruit/notifications', async (c) => { need(c); return { unread: q('select count(*) n from rc_notes where read=0').n, items: all('select id,text,created,read from rc_notes order by created desc limit 50') }; });
  R('POST', '/api/recruit/notifications/read', async (c) => { need(c); run('update rc_notes set read=1'); return { ok: 1 }; });

  // ---- صفحة المستهدف العامة (بلا دخول، بالرمز الشخصي) ----
  R('GET', '/api/join/:token', async (c) => { const t = byToken(c.p.token); mark(t, 'opened'); return { name: t.name, steps: JSON.parse(t.steps || '[]'), total: STEPS.length }; });
  R('POST', '/api/join/:token/step', async (c) => {
    const t = byToken(c.p.token), s = String(c.body.step); if (!STEPS.includes(s)) throw E(400, 'خطوة غير معروفة');
    const done = [...new Set([...JSON.parse(t.steps || '[]'), s])]; run('update rc_targets set steps=? where id=?', JSON.stringify(done), t.id);
    if (STEPS.every((x) => done.includes(x))) mark(t, 'learned');
    return { done };
  });

  // ---- ربط تلقائي من بقية الخادم ----
  return {
    registered(token, userId) { const t = q('select * from rc_targets where token=?', String(token || '')); if (!t) return; run('update rc_targets set user_id=? where id=?', userId, t.id); mark(t, 'registered'); },
    byUser(userId, stage) { const t = q('select * from rc_targets where user_id=?', userId); if (t) mark(t, stage); },
  };
}

module.exports = { schema, register, COUNTRIES, STAGES, STEPS };
