# Tiny Business Empire — PRD v2.0

Oct 17, 2026 · Mohan Sharma

## 1. Executive summary

Tiny Business Empire is a 2D isometric idle tycoon for Android and iOS. Players turn a single chai stall into a business network, unlock new neighborhoods and, in later releases, build a global empire.

**Product vision:** turn a tiny street stall into a thriving global business empire, one smart investment at a time.

**Core value:** the satisfaction of starting from nothing, making business decisions, watching the street grow, and seeing your progress ranked against players in your country and the world.

The game combines idle income, upgrades and staff, strategic reinvestment, unlockable businesses and locations, visible city growth, objectives, and (from soft launch) global and country leaderboards.

### What changed in v2.0

| Area | Change |
| --- | --- |
| Architecture | Economy is calculated as a rate, separate from visuals; one function serves online and offline earnings |
| Performance | Measurable budgets for frame rate, startup, memory, download size and battery, per device tier |
| Numbers | Big-number type and display format required from day one |
| Saves | Atomic writes, two save slots, checksums, versioned migrations |
| Economy | First-30-minute pacing table, a concrete no-soft-lock rule, config-driven tuning, simulation tool moved to P0 |
| Consistency | Synergies use real businesses; exact MVP business list; operating costs removed from MVP |
| New feature | Global and country leaderboards with milestone and rank-band notifications (P1) |
| Compliance | Consent, GDPR, India's DPDP Act, age rating, accessibility and localization |
| Decisions | Open product decisions resolved so production can start; engine set to Godot 4 |

## 2. Goals and success criteria

The MVP must prove three things: players enjoy the loop, they come back, and they share or compete voluntarily.

### Primary goals

1. Deliver an enjoyable, playable business-building loop.
2. Make progression visible and rewarding.
3. Drive daily returns through offline earnings, daily objectives and rank notifications.
4. Create natural sharing moments around achievements and rankings.
5. Validate retention and monetization before expanding content.
6. Run well on low-end Android devices common in the launch market.

### Success criteria

These are internal targets, to be revised after the first playtests and soft launch.

| Metric | Target |
| --- | --- |
| Tutorial completion | ≥ 80% |
| Tutorial completion time | ≤ 3 minutes |
| First upgrade | Within 2 minutes |
| Second business unlocked (first session) | ≥ 50% of players |
| Day-1 retention | ≥ 30% |
| Day-7 retention | ≥ 10% |
| Crash-free sessions | ≥ 99.5% |
| ANR rate (Android) | < 0.47% (Play Console bad-behavior threshold) |
| Steady 30 fps on low-end reference device | ≥ 95% of sessions |
| Push opt-in after first milestone (P1) | ≥ 40% |

### Non-goals for the MVP

- Real-money stock markets, gambling or financial advice.
- Player-to-player trading or complex multiplayer economies.
- Real-time competitive multiplayer.
- 3D open-world exploration.
- Tiers 3–5 content and multiple cities.
- Paid random rewards (loot boxes).

## 3. Audience and design principles

The primary audience is casual mobile players who enjoy watching small systems grow, starting with an Android-first launch in India.

### Audience

- **Primary:** casual players who like incremental progression and short sessions.
- **Secondary:** idle-game enthusiasts, tycoon and city-builder fans, optimizers.
- **Device reality:** many players use 3–4 GB RAM Android phones on metered data. Download size and low-end performance are product requirements, not polish.

### Player motivations

1. **Progression:** build something bigger every session.
2. **Optimization:** improve profit and efficiency.
3. **Ownership:** a street that feels like theirs.
4. **Discovery:** new businesses and combinations.
5. **Status:** milestones, achievements and rank against friends, country and world.

### Design principles

- **Immediate feedback:** every meaningful action visibly changes cash, speed, customers or buildings.
- **Simple decisions, deeper strategy:** complexity arrives gradually through upgrades, staff and synergies.
- **Meaningful sessions:** every session offers a reachable upgrade, unlock or objective.
- **Respect player time:** fun without constant attention; offline earnings reward returns.
- **Fair monetization:** core progression never requires payment; ads are optional.
- **Light on the device:** the game is idle most of the time, so it should use little battery, memory and data while doing so.

## 4. Core loop and pacing

Play moves from tapping to serve, to automating, to managing several businesses, within the first 15 minutes.

### Core loop

1. Open a business.
2. Serve customers and earn cash (manually at first).
3. Upgrade equipment, capacity, quality and marketing.
4. Hire staff to automate the business.
5. Reinvest into new businesses.
6. Unlock the next neighborhood.
7. Complete objectives and climb the leaderboards.
8. Leave, then return to collect offline earnings.

### Active mechanic (hybrid play)

- Before automation, the player **taps a business to complete a serving cycle**. A progress ring fills; on completion, cash pops out.
- Holding a finger on the business repeats the cycle, so players never need to tap rapidly.
- After a manager is hired, cycles run automatically. Tapping an automated business gives a small temporary speed boost (for example +20% for 10 seconds), so active play stays useful without being required.

### First 30 minutes (target pacing)

The economy simulation tool (P0) must reproduce this timeline for an average player before playtests.

| Time | Milestone |
| --- | --- |
| 0:00 | Tutorial starts on the chai stall |
| 0:15 | First sale |
| 1:30 | First upgrade (stove) |
| 3:00 | Tutorial complete |
| 5:00 | First worker hired |
| 8:00 | Chai stall automated (manager) |
| 12:00 | Second business: pani puri cart |
| 20:00 | Third business: fruit stand |
| 30:00 | First offline-earnings prompt seeded ("come back in 1 hour") |

### No-soft-lock rule

At any point, the player must be able to afford at least one upgrade or unlock within **5 minutes of idle income**. The simulation tool checks this rule across the whole MVP progression.

## 5. Businesses and economy

The MVP ships five businesses across two locations, with every economy number held in config so balancing never needs a new build.

### Business roster

| Business | Tier | Location | Release |
| --- | --- | --- | --- |
| Chai stall | 1 | Starter Street | P0 |
| Pani puri cart | 1 | Starter Street | P0 |
| Fruit stand | 1 | Starter Street | P0 |
| Bakery | 2 | Market Lane | P0 |
| Café | 2 | Market Lane | P0 |
| Food truck | 1 | Starter Street | P1 |
| Grocery store, salon | 2 | Market Lane | P1 |
| Tiers 3–5 (city, industrial, global) | 3–5 | Later locations | P2+ |

### Business attributes

Each business is defined in config with: ID, display name, unlock cost, unlock requirements, base revenue per cycle, cycle time, capacity, upgrade tracks and their base costs, staff slots, and synergy tags. Runtime state is only: owned flag, level per upgrade track, assigned staff and automation status.

### Upgrade tracks

- **Equipment:** shorter cycle time.
- **Capacity:** more customers per cycle.
- **Quality:** more revenue per customer.
- **Marketing:** higher customer arrival rate (raises the demand cap).
- **Automation:** unlocked by hiring a manager.

Each upgrade shows its cost and its effect on income per second before purchase. Every 25 levels on a track gives a milestone multiplier (×2), a proven idle-game pacing beat.

### Income model (rate-based)

Income is computed as a rate, recalculated only when something changes (upgrade, hire, purchase, boost start or end). It is not simulated customer by customer.

```
Income/s = min(Demand, Capacity) × Revenue per customer / Cycle time × Multipliers
```

Multipliers include staff, synergies, milestones and temporary boosts. Operating costs are **not** part of the MVP; they may return later if playtests show the economy needs a sink.

### Upgrade pricing

```
Cost(n) = Base cost × r^n
```

Start with r between 1.07 and 1.15 per level for upgrade tracks and 1.15–1.35 for business unlocks, then tune with the simulation tool. Bulk-buy buttons (×1, ×10, ×Max) use the closed-form geometric sum rather than looping.

### Currency

- **Cash (soft):** earned from businesses, objectives and offline earnings; spent on everything in the MVP.
- **Gems (premium):** not in the MVP. If added later, cosmetics and optional convenience only.

### Big numbers

Idle economies grow exponentially, and a standard double loses precision and tops out near 1e308. All currency uses a **big-number type** (mantissa + exponent) from day one. Display format: 1,234 → 12.3K → 4.56M → B → T → aa, ab, ac… An Indian-numbering option (lakh, crore) is offered for the India launch.

### Offline earnings

- On launch or resume, elapsed time = now − last save timestamp, capped at **2 hours** at start (raised by upgrades to 8 hours).
- Earnings = the same income-per-second function used online × capped elapsed time × an offline rate (start at 50%).
- A summary screen shows time away, total and per-business breakdown, with an optional rewarded ad to double it.
- The claim is recorded in the save before the cash is granted, so it can't be claimed twice.
- **Clock protection:** if the device clock moved backwards, grant nothing for that gap and re-anchor. Use network time when online. Local-only saves can't be fully secured; this is accepted while there is no paid currency, and server checks apply once leaderboards launch (Section 8).

## 6. Synergies, city and staff

The MVP has two predefined synergies, two locations and two staff types; each system is data-driven so later content is config, not code.

### Synergies (MVP)

| Synergy | Required businesses | Effect | Unlock |
| --- | --- | --- | --- |
| Street Snack Combo | Chai stall + Pani puri cart | +25% income on both | Both owned, each level 10+ |
| Breakfast Corner | Bakery + Café | +50% income on both | Both owned, each level 10+ |

Each synergy shows its required businesses, conditions, reward and active status. No synergy is ever required for progression. Later synergies (for example Warehouse + Grocery store) arrive with their businesses.

### City expansion

| Location | Release | Unlock condition |
| --- | --- | --- |
| Starter Street | P0 | Default |
| Market Lane | P0 | Own 3 businesses and earn 50K lifetime cash (tunable) |
| Shopping District, Industrial District, Downtown, International Business District | P2+ | Later releases |

As players progress, empty plots fill, businesses change appearance at level milestones (levels 1, 25, 50, 100), streets get busier, and decorations appear. Locked plots show their unlock requirement when tapped.

### Staff and automation

- **Worker:** +20% speed on one business per worker level (tunable).
- **Manager:** automates one business. The first manager is reachable around minute 8 (Section 4).
- **Specialist:** business-specific bonus (P2).
- Staff can be reassigned between businesses at no cost.
- The Business Details screen always shows the staff effect and automation status.

## 7. Screens and navigation

Nine screens; the Main City stays the home screen and everything else opens as a panel over it, so the city scene is never reloaded.

| Screen | Purpose | Key contents | Release |
| --- | --- | --- | --- |
| Onboarding | Get into play fast | 2–3 short guided steps on the chai stall; no account; skip for returning players | P0 |
| Main City | Home screen | Street, businesses, animated customers, cash, income per second, tap-to-serve, purchase and upgrade buttons | P0 |
| Business Details | Manage one business | Level, income/s, upgrade tracks with cost and effect, ×1/×10/×Max, staff, automation, synergy status | P0 |
| Business Unlock | Buy a business | Preview, cost, requirements, expected starting income, confirm | P0 |
| Offline Earnings | Welcome back | Time away, total, per-business breakdown, collect, optional ad to double | P0 |
| Objectives | Goals | Onboarding goals, daily tasks, achievements, rewards | P0 (daily: P1) |
| Empire Overview | Big picture | Businesses owned, lifetime earnings, income/s, city level, next expansions | P0 |
| Leaderboards | Status | Global / Country tabs, All-time / Weekly, top 100, own rank, nearby players | P1 |
| Settings | Control | Sound, music, haptics, battery saver (30 fps), number format, notifications, language, privacy, leaderboard visibility, restore purchases, delete data, support | P0 |

### UI performance rules

- Panels are pooled and reused, not created on each open.
- The cash and income labels update at most 4 times per second.
- Lists (upgrades, leaderboards) use recycled rows.
- Opening a full-screen panel pauses rendering of the city behind it.

## 8. Objectives, social and leaderboards

Objectives guide the first sessions; from soft launch, global and country leaderboards with milestone notifications give players a reason to keep climbing.

### Objectives and achievements

- **Onboarding objectives (P0):** serve the first customer, collect earnings, upgrade the chai stall, hire a worker, open the second business.
- **Daily objectives (P1):** three per day, such as earn an amount scaled to the player's income, buy 10 upgrades, collect offline earnings. Rewards are sized to 10–20 minutes of current income.
- **Achievements (P1):** First Business, Local Entrepreneur (3 businesses), Automation Expert (3 automated), Neighborhood Leader (Market Lane), Millionaire, and earnings milestones.
- **Streaks (P2):** only after retention testing; a missed day pauses a streak instead of resetting it.

### Social sharing (P1)

- Shareable cards for achievements, businesses owned, latest location, and rank milestones.
- Invites use the standard platform share sheet. No access to contacts.

### Global and country leaderboards (P1)

**Boards.** Four boards: Global and Country, each with **All-time** and **Weekly** (resets Monday 00:00 IST, shown in the player's local time). Weekly boards give new players a real chance to rank; all-time gives long-term status.

**Ranking metric.** Lifetime earnings (weekly: earnings during the week). Spending never lowers rank.

**Leaderboard screen.** Top 100, the player's own rank and score pinned at the bottom, and the 5 players above and below them.

**Rank display.**

- Top 10,000: exact rank, for example "#1,382 in India".
- Below 10,000: a percentile, for example "Top 12% globally".

**Milestone notifications.** Two triggers:

| Trigger | Thresholds | Example message |
| --- | --- | --- |
| Earnings milestone | 1K, 10K, 100K, 1M, 10M… (each 10× the last) | "You crossed 1 crore in earnings! You're now #1,400 in India." |
| Rank band | Top 10,000, 5,000, 1,000, 500, 100, 50, 10, #1 (global or country) | "You're in the Top 1,000 in India! Only 999 entrepreneurs ahead of you." |

Delivery rules:

- **Game open:** an in-app celebration card with a share button.
- **Game closed:** a push notification, at most 1 per day, opt-in only. Ask for permission after the first milestone, never at launch (Android 13+ and iOS require explicit permission).
- Each milestone and band fires once per board, so players near a boundary aren't spammed.
- **Overtaken alert (optional):** "Someone just passed you — you're #1,001." At most once a week, top 1,000 only, tested before full rollout.

**Technical design.**

- The client submits scores in batches: every 5 minutes, on a milestone, and when the app goes to the background.
- The server keeps one sorted set per board (for example Redis sorted sets), so rank lookups stay fast with millions of players.
- Top-100 lists are cached for 1–5 minutes.
- Percentiles come from score buckets recomputed every few minutes, not from exact rank queries.
- Rank bands are checked on the server when scores arrive; notifications are queued through FCM (Android) and APNs (iOS).
- Country comes from the store region or device locale, changeable once by the player. No GPS.
- Backend: **Nakama** (open-source game server) with modules in TypeScript, which provides accounts, authoritative leaderboards with weekly resets, rank lookups and "players around me" out of the box (Section 10). Google Play Games and Game Center leaderboards lack country boards and custom rank alerts.
- Scores are big numbers, but leaderboard scores are 64-bit integers (overflow near 9.2e18), so they are stored as score = exponent and subscore = mantissa × 1e12, which sorts correctly.

**Cheat prevention.**

- The server checks each submission against the maximum plausible earnings rate for the player's businesses and levels.
- Impossible jumps and clock tricks are flagged; flagged players are quietly hidden from public boards but keep playing.
- Eligibility requires a light account: anonymous ID linked to Google Play Games or Game Center. No mandatory sign-up.

**Privacy.** Auto-generated display names by default, a profanity filter on custom names, and a setting to hide from public boards.

**Validation.** A/B test rank notifications on half of soft-launch players; keep them only if D7 retention improves without raising notification opt-outs.

## 9. Monetization

Monetization starts at soft launch with optional rewarded ads and a one-time purchase; nothing appears before the tutorial is complete.

### Model

| Item | Description | Release |
| --- | --- | --- |
| Rewarded ad: double offline earnings | Offered on the Offline Earnings screen | P1 |
| Rewarded ad: 2× income boost | 30 minutes, stackable up to 4 hours | P1 |
| Rewarded ad: bonus crate | Fixed, disclosed cash reward | P1 |
| Remove ads / VIP | One-time purchase; boosts granted without watching ads | P1 |
| Cosmetic shop designs | Business skins and street decorations | P2 |
| Convenience bundles | Only if playtests support them | P2 |

### Constraints

- No interstitial or forced ads.
- The reward is shown before any ad starts.
- No paid random rewards.
- Core progression and leaderboard ranking stay achievable without paying; purchased boosts are capped so spending can't buy the top of a leaderboard.
- Ad frequency is validated against retention.
- All monetization can be switched off by remote config for testing.

### Performance rules for SDKs

- Ad SDKs initialize only after the tutorial, never during cold start.
- Use a single ad mediation SDK and only the networks that measurably add revenue.
- Each SDK's added download size and startup time is measured and must fit the budgets in Section 10.

## 10. Technical architecture and performance

The game's economy runs as a small, fixed-rate calculation separate from rendering, which keeps it cheap on the CPU and battery, and makes online and offline earnings identical.

### Platforms and engine

- Android first (minimum Android 8.0, API 26; `arm64-v8a` and `armeabi-v7a`; App Bundle for Google Play), iOS after soft-launch validation (minimum iOS 15). Full mobile requirements: `docs/MOBILE.md`.
- Offline-first: the game is fully playable without internet; network calls queue and retry, and never block gameplay.
- Engine: **Godot 4, GDScript only, Compatibility renderer.** Chosen because its scenes and scripts are plain text (reliable for AI-assisted development), it exports a web build for browser testing, and it has a small runtime that suits the 80 MB download budget. C# is excluded because Godot 4 can't export C# projects to the web.

### Architecture

1. **Economy layer:** pure logic with no rendering dependencies. Holds state, computes income per second, applies purchases. Unit-tested and shared with the simulation tool.
2. **Tick:** the economy updates 4 times per second on a fixed timer, independent of frame rate. Income is integrated as rate × elapsed time.
3. **Presentation layer:** reads economy state and renders. Customers are cosmetic, spawned to match the current rate; they never decide revenue.
4. **Config:** all business, upgrade, reward and cap values in data files (with remote config from soft launch).
5. **Backend (P1):** anonymous accounts, leaderboards, score validation, push notifications, purchase validation. Cloud saves are P2.

### Backend stack

| Piece | Choice | Release |
| --- | --- | --- |
| Crash reports and analytics | Firebase Crashlytics and Analytics | P0 |
| Game server | Nakama, modules in TypeScript (pinned to TypeScript 5.x) | P1 |
| Database | PostgreSQL | P1 |
| Push notifications | Firebase Cloud Messaging (HTTP v1), sent by Nakama; iOS through APNs | P1 |
| Client SDK | Official Nakama Godot SDK, wrapped by `scripts/services/backend_client.gd` | P1 |
| Hosting | One small VM in a Mumbai region running Docker Compose, HTTPS via Caddy; move to managed Nakama hosting if needed | P1 |

Server code, setup and the client API are in `server/` (see `server/README.md`).

### Rendering budget

- 60 fps target; 30 fps battery-saver mode, on by default on low-end devices and when battery is below 20%.
- Sprite atlases per location; at most ~30 draw calls on the Main City screen.
- Customers come from an object pool, capped at 6–10 visible per business.
- Off-screen objects are culled; animations pause when a full-screen panel is open.
- When the app goes to the background, rendering and the tick stop; time away is credited through offline earnings on resume.
- Asset compression: ETC2/ASTC textures on Android, ASTC on iOS.

### Performance budgets

Reference devices are named before production: one low-end Android (3 GB RAM, around 2020 chipset), one mid-range Android, and one iPhone from about four years earlier.

| Metric | Low-end reference | Mid/high-end |
| --- | --- | --- |
| Frame rate | Steady 30 fps | 60 fps |
| Cold start to playable | ≤ 5 s | ≤ 3 s |
| Memory (peak) | ≤ 300 MB | ≤ 500 MB |
| Initial download | ≤ 80 MB | ≤ 80 MB |
| Battery drain, active play | ≤ 5% per 30 min | ≤ 3% per 30 min |
| Network while playing | ≤ 1 MB per hour | ≤ 1 MB per hour |
| Save write time | ≤ 20 ms, off the main thread | ≤ 10 ms |

Later locations and content are delivered as downloadable asset packs to keep the initial download small. Performance is measured on reference devices in every build, and a regression past budget blocks release.

### Persistence

- **Saved data:** cash (big number), lifetime earnings, businesses and levels, staff, locations, achievements, milestone and rank-band flags, last-save timestamp, last offline claim, save version, economy config version.
- **When:** on every purchase or claim (debounced to once per 2 s), every 30 s, and always when the app goes to the background.
- **How:** write to a temporary file, then rename over the old save, so a crash can't corrupt it. Keep two save slots with checksums; load the newest valid one.
- **Versioning:** each save carries a version number; ordered migration steps upgrade old saves. An unreadable save falls back to the backup slot, never to a silent reset.

### Security and integrity

- Purchases validated through Google Play and the App Store (server-side once the backend exists).
- Reward and offline claims recorded before currency is granted, preventing duplicates.
- The server never trusts client-reported premium balances; leaderboard scores are plausibility-checked (Section 8).
- Analytics events are batched and sent at most once per minute or on backgrounding.

## 11. Analytics, privacy and compliance

Every event carries the parameters needed for funnel analysis, and no personal data is collected beyond what the game needs.

### Common parameters (every event)

`session_number`, `minutes_since_install`, `lifetime_earnings` (log-scaled bucket), `businesses_owned`, `location`, `device_tier`, `app_version`, `economy_config_version`.

### Events

| Group | Events | Extra parameters |
| --- | --- | --- |
| Onboarding | `game_started`, `tutorial_step`, `tutorial_completed`, `first_business_purchased` | `step_id`, `seconds_elapsed` |
| Core | `business_purchased`, `upgrade_purchased`, `employee_hired`, `business_automated`, `location_unlocked`, `offline_earnings_collected` | `business_id`, `track`, `level`, `cost`, `offline_minutes`, `doubled` |
| Retention | `session_started`, `session_ended`, `daily_objective_completed`, `achievement_unlocked` | `objective_id`, `achievement_id`, `session_seconds` |
| Leaderboards | `leaderboard_viewed`, `rank_band_reached`, `milestone_reached`, `milestone_notification_sent`, `notification_opened`, `push_permission_granted`, `push_permission_denied` | `board`, `band`, `milestone`, `channel` |
| Social | `share_clicked`, `share_completed` (where the platform confirms) | `share_type` |
| Monetization | `rewarded_ad_offered`, `rewarded_ad_started`, `rewarded_ad_completed`, `purchase_started`, `purchase_completed`, `purchase_failed` | `placement`, `product_id`, `error_code` |
| Performance | `fps_bucket_report` (every 5 min), `cold_start_time`, `save_failed`, `memory_warning` | `avg_fps`, `p5_fps`, `ms` |

### Primary KPIs

D1, D7 and D30 retention; sessions per day; session length; tutorial completion; second-business rate; offline collection rate; push opt-in and notification open rate; leaderboard view rate; revenue per daily active user; rewarded-ad engagement; crash-free sessions and ANR rate; share and invite rate.

### Privacy and compliance

- Consent is collected before analytics or ad SDKs start, where required by region.
- Compliance with GDPR and India's Digital Personal Data Protection Act; privacy policy and in-app data deletion.
- Age rating via IARC; if players under 18 may play, use child-appropriate ad settings and disable leaderboard custom names for them.
- Google Play Data safety form and Apple privacy labels kept in sync with SDKs.
- No contacts, location or advertising ID access beyond what ad SDKs require with consent.

### Accessibility and localization

- Text scales with system font size; minimum touch target 48 dp.
- Upgrade availability shown by icon and label, not color alone.
- Haptics and screen shake can be turned off.
- Strings externalized from day one; launch in English and Hindi, with lakh/crore number formatting.

## 12. Scope, acceptance, risks and roadmap

P0 is a fully offline game that hits every performance budget; the backend, leaderboards and monetization arrive together in P1 for soft launch.

### Prioritization

**P0 — first playable (no backend)**

- Main City scene with Starter Street and Market Lane.
- Five businesses (chai stall, pani puri cart, fruit stand, bakery, café).
- Rate-based economy, big numbers, config-driven tuning.
- Tap-to-serve, upgrades with bulk buy, workers and managers.
- Offline earnings with clock protection.
- Two synergies; onboarding objectives; Empire Overview.
- Robust local saves with migrations.
- Tutorial, analytics, crash and ANR reporting.
- **Economy simulation tool** (moved from P1).
- Performance budgets met on reference devices.

**P1 — soft launch**

- Light backend and anonymous accounts.
- Global and country leaderboards with milestone and rank-band notifications.
- Daily objectives, achievements, share cards.
- Rewarded ads, remove-ads / VIP purchase, remote config.
- Food truck, grocery store and salon.

**P2 — later**

- Cloud saves, friend leaderboards, city visits.
- Prestige system (if testing supports it), more locations and tiers, specialists.
- Cosmetic shop, seasonal events, streaks.

### Acceptance criteria (internal release)

1. A new player completes onboarding unaided in ≤ 3 minutes.
2. The player earns cash, upgrades, and sees income per second change by the displayed amount.
3. Managers automate businesses; automated income matches the rate formula within 1%.
4. Offline earnings equal online earnings for the same duration × offline rate, and can't be claimed twice or inflated by moving the clock backwards.
5. The player unlocks a second business and Market Lane after meeting the conditions.
6. Progress survives restarts, force-closes and a crash during save.
7. Failed purchases or saves never corrupt progress.
8. Big numbers display correctly up to at least 1e100.
9. All defined analytics events fire with their parameters.
10. Every performance budget in Section 10 is met on the reference devices.
11. Monetization can be disabled without blocking gameplay.
12. (P1) Leaderboard ranks update within 5 minutes; each milestone and rank-band notification fires exactly once; implausible scores are hidden.

### Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Gameplay becomes repetitive | Synergies, objectives, weekly leaderboards, new decisions per location |
| Progression too slow or stuck | Simulation tool, no-soft-lock rule, remote-config tuning |
| Players leave after session one | Clear 30-minute pacing, early automation, offline-earnings hook |
| Poor low-end performance | Budgets per device tier, rendering caps, battery-saver mode, regression gating |
| Large download hurts installs | 80 MB budget, asset packs for later content |
| Save corruption | Atomic writes, two slots, checksums, migrations |
| Leaderboard cheating | Server plausibility checks, quiet hiding, account requirement |
| Notifications feel spammy | 1 per day cap, opt-in after first milestone, A/B test |
| Ads harm retention | Rewarded only, frequency tested |
| Content costs grow | Modular business assets, config-driven content |

### Roadmap

| Phase | Scope | Exit criterion |
| --- | --- | --- |
| 1. Prototype | One business, tap-to-serve, upgrades, rate-based economy | Players understand the loop and enjoy the first upgrade |
| 2. MVP (P0) | Five businesses, two locations, automation, offline earnings, saves, tutorial, simulation tool | Full progression path works and meets performance budgets |
| 3. Soft launch (P1) | Backend, leaderboards, notifications, ads, daily objectives; limited Android release in India | D1 ≥ 30%, D7 ≥ 10%, crash-free ≥ 99.5% |
| 4. Expansion (P2) | New tiers and locations, social features, iOS, cloud saves | New content improves engagement without hurting retention |

### Product decisions

| Decision | Choice |
| --- | --- |
| Visual style | Stylized 2D isometric |
| Interaction | Hybrid: tap early, automate later, optional tap boosts |
| Setting | India-inspired start, internationally recognizable later businesses |
| Progression | Continuous for MVP; prestige evaluated in P2 |
| Engine | Godot 4, GDScript, Compatibility renderer |
| Backend | Nakama + TypeScript + PostgreSQL; Firebase for crash reports, analytics and push |
| Release | Android-first soft launch in India, then iOS |
| Accounts | Local saves in P0; anonymous linked accounts in P1; cloud saves in P2 |
| Monetization | None in P0; rewarded ads + remove-ads purchase in P1 |

## 13. Development workflow

The game is built with two AI coding tools working in one Git repository, with clear folder ownership so they never edit the same files.

| Area | Owner |
| --- | --- |
| Economy core, BigNumber, saves, offline earnings, simulation tool, tests, config | Claude Code |
| Backend (`server/`), service wrappers, Firebase, plugins, Android/iOS export setup | Claude Code |
| Scenes, UI screens, animation, art, web-build browser testing | Google Antigravity |
| Code review of `ui/*` branches | Claude Code |

- Shared rules live in `AGENTS.md`; each tool loads them through its own entry file.
- Mobile build details are in `docs/MOBILE.md`.
- The UI never computes money; it reads from and calls `EconomyService`.
- The `EconomyService` API is written first, so both tools can then work in parallel.
- Cross-tool change requests go in `docs/REQUESTS.md`; build-order prompts are in `docs/PROMPTS.md`.

**Product principle:** build a small but satisfying empire that runs well on every phone first. Expand the world only after players prove they want to keep building it.
