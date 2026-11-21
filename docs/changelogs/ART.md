# Art Changelog

Detailed record of original Blender 3D models, materials, preview renders, and audio assets.  
See [`docs/ART_PIPELINE.md`](../ART_PIPELINE.md) and [`docs/DECISION_LOG.md`](../DECISION_LOG.md).

---

## 2026-11-18 — Milestone 1 (`v0.1` Vertical Slice) First-Pass Clean Stylized Dark Fantasy Art & Procedural SFX

- **Blender 4.5.9 LTS Pipeline (`D-005`, `D-025`):**
  - Created deterministic headless Blender build scripts in `art/blender/` (`common.py`, `build_batch1_dungeon.py`, `build_batch2_gear.py`, `build_batch3_actors.py`, `build_all.py`) exporting 29 `.glb` models and `art/manifest.json`.
- **Batch 1 — Nordic-Ruin Modular Dungeon Kit (15 `.glb` models):**
  - Modeled 4×4m beveled stone floors, ceilings, ashlar walls, doorway arches, pillars, wall torches, chests, crates, urns, Safe Room rune beacon, Quest Board, Boss Arena portcullis gate, Treasure Vault gate, hidden descending staircase, spike trap grate, and disarm lever.
  - Rendered Cycles studio preview sheet `art/previews/batch1_dungeon_kit.png` (superseded by the v2 overhaul).
- **Batch 2 — Weapons, Gear & Spell Props (8 `.glb` models):**
  - Modeled Iron Sword, Iron Shield, Steel Greatsword, Hunting Bow, Arrow, Arcane Spell Orb, Health Potion, and Sponsored/Mythic Gauntlets.
  - Visual QA refinement: rebuilt `hunting_bow.glb` as a smooth 10-segment parabolic arc (eliminating limb gaps) and added articulated steel fingers/thumbs to `mythic_gloves.glb`.
  - Rendered Cycles studio preview sheet [`art/previews/batch2_weapons_gear.png`](../../art/previews/batch2_weapons_gear.png).
- **Batch 3 — Characters, Enemies, Boss & Vendor (6 `.glb` models):**
  - Modeled Player Crawler (3rd-person), Draugr Raider, Bone Archer, Sponsored Goblin Streamer (with glowing neon ring-light halo & camera rig), Iron Warden Floor Boss, and Safe Room Vendor.
  - Visual QA refinement: switched Batch 3 studio preview to a single-row showcase lineup so `draugr_raider.glb` is completely unobstructed beside the towering `iron_warden_boss.glb`.
  - Rendered Cycles studio preview sheet `art/previews/batch3_characters_enemies.png` (superseded by the v2 overhaul).
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

## 2026-11-19 — Visual Overhaul v2: Procedural High-Detail Art, Rigged Animation, Atmosphere & UI Kit (`D-031`–`D-036`)

Requested by the User: replace blocky/low-poly art, stiff animation and plain menus with work "between AAA and indie" quality.

- **Texture library (`art/pipeline/generate_textures.py`):** 35 tileable 1024² PBR materials (albedo + OpenGL normal + ORM, height for floors/walls, emission for runes/embers) authored from periodic spectral noise, periodic Voronoi, ashlar/plank/flagstone layouts and cavity AO; stored as WebP (≈33 MB total vs 186 MB PNG). Includes unique banner (original crowned-skull sigil) and rug designs. VFX sprites: 8×8 looping flame flipbook, smoke flipbook, embers, glows, dust, cobweb, light shaft.
- **Shared material library (`game/data/materials.json`, `D-031`):** 55 named materials used identically by Blender previews and Godot (`MaterialLibrary`), with per-material texel density baked into UVs.
- **Modelling library (`art/blender/dclib/`):** irregular hand-cut stones, lathes, tapered sweeps, voussoir arches, cloth with folds & frayed hems, planks with grain-aligned UVs, ray-cast vertex AO, per-part tint, skin-modifier bodies, rigging and animation DSL.
- **Kit (12):** three ashlar wall variants with base course & cornice, burial-niche wall, damaged wall with rubble, three flagstone floors, two coffered rib-vault ceilings, drummed column, voussoir doorway arch.
- **Props (23):** torch sconce & brazier with flame sockets, candle cluster, chest with hinged lid, stave barrel, crate, urn, war banner, tasselled rug, rune boss dais, sanctuary beacon, merchant stall, quest board, portcullis, gilded vault doors, spike trap, lever, rubble & bone piles, sarcophagus, weapon rack, table, descending stairwell.
- **Gear (22) + icons (18):** fullered longsword, bearded battleaxe, painted round shield, recurve bow with pullable string, arrow, three spell tomes, two potions, helm, cuirass, gauntlets ×2, boots, ring, amulet, ratings cleaver, four gloved first-person arms; inventory icons rendered from the models (`game/assets/icons/`).
- **Characters (6, rigged & animated, `D-033`):** crawler, draugr, bone archer, goblin streamer, Iron Warden boss, vendor — idle / combat idle / walk / run / attack / hit / death + block, cast, draw, shoot, roar, slam, talk.
- **UI kit (`art/pipeline/generate_ui.py`, `D-034`):** gilded 9-slice panel frames, chamfered buttons (normal/hover/pressed/disabled), item slots with rarity-tintable borders, vital bar frame & fill, divider, key cap, compass strip, map/HUD icons, crest emblem, cursor, check boxes, slider grabber.
- **Previews:** [`kit room`](../../art/previews/batch1_kit_room.png), [`props`](../../art/previews/batch1_props.png), [`gear`](../../art/previews/batch2_weapons_gear.png), [`characters`](../../art/previews/batch3_characters.png), [`texture library`](../../art/previews/texture_library.png).
- **Removed:** the 38 first-pass `batch1/2/3` models, 256² textures and old build scripts (superseded).

## 2026-11-19 — v2 Visual QA Polish Pass (`D-028`)

Every screenshot and the 40-frame combat clip from the full Forward+ capture were reviewed from the player's camera; fixes:
- **First-person arms:** forearms slimmed and re-angled — the forearm now leaves the fist at ~125° to the grip axis (back and down toward the pommel side, like a real sword grip) instead of 90°, so with the blade cocked up-forward the forearm runs out of the bottom of the view; the vambrace ends in a domed elbow cop, so it never reads as a hollow tube.
- **Steel:** `steel_blade` re-authored as polished, lightly brushed steel (lower normal strength and roughness, smoother albedo); `steel_armor` normal scale reduced.
- **New `chainmail` material** (two interlinked ring lattices, tiles exactly) and a mail aventail on the `crawler` helm, so the 3rd-person view no longer shows a bare head under the helmet.
- **Icons:** finishing pass on every inventory icon (exposure normalisation for dark items + soft warm halo) — the axe, bow and shield now read on dark slots.
- **Character animation export fixed:** `export_animation_mode="ACTIONS"` exports every bone-compatible action in the .blend, so in a full build each later character's file also carried all earlier characters' clips, and because Blender action names are global its own clips became `idle.001`, `attack.002`, …; the game resolves clips by name, so every enemy played the crawler's clips. `core.export_glb` now uses `NLA_TRACKS` (one clip per track of the exported armature, named after the track); the preview / `--strip` helpers pick the armature's own track action. Files shrank accordingly (e.g. vendor 1.18 MB → 0.77 MB).
- **Reproducible builds:** `build_characters.py` seeded each body's UV offset / weathering with Python's `hash(name)`, which is salted per process, so every rebuild produced slightly different characters; it now uses `zlib.crc32`. The gear preview sheet camera was pulled back so the widest weapon row is fully in frame.
- **UI kit:** vital bar split into `bar_back` (trough, under the fill) and `bar_frame` (border, over it) — the old frame's dark interior was dimming every bar; new `map_paper.webp` vellum with a faint survey grid replaces the handwriting-ruled parchment behind the map.

## 2026-11-19 — Biomechanical Skeletal Animation & Prop Rig Overhaul (`D-037`)

- **World-Space 2-Bone Soft-IK Animation Engine (`art/blender/dclib/rig.py`, `art/blender/dclib/char_anims.py`):**
  - Added exact world-space rotation/translation helpers (`set_bone_world_rot`, `set_bone_world_delta`), analytical 2-bone soft-IK solver (`solve_2bone_ik`), flat-floor foot orienter (`orient_foot_world`), grip-socket arm solver (`grip_rest_local_matrix`, `orient_hand_for_grip`), head look-at, and hemisphere-continuous 30 FPS quaternion action sampler (`make_sampled_action`).
  - Re-authored every single animation clip across all 6 characters (`crawler`, `draugr`, `bone_archer`, `goblin_streamer`, `iron_warden`, `vendor`): grounded asymmetric `idle`/`idle_combat`, zero-slip constant-velocity stance `walk`/`run`, kinetic-chain 1H & 2H `attack` (both hands locked onto the lower + upper battleaxe leather wraps), distinct Iron Warden vertical overhead `slam` and living furnace-rage `roar`, sideways vertical-bow `shoot`/`draw_hold`/`bow_shoot`, rim-peeking `block`, straight-forward `cast`, expressive open-handed Merchant `talk`, grounded knee-absorbing `hit`, and smooth gravity-accelerated `death` collapses that rest flush on top of the flagstones (`z >= 0.04m` asserted at export).
  - Added `attack_2h` and `bow_shoot` clips to `crawler.glb` (12 clips total) and aligned `GripR` (`Rx(90°) @ Rz(-90°)`) in `art/blender/build_characters.py` so blade/axe cutting edges lead cleanly in the strike plane.
- **Pivoted Prop Sub-Meshes (`art/blender/build_props.py`):**
  - Separated `lever.glb`'s moving iron arm into a pivoted child `Handle` at fulcrum `(0, 0, 0.58)` so the stone pedestal stays planted when thrown, and separated `safe_beacon.glb`'s `Crystal` child at `(0, 0, 1.58)` for floating/rotation.
- **Preview Updated:** Regenerated [`art/previews/batch3_characters.png`](../../art/previews/batch3_characters.png) showcasing the new natural stances.



## 2026-11-20 — First-Person Animation Pass v3 (`D-040`)

- New gear model `fp_upper_arm` (quilted dark gambeson sleeve with a leather cuff band, unit length, 852 tris) built by `build_gear.py`; the game stretches it from each first-person forearm's elbow to the shoulder.
- First-person viewmodel animation rebuilt as a weapon-first pose library with arm IK and edge-leading cuts (battleaxe, sword, dual-wield, spells, bow). The open-hand arm meshes are turned palm-to-target and used mirror-swapped (`fp_arm_open_l` is the anatomical right hand once facing away). Reviewed frame-by-frame from the player's view with `./scripts/fp-pose-probe.sh` and in-game with `./scripts/record-anim-review.sh`.

## 2026-11-20 — Brighter Dungeon Lighting Pass (`D-041`)

- Dense, brighter wall torch lines in rooms and corridors (up to 240 per floor), corner fire braziers (`brazier.glb`) in ordinary rooms, a soft overhead fill per room, warmer and stronger ambient light, +20% exposure and lighter fog. Reviewed before/after from the player's view (room, corridor, third-person, battleaxe).

## 2026-11-20 — FB-014: Solid Chest & Shield, Third-Person Combat Clips (`D-048`)

- `chest.glb`: dark inner wall linings behind the planks and an overlapping inner lid shell (9,378 tris); `round_shield.glb`: full-disc dark backing board behind the planks (5,458 tris). No light shows between boards from any angle.
- `char_anims.py`: `_mirror_current_pose` mirrors any pose left/right (per-bone target chosen so the skin deform is the exact mirror, independent of bone roll); new crawler clips `idle_dual`, `attack_dual`, `attack_l`, `cast_r`, `cast_dual`, `bow_draw`.
- First-person blades: rest/sprint poses turn every blade edge-on to the eye (standing rule).

## 2026-11-20 — FB-015: New Gear & Enemy Variants (`D-049`)

- 21 new gear models + icons in `build_gear.py`: hand axe, flanged mace, seax, broadsword, war hammer, Dane axe, yew longbow, bone short bow, iron kite shield, buckler, frost/venom/void/blood tomes, chain hauberk, wolf-pelt hood, hide bracers, fur boots, ember ring, gold signet, wolf-tooth amulet. `build_bow` and `build_tome` are now parametric.
- Enemy variants reuse the rigs with a per-type colour wash (`CharacterVisual.set_tint`), scale, shield and weapon so no two types look alike.

## 2026-11-21 — FB-022: New Consumables, Re-Themed Goblin & Relics (`D-057`)
- New gear models + icons (`art/blender/build_gear.py`): stamina potion, swiftness draught, ironbark tonic, troll-fat salve, glowcap mushroom, grave moss, bat-wing jerky, goblin toenail. New materials: `glass_amber`, `glass_lime`, `moss`, `fungus_glow`, `salve_fat`, `keratin`.
- `goblin_streamer` → `goblin`: the neon ring-light pole is now a pack-frame with an iron hoop of stolen candles (`CandleHoop` socket, warm light).
- `ratings_cleaver` → `gravefeast_cleaver` (glowing blood-runes instead of neon rating bars); `sponsored_gauntlets` → `thunderclap_gauntlets`. Old files removed; `batch2`/`batch3` previews re-rendered.
- Enemy health bar is a single shader-drawn billboard; damage-over-time body effects (fire, blood drips, poison haze, frost aura); HUD hotbar strip and status list.
