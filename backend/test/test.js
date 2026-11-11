// FollowBoost API tests — self-contained.
//
// Starts the real server as a child process on a test port with a throwaway
// temp SQLite database (env DB_PATH + PORT), then exercises the whole API
// over HTTP with the global fetch. Run: npm test

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const PORT = 3457;
const BASE = `http://127.0.0.1:${PORT}`;
const BACKEND_DIR = path.join(__dirname, '..');

// Unit tests for the OAuth helpers need server.js loaded in THIS process
// (the HTTP tests below use a child-process server instead). Point it at a
// throwaway DB first so it never touches the real data/followboost.db, and
// keep Meta's real endpoints out of reach — helpers are called with a
// stubbed fetch only.
const unitTmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'followboost-unit-'));
process.env.DB_PATH = path.join(unitTmpDir, 'unit.db');
const serverModule = require('../server');
const { exchangeCodeForToken, fetchInstagramProfile } = serverModule;

let server; // child process
let tmpDir;

// Shared state between tests (tests run sequentially in file order).
const state = { token: null, userId: null, inviteCode: null, token2: null, orderId: null, orderTaskIds: [] };

async function api(method, p, { token, body } = {}) {
  const res = await fetch(BASE + p, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let data = null;
  try { data = await res.json(); } catch { /* non-JSON body */ }
  return { status: res.status, body: data };
}

async function waitForServer(timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(BASE + '/');
      if (res.ok) return;
    } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, 200));
  }
  throw new Error('Server did not start in time');
}

before(async () => {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'followboost-test-'));
  server = spawn('node', ['server.js'], {
    cwd: BACKEND_DIR,
    env: {
      ...process.env,
      PORT: String(PORT),
      DB_PATH: path.join(tmpDir, 'test.db'),
      JWT_SECRET: 'test-secret-do-not-use-in-prod',
    },
    stdio: 'pipe',
  });
  server.stdout.on('data', (d) => process.stdout.write(`[server] ${d}`));
  server.stderr.on('data', (d) => process.stderr.write(`[server:err] ${d}`));
  await waitForServer();
});

after(() => {
  if (server && !server.killed) server.kill('SIGTERM');
  if (tmpDir) fs.rmSync(tmpDir, { recursive: true, force: true });
  if (unitTmpDir) fs.rmSync(unitTmpDir, { recursive: true, force: true });
});

// --- Health -----------------------------------------------------------------

test('GET / returns service info', async () => {
  const { status, body } = await api('GET', '/');
  assert.equal(status, 200);
  assert.equal(body.name, 'FollowBoost API');
  assert.equal(body.version, '1.0.2');
  assert.equal(body.status, 'ok');
});

// --- Auth -------------------------------------------------------------------

test('register: creates user with 50-coin signup bonus', async () => {
  const { status, body } = await api('POST', '/api/auth/register', {
    body: { name: 'Test User', email: 'test@example.com', password: 'secret123' },
  });
  assert.equal(status, 201);
  assert.ok(body.token);
  assert.equal(body.user.email, 'test@example.com');
  assert.equal(body.user.coins, 50);
  state.token = body.token;
  state.userId = body.user.id;
});

test('register: duplicate email is rejected (409)', async () => {
  const { status, body } = await api('POST', '/api/auth/register', {
    body: { name: 'Copy', email: 'test@example.com', password: 'secret123' },
  });
  assert.equal(status, 409);
  assert.ok(body.error);
});

test('register: invalid email and short password are rejected (400)', async () => {
  assert.equal((await api('POST', '/api/auth/register', {
    body: { name: 'Bad', email: 'not-an-email', password: 'secret123' },
  })).status, 400);
  assert.equal((await api('POST', '/api/auth/register', {
    body: { name: 'Bad', email: 'bad2@example.com', password: '123' },
  })).status, 400);
});

test('login: wrong password is 401, correct password returns a token', async () => {
  const bad = await api('POST', '/api/auth/login', {
    body: { email: 'test@example.com', password: 'wrongpass' },
  });
  assert.equal(bad.status, 401);
  const good = await api('POST', '/api/auth/login', {
    body: { email: 'test@example.com', password: 'secret123' },
  });
  assert.equal(good.status, 200);
  assert.ok(good.body.token);
  state.token = good.body.token;
});

test('GET /api/me requires auth and returns invite code + streak', async () => {
  assert.equal((await api('GET', '/api/me')).status, 401);
  const { status, body } = await api('GET', '/api/me', { token: state.token });
  assert.equal(status, 200);
  assert.equal(body.email, 'test@example.com');
  assert.equal(body.coins, 50);
  assert.equal(body.streak, 0);
  assert.match(body.inviteCode, /^FB[0-9A-Z]{6}$/);
  state.inviteCode = body.inviteCode;
});

// --- Wallet -----------------------------------------------------------------

test('wallet: balance and totals reflect the signup bonus', async () => {
  const { status, body } = await api('GET', '/api/wallet', { token: state.token });
  assert.equal(status, 200);
  assert.equal(body.coins, 50);
  assert.equal(body.totalEarned, 50);
  assert.equal(body.totalSpent, 0);
});

test('wallet history: newest first, contains the signup bonus entry', async () => {
  const { status, body } = await api('GET', '/api/wallet/history', { token: state.token });
  assert.equal(status, 200);
  assert.ok(Array.isArray(body));
  assert.equal(body[0].type, 'earn');
  assert.equal(body[0].amount, 50);
  assert.equal(body[0].reason, 'Signup bonus');
});

// --- Daily reward -----------------------------------------------------------

test('daily reward: first claim awards 20 (streak 1), second claim is alreadyClaimed', async () => {
  const first = await api('POST', '/api/rewards/daily', { token: state.token });
  assert.equal(first.status, 200);
  assert.equal(first.body.awarded, 20);
  assert.equal(first.body.streak, 1);
  assert.equal(first.body.alreadyClaimed, false);
  assert.equal(first.body.coins, 70); // 50 signup + 20 daily

  const second = await api('POST', '/api/rewards/daily', { token: state.token });
  assert.equal(second.status, 200);
  assert.equal(second.body.alreadyClaimed, true);
  assert.equal(second.body.coins, 70); // no double award
});

// --- Tasks ------------------------------------------------------------------

test('tasks: 8 seeded demo tasks, all available (availableAt null)', async () => {
  const { status, body } = await api('GET', '/api/tasks', { token: state.token });
  assert.equal(status, 200);
  assert.equal(body.length, 8);
  assert.ok(body.every((t) => t.availableAt === null));
  assert.ok(body.some((t) => t.type === 'follow' && t.coins === 5));
  assert.ok(body.some((t) => t.type === 'like' && t.coins === 3));
});

test('task complete: awards coins, second attempt within 24h is cooldown 409', async () => {
  const first = await api('POST', '/api/tasks/1/complete', { token: state.token });
  assert.equal(first.status, 200);
  assert.equal(first.body.coins, 5);
  assert.equal(first.body.newBalance, 75); // 70 + 5

  const second = await api('POST', '/api/tasks/1/complete', { token: state.token });
  assert.equal(second.status, 409);
  assert.equal(second.body.error, 'cooldown');
  assert.ok(second.body.availableAt);

  // Task list now shows the cooldown for task 1 only.
  const list = await api('GET', '/api/tasks', { token: state.token });
  const t1 = list.body.find((t) => t.id === 1);
  assert.ok(t1.availableAt);
  assert.ok(list.body.filter((t) => t.id !== 1).every((t) => t.availableAt === null));

  // Unknown task is 404.
  assert.equal((await api('POST', '/api/tasks/999/complete', { token: state.token })).status, 404);
});

// --- Orders -----------------------------------------------------------------

test('orders: validation errors, insufficient balance, then a valid order', async () => {
  // Balance is 75 here.
  assert.equal((await api('POST', '/api/orders', {
    token: state.token, body: { type: 'follow', targetHandle: 'someone', count: 5 },
  })).status, 400); // count < 10
  assert.equal((await api('POST', '/api/orders', {
    token: state.token, body: { type: 'share', targetHandle: 'someone', count: 10 },
  })).status, 400); // bad type

  // 5000 follows * 2 = 10000 coins — far above the 75 balance.
  const poor = await api('POST', '/api/orders', {
    token: state.token, body: { type: 'follow', targetHandle: 'someone', count: 5000 },
  });
  assert.equal(poor.status, 400);
  assert.match(poor.body.error, /Insufficient balance/);

  // Valid: 10 follows * 2 = 20 coins.
  const ok = await api('POST', '/api/orders', {
    token: state.token, body: { type: 'follow', targetHandle: '@someone', count: 10 },
  });
  assert.equal(ok.status, 201);
  assert.equal(ok.body.order.status, 'queued');
  assert.equal(ok.body.order.cost, 20);
  assert.equal(ok.body.order.fulfilled, 0);
  assert.equal(ok.body.order.targetHandle, 'someone');
  assert.equal(ok.body.newBalance, 55); // 75 - 20

  const list = await api('GET', '/api/orders', { token: state.token });
  assert.equal(list.status, 200);
  assert.equal(list.body.length, 1);
  assert.equal(list.body[0].type, 'follow');
  assert.equal(list.body[0].count, 10);
  assert.equal(list.body[0].fulfilled, 0);
});

// --- Gift codes -------------------------------------------------------------

test('gift code: WELCOME100 redeems once (case-insensitive), second time is 409', async () => {
  const first = await api('POST', '/api/gift-codes/redeem', {
    token: state.token, body: { code: 'welcome100' },
  });
  assert.equal(first.status, 200);
  assert.equal(first.body.coins, 100);
  assert.equal(first.body.newBalance, 155); // 55 + 100

  const second = await api('POST', '/api/gift-codes/redeem', {
    token: state.token, body: { code: 'WELCOME100' },
  });
  assert.equal(second.status, 409);

  const bad = await api('POST', '/api/gift-codes/redeem', {
    token: state.token, body: { code: 'NOPE123' },
  });
  assert.equal(bad.status, 404);
});

// --- Leaderboard ------------------------------------------------------------

test('leaderboard: works without auth, lists the real user', async () => {
  const { status, body } = await api('GET', '/api/leaderboard');
  assert.equal(status, 200);
  assert.ok(body.length >= 1);
  assert.equal(body[0].rank, 1);
  assert.equal(body[0].name, 'Test User');
  assert.equal(body[0].coins, 155);
});

// --- Referrals --------------------------------------------------------------

test('referrals: second user applies the first user code (+25 applier, +50 referrer)', async () => {
  const reg = await api('POST', '/api/auth/register', {
    body: { name: 'Friend', email: 'friend@example.com', password: 'secret123' },
  });
  assert.equal(reg.status, 201);
  state.token2 = reg.body.token;

  // Own code is rejected.
  const me = await api('GET', '/api/me', { token: state.token2 });
  const own = await api('POST', '/api/referrals/apply', {
    token: state.token2, body: { code: me.body.inviteCode },
  });
  assert.equal(own.status, 400);

  // Invalid code is 404.
  assert.equal((await api('POST', '/api/referrals/apply', {
    token: state.token2, body: { code: 'FBZZZZZZ' },
  })).status, 404);

  // Valid: applier +25 (50 signup + 25 = 75).
  const applied = await api('POST', '/api/referrals/apply', {
    token: state.token2, body: { code: state.inviteCode },
  });
  assert.equal(applied.status, 200);
  assert.equal(applied.body.coins, 25);
  assert.equal(applied.body.newBalance, 75);

  // Second apply is rejected — one referral per user, ever.
  assert.equal((await api('POST', '/api/referrals/apply', {
    token: state.token2, body: { code: state.inviteCode },
  })).status, 409);

  // Referrer sees 1 referral and 50 earned coins.
  const ref = await api('GET', '/api/referrals', { token: state.token });
  assert.equal(ref.status, 200);
  assert.equal(ref.body.inviteCode, state.inviteCode);
  assert.equal(ref.body.referredCount, 1);
  assert.equal(ref.body.earnedCoins, 50);
});

// --- Instagram --------------------------------------------------------------

test('instagram: password field is rejected, username connect + status work', async () => {
  const withPassword = await api('POST', '/api/instagram/connect', {
    token: state.token, body: { username: 'test.user', password: 'hunter2' },
  });
  assert.equal(withPassword.status, 400);

  const connect = await api('POST', '/api/instagram/connect', {
    token: state.token, body: { username: '@Test.User' },
  });
  assert.equal(connect.status, 200);
  assert.equal(connect.body.connected, true);
  assert.equal(connect.body.username, 'test.user'); // lowercased, @ stripped

  const statusRes = await api('GET', '/api/instagram/status', { token: state.token });
  assert.equal(statusRes.status, 200);
  assert.equal(statusRes.body.connected, true);
  assert.equal(statusRes.body.username, 'test.user');
  // Manual connect fills no profile fields — all present as null.
  assert.equal(statusRes.body.profilePicUrl, null);
  assert.equal(statusRes.body.accountType, null);
  assert.equal(statusRes.body.mediaCount, null);

  // A user who never connected reports connected: false, all fields null.
  const status2 = await api('GET', '/api/instagram/status', { token: state.token2 });
  assert.equal(status2.body.connected, false);
  assert.equal(status2.body.username, null);
  assert.equal(status2.body.profilePicUrl, null);
  assert.equal(status2.body.accountType, null);
  assert.equal(status2.body.mediaCount, null);
});

test('instagram oauth-url: unconfigured without env vars', async () => {
  const { status, body } = await api('GET', '/api/instagram/oauth-url');
  assert.equal(status, 200);
  assert.equal(body.configured, false);
});

// --- Orders -> tasks (v1.0.1) ----------------------------------------------

test('orders v1.0.1: creating an order generates N tasks visible to other users only', async () => {
  // User 1 balance: 155 (gift code) + 50 (referral) = 205.
  const ok = await api('POST', '/api/orders', {
    token: state.token, body: { type: 'follow', targetHandle: '@v101target', count: 10 },
  });
  assert.equal(ok.status, 201);
  assert.equal(ok.body.order.cost, 20);
  assert.equal(ok.body.order.fulfilled, 0);
  assert.equal(ok.body.order.status, 'queued');
  assert.equal(ok.body.newBalance, 185); // 205 - 20
  state.orderId = ok.body.order.id;

  // The orderer does NOT see their own order tasks.
  const ownList = await api('GET', '/api/tasks', { token: state.token });
  assert.equal(ownList.status, 200);
  assert.equal(ownList.body.filter((t) => t.handle === 'v101target').length, 0);

  // A second user sees all 10, each paying 1 coin and linked to the order.
  const otherList = await api('GET', '/api/tasks', { token: state.token2 });
  assert.equal(otherList.status, 200);
  const orderTasks = otherList.body.filter((t) => t.handle === 'v101target');
  assert.equal(orderTasks.length, 10);
  assert.ok(orderTasks.every((t) => t.orderId === state.orderId));
  assert.ok(orderTasks.every((t) => t.coins === 1));
  assert.ok(orderTasks.every((t) => t.type === 'follow'));
  assert.ok(orderTasks.every((t) => t.availableAt === null));
  state.orderTaskIds = orderTasks.map((t) => t.id);
});

test('orders v1.0.1: orderer gets 403 completing their own order task', async () => {
  const { status, body } = await api('POST', `/api/tasks/${state.orderTaskIds[0]}/complete`, { token: state.token });
  assert.equal(status, 403);
  assert.equal(body.error, 'Cannot complete your own order');
});

test('orders v1.0.1: completing one order task awards 1 coin, order becomes partial', async () => {
  // User 2 balance: 50 signup + 25 referral = 75.
  const first = await api('POST', `/api/tasks/${state.orderTaskIds[0]}/complete`, { token: state.token2 });
  assert.equal(first.status, 200);
  assert.equal(first.body.coins, 1);
  assert.equal(first.body.newBalance, 76);

  // Same task again is 409 (already completed).
  const again = await api('POST', `/api/tasks/${state.orderTaskIds[0]}/complete`, { token: state.token2 });
  assert.equal(again.status, 409);
  assert.equal(again.body.error, 'Task already completed');

  // Order is now partial with fulfilled = 1.
  const orders = await api('GET', '/api/orders', { token: state.token });
  const order = orders.body.find((o) => o.id === state.orderId);
  assert.equal(order.fulfilled, 1);
  assert.equal(order.status, 'partial');

  // The completed task no longer shows for user 2.
  const list = await api('GET', '/api/tasks', { token: state.token2 });
  assert.equal(list.body.filter((t) => t.id === state.orderTaskIds[0]).length, 0);
});

test('orders v1.0.1: completing all order tasks marks the order completed', async () => {
  for (const taskId of state.orderTaskIds.slice(1)) {
    const r = await api('POST', `/api/tasks/${taskId}/complete`, { token: state.token2 });
    assert.equal(r.status, 200);
    assert.equal(r.body.coins, 1);
  }
  // User 2 balance: 76 + 9 = 85.
  const wallet = await api('GET', '/api/wallet', { token: state.token2 });
  assert.equal(wallet.body.coins, 85);

  const orders = await api('GET', '/api/orders', { token: state.token });
  const order = orders.body.find((o) => o.id === state.orderId);
  assert.equal(order.fulfilled, 10);
  assert.equal(order.status, 'completed');

  // No tasks of a completed order remain visible to other users.
  const list = await api('GET', '/api/tasks', { token: state.token2 });
  assert.equal(list.body.filter((t) => t.handle === 'v101target').length, 0);
});

// --- Admin (v1.0.1) ---------------------------------------------------------

test('admin v1.0.1: first user is admin, second is not; admin can list all orders', async () => {
  const me1 = await api('GET', '/api/me', { token: state.token });
  assert.equal(me1.body.isAdmin, true);
  const me2 = await api('GET', '/api/me', { token: state.token2 });
  assert.equal(me2.body.isAdmin, false);

  // Non-admin gets 403; no token gets 401.
  assert.equal((await api('GET', '/api/admin/orders', { token: state.token2 })).status, 403);
  assert.equal((await api('GET', '/api/admin/orders')).status, 401);

  const admin = await api('GET', '/api/admin/orders', { token: state.token });
  assert.equal(admin.status, 200);
  assert.ok(Array.isArray(admin.body));
  assert.ok(admin.body.length >= 2); // 'someone' order + v101target order
  const mine = admin.body.find((o) => o.id === state.orderId);
  assert.equal(mine.type, 'follow');
  assert.equal(mine.targetHandle, 'v101target');
  assert.equal(mine.count, 10);
  assert.equal(mine.fulfilled, 10);
  assert.equal(mine.status, 'completed');
  assert.equal(mine.ownerName, 'Test User');
  assert.equal(mine.ownerEmail, 'test@example.com');
});

// --- Instagram OAuth (v1.0.2) ----------------------------------------------
// No Meta env vars are set for the child server, so the OAuth flow is
// unconfigured here. Meta's real endpoints are NEVER called in tests.

test('instagram oauth start: no auth is 401, authed but unconfigured is 503', async () => {
  assert.equal((await api('POST', '/api/instagram/oauth/start')).status, 401);

  const { status, body } = await api('POST', '/api/instagram/oauth/start', { token: state.token });
  assert.equal(status, 503);
  assert.equal(body.error, 'Instagram login is not configured on the server');
});

test('instagram oauth callback: missing code/state is a 400 error page', async () => {
  // No params at all.
  const none = await fetch(BASE + '/api/instagram/oauth/callback');
  assert.equal(none.status, 400);
  assert.match(await none.text(), /Instagram login failed/);

  // Code without state.
  const noState = await fetch(BASE + '/api/instagram/oauth/callback?code=abc123');
  assert.equal(noState.status, 400);
  assert.match(await noState.text(), /Instagram login failed/);

  // State without code.
  const noCode = await fetch(BASE + '/api/instagram/oauth/callback?state=abc123');
  assert.equal(noCode.status, 400);
});

test('instagram oauth callback: unknown state is a 400 error page', async () => {
  const res = await fetch(
    BASE + '/api/instagram/oauth/callback?code=abc123&state=' + '0'.repeat(64)
  );
  assert.equal(res.status, 400);
  assert.match(await res.text(), /Unknown or already-used login request/);
});

// --- OAuth helpers (unit tests, stubbed fetch — no Meta calls) --------------

function withOAuthEnv(fn) {
  const saved = {
    id: process.env.OAUTH_CLIENT_ID,
    secret: process.env.OAUTH_CLIENT_SECRET,
    redirect: process.env.OAUTH_REDIRECT_URI,
  };
  process.env.OAUTH_CLIENT_ID = 'test-client-id';
  process.env.OAUTH_CLIENT_SECRET = 'test-client-secret';
  process.env.OAUTH_REDIRECT_URI = 'https://example.com/api/instagram/oauth/callback';
  return Promise.resolve()
    .then(fn)
    .finally(() => {
      if (saved.id === undefined) delete process.env.OAUTH_CLIENT_ID;
      else process.env.OAUTH_CLIENT_ID = saved.id;
      if (saved.secret === undefined) delete process.env.OAUTH_CLIENT_SECRET;
      else process.env.OAUTH_CLIENT_SECRET = saved.secret;
      if (saved.redirect === undefined) delete process.env.OAUTH_REDIRECT_URI;
      else process.env.OAUTH_REDIRECT_URI = saved.redirect;
    });
}

test('oauth helper: exchangeCodeForToken posts form-encoded to api.instagram.com', async () => {
  await withOAuthEnv(async () => {
    let seenUrl = null;
    let seenOpts = null;
    const stubFetch = async (url, opts) => {
      seenUrl = url;
      seenOpts = opts;
      return {
        ok: true,
        status: 200,
        json: async () => ({
          access_token: 'SHORT-LIVED-TOKEN',
          user_id: 17841400000000000,
          permissions: ['instagram_business_basic'],
        }),
      };
    };
    const out = await exchangeCodeForToken('AUTH-CODE-123', stubFetch);
    assert.equal(out.accessToken, 'SHORT-LIVED-TOKEN');
    assert.equal(out.instagramUserId, '17841400000000000');
    assert.equal(seenUrl, 'https://api.instagram.com/oauth/access_token');
    assert.equal(seenOpts.method, 'POST');
    assert.equal(seenOpts.headers['Content-Type'], 'application/x-www-form-urlencoded');
    const params = new URLSearchParams(seenOpts.body);
    assert.equal(params.get('client_id'), 'test-client-id');
    assert.equal(params.get('client_secret'), 'test-client-secret');
    assert.equal(params.get('grant_type'), 'authorization_code');
    assert.equal(params.get('redirect_uri'), 'https://example.com/api/instagram/oauth/callback');
    assert.equal(params.get('code'), 'AUTH-CODE-123');
  });
});

test('oauth helper: exchangeCodeForToken throws (no token leaked) on Meta error', async () => {
  await withOAuthEnv(async () => {
    const stubFetch = async () => ({
      ok: false,
      status: 400,
      json: async () => ({ error_message: 'Invalid authorization code' }),
    });
    await assert.rejects(
      () => exchangeCodeForToken('BAD-CODE', stubFetch),
      /Instagram token exchange failed: Invalid authorization code/
    );
  });
});

test('oauth helper: fetchInstagramProfile normalizes the /me response', async () => {
  let seenUrl = null;
  const stubFetch = async (url) => {
    seenUrl = url;
    return {
      ok: true,
      status: 200,
      json: async () => ({
        id: '17841400000000000',
        username: 'Test.User',
        account_type: 'BUSINESS',
        media_count: 42,
        profile_picture_url: 'https://example.com/pic.jpg',
      }),
    };
  };
  const out = await fetchInstagramProfile('SHORT-LIVED-TOKEN', stubFetch);
  assert.equal(out.instagramUserId, '17841400000000000');
  assert.equal(out.username, 'test.user'); // lowercased
  assert.equal(out.accountType, 'BUSINESS');
  assert.equal(out.mediaCount, 42);
  assert.equal(out.profilePicUrl, 'https://example.com/pic.jpg');
  assert.ok(seenUrl.startsWith('https://graph.instagram.com/me?'));
  assert.ok(seenUrl.includes('fields=id%2Cusername%2Caccount_type%2Cmedia_count%2Cprofile_picture_url'));
  assert.ok(seenUrl.includes('access_token=SHORT-LIVED-TOKEN'));
});

test('oauth helper: fetchInstagramProfile returns null pic when Meta sends none', async () => {
  const stubFetch = async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      id: '17841400000000000',
      username: 'nopicture',
      account_type: 'CREATOR',
      media_count: 0,
      // no profile_picture_url — must stay null, never faked
    }),
  });
  const out = await fetchInstagramProfile('TOKEN', stubFetch);
  assert.equal(out.username, 'nopicture');
  assert.equal(out.profilePicUrl, null);
  assert.equal(out.mediaCount, 0);
});
