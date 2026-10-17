# Kickoff prompts

Paste these in order. Steps on the same row can run at the same time in both tools.
Each prompt assumes the tool has read `AGENTS.md` (Claude Code via `CLAUDE.md`,
Antigravity via `.agent/rules/project-rules.md`).

---

## Step 0 — Mobile foundation (before any gameplay)

Do the human-only parts of `docs/MOBILE.md` section 2 first (Android Studio, JDK 17, keystore).

**Claude Code**
> Read docs/MOBILE.md and AGENTS.md section 6. Configure the Android and Web export presets as
> described (Gradle build, arm64-v8a + armeabi-v7a, min SDK 26, portrait, permissions INTERNET,
> ACCESS_NETWORK_STATE, VIBRATE only). Add a minimal boot scene that shows the game title so we can
> install a debug APK on a phone. Write scripts/core/app_lifecycle.gd handling paused/resumed,
> back button and memory warnings (empty hooks for now, with TODOs pointing at the save system).
> Tell me exactly which steps I must do by hand.

---

## Step 1 — Contract (Claude Code first, Antigravity waits)

**Claude Code**
> Read docs/PRD.md sections 5 and 10 and AGENTS.md. On branch core/contract, create
> scripts/core/big_number.gd (class_name BigNumber: mantissa + exponent, add, subtract, multiply,
> compare, format as 1,234 / 12.3K / 4.56M / B / T / aa, ab…, plus an Indian lakh/crore option)
> and scripts/core/economy_service.gd as an autoload with the public API and signals the UI will
> use (get_cash, get_income_per_second, get_business_state, can_afford, buy_business,
> buy_upgrade, hire_staff, tap_business; signals cash_changed, income_changed, business_purchased,
> upgrade_purchased, business_automated, location_unlocked, milestone_reached). Methods may be stubs
> for now, but signatures must be final. Load config from config/*.json. Write GUT tests for
> BigNumber math and formatting. Register the autoload in project.godot. Don't touch scenes/.

**Antigravity** (in parallel, no code yet)
> Read docs/PRD.md sections 3, 4 and 7. Propose an art direction for a stylized 2D isometric
> India-inspired street: palette, tile size, building scale, customer sprite size. Generate
> placeholder sprites for the chai stall (3 visual levels), one customer, and street tiles into
> assets/placeholder/. Don't write gameplay code yet.

---

## Step 2 — Prototype

**Claude Code**
> On branch core/rate-engine: implement EconomyService fully for one business (chai stall):
> rate-based income per AGENTS.md, 4 Hz tick, the four upgrade tracks with Cost(n) = base × r^n,
> ×1/×10/×Max bulk buy using the closed-form geometric sum, tap_business for manual serving
> cycles, and milestone multipliers every 25 levels. All numbers from config/. Tests for
> income-per-second, upgrade costs and bulk-buy math.

**Antigravity**
> On branch ui/main-city: build scenes/main_city.tscn — an isometric street with the chai stall,
> a cash label and income/s label (updated max 4×/s), a tap-and-hold serving ring, and an upgrade
> button. Read everything from EconomyService; never compute money in UI. Pool customers (max 8).
> Export to web and test in the browser that tapping earns cash and upgrading works.

---

## Step 3 — Persistence and screens

**Claude Code**
> On branch core/saves: implement scripts/core/save_system.gd per AGENTS.md section 4 (atomic
> write, two slots, checksum, save_version + migrations, save on backgrounding) and offline
> earnings per PRD section 5 (same rate function, 2 h cap, 50% rate, claim recorded before cash is
> granted, clock-rollback protection). Tests: crash mid-save, corrupted slot, clock moved back,
> double claim.

**Antigravity**
> On branch ui/panels: build the Business Details panel and the Offline Earnings screen
> (PRD section 7). Panels are instantiated once and reused. Opening a full-screen panel pauses
> the city. Test in the web build.

---

## Step 4 — Balancing

**Claude Code**
> On branch core/sim: build tools/sim/ — a headless script that plays the economy with a simple
> "buy the best value upgrade" strategy and prints the time each milestone is reached. Compare
> with the 30-minute pacing table in PRD section 4 and check the no-soft-lock rule. Suggest
> config changes to hit the targets.

**Antigravity**
> On branch ui/onboarding: build the tutorial (2–3 guided steps on the chai stall), the
> Objectives screen and the Empire Overview (PRD section 7).

---

## Step 5 — Content

**Claude Code**
> On branch core/content: support all five MVP businesses, staff (workers, managers), both
> synergies and the Market Lane unlock from config. Tests for synergy activation and unlock rules.

**Antigravity**
> On branch ui/market-lane: add Market Lane, the other four businesses, the Business Unlock
> screen, locked-plot hints, and the 30 fps battery-saver mode in Settings.

---

## Step 6 — Quality

**Claude Code**
> Review all merged code against AGENTS.md performance and architecture rules. List violations
> with file and line, then fix those in folders you own and add the rest to docs/REQUESTS.md.

**Antigravity**
> Play the web build for 15 minutes following the PRD pacing table. Report anything confusing,
> slow or broken. Then export an Android build and check frame rate on a low-end phone.

---

## Step 7 — Crash reports and analytics (end of P0)

**Claude Code**
> Read docs/MOBILE.md section 3 and docs/PRD.md section 11. Evaluate maintained Godot 4 Firebase
> plugins for Crashlytics and Analytics on Android; if none is reliable, write a small Kotlin
> Android plugin. Implement scripts/services/crash_reporting.gd and analytics.gd with batched
> events and the common parameters from the PRD. Measure the added download size and cold-start
> time and report them against the budgets in AGENTS.md.

---

# P1 — Soft launch (only after P0 meets its exit criteria)

## Step 8 — Backend up locally

**Claude Code**
> Read server/README.md and AGENTS.md section 7. Get the Nakama server running locally with
> docker compose, run npm test, and confirm the RPCs work with a small script that authenticates
> a device and calls set_country, submit_score and get_my_ranks. Then add the Nakama Godot SDK to
> addons/ and implement scripts/services/backend_client.gd per server/README.md ("API for the
> Godot client"), including an offline queue with retry and backoff from config/backend.json.

**Antigravity**
> Read docs/PRD.md section 8 and server/README.md ("API for the Godot client"). Build
> scenes/panels/leaderboards.tscn: Global / Country tabs, All-time / Weekly toggle, top 100 with
> recycled rows, the player's rank pinned at the bottom (exact rank or "Top X%"), and an offline
> state. Use only backend_client.gd; mock its responses until Claude Code's version is merged.

## Step 9 — Celebrations and push

**Claude Code**
> Implement scripts/services/notifications.gd: ask for notification permission after the first
> earnings milestone (never at launch), get the FCM token, call register_push_token. Handle
> Nakama in-app notifications with code 100 and expose a signal for the UI. Fill in the FCM
> settings in nakama.yml and test a real push on an Android phone.

**Antigravity**
> Build the rank-band and earnings-milestone celebration card (PRD section 8) with a share button
> using the platform share sheet. It listens to the notifications.gd signal and to EconomyService's
> milestone_reached signal.

## Step 10 — Deploy for soft launch

**Claude Code**
> Follow server/README.md "Deploying". Prepare the production checklist: domain, HTTPS via
> docker-compose.prod.yml, firewall, daily database backups, admin console via SSH tunnel.
> Then work through the P1 to-do list in server/README.md and the release checklist in
> docs/MOBILE.md section 9, and tell me which items need me.
