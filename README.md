# Tiny Business Empire

A 2D isometric idle tycoon for Android (first) and iOS: turn a chai stall into a business empire.
Built with Godot 4 (GDScript), using two AI tools: **Claude Code** and **Google Antigravity**.
Backend (from soft launch): Nakama + TypeScript + PostgreSQL, with Firebase for crash reports, analytics and push.

## Where to start

| File | What it is |
|---|---|
| `docs/PRD.md` | What we're building (product requirements, v2.0) |
| `AGENTS.md` | How we build it: shared rules for both AI tools |
| `CLAUDE.md` | Claude Code's entry point (loads `AGENTS.md`) |
| `.agent/rules/project-rules.md` | Antigravity's workspace rules (points to `AGENTS.md`) |
| `docs/PROMPTS.md` | Kickoff prompts for each tool, in build order (Step 0 → Step 10) |
| `docs/MOBILE.md` | Android/iOS setup, plugins, permissions, lifecycle, store release checklist |
| `server/README.md` | Backend: local setup, leaderboards, client API, push, deployment |
| `docs/REQUESTS.md` | Cross-tool change requests and the "Done" log |
| `config/` | Every tunable game number (businesses, upgrades, economy) |

## Folder ownership

```
tiny-business-empire/
├── AGENTS.md              shared rules
├── CLAUDE.md              Claude Code entry point
├── .agent/rules/          Antigravity rules
├── docs/                  PRD, prompts, requests
├── config/                tunable numbers (JSON)
├── scripts/core/          Claude Code — economy, BigNumber, saves (no UI)
├── scripts/services/      Claude Code — analytics, backend client
├── scripts/ui/            Antigravity — UI scripts
├── scenes/                Antigravity — city, screens, panels
├── assets/                Antigravity — sprites, fonts, audio
├── tools/sim/             Claude Code — economy simulator
├── tests/                 Claude Code — GUT unit tests
├── addons/                Claude Code — Godot plugins (created when installing GUT, SDKs)
└── server/                Claude Code — Nakama backend in TypeScript (P1)
```

## One-time setup

1. **Install Godot 4** (latest stable, standard version — not .NET).
2. **Open this folder in Godot** (Import → select `project.godot`). Godot creates its `.godot/` cache.
3. **Install GUT** (Godot Unit Test): AssetLib tab → search "GUT" → install into `addons/gut/`,
   then enable it in Project → Project Settings → Plugins.
4. **Create a Git repo** and push to GitHub:
   ```bash
   git init
   git add .
   git commit -m "Project scaffold"
   git branch -M main
   git remote add origin <your-repo-url>
   git push -u origin main
   ```
5. **Export templates:** Editor → Manage Export Templates → download (needed for Android and Web).
6. **Android:** follow `docs/MOBILE.md` section 2 (Android Studio, JDK 17, export preset, upload keystore).
   Keep the keystore backed up somewhere safe outside this folder.
7. **Claude Code:** open a terminal in this folder and run `claude`. It reads `CLAUDE.md` automatically.
8. **Antigravity:** open this folder as the workspace. If the rules in `.agent/rules/` aren't
   picked up automatically, add `project-rules.md` as a workspace rule in Antigravity's settings.
9. **Start building:** paste Step 0 from `docs/PROMPTS.md` into Claude Code.

Backend setup (Node.js, Docker, Firebase) waits until P1; see `server/README.md`.

## Run tests

```bash
# Game logic
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Backend (P1)
cd server && npm install && npm test
```

## Release phases

| Phase | What ships | Guide |
|---|---|---|
| P0 — first playable | Fully offline game, crash reports, analytics | `docs/PROMPTS.md` Steps 0–7 |
| P1 — soft launch (Android, India) | Backend, leaderboards, notifications, rewarded ads | Steps 8–10, `server/README.md` |
| P2 — expansion | iOS, cloud saves, more content | `docs/PRD.md` section 12 |

## Branches

- `main` — always runs.
- `core/<feature>` — Claude Code's work.
- `ui/<feature>` — Antigravity's work; reviewed by Claude Code before merge.
