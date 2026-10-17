# config — owner: Claude Code

Every tunable game number lives here. No magic numbers in code.

| File | Contents |
|---|---|
| `economy.json` | Tick rate, offline cap and rate, milestone multipliers, save timings, UI limits |
| `businesses.json` | The five MVP businesses: costs, revenue, cycle time, capacity, demand, staff costs |
| `upgrades.json` | Upgrade tracks: cost growth and per-level effects; staff rules |
| `synergies.json` | The two MVP synergies |
| `locations.json` | Starter Street and Market Lane, with unlock rules |
| `backend.json` | Backend address, server key, score-submit interval, retry backoff (P1; `enabled: false` in P0) |

All values are starting points. Tune them with `tools/sim` before playtests.
Bump `config_version` in `economy.json` whenever a change affects saved games.
