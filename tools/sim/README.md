# tools/sim — owner: Claude Code

Headless economy simulator (P0). It uses the same `scripts/core` code as the game.

What it does:

1. Plays the economy with a simple strategy ("buy the best-value upgrade or business").
2. Prints the time each milestone is reached.
3. Compares the result with the 30-minute pacing table (PRD section 4).
4. Checks the no-soft-lock rule: something is always affordable within 5 minutes of idle income.

Run (once written):

```bash
godot --headless -s res://tools/sim/run_sim.gd
```
