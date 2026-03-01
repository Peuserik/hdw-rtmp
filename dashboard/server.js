'use strict';

const express = require('express');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const MEDIAMTX_API_URL = process.env.MEDIAMTX_API_URL || 'http://localhost:9997';
const MEDIAMTX_API_BASE = process.env.MEDIAMTX_API_BASE || '/v3';
const DASHBOARD_USER = process.env.DASHBOARD_USER || 'admin';
const DASHBOARD_PASSWORD = process.env.DASHBOARD_PASSWORD || 'changeme';
const JWT_SECRET = process.env.JWT_SECRET || 'change-this-secret-in-production';

// ── Rate limiters ──────────────────────────────────────────────────────────────
// Strict limiter for the login endpoint – prevents brute-force attacks
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many login attempts, please try again later.' },
});

// General limiter for authenticated API endpoints and static assets
const apiLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
});

// ── Middleware ────────────────────────────────────────────────────────────────
app.use(express.json());
app.use(apiLimiter);
app.use(express.static(path.join(__dirname, 'public')));

// ── Auth helper ───────────────────────────────────────────────────────────────
function requireAuth(req, res, next) {
  const auth = req.headers.authorization || '';
  // Accept token from Authorization header OR query param (required for SSE)
  const token = (auth.startsWith('Bearer ') ? auth.slice(7) : null)
    || req.query.token;

  if (!token) return res.status(401).json({ error: 'Unauthorized' });

  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}

// ── Login ─────────────────────────────────────────────────────────────────────
app.post('/api/login', loginLimiter, (req, res) => {
  const { username, password } = req.body || {};
  if (username === DASHBOARD_USER && password === DASHBOARD_PASSWORD) {
    const token = jwt.sign({ username }, JWT_SECRET, { expiresIn: '8h' });
    return res.json({ token });
  }
  res.status(401).json({ error: 'Invalid credentials' });
});

// ── MediaMTX helpers ──────────────────────────────────────────────────────────
async function fetchPaths() {
  const res = await fetch(`${MEDIAMTX_API_URL}${MEDIAMTX_API_BASE}/paths/list`);
  if (!res.ok) throw new Error(`MediaMTX API returned ${res.status}`);
  const data = await res.json();
  return data.items || [];
}

// Track previous bytesReceived per path for live bitrate calculation
const bytesCache = new Map();

function calcBitrate(pathName, currentBytes) {
  const now = Date.now();
  const cached = bytesCache.get(pathName);

  if (!cached) {
    bytesCache.set(pathName, { bytes: currentBytes, ts: now });
    return 0;
  }

  const elapsed = (now - cached.ts) / 1000;
  if (elapsed <= 0) return 0;

  const delta = Math.max(0, currentBytes - cached.bytes);
  const kbps = Math.round((delta * 8) / elapsed / 1000);
  bytesCache.set(pathName, { bytes: currentBytes, ts: now });
  return kbps;
}

function summariseStreams(paths) {
  const streams = {};
  const now = Date.now();

  // First pass – collect source streams
  for (const p of paths) {
    if (!p.ready || !p.name.startsWith('live/')) continue;
    const key = p.name.slice('live/'.length);
    const readyMs = p.readyTime ? new Date(p.readyTime).getTime() : now;
    streams[key] = {
      name: key,
      variants: [],
      viewers: 0,
      bitrate: calcBitrate(p.name, p.bytesReceived || 0),
      uptime: Math.max(0, Math.round((now - readyMs) / 1000)),
      readyTime: p.readyTime,
    };
  }

  // Second pass – aggregate transcoded variants and count real viewers
  for (const p of paths) {
    if (!p.ready || !p.name.startsWith('transcoded/')) continue;
    const variant = p.name.slice('transcoded/'.length);
    const m = variant.match(/^(.+?)_(360p|720p|source)$/);
    if (!m) continue;
    const [, key, quality] = m;
    if (!streams[key]) continue; // orphan variant (source gone)

    streams[key].viewers += (p.readers || []).length;
    if (!streams[key].variants.includes(quality)) {
      streams[key].variants.push(quality);
    }
  }

  // Evict bytesCache entries for paths that are no longer active
  const activePaths = new Set(paths.map(p => p.name));
  for (const key of bytesCache.keys()) {
    if (!activePaths.has(key)) bytesCache.delete(key);
  }

  return Object.values(streams);
}

// ── Central polling loop ──────────────────────────────────────────────────────
let latestStreams = [];
const sseClients = new Set();

async function poll() {
  try {
    const paths = await fetchPaths();
    latestStreams = summariseStreams(paths);
  } catch (err) {
    // Keep previous state on error; log for ops visibility
    console.error(`[poll] MediaMTX API unreachable (${MEDIAMTX_API_URL}): ${err.message}. Retrying in 2s…`);
  }

  const payload = `data: ${JSON.stringify(latestStreams)}\n\n`;
  for (const res of sseClients) {
    try { res.write(payload); } catch { /* client disconnected */ }
  }
}

setInterval(poll, 2000);
poll(); // initial fetch

// ── REST – snapshot ───────────────────────────────────────────────────────────
app.get('/api/streams', requireAuth, (_req, res) => {
  res.json(latestStreams);
});

// ── SSE – live updates ────────────────────────────────────────────────────────
app.get('/api/streams/live', requireAuth, (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  // Send current state immediately so the client doesn't wait up to 2 s
  res.write(`data: ${JSON.stringify(latestStreams)}\n\n`);

  sseClients.add(res);
  req.on('close', () => sseClients.delete(res));
});

// ── Health ────────────────────────────────────────────────────────────────────
app.get('/healthz', (_req, res) => res.json({ status: 'ok' }));
app.get('/readyz', (_req, res) => res.json({ status: 'ok' }));

// ── SPA fallback ──────────────────────────────────────────────────────────────
app.get('*', (_req, res) =>
  res.sendFile(path.join(__dirname, 'public', 'index.html')),
);

// ── Start ──────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`Dashboard listening on http://0.0.0.0:${PORT}`);
  console.log(`MediaMTX API: ${MEDIAMTX_API_URL}${MEDIAMTX_API_BASE}`);
});
