// خادم نفسيتي (بلا اعتماديات). المرحلة الحالية: توكنات الفيديو لغرف التجربة فقط.
// لاحقاً: يتحقق من جلسة wardyat-core ومن أن الحجز يخص المستخدم قبل إصدار التوكن.
const http = require('http');
const crypto = require('crypto');

const KEY = process.env.LIVEKIT_API_KEY, SECRET = process.env.LIVEKIT_API_SECRET;
const LK_URL = process.env.LIVEKIT_URL || 'wss://lk.wardyat.net';
if (!KEY || !SECRET) { console.error('مفاتيح LiveKit مفقودة'); process.exit(1); }

const b64 = (o) => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');
function livekitToken({ room, identity, name, ttl = 1800 }) {
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'HS256', typ: 'JWT' });
  const body = b64({
    iss: KEY, sub: identity, name, nbf: now - 5, exp: now + ttl,
    video: { room, roomJoin: true, canPublish: true, canSubscribe: true, canPublishData: true },
  });
  const sig = crypto.createHmac('sha256', SECRET).update(head + '.' + body).digest('base64url');
  return head + '.' + body + '.' + sig;
}

// تحديد معدل بسيط لكل IP (30 طلباً/دقيقة)
const hits = new Map();
function limited(ip) {
  const m = Math.floor(Date.now() / 60000), k = ip + m;
  hits.set(k, (hits.get(k) || 0) + 1);
  if (hits.size > 5000) for (const x of hits.keys()) if (!x.endsWith(String(m))) hits.delete(x);
  return hits.get(k) > 30;
}

const send = (res, code, obj) => { res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(obj)); };

http.createServer((req, res) => {
  const ip = (req.headers['cf-connecting-ip'] || req.socket.remoteAddress || '').toString();
  if (req.method === 'GET' && req.url === '/api/health') return send(res, 200, { ok: 1 });
  if (req.method === 'POST' && req.url === '/api/video/token') {
    if (limited(ip)) return send(res, 429, { error: 'طلبات كثيرة' });
    let raw = '';
    req.on('data', (d) => { raw += d; if (raw.length > 4096) req.destroy(); });
    req.on('end', () => {
      let b; try { b = JSON.parse(raw || '{}'); } catch { return send(res, 400, { error: 'JSON غير صالح' }); }
      const room = String(b.room || ''), name = String(b.name || 'مستخدم').slice(0, 40);
      // غرف التجربة فقط حتى يُربط الحجز: demo-<حروف/أرقام>
      if (!/^demo-[a-z0-9]{4,32}$/.test(room)) return send(res, 403, { error: 'الغرفة غير مسموحة' });
      const identity = 'u-' + crypto.randomBytes(6).toString('hex');
      send(res, 200, { url: LK_URL, token: livekitToken({ room, identity, name }), identity });
    });
    return;
  }
  send(res, 404, { error: 'غير موجود' });
}).listen(3000, () => console.log('nafsiyati-api :3000'));
