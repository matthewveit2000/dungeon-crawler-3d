# Architecture Changelog

Detailed record of engine setup, data schemas, core infrastructure, and architectural changes.  
See [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) and [`docs/DECISION_LOG.md`](../DECISION_LOG.md).

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
