'use strict';

// ── State ─────────────────────────────────────────────────────────────────────
let token = sessionStorage.getItem('token') || '';
let eventSource = null;

// ── DOM refs ──────────────────────────────────────────────────────────────────
const loginView     = document.getElementById('login-view');
const dashboardView = document.getElementById('dashboard-view');
const loginForm     = document.getElementById('login-form');
const loginError    = document.getElementById('login-error');
const loginBtn      = document.getElementById('login-btn');
const logoutBtn     = document.getElementById('logout-btn');
const streamsGrid   = document.getElementById('streams-grid');
const noStreams     = document.getElementById('no-streams');
const statusDot     = document.getElementById('connection-status');
const streamCount   = document.getElementById('stream-count');

// ── Bootstrap ─────────────────────────────────────────────────────────────────
if (token) {
  showDashboard();
} else {
  showLogin();
}

// ── Login ─────────────────────────────────────────────────────────────────────
loginForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  loginError.classList.add('hidden');
  loginBtn.disabled = true;
  loginBtn.textContent = 'Signing in…';

  const username = document.getElementById('username').value.trim();
  const password = document.getElementById('password').value;

  try {
    const res = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Login failed');

    token = data.token;
    sessionStorage.setItem('token', token);
    showDashboard();
  } catch (err) {
    loginError.textContent = err.message;
    loginError.classList.remove('hidden');
  } finally {
    loginBtn.disabled = false;
    loginBtn.textContent = 'Sign in';
  }
});

logoutBtn.addEventListener('click', () => {
  token = '';
  sessionStorage.removeItem('token');
  stopSSE();
  showLogin();
});

// ── Views ─────────────────────────────────────────────────────────────────────
function showLogin() {
  loginView.classList.remove('hidden');
  dashboardView.classList.add('hidden');
}

function showDashboard() {
  loginView.classList.add('hidden');
  dashboardView.classList.remove('hidden');
  startSSE();
}

// ── SSE ───────────────────────────────────────────────────────────────────────
// EventSource cannot send custom headers, so the token is passed as a query
// parameter. The server accepts it there for this endpoint only.
function startSSE() {
  stopSSE();
  const url = `/api/streams/live?token=${encodeURIComponent(token)}`;
  eventSource = new EventSource(url);

  eventSource.onopen = () => setStatus(true);

  eventSource.onmessage = (e) => {
    try {
      const data = JSON.parse(e.data);
      renderStreams(Array.isArray(data) ? data : []);
    } catch (err) {
      console.error('SSE parse error:', err);
    }
  };

  eventSource.onerror = () => {
    setStatus(false);
    // EventSource retries automatically; token expiry causes 401 → stop
    if (eventSource.readyState === EventSource.CLOSED) {
      stopSSE();
      showLogin();
    }
  };
}

function stopSSE() {
  if (eventSource) { eventSource.close(); eventSource = null; }
  setStatus(false);
}

// ── Render ────────────────────────────────────────────────────────────────────
function renderStreams(streams) {
  const n = streams.length;
  streamCount.textContent = `${n} stream${n !== 1 ? 's' : ''}`;

  if (n === 0) {
    noStreams.classList.remove('hidden');
    streamsGrid.innerHTML = '';
    streamsGrid.classList.add('hidden');
    return;
  }

  noStreams.classList.add('hidden');
  streamsGrid.classList.remove('hidden');

  // Diff update: keep cards that still exist, update their content
  const existing = new Set(
    [...streamsGrid.children].map(c => c.dataset.name),
  );
  const incoming = new Set(streams.map(s => s.name));

  // Remove cards for gone streams
  for (const card of [...streamsGrid.children]) {
    if (!incoming.has(card.dataset.name)) card.remove();
  }

  for (const stream of streams) {
    const existing = streamsGrid.querySelector(`[data-name="${CSS.escape(stream.name)}"]`);
    if (existing) {
      // In-place update to avoid flicker
      updateCard(existing, stream);
    } else {
      streamsGrid.appendChild(buildCard(stream));
    }
  }
}

const QUALITY_ORDER = ['source', '720p', '360p'];

function sortedVariants(variants) {
  return [...(variants || [])].sort(
    (a, b) => QUALITY_ORDER.indexOf(a) - QUALITY_ORDER.indexOf(b),
  );
}

function buildCard(stream) {
  const card = document.createElement('div');
  card.className = 'stream-card';
  card.dataset.name = stream.name;
  fillCard(card, stream);
  return card;
}

function updateCard(card, stream) {
  fillCard(card, stream);
}

function fillCard(card, stream) {
  const host     = window.location.hostname;
  const origin   = window.location.origin; // includes protocol + host + port via nginx
  const variants = sortedVariants(stream.variants);

  // Use nginx proxy paths (/hls/...) so URLs work from any network location
  const variantChips = variants.map(v => {
    const url = `${origin}/hls/transcoded/${stream.name}_${v}/index.m3u8`;
    return `<a class="quality-chip ${v === 'source' ? 'source' : ''}"
               href="${esc(url)}" target="_blank" rel="noopener">${esc(v)}</a>`;
  }).join('');

  const hlsUrl  = `${origin}/hls/live/${stream.name}/index.m3u8`;
  const rtmpUrl = `rtmp://${host}:1935/live/${stream.name}`;

  card.innerHTML = `
    <div class="card-header">
      <span class="stream-name">${esc(stream.name)}</span>
      <span class="live-badge">● LIVE</span>
    </div>

    <div class="stats">
      <div class="stat">
        <div class="stat-label">Viewers</div>
        <div class="stat-value">${stream.viewers ?? 0}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Bitrate</div>
        <div class="stat-value">${stream.bitrate ? stream.bitrate + ' kbps' : '—'}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Uptime</div>
        <div class="stat-value">${fmtUptime(stream.uptime)}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Qualities</div>
        <div class="stat-value">${variants.length || '—'}</div>
      </div>
    </div>

    ${variants.length ? `
    <div class="qualities">
      <span class="quality-label">Watch:</span>
      ${variantChips}
    </div>` : ''}

    <div class="card-footer">
      <button class="copy-btn" data-url="${esc(hlsUrl)}">📋 HLS URL</button>
      <button class="copy-btn" data-url="${esc(rtmpUrl)}">📋 RTMP URL</button>
    </div>
  `;

  card.querySelectorAll('.copy-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      navigator.clipboard.writeText(btn.dataset.url).then(() => {
        const orig = btn.textContent;
        btn.textContent = '✅ Copied!';
        setTimeout(() => { btn.textContent = orig; }, 1500);
      });
    });
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────
function setStatus(online) {
  statusDot.classList.toggle('online', online);
  statusDot.classList.toggle('offline', !online);
  statusDot.title = online ? 'Connected' : 'Reconnecting…';
}

function fmtUptime(secs) {
  if (!secs) return '—';
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  const s = secs % 60;
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}

function esc(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
