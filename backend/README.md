# FollowBoost API

The backend for FollowBoost — an Instagram growth & rewards app.
Node.js + Express + SQLite (better-sqlite3). Original code, written from
scratch. Coins are server-side only: the balance is the ledger, and every
earn/spend is recorded in `wallet_history`.

## Run locally

```bash
cd backend
npm install
npm start
```

The API listens on `http://localhost:3000` by default. On first start it
creates `data/followboost.db` and seeds the demo tasks + the `WELCOME100`
gift code. The database file is gitignored — never commit it.

Health check: `GET /` → `{ "name": "FollowBoost API", "version": "1.0.2", "status": "ok" }`

## Environment variables

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `PORT` | No | `3000` | Port to listen on |
| `JWT_SECRET` | Yes in production | `followboost-dev-secret-change-me` | Secret for signing auth tokens. **Set a long random value in production** — anyone with it can forge logins. |
| `DB_PATH` | No | `data/followboost.db` | SQLite file location (tests use a temp file) |
| `OAUTH_CLIENT_ID` | Yes, for Instagram login | — | Meta app client ID (App ID) for Instagram OAuth |
| `OAUTH_CLIENT_SECRET` | Yes, for Instagram login | — | Meta app client secret (App Secret). **Never put this in the app or any client-side code — server only.** |
| `OAUTH_REDIRECT_URI` | Yes, for Instagram login | — | Exact OAuth redirect URI registered in the Meta app, e.g. `https://api.your-domain.com/api/instagram/oauth/callback`. Must match character-for-character. |

All three `OAUTH_*` variables must be set together for Instagram login to
work; if any one is missing, `GET /api/instagram/oauth-url` reports
`{configured:false}` and `POST /api/instagram/oauth/start` returns 503.

## Tests

```bash
npm test
```

Starts the real server on a test port with a throwaway temp database and
exercises the whole API over HTTP (register/login, wallet, daily reward,
tasks + cooldown, orders → tasks → fulfilment, admin, gift codes,
leaderboard, referrals, Instagram connect + OAuth start/callback/status).
29 tests, all passing. Meta's real endpoints are never called in tests —
the token exchange and profile fetch are unit-tested with a stubbed
`fetch` via the helpers exported from `server.js`
(`exchangeCodeForToken`, `fetchInstagramProfile`).

## Auth

All endpoints except `GET /`, `GET /api/leaderboard`,
`GET /api/instagram/oauth-url`, and `GET /api/instagram/oauth/callback`
(Meta redirects the user's browser there — the one-time `state` is the
auth) require:

```
Authorization: Bearer <JWT>
```

Errors are always `{ "error": "message" }` with the proper HTTP status
(400 validation, 401 bad/missing token, 404 not found, 409 conflict).

## API endpoints

### Auth

| Method | Endpoint | Body | Response |
|---|---|---|---|
| POST | `/api/auth/register` | `{name, email, password}` | 201 `{token, user:{id,name,email,coins,isAdmin}}` — 50-coin signup bonus; email must be valid, password ≥ 6 chars; duplicate email → 409. The very first registered user becomes the admin (`isAdmin: true`) |
| POST | `/api/auth/login` | `{email, password}` | `{token, user}` — wrong credentials → 401 |
| GET | `/api/me` | — | `{id, name, email, coins, inviteCode, streak, isAdmin}` |

### Wallet & rewards

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/api/wallet` | `{coins, totalEarned, totalSpent}` |
| GET | `/api/wallet/history` | `[{id, type, amount, reason, createdAt}]`, newest first, limit 50 |
| POST | `/api/rewards/daily` | Once per calendar day (UTC). `{coins, awarded, streak, alreadyClaimed}`. Award = `min(20 + 5*(streak-1), 50)`; streak increments on consecutive days, resets if a day is missed. Claiming twice in a day returns `{alreadyClaimed:true}` with no double award. |

### Tasks

Manual tasks: the user follows/likes the profile in Instagram themselves,
then confirms here. One completion per user per task per 24h (seeded
tasks). Order tasks pay **1 coin** and can be completed once ever, by
anyone except the orderer.

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/api/tasks` | `[{id, type, handle, displayName, avatarColor, coins, orderId, availableAt}]` — `orderId` is `null` for seeded tasks. Seeded tasks: `availableAt` is `null` when completable now, else the ISO time the 24h cooldown ends. Order tasks: never on cooldown (one-shot). The list excludes your own order tasks, already-fulfilled tasks, tasks of `completed` orders, and tasks you already completed |
| POST | `/api/tasks/:id/complete` | `{coins, newBalance}` — seeded task: completing again within 24h → 409 `{error:'cooldown', availableAt}`. Order task: orderer → 403 `{error:'Cannot complete your own order'}`; already completed → 409 `{error:'Task already completed'}`; awards 1 coin and advances the order (`queued` → `partial` → `completed`) |

### Orders

Placing an order charges the coins **and generates `count` tasks**
targeting the handle, so real users can fulfil the order by completing
those tasks (manual follows/likes only — nothing here is automated).
Each order-task completion pays the doer 1 coin and increments the
order's `fulfilled` count; the order status moves `queued` → `partial`
→ `completed`. The orderer never sees their own order tasks and cannot
complete them (403).

| Method | Endpoint | Notes |
|---|---|---|
| POST | `/api/orders` | `{type:'follow'\|'like', targetHandle, count}` → 201 `{order:{id,type,targetHandle,count,cost,fulfilled:0,status:'queued'}, newBalance}`. Count 10–5000. Cost = count × 2 (follow) or × 1 (like). Balance too low → 400. Order insert + task generation run in one transaction |
| GET | `/api/orders` | `[{id, type, targetHandle, count, cost, fulfilled, status, createdAt}]`, newest first. Status is `queued` \| `partial` \| `completed` |

### Admin

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/api/admin/orders` | Admin only (first registered user; others → 403). `[{id, type, targetHandle, count, fulfilled, cost, status, ownerName, ownerEmail, createdAt}]`, newest first. Read-only — there is deliberately **no** endpoint that marks an order complete without real task completions |

### Gift codes

| Method | Endpoint | Notes |
|---|---|---|
| POST | `/api/gift-codes/redeem` | `{code}` (case-insensitive) → `{coins, newBalance}`. One redemption per user per code → second attempt is 409. Unknown/inactive code → 404. Seeded code: `WELCOME100` = 100 coins. |

### Leaderboard & referrals

| Method | Endpoint | Notes |
|---|---|---|
| GET | `/api/leaderboard` | `[{rank, name, coins}]` — top 20 by coins. Real users only. No auth needed. |
| GET | `/api/referrals` | `{inviteCode, referredCount, earnedCoins}` |
| POST | `/api/referrals/apply` | `{code}` → `{coins}`. Applier +25, referrer +50. One referral per user ever (409 on second attempt); own code → 400; unknown code → 404. |

### Instagram

**Real Meta OAuth login** (plus the manual username connect as a
fallback). No password is ever accepted, stored, or logged — a request
containing a `password` field is rejected with 400. The Instagram access
token is never stored: it is used once at connect time to fetch the
profile, then discarded.

| Method | Endpoint | Notes |
|---|---|---|
| POST | `/api/instagram/connect` | `{username}` → `{connected:true, username}` (lowercased, leading `@` stripped). Manual fallback — fills no profile fields. |
| GET | `/api/instagram/status` | `{connected, username, profilePicUrl, accountType, mediaCount}` — profile fields are `null` when not connected, and also `null` after a manual connect (only OAuth fills them). |
| GET | `/api/instagram/oauth-url` | `{configured:false}` unless `OAUTH_CLIENT_ID` + `OAUTH_REDIRECT_URI` are set, then `{configured:true, url}` — the Meta authorization URL (no `state`; prefer `POST /api/instagram/oauth/start`, which mints a one-time state). |
| POST | `/api/instagram/oauth/start` | Auth required. Without all three `OAUTH_*` env vars → 503 `{error:'Instagram login is not configured on the server'}`. Otherwise mints a one-time state (valid 10 min) and returns `{url}` — the Meta authorize URL. Open it in a browser; Meta redirects to the callback. |
| GET | `/api/instagram/oauth/callback` | No auth header (Meta redirects the browser here). Requires `?code=…&state=…`; missing params → 400 error page, unknown/expired state → 400 error page. Exchanges the code for a token, fetches the profile, stores it (OAuth overwrites a manual-connect username), deletes the used state, and serves a success page — "Instagram connected as @username — you can return to the FollowBoost app" — with a button linking to `followboost://instagram/connected`. Exchange/profile failures serve a simple error page (no tokens or secrets leaked). |

**Honest limits of the Instagram API (do not fake these):**
- The Instagram Basic Display API is **dead** — Meta shut it off on
  2024-12-04, and every request to it now fails. This backend uses the
  currently supported **Instagram API with Instagram Login** (Business
  Login for Instagram). The old `user_profile,user_media` scopes and the
  `api.instagram.com/oauth/authorize` URL no longer work.
- Only **Business or Creator** Instagram accounts can connect. Personal
  accounts have no official API access at all — a user with a personal
  account must convert it to Creator (free, in the Instagram app) first.
- The profile fetch requests `id, username, account_type, media_count,
  profile_picture_url`. Basic Display's `/me` never returned a profile
  picture; the current API's `/me` does — `profilePicUrl` is stored only
  when Meta actually returns one, otherwise it stays `null` and the app
  must show an initials avatar, never a faked picture.
- **Follower/following counts are NOT fetched or stored by this build.**
  They are documented fields on the current API's `/me` for professional
  accounts, but this build deliberately does not request them, so the app
  must not display follower/following numbers as if they came from
  Instagram. (Showing them would require requesting the fields and a
  business/creator account — a later change, not this one.)

## Coin economy

| Action | Coins |
|---|---|
| Signup bonus | +50 |
| Daily reward | +20 base, +5 per streak day, max +50 |
| Complete a seeded follow task | +5 (house-funded) |
| Complete a seeded like task | +3 (house-funded) |
| Complete an order task (follow or like) | +1 (paid from the orderer's payment) |
| Order 1 follower | −2 |
| Order 1 like | −1 |
| Referral — applier | +25 |
| Referral — referrer | +50 |
| Gift code `WELCOME100` | +100 |

Follow orders leave a 1-coin-per-follower house margin (orderer pays 2,
doer gets 1); like orders are 1:1. No coins are created from nothing by
order tasks — the doer's 1 coin comes out of what the orderer paid.

## Real Instagram OAuth (Meta)

The manual username connect is a fallback only. For real login, the user
must create a Meta developer app and configure the **Instagram API with
Instagram Login** (Business Login for Instagram). Steps:

1. Go to [Meta for Developers](https://developers.facebook.com/) and
   register as a Meta developer (free). Create an app (type: pick the
   option for connecting Instagram / "Other" — the exact app-type names
   change; what matters is the next step).
2. In the app dashboard, add the **Instagram** product, then open
   **API setup with Instagram business login** (the Instagram Login
   setup page).
3. Under **Instagram API with Instagram Login**, set the OAuth redirect
   URI to your backend callback URL — exactly:
   `https://<your-api-domain>/api/instagram/oauth/callback`
   (e.g. `https://followboost-api.onrender.com/api/instagram/oauth/callback`).
   Meta rejects the login if this does not match character-for-character.
   `localhost` redirect URIs are rejected by Instagram — use a public
   HTTPS URL (your deployed backend) even for testing.
4. Copy the **App ID** (client ID) and **App Secret** (client secret)
   from Settings → Basic into the backend env as `OAUTH_CLIENT_ID` and
   `OAUTH_CLIENT_SECRET`, and set `OAUTH_REDIRECT_URI` to the same URL
   from step 3. Restart the backend.
5. `GET /api/instagram/oauth-url` should now return `{configured:true,
   url}` and `POST /api/instagram/oauth/start` (with a login token)
   should return a `{url}`. Open it in a browser and log in with a
   **Business or Creator** Instagram account to test.
6. **Test users / app review:** while the app is in development mode,
   only users added as testers can log in — add test Instagram accounts
   under App Roles → Test Users (or Roles) in the dashboard, and have
   them accept the invite. To let the general public log in, the app
   must go through **App Review** for the `instagram_business_basic`
   permission (Meta reviews the app, a screencast of the login flow, and
   a privacy policy URL). Until review passes, logins from anyone who is
   not a tester will fail.
7. **Account requirement:** only Business or Creator Instagram accounts
   can log in through this API. Personal accounts get no access — the
   user must switch to Creator (free, in the Instagram app under
   Settings → Account type) before connecting.

Technical flow (implemented in `server.js`): authorize URL
`https://www.instagram.com/oauth/authorize` with
`client_id`, `redirect_uri`, `scope=instagram_business_basic`,
`response_type=code`, `state`; code exchange `POST
https://api.instagram.com/oauth/access_token` (form-encoded:
`client_id`, `client_secret`, `grant_type=authorization_code`,
`redirect_uri`, `code`) → short-lived token (~1 hour); profile `GET
https://graph.instagram.com/me?fields=id,username,account_type,media_count,profile_picture_url`.
The token is used once and discarded — it is never stored. (A long-lived
60-day token exchange exists — `GET https://graph.instagram.com/access_token?grant_type=ig_exchange_token`
— but this build does not need it, because it only reads the profile at
connect time and stores no token.)

## Deploy

### VPS (pm2 + nginx)

```bash
# on the server
git clone <your-repo> && cd followboost/backend
npm install --omit=dev
JWT_SECRET='<long-random-secret>' PORT=3000 pm2 start server.js --name followboost-api
pm2 save && pm2 startup
```

nginx reverse proxy (example):

```nginx
server {
    listen 80;
    server_name api.your-domain.com;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Then add HTTPS with `certbot --nginx`. Keep `data/followboost.db` on the
server and back it up regularly — it is the only copy of user data.

### Render (web service)

A `render.yaml` blueprint lives at the repo root (`followboost/render.yaml`):
deploy via Render dashboard → "New +" → "Blueprint", point it at the repo.
It creates one Node 24 web service (`followboost-api`, root directory
`backend`, build `npm install`, start `npm start`) with `PORT=3000`,
an auto-generated `JWT_SECRET`, `DB_PATH=data/followboost.db`, and empty
`OAUTH_CLIENT_ID` / `OAUTH_CLIENT_SECRET` / `OAUTH_REDIRECT_URI`
(fill those in once the Meta app exists). Manual setup is the same:

1. Create a **Web Service** from the repo, root directory `followboost/backend`.
2. Build command: `npm install`
3. Start command: `npm start`
4. Environment variables: `JWT_SECRET` (generate a random value),
   `OAUTH_CLIENT_ID` / `OAUTH_CLIENT_SECRET` / `OAUTH_REDIRECT_URI`
   (when the Meta app exists).
5. **⚠️ DATA LOSS WARNING — Render free tier:** Render's free tier has
   an **ephemeral filesystem**. `data/followboost.db` — every user,
   coin balance, order, and gift-code redemption — is **LOST on every
   deploy and every restart** (including Render's automatic restarts).
   There is no way around this on the free tier. For durable production
   data you MUST either attach a **Persistent Disk** (paid plan;
   Render dashboard → Disks, mount it and set `DB_PATH` to a path on
   that disk, e.g. `/var/data/followboost.db`) or migrate the backend
   to Postgres (not done in this build). **Do not run real users on the
   Render free tier expecting their accounts and coins to survive.**

## Security notes

- Passwords are hashed with bcrypt; never logged.
- JWTs expire after 30 days; keep `JWT_SECRET` secret and rotate it if leaked.
- The database file (`data/*.db`) is gitignored — it contains user accounts.
- This API never automates Instagram actions and never handles Instagram
  passwords. Orders are manual; tasks are confirmed by the user after they
  act in Instagram themselves.
