# Testing & CI Changelog

Detailed record of automated test suites, validators, and CI pipelines.  
See [`docs/TESTING_STRATEGY.md`](../TESTING_STRATEGY.md) and [`docs/DECISION_LOG.md`](../DECISION_LOG.md) (`D-009`).

---

## 2026-11-19 — Live Player-POV Visual QA Harness (`D-028`) & Expanded Test Coverage (`D-029`, `D-030`)

- **Automated Live Player-POV Visual & Motion QA (`D-028`):**
  - Added `scripts/run-visual-qa.sh` and `game/src/tools/visual_qa_capture.gd` to render the live running Godot 4.7.2 game at `1280×720` via `Xvfb` + Mesa OpenGL3 and capture **11 player-POV gameplay/UI screenshots** (Entrance Sword+Shield, Mid-Swing, Shield Block, Sword+Spell, Drawn Bow, 3rd-Person, Safe Room Sanctuary, Boss Arena, Inventory Menu, Vendor Menu, Pause Menu) plus a **36-frame live combat motion video (`art/visual_qa/combat_motion.mp4`)** via `ffmpeg`.
  - Mandatory inspection of these captures caught and verified fixes for OpenGL3 light starvation, 3rd-person wall-camera clipping, oversized shield framing, mid-swing blade visibility, bow forearm clipping, top-wall ceiling seam, HUD vitals contrast, AI toast/clock separation, and Inventory value/button layout.
- **Expanded Automated Test Suite (39 Tests, 5,450 Assertions across 10 GUT Scripts):**
  - Added `game/tests/test_tutorial_and_setpieces.gd` covering `TutorialSystem` first-trigger gating, toggle on/off, dismissal, reset, save/load persistence, and handcrafted `setpieces.json` placement across generated floors.
  - Updated `scripts/validate-data.py` to validate all **9 Tier 3 JSON packs** (adding `setpieces.json` and `tutorials.json` schema & cross-reference checks).
  - Updated `scripts/validate-assets.py` to validate all **38 sculpted PBR `.glb` models** + seamless PBR texture maps (`art/textures/`) + 3 denoised Cycles studio previews (`art/previews/`).

---

## 2026-11-18 — Milestone 1 (`v0.1` Vertical Slice) Five-Layer Automated Verification Pipeline

- **Master Local & CI Runner (`scripts/run-tests.sh` & `.github/workflows/ci.yml`):**
  1. **Tier 3 Data Validator (`scripts/validate-data.py`):** Validates all 7 JSON packs, item/enemy/affix/rarity cross-references, and locked design invariants (`days_per_floor == 5`, `staircase_preview_enabled == false`, `reset_to_floor_entry_on_collapse == true`, `reset_to_floor_entry_on_death == true`).
  2. **Repo & Architecture Hygiene (`scripts/check-repo-hygiene.py`):** Verifies all universal AI entry files (`AGENTS.md`, `CLAUDE.md`, `.cursorrules`, Copilot), enforces zero unseeded RNG calls in `game/src/`, and checks every local relative Markdown link.
  3. **Blender Asset & Preview Validator (`scripts/validate-assets.py`):** Validates binary glTF headers, non-empty sizes, bounds, triangle budgets, and 1280×720 Cycles preview PNGs for all 29 `.glb` models in `art/manifest.json`.
  4. **Godot Headless Main Scene Smoke Boot:** Boots `res://scenes/main.tscn` headlessly for 20 physics frames and fails immediately if any `SCRIPT ERROR`, `Parse Error`, `Compile Error`, or `ERROR:` appears.
  5. **GUT 9.7.1 Headless Unit & 3D Gameplay Integration Suite (`game/tests/`):**
     - `test_seeded_rng.gd` — deterministic sequences, stream isolation, weighted picks.
     - `test_data_loader.gd` — pack integrity and locked design rule assertions.
     - `test_combat_math.gd` — left/right-hand rules, asymptotic armor, blocking, power attacks, bow draw scaling, Sponsored crits.
     - `test_loot_generator.gd` — rarity scaling, Sponsored affix guarantees, Skyrim equipment slot aggregation.
     - `test_progression_system.gd` — XP/Level-Up attributes/perks, Skyrim use-to-improve proficiencies, save serialization.
     - `test_floor_timer_and_snapshot.gd` — 5-day clock pause/collapse, Floor-Entry Snapshot reset, Save-and-Quit round-trip.
     - `test_dungeon_generator.gd` — **100-seed invariant sweep** proving 100% room connectivity, Entrance/Safe Room/Boss Arena/Vault/Hidden Stairs placement, and bit-exact seed determinism.
     - `test_vendor_compass_ai_console.gd` — Vendor buy/sell economy, Compass discovery/bearing math, Dungeon AI banner templates, Audit Console dispatch.
     - `test_headless_gameplay_integration.gd` — Full headless 3D `GameMain` integration suite verifying fresh boot, 1st/3rd-person toggle, menu clock freeze, Safe Room enemy repulsion, Boss Gate seal & Vault unlock, Floor Collapse + Combat Death snapshot resets, Floor 2 descent, Save-and-Quit resume, spells/archery projectiles, melee enemy kills + Skyrim skill use + corpse looting, chest/Quest Board/Vendor interaction, and every Playtest Audit Console command.
- **Hardened GUT Failure Guard:** Updated `scripts/run-tests.sh` to inspect GUT output and fail the build if any test script encounters a parse/load error or gets silently ignored by GUT.
