# AGENTS.md — Universal AI Agent Handbook

This file is the **single source of truth** for any AI agent or coding assistant (Antigravity, Claude Code, Cursor, GitHub Copilot, OpenAI Codex, Jules, etc.) working on `dungeon-crawler-3d`.

Read this file and the linked documents in `docs/` before taking any action.

---

## 1. Project Identity & North Star

- **What we are building:** A completely free, open-source 3D action-RPG dungeon crawler inspired by *Dungeon Crawler Carl*.
- **Gameplay North Star:** **The game must feel like Skyrim.** Every major gameplay, camera, pacing, exploration, and combat decision is evaluated against this north star.
- **Core Loop Rules (Locked In):**
  - **Floor Collapse Timer:** 5 in-game days per floor (~30 real-time minutes per in-game day for now; data-driven/configurable) to compel exploration.
  - **Collapse Consequence:** Reset to the **beginning of the current floor** (no full-run permadeath).
  - **No Staircase Previews:** Descending to a new floor does not preview what is below.
  - **One Fixed Seed (`D-039`):** Every playthrough uses the same seed; a floor's layout, enemies, vendor stock and loot are identical on every attempt, so dying or a collapse replays the same floor.
  - **Vast Floors (`D-044`):** Each floor is a **vast** labyrinth (336×336 tiles ≈ 1.3 km square, ~650 rooms, ~430,000 m² walkable) sized so a player **cannot realistically explore even 25% of it in one 5-day run**: a quarter of the tiles takes ~85 min of perfect, never-backtracking walking, ~2.8 h with normal maze backtracking, versus a 2.5 h floor clock, before any fighting or looting. Stairwells (3), the boss arena + vault and safe rooms (9) are spread far apart but always reachable, and the compass always hints toward the nearest undiscovered stairwell and the boss gate. Keep this rule when changing world size, timers or movement speed.
  - **Core Gimmick — The Power-Scaling Race (`D-038`):** Each floor ramps up in difficulty; the central challenge is whether the player can level up and gear up enough to survive the end of every floor without falling behind. Players can always reset their progress to the start of any floor they have reached.
- **Build Philosophy:**
  - Leverage existing **free, open-source** engines and libraries rather than building engine plumbing from scratch, while preserving maximum flexibility and freedom.
  - **100% original in-house art** created by us using **Blender** and other free, open-source tools. No third-party asset packs.
  - **Automated-Testing First:** Anything that can be tested automatically *must* be tested automatically to minimize manual testing for the user.

See [`docs/VISION_AND_CONSTRAINTS.md`](docs/VISION_AND_CONSTRAINTS.md) and [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md) for full details.

---

## 2. Current Phase

- **Phase:** `Active Development — Milestone 1 (v0.1 Vertical Slice)`
- **Pre-Production Alignment:** Completed (`Rounds 0–5`, Decisions `D-001` through `D-027`).
- **Workflow:** Build on feature branches, maintain green automated tests and CI, log every change in `CHANGELOG.md` and domain changelogs, and open PRs for User approval before merging to `main`.

---

## 3. Roles & Division of Labor

> **Status:** `LOCKED (Aligned in Round 1)` — Full rules in [`docs/ROLES_AND_GOVERNANCE.md`](docs/ROLES_AND_GOVERNANCE.md).

- **User = Product Owner & Creative Director:** Owns vision, feel, fun, art taste, scope approvals, and milestone PR sign-off.
- **AI = Full Technical Lead, Engineer & Technical Artist:** Owns all architecture, code cleanliness/organization, libraries, automated testing, CI, documentation/changelogs, minor balance tuning (logged), and Blender 3D asset execution.
- **Ask First ONLY For:** (1) Core gameplay feel / Skyrim north star changes, (2) Art style direction & batched 3D preview approvals, (3) Major scope changes, (4) Major irreversible tech/platform choices.
- **Workflow & Communication:** Plain-English, jargon-free updates with proactive push-back authority. Once implementation starts, work on feature branches, open one PR per milestone/phase, keep CI green, and wait for User approval before merging. Only request manual playtesting at meaningful playable milestones and visual review via batched Blender preview renders.

---

## 4. Non-Negotiable Documentation & Changelog Rules

Because this repository must be seamlessly usable by **any AI tool** across sessions:

1. **Log Every Decision:** Any new gameplay, architectural, tooling, or governance decision MUST be added to [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md) with a unique ID (`D-XXX`), date, decision, and rationale.
2. **Maintain Changelogs for Everything:** Every meaningful change (documentation, design decisions, code, tests, art assets, tooling) MUST be recorded in [`CHANGELOG.md`](CHANGELOG.md) and, when applicable, the corresponding domain changelog under [`docs/changelogs/`](docs/changelogs/README.md).
3. **Keep Tool Entry Points Synchronized:** Never duplicate detailed rules in `CLAUDE.md`, `.cursorrules`, or `.github/copilot-instructions.md`. Update `AGENTS.md` and `docs/` so every AI tool reads the exact same truth.
4. **Never Leave Stale Docs:** If a change alters architecture, controls, systems, or status, update the affected docs in the same commit/PR.

---

## 5. Testing & Mandatory Player-POV Visual QA Mandate

- **Automated Verification (`D-009`):** Every feature, system, data schema, and art-export pipeline step that can be verified automatically MUST have automated tests. Tests must be fast, deterministic (seeded randomness), and green in CI before declaring work complete.
- **Mandatory Player-POV Visual & Motion Inspection (`D-028` — NON-NEGOTIABLE):** Passing unit tests is NOT enough for visual polish. Whenever you touch 3D assets, lighting, materials, camera framing, first-person hands/weapons/shields, animations, HUD, or menus, you **MUST** run `./scripts/run-visual-qa.sh` to capture **actual in-game screenshots AND motion video** of the running 3D game, open and inspect every screenshot and motion sequence with your own eyes, and **put yourself in the shoes of a real player**! Critically check:
  - Does anything block the player's sightline (e.g., shield or weapon hogging the screen)?
  - Do lighting, stonework, props, and atmosphere look rich, handcrafted, and Skyrim-worthy?
  - Do swing/block/draw/cast/walk/enemy animations feel fluid, weighty, and expressive rather than stiff or robotic?
  - Are HUD elements, menus, typography, spacing, and tutorials clean, stylish, readable, and high-QoL?
  - Never ship a visual change you haven't personally scrutinized from the player's seat.
- **Visual Overhaul v2 Standards (`D-031`–`D-036`):** New art must come from the procedural pipeline (`art/pipeline/` for textures & UI art, `art/blender/dclib` for models) and use material names defined in `game/data/materials.json` (never embed images in `.glb`). Characters must ship the standard animation clips. UI must be built with `UiTheme` helpers. `./scripts/run-visual-qa.sh` captures the Vulkan Forward+ renderer by default (`RENDER=opengl3` for the fallback, `QA_ONLY=...` for subsets). See [`docs/ART_PIPELINE.md`](docs/ART_PIPELINE.md).
- **Hybrid World & Low-Friction Tutorial Standards (`D-029`, `D-030`):** Rooms and encounters combine procedural layouts with handcrafted signature setpieces/boss arenas; every new mechanic must integrate with the toggleable, non-intrusive first-time Tutorial Mode.

---

## 6. Essential Reading Order for New AI Sessions

1. `AGENTS.md` (this file)
2. `docs/ROLES_AND_GOVERNANCE.md`
3. `docs/VISION_AND_CONSTRAINTS.md`
4. `docs/GAME_DESIGN.md`
5. `docs/ARCHITECTURE.md`
6. `docs/ART_PIPELINE.md`
7. `docs/TESTING_STRATEGY.md`
8. `docs/PLAYTEST_GUIDE.md`
9. `docs/ROADMAP.md`
10. `docs/DECISION_LOG.md`
11. `docs/ALIGNMENT_LOG.md`
12. `CHANGELOG.md` and `docs/changelogs/`
