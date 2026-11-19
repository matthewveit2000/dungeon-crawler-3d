# Dungeon Crawler 3D

A free, open-source 3D roguelike action-RPG inspired by *Dungeon Crawler Carl*, guided by the gameplay feel of **Skyrim**.

> **Current Status:** `Pre-Production — Alignment Phase`  
> No game code or art assets have been built yet. We are aligning on roles, gameplay feel, world design, tech stack, and testing strategy before writing our first line of game code.

---

## North Star

- **Gameplay Feel:** **Skyrim** is the north star for how the game should feel—immersive 3D exploration, tactile combat, environmental discovery, and meaningful progression.
- **Floor Collapse Loop:** Each floor has a **5 in-game day** countdown (currently targeted at ~30 real-time minutes per in-game day) to push the player to explore. When the floor collapses, the game **resets to the beginning of the current floor** rather than triggering full permadeath.
- **Unknown Descent:** No staircase previews—descending to a new floor is a genuine step into the unknown.
- **Open-Source Leverage:** Built on existing free, open-source engines and libraries rather than from scratch, preserving maximum flexibility and zero proprietary lock-in.
- **100% Original Art:** All 3D models, textures, animations, and audio created in-house using Blender and other free, open-source tools.
- **Automated-Testing First:** Anything that can be tested automatically *must* be tested automatically, minimizing manual testing burden on the user.

---

## Documentation & AI Tool Compatibility

This repository is structured to work seamlessly with **any AI coding tool** (Antigravity, Claude Code, Cursor, GitHub Copilot, Codex, Jules, etc.). All tool-specific instruction files point to [`AGENTS.md`](AGENTS.md) as the single source of truth.

| Document | Purpose |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Canonical instructions for all AI agents working in this repo |
| [`CLAUDE.md`](CLAUDE.md) | Claude Code entry point (references `AGENTS.md`) |
| [`.cursorrules`](.cursorrules) | Cursor entry point (references `AGENTS.md`) |
| [`.github/copilot-instructions.md`](.github/copilot-instructions.md) | GitHub Copilot entry point (references `AGENTS.md`) |
| [`docs/VISION_AND_CONSTRAINTS.md`](docs/VISION_AND_CONSTRAINTS.md) | North star, goals, constraints, and open alignment topics |
| [`docs/ROLES_AND_GOVERNANCE.md`](docs/ROLES_AND_GOVERNANCE.md) | Division of labor, decision authority, and communication rules |
| [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md) | Permanent record of every locked-in design and technical decision |
| [`docs/ALIGNMENT_LOG.md`](docs/ALIGNMENT_LOG.md) | Q&A alignment rounds and agreed outcomes |
| [`CHANGELOG.md`](CHANGELOG.md) | Root changelog tracking every meaningful change to the repo |
| [`docs/changelogs/README.md`](docs/changelogs/README.md) | Changelog conventions for code, design, art, and documentation |

---

## Repository History & Lineage

This project succeeds two earlier 2D browser prototypes (`Dungeon-Crawler-Game-2` and `dungeon-crawler-engine`). Rather than rebuilding those 2D games, we are carrying forward their best concepts and hard-won engineering lessons into a fresh 3D project built on existing open-source engines.
