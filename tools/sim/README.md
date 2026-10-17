# tools/sim — owner: Claude Code

Headless economy simulator (P0). It drives the real `EconomyService` and `IncomeModel`,
so it can never drift from the game's formulas.

```bash
godot --headless -s res://tools/sim/run_sim.gd                  # pacing report
godot --headless -s res://tools/sim/run_sim.gd -- --log         # plus every purchase
godot --headless -s res://tools/sim/run_sim.gd -- --config=/abs/path/to/config_dir
```

Exit code 1 means an economy-driven milestone is outside the tolerance or the
no-soft-lock rule broke. Run it after every change to `config/`.

## Player model (`sim_settings.json`)

- One finger on the best manual business, serving only `active_fraction` of each
  `attention_period_seconds`, re-tapping `retap_delay_seconds` after a cycle ends.
- Buys the option with the lowest *wait until affordable + payback time*
  (cost ÷ extra income/s) among upgrades (×1), workers, managers and businesses.
- Never taps automated businesses for the boost.

## What it checks

- Milestone times against the PRD section 4 table (±`tolerance`). "First sale" is
  reported but not gated: it depends on tutorial UI timing, not the economy.
  "Tutorial complete" and "offline prompt" are UI events and aren't simulated.
- No-soft-lock: the longest wait to afford the cheapest option on current income
  (passive income once something is automated, tapping income before that) must
  stay under `config/economy.json` → `no_soft_lock_max_seconds`.

- Full progression through the café (Market Lane, both synergies) as an untargeted
  timeline; the run stops once every business is owned and every synergy is active.
