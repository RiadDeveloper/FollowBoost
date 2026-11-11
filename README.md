# FollowBoost 🚀

[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-24-339933?logo=node.js)](https://nodejs.org)
[![SQLite](https://img.shields.io/badge/SQLite-better--sqlite3-003B57?logo=sqlite)](https://github.com/Wiseluster/better-sqlite3)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**FollowBoost** is an Instagram growth & rewards app — earn coins by
completing follow/like tasks, spend coins to grow your own followers.
A Flutter Android app backed by a Node.js API with a server-side coin
ledger. Original code, built from scratch.

> **The one rule that shapes everything:** follows are always manual.
> The app never logs into Instagram for you, never handles Instagram
> passwords, and never automates follows or likes. You follow people
> yourself in the Instagram app, confirm it in FollowBoost, and get
> paid in coins. That is the whole deal — and it is why no one's
> Instagram account is ever put at risk by this app.

## ✨ Features

- **Earn coins** — complete follow/like tasks, claim a daily reward with
  a streak bonus, redeem gift codes, invite friends.
- **Spend coins** — order followers or likes for your own handle. Every
  order becomes tasks for other users, so real people follow you
  manually and your order fills up as they do.
- **Order → task pool** — placing an order instantly creates tasks for
  other users, with live progress (`queued` → `partial` → `completed`).
- **Official Instagram login** — connect with Meta's own login flow
  (your real username, profile picture, account type). No password
  ever touches the app.
- **Wallet** — balance plus a full earn/spend history, all server-side.
- **Leaderboard** — top 20 users by coins.
- **Referrals** — invite friends, you both earn.
- **Gift codes** — the owner mints codes like `WELCOME100`.
- **Admin view** — the first registered user sees every order at a glance.
- **Tasks auto-refresh** — new orders appear on the Tasks screen within
  seconds, no restart needed.

## 🔄 How it works

1. **Deploy the backend** (Render via `render.yaml`, or a VPS — see
   [`backend/README.md`](backend/README.md)) and point the app at it.
2. **Sign up** in the app (email + password) — you get a **50-coin**
   signup bonus.
3. **Connect Instagram** (Profile → "Connect with Instagram"): Meta's
   official login opens in your browser. The app shows your real
   username, profile picture, account type, and media count. A manual
   username link remains as a fallback.
4. **Earn coins** — do tasks, claim your daily reward, redeem gift
   codes, refer friends.
5. **Spend coins** — create a follower/like order for your handle.
   Other users see it as tasks, follow or like you manually on
   Instagram, confirm in the app, and earn coins. Your order fills up
   as they complete it.

### Coin economy

| Action | Coins |
|---|---|
| Signup bonus | +50 |
| Daily reward | +20 base, +5 per streak day, max +50 |
| Complete a seeded follow task | +5 |
| Complete a seeded like task | +3 |
| Complete an order task (follow or like) | +1 |
| Gift code `WELCOME100` | +100 (once per user) |
| Referral — you / the friend who invited you | +25 / +50 |
| Order: followers | −2 per follower (min 10) |
| Order: likes | −1 per like (min 10) |

Order tasks pay the doer 1 coin, so a follow order leaves a
1-coin-per-follower margin and likes are 1:1 — **no coins are created
from nothing**. Seeded tasks are funded by the house. Every movement is
recorded in the wallet history, and the balance is the ledger.

## 📥 Install

Download the latest APK from the
[**Releases**](https://github.com/RiadDeveloper/FollowBoost/releases)
page and install it on your Android phone. The app is live-only: on
first launch it asks for the backend URL — enter the URL of your
deployed backend (Profile → Settings to change it later).

> **Note:** FollowBoost is a hosted service, not a standalone app. The
> APK alone does nothing without a backend to talk to. Deploy the
> backend first (below), or ask the person running the service for
> their backend URL.

## 🛠️ Run it yourself (developers)

### Backend

```bash
cd backend
npm install
npm start          # listens on PORT (default 3000)
npm test           # 29 tests
```

Set `JWT_SECRET` in production. Full endpoint list, environment
variables, and deploy guides (VPS with pm2 + nginx, and Render) are in
[`backend/README.md`](backend/README.md).

**Deploy on Render** — a `render.yaml` blueprint is included: in the
Render dashboard, "New +" → "Blueprint" and point it at this repo.
It creates one Node 24 web service with an auto-generated `JWT_SECRET`.

> ⚠️ **Render free tier warning:** the free tier has an ephemeral
> filesystem — `data/followboost.db` (every user, coin balance, and
> order) is **lost on every deploy and restart**. For durable
> production data, attach a paid Persistent Disk or migrate the backend
> to Postgres before running real users.

**Instagram login setup** — create a Meta developer app, add the
Instagram product ("Instagram API with Instagram Login"), set the
redirect URI to `https://<your-api-domain>/api/instagram/oauth/callback`,
and set `OAUTH_CLIENT_ID` / `OAUTH_CLIENT_SECRET` /
`OAUTH_REDIRECT_URI` on the backend. Step-by-step instructions are in
[`backend/README.md`](backend/README.md). Only Business/Creator
Instagram accounts can connect through the official API.

### Android app

```bash
cd app
flutter pub get
flutter analyze    # must be clean
flutter test       # must pass
flutter build apk --release
```

Requirements: Flutter 3.47.9, JDK 17, Android SDK. The release is
signed with the FollowBoost keystore (`app/android/app/keystore.jks` +
`android/key.properties`) — **back those files up and never commit
them**, or you will not be able to publish updates to the same app.

## 📁 Project structure

```
followboost/
├── app/         Flutter Android app (com.followboost.app, v1.0.2+3)
│   ├── lib/     screens, models, services, widgets
│   └── test/    live API + widget tests
├── backend/     Node.js + Express + SQLite REST API
│   ├── server.js    all endpoints (auth, wallet, tasks, orders,
│   │                admin, gift codes, referrals, Instagram OAuth)
│   ├── db.js        schema, seeding, server-side coin ledger
│   └── test/        29 API tests (real server, throwaway database)
├── render.yaml  Render deploy blueprint
├── LICENSE      MIT
└── README.md    this file
```

## 📜 Version history

- **v1.0.2** — Live-only. Demo mode removed entirely; official
  Instagram login (Meta OAuth, "Instagram API with Instagram Login");
  Tasks auto-refresh every 30 s; Render deploy config (`render.yaml`).
- **v1.0.1** — Orders now create tasks: every order generates one task
  per follower/like for other users, with live progress
  (`queued` → `partial` → `completed`) and a read-only admin view.
  The orderer can never complete their own order's tasks.
- **v1.0.0** — First release: full app + backend, demo mode, manual
  tasks, orders, wallet, leaderboard, gift codes, referrals.

## ⚠️ Honest limitations

- **It needs a deployed backend.** Without one, the app only shows the
  setup screen. There is no offline mode.
- **Instagram login needs a Business/Creator account** and a Meta
  developer app (plus App Review before the general public can log in).
  Follower/following counts are deliberately not fetched — the official
  API path for them is a later change, and the app will never display
  numbers it did not get from Instagram.
- **No auto-follow, by design.** Follows are manual, so an order fills
  up only as fast as real users do the tasks. That is also why the app
  never gets anyone's Instagram account banned.
- **Render free tier loses the database on restart** (see above).
- VIP and coin-pack payments are not wired yet, and there is no admin
  action to refund or cancel an order.

## 🗺️ Roadmap

- Postgres migration (or a Persistent Disk) for durable production data
- Push notifications when new orders arrive
- Coin packs & VIP payments
- Admin refund / cancel actions
- Follower/following counts via the Instagram Graph API
- Play Store release

## 👤 Credits

**Created by [Riad Developer](https://github.com/RiadDeveloper)**

- GitHub: <https://github.com/RiadDeveloper>
- Portfolio: <https://riaddeveloper.is-a-good.dev>
- Email: <riaddeveloperr@gmail.com>

## 📄 License

MIT — see [LICENSE](LICENSE). Original code, built from scratch.
