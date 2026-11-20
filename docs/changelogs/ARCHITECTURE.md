# Architecture Changelog

Detailed record of engine setup, data schemas, core infrastructure, and architectural changes.  
See [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) and [`docs/DECISION_LOG.md`](../DECISION_LOG.md).

---

## 2026-11-19 — Milestone 1 (`v0.1`) Visual Overhaul, Hybrid Setpieces, Tutorial System & OpenGL3 Lighting Architecture

- **Tier 3 Data Packs Expanded (7 -> 9 Packs, `D-029`, `D-030`):**
  - Added `game/data/setpieces.json` defining handcrafted custom room layouts (`entrance_antechamber`, `safe_room_sanctuary`, `iron_warden_arena`, `gilded_treasure_vault`, `descent_stairwell`) with prop anchors, rugs, banners, runes, and lighting markers woven into the procedural dungeon graph.
  - Added `game/data/tutorials.json` defining 9 low-friction, first-interaction contextual mechanic walkthroughs (`movement_and_combat`, `safe_room_sanctuary`, `looting_and_inventory`, `boss_arena_lockdown`, `treasure_vault_reward`, `leveling_and_skills`, `archery_and_spells`, `five_day_clock`, `vendor_exchange`) plus persistence/toggle settings.
- **Tier 2 Systems (`game/src/systems/`):**
  - Added `TutorialSystem` (`game/src/systems/tutorial_system.gd`) tracking first-time mechanic triggers, toggle state (`enabled`), non-blocking card dismissal, and save-state persistence.
  - Extended `DungeonGenerator` (`game/src/systems/dungeon_generator.gd`) to assign handcrafted `setpiece_id` templates from `setpieces.json` onto matching procedural room nodes while preserving 100% seed determinism.
- **Tier 1 / 3D World & Dark-Fantasy UI (`game/src/world/`, `game/src/ui/`):**
  - Added shared dark-fantasy theme builder `UiTheme` (`game/src/ui/ui_theme.gd`) unifying obsidian/gold/rarity styling across `Hud`, `InventoryMenu`, `VendorMenu`, `PauseMenu`, and the non-blocking bottom-right `TutorialCard` widget.
  - Updated `DungeonBuilder` (`game/src/world/dungeon_builder.gd`) with handcrafted setpiece prop assembly, seamless ceiling-to-wall geometry sealing, and a **6-nearest proximity `OmniLight3D` budget manager** (`set_light_focus_target`, `update_light_budget`) paired with a soft directional fill light so OpenGL3 Compatibility renders full illumination in every room without light starvation.
  - Overhauled `PlayerController` (`game/src/world/player_controller.gd`) with compact Skyrim 1st-person viewmodel framing, alternating 2-hit melee combo arcs with blade-edge slash trails, dynamic bow draw/arrow pullback, animated arcane astrolabe casting, smooth camera bob/fov kick, and real raycast 3rd-person camera wall-collision pullback (`_update_third_person_camera`).
  - Fixed `InventoryMenu` item value display (`value` / `base_value` fallback) and equip/consumable callbacks (`equip_from_inventory`, `use_consumable`).

---

## 2026-11-18 — Milestone 1 (`v0.1` Vertical Slice) Three-Tier Godot 4 Architecture

- **Engine & Tooling (`D-003`, `D-004`, `D-024`):**
  - Scaffolded Godot `4.7.2-stable` project in `game/project.godot` with autoloads `DataLoader`, `EventBus`, and `AudioManager`.
  - Added reproducible toolchain installer `scripts/setup-tools.sh` fetching pinned Godot `4.7.2-stable`, GUT `v9.7.1`, and Blender `4.5.9 LTS`.
- **Tier 1 Core (`game/src/core/`):**
  - Implemented `SeededRng` (named isolated deterministic PRNG streams), `DataLoader`, `EventBus`, `ModelLoader` (GLTF runtime fallback + caching), and `AudioManager` (graceful missing-audio fallback).
- **Tier 2 Pure Gameplay Systems (`game/src/systems/`):**
  - Implemented 10 zero-hardcoding `RefCounted` modules: `DungeonGenerator`, `CombatMath`, `LootGenerator`, `ProgressionSystem`, `FloorTimer`, `SnapshotManager`, `VendorSystem`, `CompassSystem`, `DungeonAiDirector`, and `DebugConsole`.
- **Tier 3 Data Packs (`game/data/`):**
  - Authored 7 JSON packs (`world.json`, `player.json`, `items.json`, `affixes.json`, `enemies.json`, `dungeon_ai.json`, `progression.json`) governing all tunable values.
- **3D World, UI & Scene Coordinator (`game/src/world/`, `game/src/ui/`, `game/src/main.gd`):**
  - Wired `GameMain` (`game/scenes/main.tscn`) connecting procedural 3D Nordic-ruin builder, Skyrim 1st/3rd-person player controller, 3D enemies & Boss Arena, projectiles, interactables, HUD, Inventory, Vendor, Pause, and Audit Console overlays.
- **Architectural Guardrails:**
  - Enforced zero unseeded randomness across `game/src/` and automated relative markdown link validation via `scripts/check-repo-hygiene.py`.

## 2026-11-19 — Presentation Layer v2 (`D-031`–`D-036`)

- **New Tier 1:** `GameSettings` autoload (persistent settings in `user://settings.cfg`, live application, key rebinding with conflict swap, colour-blind filter layer, audio buses), `MaterialLibrary` (binds shared `ORMMaterial3D`s to `.glb` material names), `ModelLoader.load_mesh` for MultiMesh batching.
- **World:** `DungeonBuilder` rewritten — chunked MultiMesh architecture, doorway arches at room/corridor junctions, wall occluders (occlusion culling), torch fire VFX and light budget with quality-scaled shadows, seeded room dressing with colliders, dust motes, cobwebs, quality-scaled `build_environment()`. New `VfxFactory`, `CharacterVisual` (rigged character wrapper: cross-faded states, one-shots, bone sockets, hit flash). `EnemyActor` drives skeletal animation with impact-synced attacks and hands its body to the corpse. `InteractableObject` animates chest lids, levers and urns. `PlayerController` gained gloved first-person arms, bowstring deformation, spell VFX, blade trails, hit-stop, camera shake, settings-aware FOV/sensitivity/head-bob and an animated third-person body with weapon sockets.
- **UI:** new `UiTheme` design system, `MenuScreen` base (blurred backdrop, fades, confirm dialogs), `SettingsPanel`, `ItemInfo`, `TitleScreen` (new main scene `res://scenes/title.tscn`), `MapMenu`, `DeathScreen`; `GameHud`, `PauseMenu`, `InventoryMenu`, `VendorMenu` rewritten.
- **Data:** `game/data/materials.json`; `items.json` gains `icon`; `enemies.json` gains `visual` (character kind, weapon, hand, scale); `setpieces.json` rewritten for the new props (with colliders & fire scale).
- **Project:** occlusion culling, soft-shadow quality, MSAA/FXAA, volumetric fog volume and anisotropic filtering settings; texture import presets pinned by `scripts/configure-texture-imports.py`.

## 2026-11-19 — v2 Visual QA Polish Pass (`D-028`)

- **`PlayerController`:** first-person shield scaled to 0.62 and posed edge-on at rest / across the left of centre when blocking; new `_hand_basis(grip_dir, forearm_dir)` builds fist orientations from where the grip axis and the forearm should point (used for the bow hand, the string-hooking draw hand and the two-handed carry), replacing hand-tuned Euler angles; melee swings (forehand, backhand, overhead cleave) are now keyed fist poses sampled by `_swing_pose` (positions lerp, orientations slerp, per-segment easing) so the elbow always trails the hand and the blade leads the cut; two-handed weapons are carried diagonally (head upper-right) with the left hand on the lower haft wrap; the bow draw anchors the nock low-right in front of the face so neither the string nor the arrow passes through the lens; blade streak keeps only the last 90 ms of blade path (`TRAIL_LIFE`), so its length no longer depends on frame rate.
- **`CharacterVisual`:** additive hit flash lowered to `FLASH_ALPHA = 0.08` (linear light — enemies pulse warm instead of turning into pale silhouettes).
- **`GameHud`:** hand panels label two-handed weapons and bows as occupying both hands and show context hints (draw/cast/attack/block); vital bars draw a separate trough under the fill; idle full vitals fade to 60 % after 6 s instead of 28 % after 3 s.
- **Layouts at 1280×720:** `InventoryMenu` pack grid computes its column count from the available width, filters wrap (`HFlowContainer`) and side columns shrink, so the detail column and both tabs fit; `PauseMenu` uses a compact crest/title and moves the tutorial toggles into the status panel; `SettingsPanel` rows expand/wrap labels, narrower controls and an explicit On/Off label beside each checkbox.
- **`MapMenu`** draws on the new `map_paper.webp`; **`GameMain`** hides the HUD while the death / collapse card is visible and clears stale broadcasts on floor entry (`GameHud.clear_transient_messages`).

## 2026-11-19 — Animation Runtime, Viewmodel & Prop Motion Fixes (`D-037`)

- **`CharacterVisual` (`game/src/world/character_visual.gd`):** Isolated one-shot `speed_scale` from locomotion `play_state()` calls while an action clip is active, restoring the queued state's `speed_scale` on `_on_anim_finished()`, and ensured re-triggered identical one-shots restart cleanly.
- **`PlayerController` (`game/src/world/player_controller.gd`):** Wrapped `_walk_bob_phase` (`fmod`) with smooth figure-8 pendulum sway (eliminating backward bob-spin on stop and sharp `abs(sin)` cusps); captured live start pose (`_swing_start_pos`, `_swing_start_quat`) on melee trigger so charged power attacks cleave seamlessly from the raised pose; aligned FP bow `rest_nock_cam` with the inner arrow rest so arrows point straight down the crosshair from rest through full draw, angled the right draw forearm outward-downward so elbow geometry stays cleanly off-screen, and added taut release string twang & arrow re-nock slide; shifted FP 2H battleaxe grip up the shaft so the bearded blade stays framed through idle, cross-cleave, and overhead charge; replaced dual-wield left-hand raw Euler swings with mirrored `_hand_basis` keyframes; fixed 3rd-person `round_shield` mounting (`Y=+90°`), wired `attack_2h`, `bow_shoot`, stride-calibrated walk/run speeds, and live 3rd-person bowstring/arrow tracking.
- **`EnemyActor` (`game/src/world/enemy_actor.gd`):** Calibrated enemy walk/run playback speeds to true animation stride speeds (`4 * stride_half / clip_duration`) and added live bowstring pull & nocked arrow tracking on `bone_archer` during `shoot`.
- **`InteractableObject` & `DungeonBuilder` (`game/src/world/interactable.gd`, `game/src/world/dungeon_builder.gd`):** Animated only `Handle*` child on levers (pedestal stationary), upgraded chests to weighted hinge settle and urns to damped rock-and-settle; upgraded portcullis/vault gates to gravity-accelerated slam (`28 m/s²`) with metallic floor bounce and weighted winch raise; added smooth hover/rotation to Safe Room `Crystal*` and proximity `talk` animation trigger for `vendor_visual`.



## 2026-11-20 — World Streaming for Vast Floors (`D-044`)

- Sector-based generator (O(rooms)), Kruskal MST, BFS corridor detours around the boss/vault.
- `DungeonBuilder` chunk streaming (`STREAM_CHUNK_TILES` 8, `STREAM_RADIUS` 2): decor spawned/freed around the player; MultiMesh chunks positioned at their centre with a 170 m visibility range; infinite floor/ceiling `WorldBoundaryShape3D` planes; merged wall colliders; per-room wall-slot index. `GameMain` freezes/hides enemies beyond 70 m.

## 2026-11-20 — Test Mode & Minimap (`D-047`, `D-046`)

- `GameMain.test_*` API + `TestModePanel` (F1), `GameMain.launch_test_mode`, `TEST_SAVE_PATH`; `DungeonGenerator.generate_test_floor`; `DungeonBuilder.spawn_test_object` / `TEST_OBJECTS`; `GameMain.spawn_enemy` shared by floor spawning and Test Mode.
- `MiniMap` HUD control; `MapMenu` locked on the player (`tile_to_screen`).

## 2026-11-20 — Mastery, Enemy Levels & Bestiary (`D-049`)

- New pure systems: `MasterySystem` (item XP, levels, ability tracks, passive aggregation), `EnemyLevels` (floor bands, level rolls, level scaling), `Bestiary` (tiered knowledge, save/load).
- New data pack `game/data/mastery.json` (DataLoader `get_mastery_pack`); `items.json` gains `mastery` tracks and `drop_weight`; `enemies.json` gains `level_min/level_max`, `traits`, `lore`, `weakness`, `level_scaling`, `floor_level_band`.
- `GameMain`: `grant_item_xp`, `chain_lightning`, `_enemy_hit_player` (blocks, shield/armor mastery, enemy traits), bestiary sightings/kills, `world_time_scale` (Hunter's Focus); `EnemyActor`: levels, traits, status effects, knockback; `GameProjectile`: pierce, homing, per-item abilities, world time scale.
