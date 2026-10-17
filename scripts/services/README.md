# scripts/services — owner: Claude Code

Wrappers around external systems, so the rest of the game never calls an SDK directly.

| File | Purpose | Release |
|---|---|---|
| `analytics.gd` | Batched event logging through Firebase Analytics (send at most once per minute or on backgrounding) | P0 |
| `crash_reporting.gd` | Firebase Crashlytics setup and non-fatal error logging | P0 |
| `backend_client.gd` | Nakama SDK wrapper: device auth, `submit_score`, `get_my_ranks`, `set_country`, leaderboard lists, in-app notifications, account deletion. Queues and retries offline. | P1 |
| `notifications.gd` | Push permission (after first milestone), FCM token → `register_push_token` | P1 |
| `ads.gd` | Rewarded ads; initialized only after the tutorial | P1 |
| `purchases.gd` | Google Play Billing: remove-ads purchase, restore | P1 |

Backend API reference: `server/README.md`. Settings: `config/backend.json`.
Every service must fail quietly when offline; gameplay never waits on the network.
