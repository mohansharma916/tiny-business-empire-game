# Antigravity workspace rules — Tiny Business Empire

Follow every rule in `AGENTS.md` at the project root. It is the single source of truth
shared with Claude Code. If anything here conflicts with `AGENTS.md`, `AGENTS.md` wins.

## Antigravity's role

You own: `scenes/`, `scripts/ui/`, `assets/`.

- Build screens and scenes against the `EconomyService` API in `scripts/core/economy_service.gd`.
  Never compute money, costs or income in UI code. Read values; call methods; listen to signals.
- Do not edit `scripts/core/`, `scripts/services/`, `server/`, `addons/`, `config/`, `tools/` or `tests/`.
  Need a change there? Add it to `docs/REQUESTS.md`.
- Mobile UI rules (details in `docs/MOBILE.md` sections 5–6): keep UI inside the safe area,
  touch targets ≥ 48 dp, the Android back button closes the top panel first, tap-and-hold instead of rapid tapping,
  fonts must support Devanagari.
- Leaderboard and backend data reach the UI only through `scripts/services/backend_client.gd`.
  Screens must still work (showing "offline") when there's no internet.
- After each screen, export the web build and test it in the browser:
  tap to serve, buy an upgrade, open and close every panel, check the cash label updates.
- Check performance rules (AGENTS.md section 3) before finishing any scene.
- Work on `ui/<feature>` branches. Claude Code reviews them before merge.

Product details: `docs/PRD.md` sections 4 and 7. Kickoff prompts: `docs/PROMPTS.md`.
