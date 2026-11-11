// FollowBoost API — Node.js + Express + SQLite (better-sqlite3).
//
// The user's OWN backend for their own app. Original code, written from
// scratch. Coins are server-side only: the balance is the ledger, and every
// earn/spend is recorded in wallet_history.
//
// HARD RULES (do not weaken these):
//  - Never accept or store an Instagram password. The /api/instagram/connect
//    endpoint takes a username only; any `password` field is rejected.
//  - Never log passwords or tokens.
//  - Orders are queued for manual fulfilment. This API never automates any
//    action on Instagram or any other service.
//  - Real Meta OAuth needs the user to create a Meta developer app; see
//    README.md. Until OAUTH_CLIENT_ID / OAUTH_CLIENT_SECRET /
//    OAUTH_REDIRECT_URI are all configured, POST /api/instagram/oauth/start
//    reports 503 and /api/instagram/oauth-url reports { configured: false }.
//    The access token is NEVER persisted — it is used once at connect time
//    to fetch the profile, then discarded.
//  - Instagram Basic Display is DEAD (Meta shut it off 2024-12-04). The
//    supported flow is the "Instagram API with Instagram Login" (Business
//    Login for Instagram): authorize at instagram.com, exchange the code at
//    api.instagram.com, read the profile at graph.instagram.com/me. Only
//    Business/Creator accounts can connect; personal accounts cannot.
//    The /me profile returns id, username, account_type, media_count and
//    (unlike Basic Display) profile_picture_url — but follower/following
//    counts are NOT fetched or stored by this build, so never display them.
//
// Run:  npm install && npm start        (PORT env, default 3000)
// Test: npm test

const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { openDb, nowIso, todayUtc, inviteCodeFor, addLedgerEntry } = require('./db');

const JWT_SECRET = process.env.JWT_SECRET || 'followboost-dev-secret-change-me';
const PORT = Number(process.env.PORT || 3000);
const TASK_COOLDOWN_MS = 24 * 60 * 60 * 1000; // 24 hours per task per user

const db = openDb();
const app = express();
app.use(cors());
app.use(express.json());

// --- Helpers ----------------------------------------------------------------

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Public shape of a user object (never includes password_hash).
function publicUser(u) {
  return { id: u.id, name: u.name, email: u.email, coins: u.coins, isAdmin: u.is_admin === 1 };
}

function signToken(userId) {
  return jwt.sign({ sub: userId }, JWT_SECRET, { expiresIn: '30d' });
}

// Auth middleware: Authorization: Bearer <JWT>
function requireAuth(req, res, next) {
  const header = req.get('Authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Missing token' });
  let payload;
  try {
    payload = jwt.verify(token, JWT_SECRET);
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(payload.sub);
  if (!user) return res.status(401).json({ error: 'User not found' });
  req.user = user;
  next();
}

// Admin middleware: only the first registered user (is_admin = 1).
function requireAdmin(req, res, next) {
  if (!req.user || !req.user.is_admin) {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
}

// --- Health -----------------------------------------------------------------

app.get('/', (req, res) => {
  res.json({ name: 'FollowBoost API', version: '1.0.2', status: 'ok' });
});

// --- Auth -------------------------------------------------------------------

app.post('/api/auth/register', (req, res) => {
  const { name, email, password } = req.body || {};
  if (!name || typeof name !== 'string' || !name.trim()) {
    return res.status(400).json({ error: 'Name is required' });
  }
  if (!email || !EMAIL_RE.test(String(email))) {
    return res.status(400).json({ error: 'Valid email is required' });
  }
  if (!password || String(password).length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters' });
  }
  const normalizedEmail = String(email).trim().toLowerCase();
  const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(normalizedEmail);
  if (existing) return res.status(409).json({ error: 'Email already registered' });

  const passwordHash = bcrypt.hashSync(String(password), 10);
  const insert = db.prepare(
    'INSERT INTO users (name, email, password_hash, coins, created_at) VALUES (?, ?, ?, 0, ?)'
  );
  const info = insert.run(name.trim(), normalizedEmail, passwordHash, nowIso());
  const userId = info.lastInsertRowid;

  // Invite code is derived from the user id (8 chars: 'FB' + base36).
  db.prepare('UPDATE users SET invite_code = ? WHERE id = ?').run(inviteCodeFor(userId), userId);

  // The very first registered user is the admin.
  const userCount = db.prepare('SELECT COUNT(*) AS n FROM users').get().n;
  if (userCount === 1) {
    db.prepare('UPDATE users SET is_admin = 1 WHERE id = ?').run(userId);
  }

  // Signup bonus: 50 coins, recorded in the ledger.
  const balance = addLedgerEntry(db, userId, 'earn', 50, 'Signup bonus');
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  res.status(201).json({ token: signToken(userId), user: { ...publicUser(user), coins: balance } });
});

app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }
  const user = db.prepare('SELECT * FROM users WHERE email = ?')
    .get(String(email).trim().toLowerCase());
  if (!user || !bcrypt.compareSync(String(password), user.password_hash)) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }
  res.json({ token: signToken(user.id), user: publicUser(user) });
});

app.get('/api/me', requireAuth, (req, res) => {
  const u = req.user;
  res.json({
    id: u.id,
    name: u.name,
    email: u.email,
    coins: u.coins,
    inviteCode: u.invite_code,
    streak: u.streak,
    isAdmin: u.is_admin === 1,
  });
});

// --- Wallet -----------------------------------------------------------------

app.get('/api/wallet', requireAuth, (req, res) => {
  const u = req.user;
  res.json({ coins: u.coins, totalEarned: u.total_earned, totalSpent: u.total_spent });
});

app.get('/api/wallet/history', requireAuth, (req, res) => {
  const rows = db.prepare(
    'SELECT id, type, amount, reason, created_at FROM wallet_history WHERE user_id = ? ORDER BY id DESC LIMIT 50'
  ).all(req.user.id);
  res.json(rows.map((r) => ({
    id: r.id, type: r.type, amount: r.amount, reason: r.reason, createdAt: r.created_at,
  })));
});

// --- Daily reward -----------------------------------------------------------
// Once per calendar day (UTC). Streak increments on consecutive days and
// resets if a day is missed. Award = min(20 + 5 * (streak - 1), 50).

app.post('/api/rewards/daily', requireAuth, (req, res) => {
  const u = req.user;
  const today = todayUtc();

  if (u.last_daily_at === today) {
    return res.json({ coins: u.coins, awarded: 0, streak: u.streak, alreadyClaimed: true });
  }

  const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  const streak = u.last_daily_at === yesterday ? u.streak + 1 : 1;
  const awarded = Math.min(20 + 5 * (streak - 1), 50);

  db.prepare('UPDATE users SET streak = ?, last_daily_at = ? WHERE id = ?')
    .run(streak, today, u.id);
  const balance = addLedgerEntry(db, u.id, 'earn', awarded, 'Daily reward');
  res.json({ coins: balance, awarded, streak, alreadyClaimed: false });
});

// --- Tasks ------------------------------------------------------------------
// Manual tasks: the user follows/likes a demo profile in Instagram
// themselves, then confirms here. One completion per user per task per 24h.

function taskAvailableAt(userId, taskId) {
  const row = db.prepare(
    'SELECT completed_at FROM task_completions WHERE user_id = ? AND task_id = ?'
  ).get(userId, taskId);
  if (!row) return null;
  const next = new Date(row.completed_at).getTime() + TASK_COOLDOWN_MS;
  return next > Date.now() ? new Date(next).toISOString() : null;
}

app.get('/api/tasks', requireAuth, (req, res) => {
  // Seeded tasks (order_id NULL) plus order-generated tasks, excluding:
  //  - the requester's own order tasks (owner_user_id == requester)
  //  - already-fulfilled order tasks (fulfilled_count >= 1)
  //  - tasks of orders already 'completed'
  //  - tasks the requester already completed
  const rows = db.prepare(
    `SELECT t.id, t.type, t.handle, t.display_name, t.avatar_color, t.coins, t.order_id
     FROM tasks t
     LEFT JOIN orders o ON o.id = t.order_id
     WHERE t.active = 1
       AND (
         t.order_id IS NULL
         OR (
           t.owner_user_id <> ?
           AND t.fulfilled_count < 1
           AND (o.status IS NULL OR o.status <> 'completed')
           AND NOT EXISTS (
             SELECT 1 FROM task_completions tc
             WHERE tc.user_id = ? AND tc.task_id = t.id
           )
         )
       )
     ORDER BY t.id`
  ).all(req.user.id, req.user.id);
  res.json(rows.map((t) => ({
    id: t.id,
    type: t.type,
    handle: t.handle,
    displayName: t.display_name,
    avatarColor: t.avatar_color,
    coins: t.coins,
    orderId: t.order_id === null ? null : t.order_id,
    // Seeded tasks have a 24h cooldown; order tasks are one-shot (a
    // completion removes them via fulfilled_count), so never on cooldown.
    availableAt: t.order_id === null ? taskAvailableAt(req.user.id, t.id) : null,
  })));
});

app.post('/api/tasks/:id/complete', requireAuth, (req, res) => {
  const taskId = Number(req.params.id);
  const task = db.prepare('SELECT * FROM tasks WHERE id = ? AND active = 1').get(taskId);
  if (!task) return res.status(404).json({ error: 'Task not found' });

  // --- Order-generated task: one completion ever, by someone other than
  // the orderer. Progress + coin award happen in ONE transaction (the
  // ledger insert + balance update are inlined here — better-sqlite3
  // cannot nest addLedgerEntry's transaction inside another one).
  if (task.order_id !== null) {
    if (task.owner_user_id === req.user.id) {
      return res.status(403).json({ error: 'Cannot complete your own order' });
    }
    if (task.fulfilled_count >= 1) {
      return res.status(409).json({ error: 'Task already completed' });
    }
    const already = db.prepare(
      'SELECT 1 FROM task_completions WHERE user_id = ? AND task_id = ?'
    ).get(req.user.id, taskId);
    if (already) return res.status(409).json({ error: 'Task already completed' });

    const reason = `Task: ${task.type} @${task.handle}`;
    const completeOrderTask = db.transaction(() => {
      db.prepare(
        'INSERT INTO task_completions (user_id, task_id, completed_at) VALUES (?, ?, ?)'
      ).run(req.user.id, taskId, nowIso());
      db.prepare('UPDATE tasks SET fulfilled_count = 1 WHERE id = ?').run(taskId);
      db.prepare('UPDATE orders SET fulfilled = fulfilled + 1 WHERE id = ?').run(task.order_id);
      const order = db.prepare('SELECT fulfilled, count FROM orders WHERE id = ?').get(task.order_id);
      const status = order.fulfilled >= order.count ? 'completed' : 'partial';
      db.prepare('UPDATE orders SET status = ? WHERE id = ?').run(status, task.order_id);
      db.prepare(
        'INSERT INTO wallet_history (user_id, type, amount, reason, created_at) VALUES (?, ?, ?, ?, ?)'
      ).run(req.user.id, 'earn', 1, reason, nowIso());
      db.prepare('UPDATE users SET coins = coins + 1, total_earned = total_earned + 1 WHERE id = ?')
        .run(req.user.id);
      return db.prepare('SELECT coins FROM users WHERE id = ?').get(req.user.id).coins;
    });
    const balance = completeOrderTask();
    return res.json({ coins: 1, newBalance: balance });
  }

  // --- Seeded task: one completion per user per 24h (unchanged v1 flow).
  const availableAt = taskAvailableAt(req.user.id, taskId);
  if (availableAt) {
    return res.status(409).json({ error: 'cooldown', availableAt });
  }

  db.prepare(
    `INSERT INTO task_completions (user_id, task_id, completed_at) VALUES (?, ?, ?)
     ON CONFLICT(user_id, task_id) DO UPDATE SET completed_at = excluded.completed_at`
  ).run(req.user.id, taskId, nowIso());
  const balance = addLedgerEntry(db, req.user.id, 'earn', task.coins, `Task: ${task.handle}`);
  res.json({ coins: task.coins, newBalance: balance });
});

// --- Orders -----------------------------------------------------------------
// Placing an order charges the coins and generates `count` tasks targeting
// the handle, so other users can fulfil the order by completing them
// (manual follows/likes only — this API never automates anything).
// Order insert + task generation happen in ONE transaction.

const ORDER_TASK_COLORS = ['#6366F1', '#F59E0B', '#10B981', '#0EA5E9', '#EC4899', '#8B5CF6', '#EF4444', '#14B8A6'];

app.post('/api/orders', requireAuth, (req, res) => {
  const { type, targetHandle, count } = req.body || {};
  if (type !== 'follow' && type !== 'like') {
    return res.status(400).json({ error: "type must be 'follow' or 'like'" });
  }
  const n = Number(count);
  if (!Number.isInteger(n) || n < 10 || n > 5000) {
    return res.status(400).json({ error: 'count must be between 10 and 5000' });
  }
  if (!targetHandle || typeof targetHandle !== 'string' || !targetHandle.trim()) {
    return res.status(400).json({ error: 'targetHandle is required' });
  }
  const handle = targetHandle.trim().replace(/^@/, '');
  const cost = n * (type === 'follow' ? 2 : 1);
  if (req.user.coins < cost) {
    return res.status(400).json({ error: 'Insufficient balance' });
  }

  const balance = addLedgerEntry(db, req.user.id, 'spend', cost, `Order: ${type} x${n} for ${handle}`);
  const createOrderWithTasks = db.transaction(() => {
    const info = db.prepare(
      `INSERT INTO orders (user_id, type, target_handle, count, cost, status, created_at)
       VALUES (?, ?, ?, ?, ?, 'queued', ?)`
    ).run(req.user.id, type, handle, n, cost, nowIso());
    const orderId = info.lastInsertRowid;
    const insertTask = db.prepare(
      `INSERT INTO tasks (type, handle, display_name, avatar_color, coins, order_id, owner_user_id, required_count, fulfilled_count)
       VALUES (?, ?, ?, ?, 1, ?, ?, ?, 0)`
    );
    for (let i = 0; i < n; i++) {
      insertTask.run(type, handle, handle, ORDER_TASK_COLORS[i % ORDER_TASK_COLORS.length], orderId, req.user.id, n);
    }
    return orderId;
  });
  const orderId = createOrderWithTasks();
  res.status(201).json({
    order: { id: orderId, type, targetHandle: handle, count: n, cost, fulfilled: 0, status: 'queued' },
    newBalance: balance,
  });
});

app.get('/api/orders', requireAuth, (req, res) => {
  const rows = db.prepare(
    'SELECT id, type, target_handle, count, cost, fulfilled, status, created_at FROM orders WHERE user_id = ? ORDER BY id DESC'
  ).all(req.user.id);
  res.json(rows.map((o) => ({
    id: o.id,
    type: o.type,
    targetHandle: o.target_handle,
    count: o.count,
    cost: o.cost,
    fulfilled: o.fulfilled,
    status: o.status,
    createdAt: o.created_at,
  })));
});

// --- Admin ------------------------------------------------------------------
// Read-only order overview for the first registered user. There is
// deliberately NO endpoint that marks an order complete without real task
// completions — orders only move via POST /api/tasks/:id/complete.

app.get('/api/admin/orders', requireAuth, requireAdmin, (req, res) => {
  const rows = db.prepare(
    `SELECT o.id, o.type, o.target_handle, o.count, o.fulfilled, o.cost, o.status, o.created_at,
            u.name AS owner_name, u.email AS owner_email
     FROM orders o JOIN users u ON u.id = o.user_id
     ORDER BY o.id DESC`
  ).all();
  res.json(rows.map((o) => ({
    id: o.id,
    type: o.type,
    targetHandle: o.target_handle,
    count: o.count,
    fulfilled: o.fulfilled,
    cost: o.cost,
    status: o.status,
    ownerName: o.owner_name,
    ownerEmail: o.owner_email,
    createdAt: o.created_at,
  })));
});

// --- Gift codes -------------------------------------------------------------

app.post('/api/gift-codes/redeem', requireAuth, (req, res) => {
  const { code } = req.body || {};
  if (!code || typeof code !== 'string') {
    return res.status(400).json({ error: 'code is required' });
  }
  const normalized = code.trim().toUpperCase();
  const gift = db.prepare('SELECT * FROM gift_codes WHERE UPPER(code) = ?').get(normalized);
  if (!gift || !gift.active) {
    return res.status(404).json({ error: 'Invalid or inactive gift code' });
  }
  const already = db.prepare('SELECT 1 FROM gift_redemptions WHERE user_id = ? AND code = ?')
    .get(req.user.id, gift.code);
  if (already) return res.status(409).json({ error: 'Gift code already redeemed' });

  db.prepare('INSERT INTO gift_redemptions (user_id, code) VALUES (?, ?)')
    .run(req.user.id, gift.code);
  const balance = addLedgerEntry(db, req.user.id, 'earn', gift.coins, `Gift code ${gift.code}`);
  res.json({ coins: gift.coins, newBalance: balance });
});

// --- Leaderboard ------------------------------------------------------------
// Real users only (every row in users is a real registered account; there
// are no seeded fake users). Auth is optional here.

app.get('/api/leaderboard', (req, res) => {
  const rows = db.prepare(
    'SELECT name, coins FROM users ORDER BY coins DESC, id ASC LIMIT 20'
  ).all();
  res.json(rows.map((r, i) => ({ rank: i + 1, name: r.name, coins: r.coins })));
});

// --- Referrals --------------------------------------------------------------

app.get('/api/referrals', requireAuth, (req, res) => {
  const u = req.user;
  const referredCount = db.prepare('SELECT COUNT(*) AS n FROM users WHERE referred_by = ?')
    .get(u.id).n;
  // Referral earnings = sum of 'Referral bonus' ledger entries for this user.
  const earned = db.prepare(
    `SELECT COALESCE(SUM(amount), 0) AS total FROM wallet_history
     WHERE user_id = ? AND type = 'earn' AND reason = 'Referral bonus'`
  ).get(u.id).total;
  res.json({ inviteCode: u.invite_code, referredCount, earnedCoins: earned });
});

app.post('/api/referrals/apply', requireAuth, (req, res) => {
  const { code } = req.body || {};
  if (!code || typeof code !== 'string') {
    return res.status(400).json({ error: 'code is required' });
  }
  const u = req.user;
  if (u.referred_by !== null) {
    return res.status(409).json({ error: 'Referral code already applied' });
  }
  const normalized = code.trim().toUpperCase();
  const referrer = db.prepare('SELECT * FROM users WHERE UPPER(invite_code) = ?').get(normalized);
  if (!referrer) return res.status(404).json({ error: 'Invalid referral code' });
  if (referrer.id === u.id) {
    return res.status(400).json({ error: 'Cannot use your own referral code' });
  }

  // Applier +25, referrer +50 — both recorded in the ledger.
  db.prepare('UPDATE users SET referred_by = ? WHERE id = ?').run(referrer.id, u.id);
  const applierBalance = addLedgerEntry(db, u.id, 'earn', 25, 'Referral bonus');
  addLedgerEntry(db, referrer.id, 'earn', 50, 'Referral bonus');
  res.json({ coins: 25, newBalance: applierBalance });
});

// --- Instagram (manual connect + Meta OAuth) -------------------------------
// Manual connect: the user types their Instagram username. No password is
// ever accepted, stored, or logged.
// Real login: "Instagram API with Instagram Login" (Business Login for
// Instagram). Basic Display is dead (shut off 2024-12-04) — do not use its
// endpoints or its `user_profile,user_media` scopes. Flow:
//   1. POST /api/instagram/oauth/start (auth) -> { url } (Meta authorize URL)
//   2. Meta redirects to GET /api/instagram/oauth/callback?code=...&state=...
//   3. Server exchanges the code at api.instagram.com/oauth/access_token
//      (short-lived token, ~1h), fetches the profile from
//      graph.instagram.com/me, stores the profile fields, and DISCARDS the
//      token — it is never persisted or logged.
// Only Business/Creator Instagram accounts can connect this way; personal
// accounts have no official API access.

const INSTAGRAM_OAUTH_SCOPE = 'instagram_business_basic';
const OAUTH_AUTHORIZE_URL = 'https://www.instagram.com/oauth/authorize';
const OAUTH_TOKEN_URL = 'https://api.instagram.com/oauth/access_token';
const OAUTH_PROFILE_URL = 'https://graph.instagram.com/me';
const OAUTH_STATE_TTL_MS = 10 * 60 * 1000; // states are single-use, 10 minutes

function oauthConfigured() {
  return Boolean(
    process.env.OAUTH_CLIENT_ID && process.env.OAUTH_CLIENT_SECRET && process.env.OAUTH_REDIRECT_URI
  );
}

function buildAuthorizeUrl(state) {
  const params = new URLSearchParams({
    client_id: process.env.OAUTH_CLIENT_ID,
    redirect_uri: process.env.OAUTH_REDIRECT_URI,
    scope: INSTAGRAM_OAUTH_SCOPE,
    response_type: 'code',
    state,
  });
  return `${OAUTH_AUTHORIZE_URL}?${params.toString()}`;
}

// Exchange an authorization code for a short-lived access token.
// `fetchImpl` is injectable so tests can stub Meta's endpoint — the real
// Meta endpoint is NEVER called from tests. Returns { accessToken,
// instagramUserId }. Throws on any failure; the message never contains
// the token.
async function exchangeCodeForToken(code, fetchImpl = fetch) {
  const body = new URLSearchParams({
    client_id: process.env.OAUTH_CLIENT_ID,
    client_secret: process.env.OAUTH_CLIENT_SECRET,
    grant_type: 'authorization_code',
    redirect_uri: process.env.OAUTH_REDIRECT_URI,
    code,
  });
  const res = await fetchImpl(OAUTH_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });
  let data = null;
  try { data = await res.json(); } catch { /* non-JSON error body */ }
  if (!res.ok || !data || !data.access_token) {
    const detail =
      (data && data.error_message) ||
      (data && data.error && data.error.message) ||
      `HTTP ${res.status}`;
    throw new Error(`Instagram token exchange failed: ${detail}`);
  }
  return {
    accessToken: data.access_token,
    instagramUserId: data.user_id != null ? String(data.user_id) : null,
  };
}

// Fetch the connected profile with a short-lived token. `fetchImpl` is
// injectable for tests. Returns { instagramUserId, username, accountType,
// mediaCount, profilePicUrl } — profilePicUrl is null when Meta does not
// return one (never faked). Follower/following counts are deliberately
// NOT requested or stored by this build.
async function fetchInstagramProfile(accessToken, fetchImpl = fetch) {
  const fields = 'id,username,account_type,media_count,profile_picture_url';
  const url =
    `${OAUTH_PROFILE_URL}?fields=${encodeURIComponent(fields)}` +
    `&access_token=${encodeURIComponent(accessToken)}`;
  const res = await fetchImpl(url);
  let data = null;
  try { data = await res.json(); } catch { /* non-JSON error body */ }
  if (!res.ok || !data || !data.username) {
    const detail =
      (data && data.error && data.error.message) || `HTTP ${res.status}`;
    throw new Error(`Instagram profile fetch failed: ${detail}`);
  }
  return {
    instagramUserId:
      data.id != null ? String(data.id)
      : data.user_id != null ? String(data.user_id) : null,
    username: String(data.username).toLowerCase(),
    accountType: data.account_type || null,
    mediaCount: typeof data.media_count === 'number' ? data.media_count : null,
    profilePicUrl: data.profile_picture_url || null,
  };
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

function oauthPage(title, heading, bodyHtml) {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">` +
    `<meta name="viewport" content="width=device-width, initial-scale=1">` +
    `<title>${escapeHtml(title)}</title><style>` +
    `body{font-family:system-ui,-apple-system,sans-serif;background:#fafafa;color:#111;` +
    `margin:0;display:flex;min-height:100vh;align-items:center;justify-content:center}` +
    `main{max-width:420px;padding:32px;text-align:center}` +
    `h1{font-size:22px;margin:0 0 12px}p{color:#444;line-height:1.5}` +
    `a.btn{display:inline-block;margin-top:20px;padding:12px 24px;border-radius:10px;` +
    `background:#7c3aed;color:#fff;text-decoration:none;font-weight:600}` +
    `</style></head><body><main><h1>${escapeHtml(heading)}</h1>${bodyHtml}</main></body></html>`;
}

function oauthSuccessPage(username) {
  return oauthPage(
    'Instagram connected — FollowBoost',
    'Instagram connected',
    `<p>Connected as <strong>@${escapeHtml(username)}</strong> — ` +
      `you can return to the FollowBoost app.</p>` +
      `<a class="btn" href="followboost://instagram/connected">Return to FollowBoost</a>`
  );
}

function oauthErrorPage(message) {
  return oauthPage(
    'Instagram login failed — FollowBoost',
    'Instagram login failed',
    `<p>${escapeHtml(message)}</p>` +
      `<p>Please try again from the FollowBoost app.</p>`
  );
}

app.post('/api/instagram/connect', requireAuth, (req, res) => {
  if (req.body && Object.prototype.hasOwnProperty.call(req.body, 'password')) {
    return res.status(400).json({ error: 'Passwords are never accepted here' });
  }
  const { username } = req.body || {};
  if (!username || typeof username !== 'string' || !username.trim()) {
    return res.status(400).json({ error: 'username is required' });
  }
  const clean = username.trim().replace(/^@/, '').toLowerCase();
  if (!/^[a-z0-9._]{1,30}$/.test(clean)) {
    return res.status(400).json({ error: 'Invalid Instagram username' });
  }
  db.prepare(
    `INSERT INTO instagram (user_id, username, connected_at) VALUES (?, ?, ?)
     ON CONFLICT(user_id) DO UPDATE SET username = excluded.username, connected_at = excluded.connected_at`
  ).run(req.user.id, clean, nowIso());
  res.json({ connected: true, username: clean });
});

app.get('/api/instagram/status', requireAuth, (req, res) => {
  const row = db.prepare(
    'SELECT username, account_type, profile_pic_url, media_count FROM instagram WHERE user_id = ?'
  ).get(req.user.id);
  if (!row) {
    return res.json({
      connected: false, username: null, profilePicUrl: null, accountType: null, mediaCount: null,
    });
  }
  res.json({
    connected: true,
    username: row.username,
    profilePicUrl: row.profile_pic_url || null,
    accountType: row.account_type || null,
    mediaCount: row.media_count === null || row.media_count === undefined ? null : row.media_count,
  });
});

app.get('/api/instagram/oauth-url', (req, res) => {
  const clientId = process.env.OAUTH_CLIENT_ID;
  const redirectUri = process.env.OAUTH_REDIRECT_URI;
  if (!clientId || !redirectUri) return res.json({ configured: false });
  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUri,
    scope: INSTAGRAM_OAUTH_SCOPE,
    response_type: 'code',
  });
  res.json({
    configured: true,
    url: `${OAUTH_AUTHORIZE_URL}?${params.toString()}`,
  });
});

// Start the OAuth login: mint a one-time state bound to this user and hand
// the app the Meta authorize URL. The app opens it in a browser; Meta
// redirects back to /api/instagram/oauth/callback.
app.post('/api/instagram/oauth/start', requireAuth, (req, res) => {
  if (!oauthConfigured()) {
    return res.status(503).json({ error: 'Instagram login is not configured on the server' });
  }
  const state = crypto.randomBytes(32).toString('hex');
  db.prepare('INSERT INTO oauth_states (state, user_id, created_at) VALUES (?, ?, ?)')
    .run(state, req.user.id, nowIso());
  res.json({ url: buildAuthorizeUrl(state) });
});

// Meta redirects here after the user approves (or denies) the login. No
// auth header — the one-time `state` is what binds this callback to the
// user who started it. Serves HTML pages (not JSON) because a browser
// lands here, not the app.
app.get('/api/instagram/oauth/callback', async (req, res) => {
  const code = req.query.code ? String(req.query.code) : null;
  const state = req.query.state ? String(req.query.state) : null;
  if (!code || !state) {
    return res.status(400).send(oauthErrorPage('Missing authorization code or state.'));
  }
  const row = db.prepare('SELECT * FROM oauth_states WHERE state = ?').get(state);
  if (!row) {
    return res.status(400).send(oauthErrorPage('Unknown or already-used login request.'));
  }
  // Single-use: delete the state now, before any network call.
  db.prepare('DELETE FROM oauth_states WHERE state = ?').run(state);
  const ageMs = Date.now() - new Date(row.created_at).getTime();
  if (!Number.isFinite(ageMs) || ageMs > OAUTH_STATE_TTL_MS) {
    return res.status(400).send(oauthErrorPage('Login request expired. Please start again from the app.'));
  }
  try {
    const { accessToken, instagramUserId } = await exchangeCodeForToken(code);
    const profile = await fetchInstagramProfile(accessToken);
    // The access token is deliberately NOT stored — only the profile.
    // OAuth overwrites a manual-connect username, same as re-connecting.
    db.prepare(
      `INSERT INTO instagram
         (user_id, username, connected_at, instagram_user_id, account_type, profile_pic_url, media_count)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET
         username = excluded.username,
         connected_at = excluded.connected_at,
         instagram_user_id = excluded.instagram_user_id,
         account_type = excluded.account_type,
         profile_pic_url = excluded.profile_pic_url,
         media_count = excluded.media_count`
    ).run(
      row.user_id, profile.username, nowIso(),
      profile.instagramUserId || instagramUserId,
      profile.accountType, profile.profilePicUrl, profile.mediaCount
    );
    return res.send(oauthSuccessPage(profile.username));
  } catch (err) {
    // Log the failure reason only — never tokens or secrets.
    console.error('Instagram OAuth callback failed:', err && err.message ? err.message : err);
    return res.status(400).send(oauthErrorPage('Instagram login failed. Please try again from the app.'));
  }
});

// --- Errors / startup -------------------------------------------------------

app.use((req, res) => res.status(404).json({ error: 'Not found' }));

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err && err.message ? err.message : err);
  res.status(500).json({ error: 'Internal server error' });
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`FollowBoost API listening on port ${PORT}`);
  });
}

module.exports = app;
module.exports.exchangeCodeForToken = exchangeCodeForToken;
module.exports.fetchInstagramProfile = fetchInstagramProfile;
module.exports.buildAuthorizeUrl = buildAuthorizeUrl;
module.exports.INSTAGRAM_OAUTH_SCOPE = INSTAGRAM_OAUTH_SCOPE;
