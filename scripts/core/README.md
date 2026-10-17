# scripts/core — owner: Claude Code

Pure game logic. No scenes, no UI, no rendering.

Files:

| File | Purpose |
|---|---|
| `big_number.gd` | `BigNumber` (mantissa + exponent), math, comparison, formatting (K/M/B/T/aa…, lakh/crore) |
| `economy_service.gd` | Autoload. Owns economy state, income-per-second, purchases, upgrades, staff, synergies. The only API the UI may call. |
| `income_model.gd` | `IncomeModel`: pure income, cycle, milestone and pricing math (closed-form bulk buy); shared by online, offline and tools/sim |
| `game_config.gd` | `GameConfig`: reads `config/*.json` once at startup (shared with tools/sim) |
| `app_lifecycle.gd` | `AppLifecycle`: pause/resume, back button, memory warnings; EconomyService forwards notifications to it |
| `save_system.gd` | `SaveSystem`: atomic writes, two slots, checksum, versioned migrations; sets unreadable files aside |
| `save_scheduler.gd` | `SaveScheduler`: debounced purchase saves + 30 s autosave, driven by the economy tick |
| `offline_earnings.gd` | `OfflineEarnings`: same rates as online, cap, offline rate, clock-rollback protection |
| `economy_persistence.gd` | `EconomyPersistence`: save format, load, offline claim (recorded before granted) |

Rules: AGENTS.md sections 2–4.
