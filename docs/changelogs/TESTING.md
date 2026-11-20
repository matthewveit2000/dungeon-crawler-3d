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

## 2026-11-19 — Presentation Test Suite & Forward+ Visual QA (`D-036`)

- Added `game/tests/test_settings_and_materials.gd` (settings defaults/set-get, rebinding conflict swap & reset, event serialisation, material library build & name binding) and `game/tests/test_ui_and_visuals.gd` (every menu opens/refreshes/closes with time-pause, unequip & sell-all-common, item comparison/sort/filter, map fog-of-war + save/load, all six characters expose required clips & weapon sockets, enemy corpses keep the animated body, chest lid opens, dungeon is dressed & lit with quality-scaled environment, death screen).
- `scripts/validate-assets.py` rewritten for the v2 library: GLB integrity, per-category triangle budgets, required animation clips, material/texture existence, item icons, setpiece/weapon references, UI kit and font licences.
- `scripts/run-visual-qa.sh` captures Vulkan Forward+ by default (Mesa lavapipe when no GPU), supports `QA_ONLY` groups and `RENDER=opengl3`; capture tool rewritten to stage title, all loadouts, third-person, each enemy, corridor, safe room, boss, every menu, death screen and a 40-frame combat clip.
- Totals: 12 test scripts, 53 tests, 5,600+ assertions — all green.

## 2026-11-19 — Visual QA Harness Iteration Support

- `visual_qa_capture.gd` honours `QA_OUT` (write captures elsewhere, leaving `art/visual_qa/` intact) and `QA_QUALITY` (graphics preset override) for fast targeted re-captures.
- The field-guide card is captured once (first-person shot) and then hidden, so later scene shots are unobstructed; the combat clip stages the draugr at its real attack range instead of inside the camera.
- `scripts/validate-assets.py` now also requires the `bar_back` UI texture.
- New tests in `test_ui_and_visuals.gd`: menus fit a 1280×720 screen (inventory columns & both tabs, pause column, settings panel), HUD labels both hands for two-handed weapons and bows, the death card hides the HUD until dismissed, and the Low preset skips dust motes instead of creating a 0-particle emitter (a real engine error the Low-quality capture exposed).
- Also: floor entry clears stale broadcasts (`GameHud.clear_transient_messages`).
- `scripts/validate-assets.py` now opens every character `.glb` and requires its clips to be exactly the character's own tracks with no `.NNN`-suffixed names; `test_each_character_plays_its_own_clips` checks the same at runtime (and that the two-handed draugr and Iron Warden use their 40-frame attack, not the player's 28-frame one). Both would have caught the shared-clip export bug.
- Totals: 12 test scripts, 59 tests, 5,724 assertions — all green.
- Showcase clips: `QA_ONLY=clips` (optionally `QA_CLIPS=bow,spell,...`) records corridor walk, bow, spell, battleaxe, third-person and boss clips to `art/visual_qa/clips/`; run with `--fixed-fps 20` so animation advances exactly one simulation step per frame.

## 2026-11-19 — Dedicated Animation Review Harness & Regression Tests (`D-037`)

- **Full Animation Review Capture Suite (`scripts/record-anim-review.sh`, `scripts/make-contact-sheet.py`, `game/scenes/anim_review.tscn`, `game/src/tools/anim_review_capture.gd`):**
  - Captures deterministic fixed-FPS MP4 video clips of all 12 animation suites (`fp_sword_shield`, `fp_battleaxe`, `fp_bow`, `fp_spell_dual`, `tp_gameplay`, `char_crawler`, `char_draugr`, `char_bone_archer`, `char_goblin_streamer`, `char_iron_warden`, `char_vendor`, `world_props`) with automatic headless Godot `--import` before capture and timestamped contact-sheet generation for frame-by-frame physics/timing audit.
- **New Automated Regression Tests (`game/tests/test_ui_and_visuals.gd`):**
  - `test_character_visual_preserves_oneshot_speed_and_crawler_clips` — verifies `crawler` exposes `attack_2h` & `bow_shoot`, `play_state()` does not stomp active one-shot `speed_scale`, and loop speed restores cleanly on finish.
  - `test_lever_handle_pivots_independently_and_beacon_exposes_crystal` — verifies `lever.glb` rotates only its `Handle` child while keeping the pedestal stationary, and `safe_beacon.glb` exposes its separate `Crystal` child.
  - `test_power_attack_charge_continuity_and_bow_sightline_alignment` — verifies releasing a charged power attack continues smoothly from the raised pose without snapping back to rest, and verifies the first-person nocked arrow aims straight along the camera sightline both at rest (`dot > 0.85`) and at full draw (`dot > 0.94`).
  - Export-time corpse ground-contact assertion inside `art/blender/dclib/char_anims.py` (`hips`, `chest`, `head` `z >= 0.04m` at final death frame).
- **Totals:** 12 test scripts, **62/62 passing tests**, **5,742 assertions** — all 5 automated layers green.


## 2026-11-20 — Floor Determinism Regression Tests (`D-039`)

- `test_d039_floor_reset_replays_identical_layout_and_loot`: layout, vendor stock, every container's loot and enemy drops match before and after a death reset.
- `test_d039_container_loot_does_not_depend_on_open_order`: a chest gives the same item whether opened first or last.
- Both confirmed failing on the pre-fix code. Suite: 64/64 tests, 5,751 assertions.
## 2026-11-20 — First-Person Viewmodel Regression Tests (`D-040`)

- `game/tests/test_fp_viewmodel.gd`: elbows never swing out ahead of the fists through every sword/axe attack; the axe edge faces forward at rest and leads the opening chop; both fists sit centred on the axe's leather wraps; the sword blade extends away from the camera at impact; spell palms face the target (idle and mid-cast); the drawn bow stands upright left of the crosshair with the arrow nocked only while drawing.
- Updated `test_power_attack_charge_continuity_and_bow_sightline_alignment`: no arrow is nocked at idle; it appears on draw and aims along the sightline.
- New iteration tool `./scripts/fp-pose-probe.sh` (`game/scenes/fp_pose_probe.tscn`): renders sampled first-person frames as [player view | side | top] strips in ~6 s.

## 2026-11-20 — Treasure Vault Access Test (`D-042`)

- `test_vault_is_walkable_after_boss_defeat`: for four seeds, enter the arena (seals), kill the boss, then physically walk from mid-arena through the vault gate to the treasure; confirmed to fail when the gate stays shut.

## 2026-11-20 — Boss Fight Playthrough & Gate Watchdog Tests (`D-043`)

- `test_real_boss_fight_opens_both_gates`: real physics and real sword swings; walk in (arena seals), kill the boss, walk back out through the boss gate, then into the vault.
- `test_gates_open_even_if_the_boss_vanishes_without_a_death_callback`: the watchdog opens both gates and drops them to collision layer 0.

## 2026-11-20 — Vast Floor Tests (`D-044`)

- `test_vast_floors.gd`: 25% of the floor outlasts the floor clock even with perfect walking x2 backtracking; landmarks sparse, reachable, boss arena single entrance; compass far-sense; only nearby decor/lights live and chunks freed after moving.
- Safe-room flee test now places its pursuer right behind the player (far enemies are frozen on vast floors).

## 2026-11-20 — FB-013 Regression Guards (`D-045`, `D-046`, `D-047`)

- `game/tests/test_feedback_fb013.gd`: rings, either-hand items, difficulty curve, enemy wandering/engagement, third-person looting, map/minimap lock, Test Mode spawning everything + separate save.

## 2026-11-20 — FB-014 Regression Guards (`D-048`)

- New `game/tests/test_feedback_fb014.gd`: wall pathing, barricade unsticking, facing while chasing, rarity tiers + save migration, first-person blades edge-on (sword, axe, dual), third-person dual-wield / spells / bow clips and aim camera.
- `test_menus_fit_a_720p_screen` now fills the bag with every item ×6 and checks the inventory at 1280×720 and at 150 % interface scale (853×480) — it failed before the fix.

## 2026-11-20 — FB-015 Regression Guards (`D-049`)

- New `game/tests/test_feedback_fb015.gd` (15 tests): all-Common varied loot, unique mastery tracks, mastery levels/stats/unlocks, in-game mastery XP, shock chaining, fire detonation, lunge + cross guard, bow bullet time, bleeding, enemy level ranges/floor bands, level scaling + deterministic levels, enemy traits, bestiary tiers + persistence through floor reset and save/load, Bestiary tab, item-card mastery with hidden abilities.
