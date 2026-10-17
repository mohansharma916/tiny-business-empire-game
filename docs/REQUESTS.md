# Cross-tool requests

When a tool needs a change in a folder it doesn't own (see `AGENTS.md` section 1),
it adds a request here instead of editing that folder. The owner picks it up,
then moves it to "Done".

## Open

| Date | From | To | Request | Status |
|---|---|---|---|---|
| 2026-10-17 | Claude Code | Antigravity | The `ui/*` branches carry their own `scripts/core/big_number.gd` and `economy_service.gd`; drop them and use the core/* versions. API differences: `buy_upgrade(id, track, amount)` takes 1, 10 or `EconomyService.BULK_MAX` and returns levels bought; `get_upgrade_cost(id, track, amount)` replaces `get_upgrade_levels_to_buy`; `BigNumber.subtract/multiply/compare` replace `sub/mul_bn/compare_to`; business state keys are listed above `get_business_state()`. | Open |
| 2026-10-17 | Claude Code | Antigravity | Offline screen: listen to `EconomyService.offline_earnings_available(summary)`, read `get_pending_offline_earnings()`, call `claim_offline_earnings()` (no ad param until P1). Never write `EconomyService.cash` directly (`scripts/ui/main_city.gd` ~line 160 does). | Open |
| 2026-10-17 | Claude Code | Antigravity | Optional: handle Back and memory warnings via `EconomyService.lifecycle.back_requested` / `memory_warning` instead of per-scene `_notification`, so only one place decides. | Open |

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
- 2026-10-17 — Claude Code: saves (atomic temp+rename, two checksummed slots, save_version + ordered migrations, debounced/30 s/background saving) and offline earnings (same rates, 2 h cap, 50%, claim saved before granted, clock-rollback re-anchor), wired into AppLifecycle. Worst save 0.8 ms on desktop. Branch core/saves.
- 2026-10-17 — Claude Code: `tools/sim` pacing simulator (real EconomyService, greedy best-value player); `buy_business` for Starter Street plus `get_business_cost`/`can_unlock_business`/`get_staff_cost`; quality made additive; config retuned so all 30-minute milestones are within ±12% and no-soft-lock holds. Branch core/sim.
- 2026-10-17 — Claude Code: all five MVP businesses, workers/managers on any business, both synergies (`synergy_activated` signal) and the Market Lane auto-unlock from config; unlocked locations saved (save_version 2 + migration); `get_location_progress`, `get_active_synergies`, `get_business_level` for the UI. Sim now runs through the café. On main.
