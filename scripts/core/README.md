# scripts/core — owner: Claude Code

Pure game logic. No scenes, no UI, no rendering.

Planned files:

| File | Purpose |
|---|---|
| `big_number.gd` | `BigNumber` (mantissa + exponent), math, comparison, formatting (K/M/B/T/aa…, lakh/crore) |
| `economy_service.gd` | Autoload. Owns economy state, income-per-second, purchases, upgrades, staff, synergies. The only API the UI may call. |
| `game_config.gd` | `GameConfig`: reads `config/*.json` once at startup (shared with tools/sim) |
| `app_lifecycle.gd` | `AppLifecycle`: pause/resume, back button, memory warnings; EconomyService forwards notifications to it |
| `save_system.gd` | Atomic writes, two slots, checksum, versioned migrations |
| `offline_earnings.gd` | Elapsed-time calculation, cap, clock-rollback protection |

Rules: AGENTS.md sections 2–4.
