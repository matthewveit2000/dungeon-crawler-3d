# Automated Testing Strategy

> **Core Mandate (`D-009`):** Anything that can be tested automatically **MUST** be tested automatically.  
> **Goal:** The User only spends manual time evaluating *subjective gameplay feel* at playable milestones and *visual taste* on batched Blender preview renders.

---

## 1. Testing Pyramid for Godot 4 + Blender

| Layer | What Gets Tested Automatically | How It Runs |
|---|---|---|
| **1. Pure Logic & Math Unit Tests** | Damage/armor/crit formulas, inherent rarity weights & floor curves, no-duplicate loot pool, mastery ceilings, hybrid XP + use-to-improve curves, 5-day timer math, floor-entry snapshot diffing, save serialization. | Headless Godot test runner (GUT / GdUnit4) in seconds on every commit. |
| **2. Procedural Dungeon Generation & Invariants** | Run 100+ seeds per CI check: 100% room connectivity, guaranteed hidden staircase placement, guaranteed Safe Room + Boss Arena + Vault placement, zero overlapping geometry, deterministic seed reproducibility. | Headless Godot CLI test suite. |
| **3. Headless Gameplay Integration Tests** | Simulated player movement/collision, left/right-hand equipping, melee/spell/bow damage resolution, enemy AI aggro & Safe Room repulsion, Boss Arena door-seal & vault-unlock lifecycle, floor collapse & combat-death reset to floor-entry snapshot, menu time-pause freeze, save-and-quit round-trip. | Headless Godot scene simulation (no GPU required). |
| **4. Data Pack & Schema Validation** | Every JSON/Resource data file (items, rarities, enemies, floor themes, mastery, Dungeon AI lines, balance curves) validated for missing IDs, broken references, invalid ranges, and zero hardcoded magic numbers. | Automated validator script in CI. |
| **5. Blender 3D Asset Pipeline Validation** | Headless Blender export checks: valid `.glb` output, non-zero mesh bounds, expected modular snap dimensions, clean transforms (applied scale/rotation), triangle-count budgets, valid UV/material slots, and automated turntable preview render generation. | Headless Blender Python check script. |
| **6. Repo & Multi-AI Hygiene Checks** | Verify `CHANGELOG.md` updated on PRs, no broken doc links, formatting/lint rules pass, and zero engine errors/warnings during headless boot & floor load. | GitHub Actions CI workflow. |
| **7. Live Player-POV Screenshot & Motion Video QA (`D-028`, `D-036`)** | Launch the actual game in 1280×720 **Vulkan Forward+** via `xvfb-run` (Mesa lavapipe when no GPU; `RENDER=opengl3` for the fallback) with `./scripts/run-visual-qa.sh`, capture the title screen, every first-person loadout (sword/shield, swing, block, spell, bow, battleaxe), 3rd-person, staged combat with each enemy type, a corridor, the Safe Room, the Boss Arena, inventory, skills, vendor, map, pause, settings and the death screen, plus a 40-frame `ffmpeg` combat clip, and visually inspect every frame before shipping. | `./scripts/run-visual-qa.sh` (optionally `QA_ONLY=fp,menus`; `QA_OUT`/`QA_QUALITY` for quick iterations) + mandatory AI visual review. |
| **8. Presentation-Layer Tests** | Settings persistence & key rebinding, shared material library binding, every menu opening/refreshing with live data, inventory/vendor QoL actions, item comparison/sort/filter, map fog-of-war save/load, rigged characters exposing required clips & sockets, corpses keeping animated bodies, chest lids opening, quality-scaled environment, death screen. | Headless GUT (`test_settings_and_materials.gd`, `test_ui_and_visuals.gd`). |

---

## 2. CI Rules (Non-Negotiable)

- **Never Merge Red:** Every PR runs the full automated suite in GitHub Actions (headless Godot tests + data validation + hygiene checks). A failing check blocks merge.
- **Deterministic Seeds Everywhere:** All randomness uses injected seeded RNG streams so any failing test or player bug report reproduces 100% identically.
- **Tests First (Red-Green-Refactor):** Every new gameplay rule or bug fix begins with a failing automated test before the implementation or fix is written.

---

## 3. Built-In Playtest Shortcuts (For User Milestone Reviews)

When the User steps in at a playable milestone, an in-game **Debug / Audit Console** (stripped or gated in release builds) provides instant one-command shortcuts so the User never has to grind for 2 hours to test a feature:
- Teleport to Entrance, Safe Room, Boss Arena, or Hidden Staircase
- Advance the 5-day floor clock or trigger instant Floor Collapse
- Spawn specific enemies, chests, or legendary loot
- Toggle God Mode, 1st/3rd person, or jump directly to a specific seed

## Test Mode & User-Feedback Regression Guards (`D-045`, `D-047`)

- **Manual testing happens in Test Mode** (title screen → Test Mode, F1 tools; see `PLAYTEST_GUIDE.md` §1b). Every tool calls the public `GameMain.test_*` API, so anything checked by hand there can be scripted in GUT the same way.
- **Every testable User request has a regression test** named after the request and listed against its `FB-###` entry in `docs/USER_FEEDBACK_LOG.md` (e.g. `game/tests/test_feedback_fb013.gd`).

