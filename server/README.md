# server — owner: Claude Code

Game backend for **P1 (soft launch)**: anonymous accounts, global and country leaderboards,
score validation, rank-band notifications and push.
Built on **Nakama** (open-source game server) with modules in **TypeScript**, plus PostgreSQL.

> Don't deploy this during P0. The game must be fully playable offline first.
> The code is here so the design is settled and Claude Code can extend it in P1.

## What's in here

| Path | Purpose |
|---|---|
| `src/config.ts` | Tuning: board ids, weekly reset, rank bands, cheat-check limits, push limits |
| `src/bignum.ts` | Big numbers (mantissa + exponent) and leaderboard score encoding |
| `src/validation.ts` | Score plausibility checks, week ids, rank bands (pure functions, unit-tested) |
| `src/leaderboards.ts` | Creates boards; reads a player's rank; exact rank vs. percentile |
| `src/push.ts` | Firebase Cloud Messaging (HTTP v1) push sender |
| `src/rpc.ts` | RPCs the game calls |
| `src/main.ts` | Nakama entry point; registers RPCs |
| `test/logic.test.js` | Unit tests for the pure logic |
| `docker-compose.yml` | Local Nakama + PostgreSQL |
| `docker-compose.prod.yml` | Production override: HTTPS via Caddy |
| `nakama.example.yml` | Nakama config template (copy to `nakama.yml`) |

## Local development

Requires Node.js 20+ and Docker.

```bash
cd server
cp .env.example .env               # set POSTGRES_PASSWORD
cp nakama.example.yml nakama.yml   # replace every CHANGE_ME
npm install
npm test                           # builds, then runs unit tests
docker compose up                  # Nakama on :7350, console on :7351
```

After changing TypeScript: `npm run restart` (rebuilds and restarts Nakama).

TypeScript is pinned to 5.x on purpose: Nakama needs a single ES5 output file (`outFile`),
which TypeScript 6 deprecates.

## Leaderboards

All boards rank **lifetime earnings** and are authoritative (only the server writes).

| Board id | Resets |
|---|---|
| `global_alltime` | Never |
| `global_weekly` | Monday 00:00 IST (cron `30 18 * * 0`, UTC) |
| `country_alltime_<CC>` (e.g. `country_alltime_IN`) | Never; created on first player from that country |
| `country_weekly_<CC>` | Monday 00:00 IST |

**Big-number scores.** Leaderboard scores are 64-bit integers, which overflow around 9.2e18,
but idle-game earnings go far beyond that. Scores are stored as
`score = exponent`, `subscore = mantissa × 1e12`, which Nakama sorts correctly.
Convert back on the client: `value = (subscore / 1e12) × 10^score`.

## API for the Godot client

Use the official Nakama Godot SDK (`heroiclabs/nakama-godot`, Godot 4 compatible) from
`scripts/services/backend_client.gd`. The rest of the game never calls Nakama directly.

**Authentication**
- First launch: `authenticate_device_async(id)` with a random UUID generated once and kept in the
  local save (privacy-friendly; don't use hardware ids).
- Optional later: link Google Play Games (Android) or Game Center (iOS) so progress survives a new phone.
- Store the session's refresh token locally and refresh it instead of re-authenticating.

**RPCs** (`rpc_async(session, id, JSON.stringify(payload))`)

| RPC | Payload | Returns | When |
|---|---|---|---|
| `set_country` | `{country: "IN"}` | `{ok, country}` or `{ok:false, error:"country_change_limit"}` | First launch (from store region / locale); Settings |
| `submit_score` | `{lifetime: {m, e}, income: {m, e}}` | `{ok, accepted, ranks:[…]}` | Every 5 min, on milestones, on backgrounding |
| `get_my_ranks` | `{}` | `{ok, country, ranks:[…]}` | Opening the Leaderboards screen |
| `register_push_token` | `{token, platform: "android"/"ios", optIn: true}` | `{ok, optIn}` | After the player grants notification permission |
| `delete_my_account` | `{confirm: true}` | `{ok}` | Settings → Delete data |

A rank entry looks like `{board, ranked, exact: true, rank, total}` inside the top 10,000,
or `{board, ranked, exact: false, topPercent, total}` beyond it.

**Leaderboard lists** (built into the SDK, no RPC needed)
- Top 100: `list_leaderboard_records_async(session, board_id, [], null, 100)`
- Around the player: `list_leaderboard_records_around_owner_async(session, board_id, user_id, null, 11)`

**In-app notifications.** Rank-band celebrations arrive as Nakama notifications with code `100`
and content `{board, band, rank}`. Listen on the socket while the game is open, and list
unread notifications on startup. Show the celebration card from them.

**Offline-first rule.** Every backend call must fail quietly. Queue `submit_score` and retry with
backoff; never block gameplay or the UI waiting on the network.

## Cheat prevention

`validation.ts` flags a submission when:
- lifetime earnings go down,
- a new account's first submission is above 1e7,
- income per second grows faster than 50× per hour,
- earnings since the last submission exceed `income × time elapsed × 3`.

Flagged players keep playing normally but are no longer written to public boards.
Review flagged players in the admin console (Storage → `tbe_player` / `score_state`).
Tune the limits in `config.ts` using soft-launch data.

## Push notifications

1. Create a Firebase project; add the Android app (and iOS app later).
2. For iOS, upload an APNs authentication key in Firebase → Cloud Messaging.
3. Firebase → Project settings → Service accounts → Generate new private key.
4. Copy `project_id`, `client_email` and `private_key` into `runtime.env` in `nakama.yml`.

Pushes are limited to 1 per player per day and only sent to players who opted in.

## Deploying (soft launch)

1. Rent a small Linux VM in a Mumbai region (2 vCPU, 4 GB RAM is plenty to start).
2. Install Docker; copy this folder; create `.env`, `nakama.yml` and `Caddyfile`.
3. Point a domain (e.g. `api.yourgame.com`) at the VM.
4. `npm install && npm run build`
5. `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d`
6. Open only ports 80 and 443 in the firewall. Reach the console through an SSH tunnel:
   `ssh -L 7351:localhost:7351 user@server`, then open http://localhost:7351.
7. Back up the database daily (for example a cron job running `pg_dump` and copying the file off the server).

If the game grows, move to Heroic Labs' managed Nakama hosting without changing game code.

## P1 to-do (Claude Code)

- [ ] Profanity filter for display names (`registerBeforeUpdateAccount` hook)
- [ ] Optional "you were overtaken" alert (top 1,000, max once a week)
- [ ] Google Play purchase validation for the remove-ads purchase
- [ ] Remote config endpoint for economy tuning
- [ ] Rate limiting and metrics review before soft launch
- [ ] Load test with simulated players before opening to the public
