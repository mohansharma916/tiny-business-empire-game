# AGENTS.md — Tiny Business Empire

Shared rules for every AI coding tool on this project (Claude Code and Google Antigravity).
Source of truth for *what* to build: `docs/PRD.md`. This file says *how* to build it.

Engine: **Godot 4, GDScript only** (no C#, so the web export keeps working).
Renderer: **Compatibility** (best for low-end Android and the web build).

---

## 1. Folder ownership

Only edit folders you own. If you need a change in a folder you don't own,
add an entry to `docs/REQUESTS.md` instead of editing it.

| Folder | Owner | Contents |
|---|---|---|
| `scripts/core/` | Claude Code | Economy, BigNumber, saves, offline earnings. Pure logic, no UI. |
| `scripts/services/` | Claude Code | Analytics, crash reporting, backend client (P1), push (P1), ads (P1) |
| `server/` | Claude Code | Nakama backend in TypeScript: leaderboards, score validation, push (P1) |
| `addons/` | Claude Code | Godot plugins: GUT, Nakama SDK, Firebase, Play Billing, ads |
| Mobile export settings, Firebase config files, keystores setup | Claude Code | See `docs/MOBILE.md` |
| `tools/sim/` | Claude Code | Headless economy simulator and pacing checks |
| `tests/` | Claude Code | GUT unit tests |
| `config/` | Claude Code (Antigravity may request changes) | All tunable numbers |
| `scenes/` | Antigravity | City, screens, panels |
| `scripts/ui/` | Antigravity | Scripts attached to scenes |
| `assets/` | Antigravity | Sprites, atlases, fonts, audio |
| `docs/` | Both (append only; never rewrite another tool's section) | PRD, requests, prompts |
| `project.godot` | Ask the human first | Engine settings |

---

## 2. Architecture rules

- `scripts/core/` is **pure logic**: no `Node` subclasses except the one `EconomyService` autoload,
  no scene references, no UI calls. UI reads core; core never reads UI.
- The UI talks to the economy **only** through `EconomyService`'s public methods and signals:
  `cash_changed`, `income_changed`, `business_purchased`, `upgrade_purchased`,
  `business_automated`, `location_unlocked`, `milestone_reached`.
- **Income is a rate** (per second), recalculated only when something changes
  (purchase, upgrade, hire, boost start/end). Never compute money per frame or per customer.
- The economy **ticks 4 times per second** on a `Timer`, independent of frame rate.
  Cash increases by `income_per_second × elapsed`.
- **Online and offline earnings use the same function.** Never write a second formula.
- **Customers are cosmetic.** They are pooled (max 8 visible per business) and spawned to match
  the current income rate. They never decide revenue.
- **All currency uses `BigNumber`** (`scripts/core/big_number.gd`, mantissa + exponent).
  Never store cash in `int` or `float`.
- **All tunable numbers live in `config/*.json`.** No magic numbers in code.

---

## 3. Performance rules

- No allocations in `_process()` / `_physics_process()`. Cache node references in `_ready()`.
- No `get_node()` or `$Path` lookups inside loops or per-frame code.
- Cash and income labels update **at most 4 times per second**.
- Opening a full-screen panel pauses the city (`process_mode` / visibility).
- When the app goes to the background (`NOTIFICATION_APPLICATION_PAUSED`):
  stop the tick, save, and stop rendering work.
- Panels are instantiated once and reused, not created on every open.
- Long lists (upgrades, leaderboards) recycle rows.
- Use sprite atlases; keep the Main City under ~30 draw calls.

### Budgets (must hold on the low-end reference device)

| Metric | Budget |
|---|---|
| Frame rate | Steady 30 fps (60 on mid/high-end) |
| Cold start to playable | ≤ 5 s |
| Peak memory | ≤ 300 MB |
| Initial download | ≤ 80 MB |
| Save write | ≤ 20 ms, never blocking a frame |

---

## 4. Save rules

- Save on every purchase/claim (debounced to once per 2 s), every 30 s, and on backgrounding.
- Write to a temp file, then rename over the real save (atomic).
- Two save slots with a checksum; load the newest valid one.
- Every save has a `save_version`. Old saves are upgraded by ordered migration steps.
  Never silently reset a player's progress.
- Record an offline-earnings or reward claim in the save **before** granting the cash.

---

## 5. Workflow rules

- One feature per branch: `core/<feature>` (Claude Code) or `ui/<feature>` (Antigravity).
- Run tests before every commit:
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
  (and `cd server && npm test` when `server/` changed)
- Small commits with clear messages. Merge to `main` at least daily.
- Claude Code reviews every `ui/*` branch before it is merged.
- If a requirement in `docs/PRD.md` is unclear, ask the human. Do not invent product behavior.
- When you finish a task, add one line to the "Done" list in `docs/REQUESTS.md`.

---

## 6. Mobile rules

Full details: `docs/MOBILE.md`.

- Targets: Android 8.0+ (API 26), `arm64-v8a` + `armeabi-v7a`, portrait; iOS 15+ later.
- Handle `NOTIFICATION_APPLICATION_PAUSED` / `RESUMED`, the Android back button
  (`NOTIFICATION_WM_GO_BACK_REQUEST`: close the top panel first) and `NOTIFICATION_OS_MEMORY_WARNING`.
- Keep UI inside `DisplayServer.get_display_safe_area()`. Touch targets ≥ 48 dp.
- **Offline-first:** the game is fully playable without internet. Network calls never block
  gameplay or UI; they queue and retry with backoff.
- Ask for notification permission only after the first milestone. No other runtime permissions.
- Never commit keystores, `.env`, `nakama.yml` or service-account keys.
- Every new SDK or plugin: measure its download size and startup time against the budgets above.

## 7. Backend rules (P1)

Full details: `server/README.md`.

- Backend: **Nakama** with modules in **TypeScript** (pinned to TypeScript 5.x), PostgreSQL, Firebase Cloud Messaging for push.
- The game talks to Nakama only through `scripts/services/backend_client.gd`, using the official Nakama Godot SDK.
- Leaderboards are authoritative: only the server writes scores, after plausibility checks.
- Scores are big numbers encoded as `score = exponent`, `subscore = mantissa × 1e12`.
- Run `npm test` in `server/` before every commit that touches it.
- Don't build or deploy backend features during P0.

## 8. Style

- GDScript: static typing everywhere (`var cash: BigNumber`, `func buy(id: String) -> bool`).
- `snake_case` for files, functions and variables; `PascalCase` for `class_name`.
- One class per file. Keep files under ~300 lines.
- Comments explain *why*, not *what*.
