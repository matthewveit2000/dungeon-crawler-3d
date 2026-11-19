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
