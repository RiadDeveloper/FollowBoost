# FollowBoost — Flutter app

The Android app for FollowBoost, an Instagram growth & rewards app.
Package `com.followboost.app`, version 1.0.2+3. **Live-only** — there is no
demo mode; the app talks only to the real backend (set its URL on the
first-launch setup screen, or later in Profile → Settings).

## How it works

- Sign up, connect Instagram (official Meta login — the app never sees your
  Instagram password), complete follow/like tasks manually in the Instagram
  app, confirm in FollowBoost, and earn coins.
- Spend coins on follower/like orders for your own handle. Each order
  becomes tasks for other users, who follow/like you manually and confirm —
  your order fills up as they do.
- Coin economy: signup bonus 50, daily reward 20 + 5/streak day (max 50),
  seeded follow task 5 / like task 3, order task 1, `WELCOME100` = 100 coins,
  referral applier +25 / referrer +50. Orders cost 2 coins per follower
  (min 10) or 1 coin per like (min 10).

## Structure

- `lib/services/` — `api_client.dart` (contract + result types),
  `live_api.dart` (HTTP), `pricing.dart` (coin rules),
  `session.dart` (token, base URL).
- `lib/models/` — User, TaskItem, OrderItem, WalletEntry, LeaderboardEntry.
- `lib/screens/` — Splash, Onboarding, Auth, Home, Tasks, Orders, Wallet,
  Leaderboard, Gift, Referral, VIP (info screen — no payment wired yet),
  Profile, Admin (first user only), BackendSetup, MainShell.
- `lib/widgets/` — GradientButton, CoinBadge (count-up), TaskCard,
  SectionTitle, GradientAppBar, StaggeredItem.
- `test/` — `live_api_test.dart` + `widget_test.dart`.

## Checks

```sh
flutter analyze   # must be clean
flutter test      # must pass
```

Release builds are signed with the FollowBoost keystore
(`android/app/keystore.jks` + `android/key.properties`) — **never commit
those files; back them up, or updates to the same app listing are
impossible.**
