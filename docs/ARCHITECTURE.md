# System Architecture

> **Status:** `Active — Milestone 1 (v0.1 Vertical Slice)`  
> **Engine & Toolchain:** Godot 4.7.2-stable (MIT), GUT 9.7.1 (MIT), Blender 4.5.9 LTS (GPL, art outputs MIT/CC0 in repo), Python 3 stdlib tooling.  
> **Related Decisions:** [`D-003`](DECISION_LOG.md), [`D-004`](DECISION_LOG.md), [`D-005`](DECISION_LOG.md), [`D-009`](DECISION_LOG.md), [`D-024`](DECISION_LOG.md).

---

## 1. Three-Tiered Architecture

`dungeon-crawler-3d` enforces strict separation between engine utilities, pure gameplay rules, and tunable data so the entire game can be tested deterministically headlessly without a GPU.

| Tier | Location | Responsibility | Rules |
|---|---|---|---|
| **Tier 1 — Core Engine Glue** | `game/src/core/` | Seeded PRNG (`SeededRng`), modular JSON data loader supporting single files and sorted subfolder overlays (`DataLoader`), decoupled signal bus (`EventBus`), `.glb` model loader with graceful fallback + MultiMesh mesh access (`ModelLoader`), shared PBR material binding (`MaterialLibrary`), persistent player settings & key rebinding (`GameSettings` autoload), procedural audio playback (`AudioManager`). | Zero hardcoded gameplay rules or item stats. Graceful fallback if an asset or audio file is missing. |
| **Tier 2 — Pure Gameplay Rules** | `game/src/systems/`, `game/src/systems/ai/` | Deterministic procedural dungeon layout (`DungeonGenerator`), unified entity stat & resistance sheet (`EntityStats`), shared status runner (`StatusComponent`), composable active-ability executor (`AbilityExecutor`), combat orchestration (`CombatResolver`), Skyrim left/right-hand & armor/crit math (`CombatMath`), unified rarity & scarcity table (`RarityTable`), first-class floor theme resolver (`FloorTheme`), item mastery (`MasterySystem`), enemy levels & ability tier scaling (`EnemyLevels`, `AbilityScaling`), pluggable AI modules (`ActorLocomotion`, `ActorBrain` incl. Utility-Scoring AI), loot rolling (`LootGenerator`), hybrid XP + Skyrim use-to-improve (`ProgressionSystem`), Bestiary (`Bestiary`), 5-day floor clock (`FloorTimer`), Floor-Entry Snapshot & Save-and-Quit persistence (`SnapshotManager`), Vendor economy (`VendorSystem`), Compass projection (`CompassSystem`), Dungeon AI snark (`DungeonAiDirector`), Audit Console parser (`DebugConsole`). | Pure `RefCounted` logic driven exclusively by Tier 3 JSON dictionaries and injected `SeededRng`. No scene-tree assumptions. |
| **Tier 3 — Pure Data Packs** | `game/data/` | Validated JSON packs (`world.json`, `player.json`, `items.json`, `affixes.json`, `rarities.json`, `themes.json`, `abilities.json`, `enemies.json`, `dungeon_ai.json`, `progression.json`, `tutorials.json`, `setpieces.json`, `mastery.json`) plus optional modular subdirectories (`items/`, `enemies/`, `themes/`, `abilities/`) and `materials.json` (shared PBR material definitions read by Blender and Godot). | All tunable numbers, spawn weights, themes, rarities, abilities, timers, item stats, text and material parameters live here. Validated by `scripts/validate-data.py` and `scripts/validate-assets.py`. |
| **3D World & UI Presentation** | `game/src/world/`, `game/src/world/combat/`, `game/src/ui/`, `game/src/main.gd` | Theme-driven Nordic-ruin builder (`DungeonBuilder`; streams decor per 32 m chunk on vast floors (`D-044`)), Skyrim 1st/3rd-person player (`PlayerController`) + extracted 1st/3rd-person viewmodel & arm-IK rig (`ViewmodelRig`), rigged animated character wrapper (`CharacterVisual`), shared actor base (`CombatActor`) & enemies/Boss (`EnemyActor`), projectiles (`GameProjectile`), reusable world combat primitives (`GroundZone`, `Barrier`), interactables (`InteractableObject`), effects (`VfxFactory`), UI design system (`UiTheme`, `ItemInfo`, `MenuScreen`), HUD (`GameHud`), menus (`TitleScreen`, `PauseMenu`, `SettingsPanel`, `InventoryMenu`, `VendorMenu`, `MapMenu`, `DeathScreen`, `DebugOverlay`) and scene coordinator (`GameMain`). | Thin visual/physics adapters delegating all rules and math to Tier 2. |

---

## 2. Scene Flow & Runtime Scene Tree

`res://scenes/title.tscn` (`TitleScreen`, project main scene: live 3D backdrop + menu) → `res://scenes/main.tscn` (`GameMain`).
Quit to Title saves and returns; Continue resumes the save, New Expedition deletes it (after confirmation).

```text
Main (GameMain — game/src/main.gd + CombatResolver)
├── DungeonBuilder (game/src/world/dungeon_builder.gd — driven by FloorTheme)
│   └── DungeonGeometry (WorldEnvironment, WorldColliders, chunked MultiMesh architecture, wall
│                        ArrayOccluder3D, torches + fire VFX + flickering lights, setpieces, dressing,
│                        dust/cobwebs, Boss Gate, Vault Gate, InteractableObjects, Spike Traps)
├── Enemies (EnemyActor extends CombatActor, w/ EntityStats, StatusComponent, ActorLocomotion, ActorBrain)
├── Projectiles (Node3D container for GameProjectile arrows & spells)
├── Corpses (lootable InteractableObjects holding the fallen, animated enemy bodies)
├── GroundZones (Node3D container for GroundZone persistent floor hazards/buffs)
├── Barriers (Node3D container for Barrier temporary walls & one-way shields)
├── Player (PlayerController — w/ ViewmodelRig, EntityStats, StatusComponent, AbilityExecutor)
│   ├── HeadPivot (Camera3D + presence fill light + blade-trail mesh + left/right hand anchors
│   │              managed by ViewmodelRig)
│   └── CharacterVisual "crawler" (rigged & animated 3rd-person body with weapons in hand sockets)
├── GameHud (CanvasLayer — compass w/ landmark icons, floor clock, vitals w/ damage trails, crosshair,
│            interaction prompt, hand icons, AI cards, loot toasts, area titles, boss bar, tutorial card)
├── InventoryMenu (MenuScreen — 3D portrait, equipment slots, filter/sort bag grid, comparison card,
│                  Skills & Perks tab, Bestiary tab)
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

---

## 6. Extensibility & Composable Entity Architecture (`D-051`, `D-055`)

Implemented in `D-055` so continuously adding **unique spells, enemies, weapons, summons, and arenas** requires zero core rewrites:

- **Unified Entity Stat Sheet (`EntityStats` + `StatusComponent`):** Player, enemies, bosses, and future player-summoned allies/companions share `EntityStats` (base values, timed/named modifiers, vitals/resources, defense, elemental/status resistances, `knockback_res`, `paralysis_res`, `poise`, `mass`, `power_tier`, mobility/offense) and `StatusComponent` (DoTs, HoTs, slows, stuns, paralysis, roots, haste, enrage, ward, invulnerability).
- **Resistance & Power-Tier Resolution:** `EntityStats.resolve_elemental_damage`, `resolve_knockback`, and `resolve_control` resolve abilities against target stats without hardcoded per-enemy `if` checks.
- **Modular `CombatActor` + Pluggable AI (`ActorLocomotion`, `ActorBrain`, `AbilityScaling`):** `EnemyActor extends CombatActor` with faction tags (`enemy`, `ally`, `player`, `neutral`), `MODE_GROUND`/`MODE_FLYING`/`MODE_KITER` locomotion, `ActorBrain.pick_utility_action` utility-scoring AI for adaptive casters/summons, and `AbilityScaling.resolve_traits` for level-based ability upgrades (`D-052`).
- **Reusable World Combat Primitives & Decoupled Execution (`GroundZone`, `Barrier`, `AbilityExecutor`, `CombatResolver`, `ViewmodelRig`):** Floor hazards, temporary walls / one-way projectile shields, composable active abilities (`abilities.json`), combat resolution, and 1st/3rd-person viewmodel posing each live in dedicated modules.
- **First-Class `FloorTheme` & `RarityTable` + Modular `DataLoader`:** Themes (`themes.json`, with `extends` inheritance), unified rarities (`rarities.json`), and optional modular subdirectories (`data/items/`, `data/enemies/`, `data/themes/`, `data/abilities/`) cleanly drive generation, rendering, drops, and pricing.
- See [`docs/CONTENT_CATALOG.md`](CONTENT_CATALOG.md) and [`docs/IDEAS_BACKLOG.md`](IDEAS_BACKLOG.md) for the concrete content slated to plug into this architecture.

