// FollowBoost — SQLite database layer (better-sqlite3, synchronous API).
//
// The DB file lives at data/followboost.db by default (env DB_PATH overrides
// it, which the test suite uses for an isolated temp database). The file is
// gitignored — it holds real user accounts and must never be committed.
//
// Coins are authoritative server-side: every earn/spend goes through
// `addLedgerEntry`, which updates users.coins AND the matching
// users.total_earned / total_spent counters inside one transaction, so the
// balance can never drift from its history.

const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');

// --- Demo seed data ---------------------------------------------------------
// All handles are clearly fictional demo profiles. No real accounts.

const SEED_TASKS = [
  { type: 'follow', handle: 'wander.tales',  displayName: 'Wander Tales',  avatarColor: '#6366F1', coins: 5 },
  { type: 'follow', handle: 'foodie.bites',  displayName: 'Foodie Bites',  avatarColor: '#F59E0B', coins: 5 },
  { type: 'follow', handle: 'fit.with.ana', displayName: 'Fit with Ana',   avatarColor: '#10B981', coins: 5 },
  { type: 'like',   handle: 'tech.daily',    displayName: 'Tech Daily',    avatarColor: '#0EA5E9', coins: 3 },
  { type: 'follow', handle: 'pet.pals',      displayName: 'Pet Pals',      avatarColor: '#EC4899', coins: 5 },
  { type: 'like',   handle: 'style.by.mia', displayName: 'Style by Mia',   avatarColor: '#8B5CF6', coins: 3 },
  { type: 'follow', handle: 'music.vibes',  displayName: 'Music Vibes',   avatarColor: '#EF4444', coins: 5 },
  { type: 'like',   handle: 'photo.frames', displayName: 'Photo Frames',  avatarColor: '#14B8A6', coins: 3 },
];

const SEED_GIFT_CODES = [
  { code: 'WELCOME100', coins: 100, active: 1 },
];

function defaultDbPath() {
  return path.join(__dirname, 'data', 'followboost.db');
}

function openDb(dbPath) {
  const resolved = dbPath || process.env.DB_PATH || defaultDbPath();
  fs.mkdirSync(path.dirname(resolved), { recursive: true });
  const db = new Database(resolved);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  initSchema(db);
  migrateSchema(db);
  seedIfEmpty(db);
  return db;
}

// v1.0.1 migration: bring databases created by v1.0.0 up to the new schema.
// Fresh DBs already get the new columns from CREATE TABLE above, so this
// only fires for columns that are actually missing. Seed data is untouched.
// v1.0.2 adds the instagram OAuth columns + the oauth_states table below.
function migrateSchema(db) {
  const ensureColumn = (table, column, ddl) => {
    const cols = db.prepare(`PRAGMA table_info(${table})`).all();
    if (!cols.some((c) => c.name === column)) {
      db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${ddl}`);
    }
  };
  ensureColumn('users', 'is_admin', 'INTEGER NOT NULL DEFAULT 0');
  ensureColumn('tasks', 'order_id', 'INTEGER REFERENCES orders(id)');
  ensureColumn('tasks', 'owner_user_id', 'INTEGER REFERENCES users(id)');
  ensureColumn('tasks', 'required_count', 'INTEGER');
  ensureColumn('tasks', 'fulfilled_count', 'INTEGER NOT NULL DEFAULT 0');
  ensureColumn('orders', 'fulfilled', 'INTEGER NOT NULL DEFAULT 0');

  // v1.0.2: Instagram OAuth profile fields (all nullable — a manual
  // username connect fills none of them; OAuth fills what Meta returns).
  ensureColumn('instagram', 'instagram_user_id', 'TEXT');
  ensureColumn('instagram', 'account_type', 'TEXT');
  ensureColumn('instagram', 'profile_pic_url', 'TEXT');
  ensureColumn('instagram', 'media_count', 'INTEGER');

  // v1.0.2: one-time OAuth state tokens (CSRF protection for the callback).
  // Created here rather than in initSchema's CREATE TABLE block so a
  // pre-v1.0.2 database gets it too; CREATE TABLE IF NOT EXISTS is safe
  // to run on every open.
  db.exec(`
    CREATE TABLE IF NOT EXISTS oauth_states (
      state      TEXT PRIMARY KEY,
      user_id    INTEGER NOT NULL REFERENCES users(id),
      created_at TEXT NOT NULL
    );
  `);

  // If a pre-v1.0.1 database already has users but no admin yet, the
  // earliest registered user is the admin (same rule the register handler
  // applies on fresh databases). No-op when there are no users or an admin
  // already exists.
  const adminCount = db.prepare('SELECT COUNT(*) AS n FROM users WHERE is_admin = 1').get().n;
  if (adminCount === 0) {
    db.prepare('UPDATE users SET is_admin = 1 WHERE id = (SELECT MIN(id) FROM users)').run();
  }
}

function initSchema(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      name          TEXT NOT NULL,
      email         TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      coins         INTEGER NOT NULL DEFAULT 0,
      total_earned  INTEGER NOT NULL DEFAULT 0,
      total_spent   INTEGER NOT NULL DEFAULT 0,
      invite_code   TEXT UNIQUE,
      referred_by   INTEGER REFERENCES users(id),
      streak        INTEGER NOT NULL DEFAULT 0,
      last_daily_at TEXT,              -- 'YYYY-MM-DD' (UTC) of last daily claim
      is_admin      INTEGER NOT NULL DEFAULT 0,
      created_at    TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS wallet_history (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id    INTEGER NOT NULL REFERENCES users(id),
      type       TEXT NOT NULL CHECK (type IN ('earn', 'spend')),
      amount     INTEGER NOT NULL,
      reason     TEXT NOT NULL,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS tasks (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      type            TEXT NOT NULL CHECK (type IN ('follow', 'like')),
      handle          TEXT NOT NULL,
      display_name    TEXT NOT NULL,
      avatar_color    TEXT NOT NULL,
      coins           INTEGER NOT NULL,
      active          INTEGER NOT NULL DEFAULT 1,
      -- v1.0.1: order-generated tasks. NULL = seeded demo task.
      order_id        INTEGER REFERENCES orders(id),
      owner_user_id   INTEGER REFERENCES users(id),
      required_count  INTEGER,
      fulfilled_count INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS task_completions (
      user_id      INTEGER NOT NULL REFERENCES users(id),
      task_id      INTEGER NOT NULL REFERENCES tasks(id),
      completed_at TEXT NOT NULL,
      PRIMARY KEY (user_id, task_id)
    );

    CREATE TABLE IF NOT EXISTS orders (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id       INTEGER NOT NULL REFERENCES users(id),
      type          TEXT NOT NULL CHECK (type IN ('follow', 'like')),
      target_handle TEXT NOT NULL,
      count         INTEGER NOT NULL,
      cost          INTEGER NOT NULL,
      fulfilled     INTEGER NOT NULL DEFAULT 0,
      status        TEXT NOT NULL DEFAULT 'queued',
      created_at    TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS gift_codes (
      code   TEXT PRIMARY KEY,
      coins  INTEGER NOT NULL,
      active INTEGER NOT NULL DEFAULT 1
    );

    CREATE TABLE IF NOT EXISTS gift_redemptions (
      user_id INTEGER NOT NULL REFERENCES users(id),
      code    TEXT NOT NULL,
      PRIMARY KEY (user_id, code)
    );

    CREATE TABLE IF NOT EXISTS instagram (
      user_id           INTEGER PRIMARY KEY REFERENCES users(id),
      username          TEXT NOT NULL,
      connected_at      TEXT NOT NULL,
      -- v1.0.2: filled by Meta OAuth only (all nullable — a manual username
      -- connect leaves them NULL). profile_pic_url is stored only if Meta
      -- actually returns one; media_count comes from the /me profile.
      instagram_user_id TEXT,
      account_type      TEXT,
      profile_pic_url   TEXT,
      media_count       INTEGER
    );

    CREATE TABLE IF NOT EXISTS oauth_states (
      state      TEXT PRIMARY KEY,
      user_id    INTEGER NOT NULL REFERENCES users(id),
      created_at TEXT NOT NULL
    );
  `);
}

// Seed demo tasks + gift codes on first start only (when tables are empty).
function seedIfEmpty(db) {
  const taskCount = db.prepare('SELECT COUNT(*) AS n FROM tasks').get().n;
  if (taskCount === 0) {
    const insert = db.prepare(
      'INSERT INTO tasks (type, handle, display_name, avatar_color, coins) VALUES (?, ?, ?, ?, ?)'
    );
    const seed = db.transaction(() => {
      for (const t of SEED_TASKS) insert.run(t.type, t.handle, t.displayName, t.avatarColor, t.coins);
    });
    seed();
  }

  const codeCount = db.prepare('SELECT COUNT(*) AS n FROM gift_codes').get().n;
  if (codeCount === 0) {
    const insert = db.prepare('INSERT INTO gift_codes (code, coins, active) VALUES (?, ?, ?)');
    for (const g of SEED_GIFT_CODES) insert.run(g.code, g.coins, g.active);
  }
}

// --- Shared helpers ---------------------------------------------------------

/** ISO timestamp, e.g. '2026-11-11T02:15:00.000Z'. */
function nowIso() {
  return new Date().toISOString();
}

/** Today's UTC date as 'YYYY-MM-DD'. */
function todayUtc() {
  return new Date().toISOString().slice(0, 10);
}

/** Invite code: 'FB' + zero-padded base36 of the user id (8 chars total). */
function inviteCodeFor(id) {
  return 'FB' + id.toString(36).toUpperCase().padStart(6, '0');
}

/**
 * Record a coin movement and update the user's balance + totals atomically.
 * amount is always positive; type is 'earn' or 'spend'.
 * Returns the user's new balance.
 */
function addLedgerEntry(db, userId, type, amount, reason) {
  const run = db.transaction(() => {
    db.prepare(
      'INSERT INTO wallet_history (user_id, type, amount, reason, created_at) VALUES (?, ?, ?, ?, ?)'
    ).run(userId, type, amount, reason, nowIso());

    if (type === 'earn') {
      db.prepare('UPDATE users SET coins = coins + ?, total_earned = total_earned + ? WHERE id = ?')
        .run(amount, amount, userId);
    } else {
      db.prepare('UPDATE users SET coins = coins - ?, total_spent = total_spent + ? WHERE id = ?')
        .run(amount, amount, userId);
    }
    return db.prepare('SELECT coins FROM users WHERE id = ?').get(userId).coins;
  });
  return run();
}

module.exports = { openDb, nowIso, todayUtc, inviteCodeFor, addLedgerEntry };
