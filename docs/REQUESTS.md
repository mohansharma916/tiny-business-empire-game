# Cross-tool requests

When a tool needs a change in a folder it doesn't own (see `AGENTS.md` section 1),
it adds a request here instead of editing that folder. The owner picks it up,
then moves it to "Done".

## Open

| Date | From | To | Request | Status |
|---|---|---|---|---|
| | | | | |

<!-- Example:
| 2026-10-20 | Antigravity | Claude Code | Add `get_next_upgrade_effect(business_id, track)` to EconomyService so the upgrade button can show "+12% income" | Open |
-->

## Done

- 2026-10-17 — Project scaffold created.
- 2026-10-17 — Backend (Nakama + TypeScript) scaffold in `server/`, mobile guide in `docs/MOBILE.md`.
- 2026-10-17 — Installed export templates, installed and enabled GUT 9.7.1, verified Android SDK & JDK 17 paths, created and backed up upload.keystore outside repository.
- 2026-10-17 — Claude Code: Android (Gradle, arm64-v8a + armeabi-v7a, min SDK 26, portrait, INTERNET/ACCESS_NETWORK_STATE/VIBRATE only) and Web export presets; boot scene `scenes/boot.tscn` + `scripts/ui/boot.gd` (added at the human's request; Antigravity owns them from here); `scripts/core/app_lifecycle.gd` with empty hooks. Branch core/mobile-foundation.
- 2026-10-17 — Claude Code: `BigNumber` (math, compare, short + lakh/crore formatting), `GameConfig`, and the final `EconomyService` API/signals as stubs, registered as autoload; GUT tests. Branch core/contract.
- 2026-10-17 — Claude Code: rate engine for the chai stall — cached income rate, 4 Hz measured tick, four upgrade tracks (Cost(n) = base × r^n), ×1/×10/×Max closed-form bulk buy, manual tap cycles, manager automation + tap boost, workers, ×2 milestones every 25 levels; `config/economy.json` gains `starting_cash`. Branch core/rate-engine.
