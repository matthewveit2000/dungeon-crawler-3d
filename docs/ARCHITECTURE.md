# System Architecture

> **Status:** `Active — Milestone 1 (v0.1 Vertical Slice)`  
> **Engine & Toolchain:** Godot 4.7.2-stable (MIT), GUT 9.7.1 (MIT), Blender 4.5.9 LTS (GPL, art outputs MIT/CC0 in repo), Python 3 stdlib tooling.  
> **Related Decisions:** [`D-003`](DECISION_LOG.md), [`D-004`](DECISION_LOG.md), [`D-005`](DECISION_LOG.md), [`D-009`](DECISION_LOG.md), [`D-024`](DECISION_LOG.md).

---

## 1. Three-Tiered Architecture

`dungeon-crawler-3d` enforces strict separation between engine utilities, pure gameplay rules, and tunable data so the entire game can be tested deterministically headlessly without a GPU.

| Tier | Location | Responsibility | Rules |
|---|---|---|---|
| **Tier 1 — Core Engine Glue** | `game/src/core/` | Seeded PRNG (`SeededRng`), JSON data loader (`DataLoader`), decoupled signal bus (`EventBus`), `.glb` model loader with graceful fallback + MultiMesh mesh access (`ModelLoader`), shared PBR material binding (`MaterialLibrary`), persistent player settings & key rebinding (`GameSettings` autoload), procedural audio playback (`AudioManager`). | Zero hardcoded gameplay rules or item stats. Graceful fallback if an asset or audio file is missing. |
| **Tier 2 — Pure Gameplay Rules** | `game/src/systems/` | Deterministic procedural dungeon layout (`DungeonGenerator`), Skyrim left/right-hand & armor/crit math (`CombatMath`), rarity & Sponsored/Mythic rolling (`LootGenerator`), hybrid XP + Skyrim use-to-improve (`ProgressionSystem`), 5-day floor clock (`FloorTimer`), Floor-Entry Snapshot & Save-and-Quit persistence (`SnapshotManager`), Vendor economy (`VendorSystem`), Compass projection (`CompassSystem`), Dungeon AI snark (`DungeonAiDirector`), Audit Console parser (`DebugConsole`). | Pure `RefCounted` logic driven exclusively by Tier 3 JSON dictionaries and injected `SeededRng`. No scene-tree assumptions. |
| **Tier 3 — Pure Data Packs** | `game/data/` | Validated JSON packs (`world.json`, `player.json`, `items.json`, `affixes.json`, `enemies.json`, `dungeon_ai.json`, `progression.json`, `tutorials.json`, `setpieces.json`) plus `materials.json` (shared PBR material definitions read by Blender and Godot). | All tunable numbers, spawn weights, timers, item stats, text and material parameters live here. Validated by `scripts/validate-data.py` and `scripts/validate-assets.py`. |
| **3D World & UI Presentation** | `game/src/world/`, `game/src/ui/`, `game/src/main.gd` | Batched, lit and dressed Nordic-ruin builder (`DungeonBuilder`; on vast floors (`D-044`) it streams decor per 32 m chunk around the player, draws architecture only within 170 m, and uses infinite floor/ceiling planes + merged wall colliders), Skyrim 1st/3rd-person player (`PlayerController`), rigged animated character wrapper (`CharacterVisual`), enemies & Boss (`EnemyActor`), projectiles (`GameProjectile`), interactables with lid/lever animation (`InteractableObject`), effects (`VfxFactory`), UI design system (`UiTheme`, `ItemInfo`, `MenuScreen`), HUD (`GameHud`), menus (`TitleScreen`, `PauseMenu`, `SettingsPanel`, `InventoryMenu`, `VendorMenu`, `MapMenu`, `DeathScreen`, `DebugOverlay`) and scene coordinator (`GameMain`). | Thin visual/physics adapters delegating all rules and math to Tier 2. |

---

## 2. Scene Flow & Runtime Scene Tree

`res://scenes/title.tscn` (`TitleScreen`, project main scene: live 3D backdrop + menu) → `res://scenes/main.tscn` (`GameMain`).
Quit to Title saves and returns; Continue resumes the save, New Expedition deletes it (after confirmation).

```text
Main (GameMain — game/src/main.gd)
├── DungeonBuilder (game/src/world/dungeon_builder.gd)
│   └── DungeonGeometry (WorldEnvironment, WorldColliders, chunked MultiMesh architecture, wall
│                        ArrayOccluder3D, torches + fire VFX + flickering lights, setpieces, dressing,
│                        dust/cobwebs, Boss Gate, Vault Gate, InteractableObjects, Spike Traps)
├── Enemies (EnemyActor instances, each with an animated CharacterVisual + weapon + health bar)
├── Projectiles (Node3D container for GameProjectile arrows & spells)
├── Corpses (lootable InteractableObjects holding the fallen, animated enemy bodies)
├── Player (PlayerController — game/src/world/player_controller.gd)
│   ├── HeadPivot (Camera3D + presence fill light + blade-trail mesh + left/right hand anchors
│   │              holding gloved first-person arms, weapons, bow with live string, spell VFX)
│   └── CharacterVisual "crawler" (rigged & animated 3rd-person body with weapons in hand sockets)
├── GameHud (CanvasLayer — compass w/ landmark icons, floor clock, vitals w/ damage trails, crosshair,
│            interaction prompt, hand icons, AI cards, loot toasts, area titles, boss bar, tutorial card)
├── InventoryMenu (MenuScreen — 3D portrait, equipment slots, filter/sort bag grid, comparison card,
│                  Skills & Perks tab)
├── VendorMenu (MenuScreen — stock/pack grids, comparison card, buy/sell, sell-all-common)
├── PauseMenu (MenuScreen — resume, settings, controls, tutorial, save, reset floor, quit to title/desktop)
├── MapMenu (MenuScreen — hand-inked fog-of-war map, landmarks, zoom/pan)
├── DeathScreen (CanvasLayer — death / floor-collapse title card)
└── DebugOverlay (CanvasLayer — built-in `~` Audit Console for playtesting shortcuts)

Autoloads: GameSettings (settings + key bindings, applied live), DataLoader, EventBus, AudioManager.
```

---

## 3. Determinism & Seeded Randomness

All randomness in `game/src/` MUST flow through `SeededRng` (`game/src/core/seeded_rng.gd`) using named isolated streams (`"dungeon"`, `"combat"`, `"loot"`, `"vendor"`, `"ai"`):
- Same run seed + floor number produces the exact same Nordic-ruin layout, room graph, and initial placements.
- `scripts/check-repo-hygiene.py` fails CI if any unseeded `randf()`, `randi()`, `randf_range()`, `randi_range()`, or `randomize()` call appears anywhere under `game/src/`.

---

## 4. Floor-Entry Snapshot & Save-and-Quit Lifecycle

1. **Entering Floor `N` (`enter_floor(N, capture_snapshot=true)`):**
   - Captures a deep JSON snapshot of the player's pre-floor state (character level, XP, attributes, perks, Skyrim proficiencies, gold, bag, equipped gear, and floor number).
2. **Mid-Floor Exploration & Save-and-Quit (`D-017`):**
   - Saves exact player 3D transform, vitals, inventory, remaining 5-day clock seconds, boss state, AND the preserved Floor-Entry Snapshot to `user://dungeon_crawler_save.json`.
3. **Floor Collapse (`D-007`, `D-014`) OR Combat Death (`D-018`):**
   - Restores the exact Floor-Entry Snapshot (discarding mid-floor loot/gold/XP gains while keeping everything entered the floor with), resets the 5-day clock to `Day 1`, and rebuilds the floor fresh.
4. **Hidden Staircase Descent (`D-008`):**
   - Immediately transitions to Floor `N + 1` with **zero preview** of the next floor and captures a new Floor-Entry Snapshot.

---

## 5. Architectural Guardrails (Automated)

Run `./scripts/run-tests.sh` (identical to GitHub Actions CI in `.github/workflows/ci.yml`) to verify:
1. Tier 3 JSON schema & cross-reference integrity (`scripts/validate-data.py`)
2. Multi-AI documentation links & zero unseeded RNG (`scripts/check-repo-hygiene.py`)
3. Blender `.glb` bounds, transforms & studio PNG previews (`scripts/validate-assets.py`)
4. Headless `res://scenes/main.tscn` 20-frame boot smoke check with zero script errors
5. Full GUT unit + 100-seed procedural dungeon + headless 3D gameplay integration suite + settings/material/UI/animation presentation suite
