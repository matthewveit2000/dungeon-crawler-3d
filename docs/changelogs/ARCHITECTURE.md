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

