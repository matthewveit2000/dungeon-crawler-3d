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

## 2. Asset Inventory (`v0.1` Polished — 38 Textured PBR Models Across 3 Batches)

Every batch uses procedural seamless 512×512 PBR textures (`art/textures/` generated via `art/blender/gen_textures.py` — ashlar masonry, flagstone tiles, weathered oak woodgrain, brushed hammered steel, dark leather, crimson/gold tapestry), exports `.glb` models into `game/assets/models/`, AND renders a denoised 1280×720 Cycles studio preview sheet into `art/previews/` for User visual review.

### Batch 1 — Nordic-Ruin Modular Kit & Handcrafted Setpiece Props (22 Models)
Preview sheet: [`art/previews/batch1_dungeon_kit.png`](../art/previews/batch1_dungeon_kit.png)

| Asset | File | Purpose |
|---|---|---|
| Stone Floor Tile | `game/assets/models/batch1/floor_tile.glb` | 4×4m carved flagstone floor with stone texture |
| Stone Ceiling Tile | `game/assets/models/batch1/ceiling_tile.glb` | 4×4m vaulted ribbed stone ceiling |
| Stone Wall | `game/assets/models/batch1/wall_segment.glb` | 4×4m Nordic ashlar stone wall with relief trim |
| Doorway Arch | `game/assets/models/batch1/door_arch.glb` | Carved Nordic stone corridor archway |
| Dungeon Pillar | `game/assets/models/batch1/pillar.glb` | Sculpted octagonal stone column with capital & plinth |
| Wall Torch Sconce | `game/assets/models/batch1/torch_sconce.glb` | Wrought-iron sconce + glowing layered flame |
| Floor Brazier | `game/assets/models/batch1/brazier.glb` | Iron tripod fire bowl for Entrance & Boss Arena setpieces |
| Hanging Wall Banner | `game/assets/models/batch1/wall_banner.glb` | Crimson & gold Nordic fabric tapestry banner |
| Woven Carpet Runner | `game/assets/models/batch1/carpet_runner.glb` | Royal crimson & antique-gold room rug |
| Boss Rune Dais | `game/assets/models/batch1/boss_dais.glb` | Raised octagonal Boss crucible platform with glowing rune ring |
| Merchant Stall | `game/assets/models/batch1/merchant_stall.glb` | Crimson/gold canopy stall with hanging lanterns & display wares |
| Loot Chest | `game/assets/models/batch1/chest.glb` | Iron-banded oak treasure chest |
| Wooden Crate & Barrel | `game/assets/models/batch1/crate.glb`, `barrel.glb` | Banded supply containers & setpiece props |
| Burial Urn | `game/assets/models/batch1/urn.glb` | Carved Nordic stone loot urn |
| Weapon Rack | `game/assets/models/batch1/weapon_rack.glb` | Handcrafted dungeon armory prop |
| Safe Room Beacon | `game/assets/models/batch1/safe_beacon.glb` | Pedestal with floating astrolabe emerald sanctuary crystal |
| Quest Board | `game/assets/models/batch1/quest_board.glb` | Timber Syndicate bounty notice board with pinned parchments |
| Boss Arena Gate | `game/assets/models/batch1/boss_gate.glb` | Heavy spiked iron portcullis (slams shut on threshold) |
| Treasure Vault Gate | `game/assets/models/batch1/vault_gate.glb` | Ornate gilded twin vault doors |
| Hidden Staircase | `game/assets/models/batch1/staircase_down.glb` | Descending carved stone stairwell |
| Spike Trap + Lever | `game/assets/models/batch1/spike_trap.glb`, `lever.glb` | Retractable floor spike grate + disarm lever |

### Batch 2 — Weapons, Gear, First-Person Gauntlets & Spell Props (10 Models)
Preview sheet: [`art/previews/batch2_weapons_gear.png`](../art/previews/batch2_weapons_gear.png)

- `iron_sword.glb` — Forged Nordic steel longsword with fuller, crossguard & leather-wrapped pommel
- `iron_shield.glb` — Woodgrain-textured oak round shield with hammered iron rim & boss
- `steel_greatsword.glb` — Heavy bearded two-handed Nordic greatsword/battle-blade
- `hunting_bow.glb` — Sculpted ashwood recurve bow with horn tips & taut bowstring
- `arrow.glb` — Steel-broadhead dungeon arrow with fletching
- `spell_orb.glb` — Compact floating arcane crystal surrounded by orbiting gold astrolabe rings
- `health_potion.glb` & `mana_potion.glb` — Glowing ruby & sapphire corked alchemy vials
- `mythic_gloves.glb` — Articulated steel Sponsored/Mythic gauntlets
- `fp_gauntlet_left.glb` & `fp_gauntlet_right.glb` — First-person armored forearm gauntlets with brass cuff trim

### Batch 3 — Characters, Enemies, Vendor & Boss (6 Models)
Preview sheet: [`art/previews/batch3_characters_enemies.png`](../art/previews/batch3_characters_enemies.png)

- `player_crawler.glb` — Third-person crawler hero with horned Nordic helm, steel pauldrons, crimson-gold cape & back scabbard
- `draugr_raider.glb` — Horned armored ancient Nordic melee warrior with glowing eyes & battleaxe
- `bone_archer.glb` — Hooded cloak skeletal marksman with quiver & strung bow
- `goblin_streamer.glb` — *DCC Payload:* Goblin skirmisher wearing a glowing neon ring-light halo & hovering twin-rotor camera drone
- `iron_warden_boss.glb` — Towering 3m horned Iron Warden Floor Boss with glowing visor, chest rune crest, crimson cloak & glowing warhammer
- `safe_room_vendor.glb` — Warm gold-robed Safe Room merchant NPC

---

## 3. Headless Rebuild, Asset Validation & Live Player-POV Visual QA (`D-028`)

To regenerate all 38 textured `.glb` models, `art/manifest.json`, and all 3 studio preview PNGs headlessly:

```bash
./.tools/bin/blender --background --python art/blender/build_all.py
python3 scripts/validate-assets.py
```

To capture live 1280×720 in-engine player-POV screenshots (11 scenarios) and a 36-frame combat motion MP4 (`art/visual_qa/combat_motion.mp4`) for visual inspection:

```bash
./scripts/run-visual-qa.sh
```

`scripts/validate-assets.py` verifies on every CI run that:
- All 38 `.glb` files exist, have valid binary glTF headers, and are non-empty.
- Every asset's exported bounding box and triangle count match `art/manifest.json` budgets.
- All 3 studio preview PNGs exist and have valid PNG dimensions (`1280×720`).

---

## 4. Planned Visual Polish (`v0.2`–`v0.3`)

In future milestones, we will expand this textured stylized dark-fantasy library with skeletal rigs & keyframe animations, distinct themed material/lighting packs for deeper floors (*The Ember Tier*, *The Permafrost*, *The Rot Gardens*), and additional handcrafted room setpieces (`D-029`).
