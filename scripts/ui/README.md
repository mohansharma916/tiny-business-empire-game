# scripts/ui — owner: Antigravity

Scripts attached to scenes in `scenes/`.

- Read values from `EconomyService` and listen to its signals. Never compute money here.
- Cache node references in `_ready()`. No allocations or node lookups in `_process()`.
- Update cash and income labels at most 4 times per second.

Rules: AGENTS.md sections 2–3.
