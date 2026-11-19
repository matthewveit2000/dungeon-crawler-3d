# 3D Art Pipeline (Blender → Godot 4)

> **Art Direction (`D-025`):** **Clean Stylized Dark Fantasy** — crisp, readable Nordic-ruin silhouettes with hand-crafted stone bevels, torchlit atmospheric materials, and expressive DCC visual humor (such as the Sponsored Goblin Streamer's glowing neon ring-light halo and corporate-branded Mythic gauntlets).  
> **Source of Truth (`D-005`):** 100% original assets generated in **Blender 4.5.9 LTS** via deterministic Python scripts under `art/blender/`. Zero third-party asset packs.

---

## 1. Modular World Scale & Snap Specification

All environment geometry snaps cleanly to a **4.0 m × 4.0 m** tile grid (`world.json` → `grid.tile_size_meters: 4.0`, `grid.wall_height_meters: 4.0`):

- **Origin:** Centered on `X/Y`, resting flat at `Z = 0.0` (floor plane) in Blender (exported Y-up to `.glb` for Godot).
- **Scale & Transforms:** Clean applied scale (`1, 1, 1`) and zero stray transforms.
- **Materials:** PBR principled materials (dark slate stone, weathered bronze, oiled iron, warm oak, crimson boss iron, arcane cyan runes, neon streamer ring-light emission) baked directly into `.glb`.

---

## 2. Asset Inventory (`v0.1` — 29 Models Across 3 Batches)

Every batch exports `.glb` models into `game/assets/models/` AND renders a denoised 1280×720 Cycles studio turntable preview sheet into `art/previews/` for User visual review.

### Batch 1 — Nordic-Ruin Modular Dungeon Kit (15 Models)
Preview sheet: [`art/previews/batch1_dungeon_kit.png`](../art/previews/batch1_dungeon_kit.png)

| Asset | File | Purpose |
|---|---|---|
| Stone Floor Tile | `game/assets/models/batch1/floor_tile.glb` | 4×4m beveled flagstone floor |
| Stone Ceiling Tile | `game/assets/models/batch1/ceiling_tile.glb` | 4×4m vaulted ceiling slab |
| Stone Wall | `game/assets/models/batch1/wall_segment.glb` | 4×4m ashlar dungeon wall |
| Doorway Arch | `game/assets/models/batch1/door_arch.glb` | Nordic stone corridor arch |
| Dungeon Pillar | `game/assets/models/batch1/pillar.glb` | Carved square support column |
| Wall Torch Sconce | `game/assets/models/batch1/torch_sconce.glb` | Iron sconce + glowing flame |
| Loot Chest | `game/assets/models/batch1/chest.glb` | Iron-banded treasure chest |
| Wooden Crate | `game/assets/models/batch1/crate.glb` | Lootable supply crate |
| Burial Urn | `game/assets/models/batch1/urn.glb` | Nordic stone loot urn |
| Safe Room Beacon | `game/assets/models/batch1/safe_beacon.glb` | Cyan rune sanctuary crystal |
| Quest Board | `game/assets/models/batch1/quest_board.glb` | Safe Room bounty notice board |
| Boss Arena Gate | `game/assets/models/batch1/boss_gate.glb` | Heavy iron portcullis (seals on entry) |
| Treasure Vault Gate | `game/assets/models/batch1/vault_gate.glb` | Ornate gold-iron vault door |
| Hidden Staircase | `game/assets/models/batch1/staircase_down.glb` | Descending stone stairwell |
| Spike Trap + Lever | `game/assets/models/batch1/spike_trap.glb`, `lever.glb` | Floor spike grate + disarm lever |

### Batch 2 — Weapons, Gear & Spell Props (8 Models)
Preview sheet: [`art/previews/batch2_weapons_gear.png`](../art/previews/batch2_weapons_gear.png)

- `iron_sword.glb` — Classic Nordic one-handed steel blade
- `iron_shield.glb` — Round banded iron-and-oak shield
- `steel_greatsword.glb` — Heavy two-handed greatsword
- `hunting_bow.glb` — Smooth 10-segment parabolic recurve bow
- `arrow.glb` — Fletched dungeon arrow projectile
- `spell_orb.glb` — Arcane flame/lightning casting focus
- `health_potion.glb` — Glowing ruby alchemy vial
- `mythic_gloves.glb` — Articulated steel Sponsored/Mythic gauntlets

### Batch 3 — Characters, Enemies, Vendor & Boss (6 Models)
Preview sheet: [`art/previews/batch3_characters_enemies.png`](../art/previews/batch3_characters_enemies.png)

- `player_crawler.glb` — Third-person crawler hero with hood, cloak & steel pauldrons
- `draugr_raider.glb` — Ancient Nordic melee skeleton-warrior with rusted axe
- `bone_archer.glb` — Hooded ranged archer with quiver & bow
- `goblin_streamer.glb` — *DCC Payload:* Goblin skirmisher wearing a glowing neon ring-light halo & camera rig
- `iron_warden_boss.glb` — Towering horned Iron Warden Floor Boss with runed warhammer
- `safe_room_vendor.glb` — Lantern-lit Safe Room merchant

---

## 3. Headless Rebuild & Automated Validation

To regenerate all 29 `.glb` models, `art/manifest.json`, and all 3 studio preview PNGs headlessly:

```bash
./.tools/bin/blender --background --python art/blender/build_all.py
python3 scripts/validate-assets.py
```

`scripts/validate-assets.py` verifies on every CI run that:
- All 29 `.glb` files exist, have valid binary glTF headers, and are non-empty.
- Every asset's exported bounding box and triangle count match `art/manifest.json` budgets.
- All 3 studio preview PNGs exist and have valid PNG dimensions (`1280×720`).

---

## 4. Planned Visual Polish (`v0.2`–`v0.3`)

In future milestones (after `v0.1` playtest feedback), we will upgrade these first-pass stylized assets with procedural normal/roughness detail maps, skeletal animations (walk/swing/draw/death), first-person articulated arm rigs, and distinct themed material palettes per floor.
