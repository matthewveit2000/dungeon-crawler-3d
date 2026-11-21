# AGENTS.md — Universal AI Agent Handbook

This file is the **single source of truth** for any AI agent or coding assistant (Antigravity, Claude Code, Cursor, GitHub Copilot, OpenAI Codex, Jules, etc.) working on `dungeon-crawler-3d`.

Read this file and the linked documents in `docs/` before taking any action.

---

## 1. Project Identity & North Star

- **What we are building:** A completely free, open-source 3D dark-fantasy action-RPG dungeon crawler: a grim, ancient dungeon full of goofy monsters and darkly funny themes (no TV-show / sponsor framing — `D-057`).
- **Gameplay North Star:** **The game must feel like Skyrim.** Every major gameplay, camera, pacing, exploration, and combat decision is evaluated against this north star.
- **Core Loop Rules (Locked In):**
  - **Floor Collapse Timer:** 5 in-game days per floor (~30 real-time minutes per in-game day for now; data-driven/configurable) to compel exploration.
  - **Collapse Consequence:** Reset to the **beginning of the current floor** (no full-run permadeath).
  - **No Staircase Previews:** Descending to a new floor does not preview what is below.
  - **One Fixed Seed (`D-039`):** Every playthrough uses the same seed; a floor's layout, enemies, vendor stock and loot are identical on every attempt, so dying or a collapse replays the same floor.
  - **Vast Floors (`D-044`):** Each floor is a **vast** labyrinth (336×336 tiles ≈ 1.3 km square, ~650 rooms, ~430,000 m² walkable) sized so a player **cannot realistically explore even 25% of it in one 5-day run**: a quarter of the tiles takes ~85 min of perfect, never-backtracking walking, ~2.8 h with normal maze backtracking, versus a 2.5 h floor clock, before any fighting or looting. Stairwells (3), the boss arena + vault and safe rooms (9) are spread far apart but always reachable, and the compass only shows safe rooms within range and landmarks revealed at safe rooms (`D-060`). Keep this rule when changing world size, timers or movement speed.
  - **Core Gimmick — The Power-Scaling Race (`D-038`):** Each floor ramps up in difficulty; the central challenge is whether the player can level up and gear up enough to survive the end of every floor without falling behind. Players can always reset their progress to the start of any floor they have reached.
  - **Blades Face Away From the Player (`D-048`, standing User rule):** In first person every blade (sword, axe, dual-wield, cleaver) is seen edge-on at rest and while sprinting, its cutting edge pointing away from the eye — never the flat of a blade turned sideways. Guarded by `test_blades_face_away_from_the_player_at_rest`.
  - **Discovery & Mastery (`D-049`):** The game must feel like constant discovery. Loot is a large variety of distinct items (all **Common** for now; higher rarities come later as truly different, more powerful items — never bigger numbers on the same item). Every gear item has its own **mastery track**: it levels with use, grows stronger and unlocks item-specific abilities (shown as "???" until discovered). Every enemy type is unique, has its own **level range**, and floors introduce new types; the **Bestiary** records what the player has learned. New content should extend these lists, not replace them.
  - **Maximum Flexibility & Unified Entity Stats (`D-051`, `D-052`):** Continuously building unique spells, enemies, weapons, summons, and arenas is a core pillar of the game. Keep systems maximally modular and data-driven, and give all living entities a shared, extensible stat & resistance sheet (`knockback_res`, `poison_res`, `fire_res`, `paralysis_res`, `mana`/`magicka`, `stamina`, `armor`, `power_tier`, etc.) so abilities resolve cleanly without hardcoded exceptions. Enemies also upgrade their unique abilities as they level up. Planned & brainstormed content lives in [`docs/CONTENT_CATALOG.md`](docs/CONTENT_CATALOG.md).
- **Build Philosophy:**
  - Leverage existing **free, open-source** engines and libraries rather than building engine plumbing from scratch, while preserving maximum flexibility and freedom.
  - **100% original in-house art** created by us using **Blender** and other free, open-source tools. No third-party asset packs.
  - **Automated-Testing First:** Anything that can be tested automatically *must* be tested automatically to minimize manual testing for the user.

See [`docs/VISION_AND_CONSTRAINTS.md`](docs/VISION_AND_CONSTRAINTS.md) and [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md) for full details.

---

## 2. Current Phase

- **Phase:** `Active Development — Milestone 1 (v0.1 Vertical Slice)`
- **Pre-Production Alignment:** Completed (`Rounds 0–5`, Decisions `D-001` through `D-027`).
- **Workflow (`D-050`, `D-056`, `D-058`, standing User rules):** Work **directly on `main`** — no feature branches or pull requests. If a session or tool starts on a branch, **always merge the finished, tested work into `main` and push it automatically** — keep a separate branch only when the User explicitly asks for one (`D-058`). **Give every command sequence in ONE code block, one command per line, paste-ready for PowerShell (no `&&`) (`D-059`).** Keep good notes so any change can be backtracked: small, well-described commits; run the full test suite before every push; log every change in `CHANGELOG.md` and the domain changelogs; and add a `docs/WORK_LOG.md` entry with the commit SHA(s) and how to undo it (`git revert <sha>`). Never force-push or rewrite `main`'s history. **Always end every response after an edit with the exact copy-paste git command for the User to sync their local folder with GitHub** (to `main`, or to the specific branch if a branch is used).

---

## 3. Roles & Division of Labor

> **Status:** `LOCKED (Aligned in Round 1)` — Full rules in [`docs/ROLES_AND_GOVERNANCE.md`](docs/ROLES_AND_GOVERNANCE.md).

- **User = Product Owner & Creative Director:** Owns vision, feel, fun, art taste, scope approvals, and milestone PR sign-off.
- **AI = Full Technical Lead, Engineer & Technical Artist:** Owns all architecture, code cleanliness/organization, libraries, automated testing, CI, documentation/changelogs, minor balance tuning (logged), and Blender 3D asset execution.
- **Ask First ONLY For:** (1) Core gameplay feel / Skyrim north star changes, (2) Art style direction & batched 3D preview approvals, (3) Major scope changes, (4) Major irreversible tech/platform choices.
- **Workflow & Communication:** Plain-English, jargon-free updates with proactive push-back authority. Commit and push directly to `main` (`D-050`), keep CI green, keep `docs/WORK_LOG.md` up to date so every change can be traced and reverted, and **always include the local GitHub sync command** (`D-056`) after any edit. Only request manual playtesting at meaningful playable milestones and visual review via batched Blender preview renders.

---

## 4. Non-Negotiable Documentation & Changelog Rules

Because this repository must be seamlessly usable by **any AI tool** across sessions:

1. **Log Every Decision:** Any new gameplay, architectural, tooling, or governance decision MUST be added to [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md) with a unique ID (`D-XXX`), date, decision, and rationale.
2. **Maintain Changelogs for Everything:** Every meaningful change (documentation, design decisions, code, tests, art assets, tooling) MUST be recorded in [`CHANGELOG.md`](CHANGELOG.md) and, when applicable, the corresponding domain changelog under [`docs/changelogs/`](docs/changelogs/README.md).
3. **Keep Tool Entry Points Synchronized:** Never duplicate detailed rules in `CLAUDE.md`, `.cursorrules`, or `.github/copilot-instructions.md`. Update `AGENTS.md` and `docs/` so every AI tool reads the exact same truth.
4. **Never Leave Stale Docs:** If a change alters architecture, controls, systems, or status, update the affected docs in the same commit.
5. **Log Every User Comment (`D-045`):** Every comment, request, bug report or direction from the User MUST be appended to [`docs/USER_FEEDBACK_LOG.md`](docs/USER_FEEDBACK_LOG.md) (next `FB-###`, verbatim wording, one line per distinct request with status, decision id and regression guard) **before** acting on it. Before changing any system, search that log for it and keep every earlier request satisfied; add an automated regression test for each testable request so it cannot silently break again.

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
- **Test Mode & Feedback Guards (`D-045`, `D-047`):** Use Test Mode (title screen, F1 tools; `GameMain.test_*` API in scripts) to reproduce and verify gameplay changes, and add a regression test for every testable User request in `docs/USER_FEEDBACK_LOG.md`.
- **Hybrid World & Low-Friction Tutorial Standards (`D-029`, `D-030`):** Rooms and encounters combine procedural layouts with handcrafted signature setpieces/boss arenas; every new mechanic must integrate with the toggleable, non-intrusive first-time Tutorial Mode.

---

## 6. Essential Reading Order for New AI Sessions

1. `AGENTS.md` (this file)
2. `docs/USER_FEEDBACK_LOG.md` (every User request so far — never regress one)
3. `docs/ROLES_AND_GOVERNANCE.md`
4. `docs/VISION_AND_CONSTRAINTS.md`
5. `docs/GAME_DESIGN.md`
6. `docs/IDEAS_BACKLOG.md` (Future Ideas Vault — capture raw User "word-vomit" ideas here with `IDEA-###` per `D-053`; do not implement until asked)
7. `docs/CONTENT_CATALOG.md` (planned & brainstormed enemies, magic tomes, items, abilities, themes, companions, arenas, unified entity stats)
8. `docs/ARCHITECTURE.md`
9. `docs/ART_PIPELINE.md`
10. `docs/TESTING_STRATEGY.md`
11. `docs/PLAYTEST_GUIDE.md`
12. `docs/ROADMAP.md`
13. `docs/DECISION_LOG.md`
14. `docs/ALIGNMENT_LOG.md`
15. `CHANGELOG.md` and `docs/changelogs/`
