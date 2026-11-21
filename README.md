# Dungeon Crawler 3D

A free, open-source 3D dark-fantasy roguelike action-RPG — a grim dungeon full of goofy monsters — guided by the gameplay feel of **Skyrim**.

> **Current Status:** `Active Development — Milestone 1 (v0.1 Vertical Slice)`  
> Pre-production alignment (`D-001`–`D-027`) is locked. Active development proceeds on feature branches with automated testing and Pull Request sign-off.

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
| [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) | Complete Game Design Document (Skyrim feel + DCC loop) |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Three-tier Godot 4 + JSON + Blender architecture & scene tree |
| [`docs/ART_PIPELINE.md`](docs/ART_PIPELINE.md) | Procedural Blender + NumPy art pipeline, material library & asset inventory (63 models) |
| [`docs/PLAYTEST_GUIDE.md`](docs/PLAYTEST_GUIDE.md) | Plain-English launch, Skyrim controls, playtest tour & Audit Console |
| [`docs/TESTING_STRATEGY.md`](docs/TESTING_STRATEGY.md) | Automated testing architecture for Godot 4, Blender, and CI |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Phased milestone roadmap (`v0.1` Vertical Slice → `v1.0`) |
| [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md) | Permanent record of every locked-in design and technical decision |
| [`docs/ALIGNMENT_LOG.md`](docs/ALIGNMENT_LOG.md) | Q&A alignment rounds and agreed outcomes |
| [`CHANGELOG.md`](CHANGELOG.md) | Root changelog tracking every meaningful change to the repo |
| [`docs/changelogs/README.md`](docs/changelogs/README.md) | Domain changelogs for design, architecture, art, and testing |

---

## Quick Start (Play & Automated Tests)

- **Play the Game:** Open `game/project.godot` in **Godot 4.7.2-stable** and press **F5** — the title screen opens (Continue / New Expedition / Settings). See [`docs/PLAYTEST_GUIDE.md`](docs/PLAYTEST_GUIDE.md) for controls & built-in `` ` `` Playtest Console shortcuts. A Vulkan-capable GPU gives the full Forward+ look; graphics presets are in Settings.
- **Run All Automated Checks Locally:**
  ```bash
  ./scripts/setup-tools.sh --godot-only
  ./scripts/run-tests.sh
  ```
- **Regenerate All Art (textures, UI kit, 63 `.glb` models, icons & preview sheets):**
  ```bash
  ./scripts/setup-tools.sh
  python3 art/pipeline/generate_textures.py --vfx && python3 art/pipeline/generate_textures.py --preview
  python3 art/pipeline/generate_ui.py
  ./.tools/bin/blender --background --python art/blender/build_all.py -- --full
  ```

---

## Repository History & Lineage

This project succeeds two earlier 2D browser prototypes (`Dungeon-Crawler-Game-2` and `dungeon-crawler-engine`). Rather than rebuilding those 2D games, we are carrying forward their best concepts and hard-won engineering lessons into a fresh 3D project built on existing open-source engines.
