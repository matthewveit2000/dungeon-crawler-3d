# System Architecture

> **Status:** `Active — Milestone 1 (v0.1 Vertical Slice)`  
> **Engine & Toolchain:** Godot 4.7.2-stable (MIT), GUT 9.7.1 (MIT), Blender 4.5.9 LTS (GPL, art outputs MIT/CC0 in repo), Python 3 stdlib tooling.  
> **Related Decisions:** [`D-003`](DECISION_LOG.md), [`D-004`](DECISION_LOG.md), [`D-005`](DECISION_LOG.md), [`D-009`](DECISION_LOG.md), [`D-024`](DECISION_LOG.md).

---

## 1. Three-Tiered Architecture

`dungeon-crawler-3d` enforces strict separation between engine utilities, pure gameplay rules, and tunable data so the entire game can be tested deterministically headlessly without a GPU.

| Tier | Location | Responsibility | Rules |
|---|---|---|---|
| **Tier 1 — Core Engine Glue** | `game/src/core/` | Seeded PRNG (`SeededRng`), JSON data loader (`DataLoader`), decoupled signal bus (`EventBus`), `.glb` model loader with graceful fallback (`ModelLoader`), procedural audio playback (`AudioManager`). | Zero hardcoded gameplay rules or item stats. Graceful fallback if an asset or audio file is missing. |
| **Tier 2 — Pure Gameplay Rules** | `game/src/systems/` | Deterministic procedural dungeon layout (`DungeonGenerator`), Skyrim left/right-hand & armor/crit math (`CombatMath`), rarity & Sponsored/Mythic rolling (`LootGenerator`), hybrid XP + Skyrim use-to-improve (`ProgressionSystem`), 5-day floor clock (`FloorTimer`), Floor-Entry Snapshot & Save-and-Quit persistence (`SnapshotManager`), Vendor economy (`VendorSystem`), Compass projection (`CompassSystem`), Dungeon AI snark (`DungeonAiDirector`), Audit Console parser (`DebugConsole`). | Pure `RefCounted` logic driven exclusively by Tier 3 JSON dictionaries and injected `SeededRng`. No scene-tree assumptions. |
| **Tier 3 — Pure Data Packs** | `game/data/` | 7 validated JSON packs (`world.json`, `player.json`, `items.json`, `affixes.json`, `enemies.json`, `dungeon_ai.json`, `progression.json`). | All tunable numbers, spawn weights, timers, item stats, and text live here. Validated automatically by `scripts/validate-data.py`. |
| **3D World & UI Presentation** | `game/src/world/`, `game/src/ui/`, `game/src/main.gd` | 3D modular Nordic-ruin builder (`DungeonBuilder`), Skyrim 1st/3rd-person player (`PlayerController`), 3D enemies & Boss (`EnemyActor`), projectiles (`GameProjectile`), interactables (`InteractableObject`), HUD/menus (`GameHud`, `InventoryMenu`, `VendorMenu`, `PauseMenu`, `DebugOverlay`), and scene coordinator (`GameMain`). | Thin visual/physics adapters delegating all rules and math to Tier 2. |

---

## 2. Runtime Scene Tree (`game/scenes/main.tscn`)

```text
Main (GameMain — game/src/main.gd)
├── DungeonBuilder (game/src/world/dungeon_builder.gd)
│   └── DungeonGeometry (StaticBody3D walls/floors/ceilings, Blender Batch 1 .glb props,
│                        torches, Boss Gate, Vault Gate, InteractableObjects, Spike Traps)
├── Enemies (Node3D container for spawned EnemyActor instances + Floor Boss)
├── Projectiles (Node3D container for GameProjectile arrows & spells)
├── Corpses (Node3D container for lootable InteractableObject enemy corpses)
├── Player (PlayerController — game/src/world/player_controller.gd)
│   ├── HeadPivot (First-Person Camera3D + Left/Right-Hand weapon anchors + Interact RayCast3D)
│   ├── ThirdPersonPivot (SpringArm3D + Over-the-Shoulder Camera3D)
│   └── ThirdPersonBody (Blender Batch 3 player_crawler.glb, visible in 3rd-person mode)
├── GameHud (CanvasLayer — top compass bar, 5-day clock, HP/MP/SP bars, reticle, AI banners)
├── InventoryMenu (CanvasLayer — Skyrim equipment slots, bag, hybrid level/perk/skill panel)
├── VendorMenu (CanvasLayer — Safe Room buy/sell trading)
├── PauseMenu (CanvasLayer — Resume, Save & Quit, Reset Floor, Camera Toggle)
└── DebugOverlay (CanvasLayer — built-in `~` Audit Console for playtesting shortcuts)
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
5. Full GUT unit + 100-seed procedural dungeon + headless 3D gameplay integration suite
