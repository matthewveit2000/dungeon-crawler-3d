# Art Changelog

Detailed record of original Blender 3D models, materials, preview renders, and audio assets.  
See [`docs/ART_PIPELINE.md`](../ART_PIPELINE.md) and [`docs/DECISION_LOG.md`](../DECISION_LOG.md).

---

## 2026-11-18 — Milestone 1 (`v0.1` Vertical Slice) First-Pass Clean Stylized Dark Fantasy Art & Procedural SFX

- **Blender 4.5.9 LTS Pipeline (`D-005`, `D-025`):**
  - Created deterministic headless Blender build scripts in `art/blender/` (`common.py`, `build_batch1_dungeon.py`, `build_batch2_gear.py`, `build_batch3_actors.py`, `build_all.py`) exporting 29 `.glb` models and `art/manifest.json`.
- **Batch 1 — Nordic-Ruin Modular Dungeon Kit (15 `.glb` models):**
  - Modeled 4×4m beveled stone floors, ceilings, ashlar walls, doorway arches, pillars, wall torches, chests, crates, urns, Safe Room rune beacon, Quest Board, Boss Arena portcullis gate, Treasure Vault gate, hidden descending staircase, spike trap grate, and disarm lever.
  - Rendered Cycles studio preview sheet [`art/previews/batch1_dungeon_kit.png`](../../art/previews/batch1_dungeon_kit.png).
- **Batch 2 — Weapons, Gear & Spell Props (8 `.glb` models):**
  - Modeled Iron Sword, Iron Shield, Steel Greatsword, Hunting Bow, Arrow, Arcane Spell Orb, Health Potion, and Sponsored/Mythic Gauntlets.
  - Visual QA refinement: rebuilt `hunting_bow.glb` as a smooth 10-segment parabolic arc (eliminating limb gaps) and added articulated steel fingers/thumbs to `mythic_gloves.glb`.
  - Rendered Cycles studio preview sheet [`art/previews/batch2_weapons_gear.png`](../../art/previews/batch2_weapons_gear.png).
- **Batch 3 — Characters, Enemies, Boss & Vendor (6 `.glb` models):**
  - Modeled Player Crawler (3rd-person), Draugr Raider, Bone Archer, Sponsored Goblin Streamer (with glowing neon ring-light halo & camera rig), Iron Warden Floor Boss, and Safe Room Vendor.
  - Visual QA refinement: switched Batch 3 studio preview to a single-row showcase lineup so `draugr_raider.glb` is completely unobstructed beside the towering `iron_warden_boss.glb`.
  - Rendered Cycles studio preview sheet [`art/previews/batch3_characters_enemies.png`](../../art/previews/batch3_characters_enemies.png).
- **Procedural Open-Source Audio (`D-026`):**
  - Added `scripts/generate-sfx.py` generating 12 clean open-source `.wav` SFX & dungeon ambience loops in `game/assets/audio/`.

## 2026-11-18 — Major 3D Art, PBR Texture, Animation & Visual QA Overhaul (`D-028`, `D-029`)

- **Seamless Procedural PBR Texture Library (`art/blender/gen_textures.py` → `art/textures/`):**
  - Generated 512×512 seamless ashlar masonry, flagstone floor, dark oak woodgrain, hammered brushed steel, oiled leather, and crimson/gold Nordic tapestry textures embedded cleanly into all `.glb` materials.
- **Expanded to 38 Sculpted Blender 4.5.9 LTS Models (+9 Setpiece Props & 1st-Person Gauntlets):**
  - Upgraded Batch 1 to 22 models: vaulted ribbed ceilings, Nordic ashlar walls, octagonal pillars, flaming tripod braziers, hanging crimson banners, woven room carpets, octagonal Boss Rune Dais, striped lantern-lit Merchant Stall, barrels, weapon racks, and astrolabe Sanctuary Beacon; removed 7 legacy unreferenced `.glb` files.
  - Upgraded Batch 2 to 10 models: woodgrain iron-rimmed shield, forged steel longsword & greatsword, sculpted recurve bow, arrows, compact astrolabe spell focus, ruby/sapphire alchemy potions, Mythic gauntlets, and sculpted 1st-person armored gauntlets (`fp_gauntlet_left.glb`, `fp_gauntlet_right.glb`).
  - Upgraded Batch 3 to 6 sculpted characters: horned Viking `player_crawler.glb` with crimson-gold cape & scabbard, armored `draugr_raider.glb`, hooded `bone_archer.glb`, neon ring-light `goblin_streamer.glb` with hovering twin-rotor drone, towering 3m `iron_warden_boss.glb` with glowing visor/warhammer, and robed `safe_room_vendor.glb`.
  - Refreshed all 3 Cycles studio preview sheets (`art/previews/batch1_dungeon_kit.png`, `batch2_weapons_gear.png`, `batch3_characters_enemies.png`).
- **Live Player-POV Visual QA Iterations (`D-028`):**
  - Audited 11 live 1280×720 screenshots + 36-frame `combat_motion.mp4` video and fixed OpenGL3 light-slot starvation (adding soft directional sculpt fill + 6-nearest proximity OmniLight manager), compact 1st-person shield framing (~11% screen area), smooth blade-edge slash streak, bow forearm clearance, 3rd-person wall-collision pullback, wall-to-ceiling seam seal, and dark-fantasy UI contrast/legibility.
