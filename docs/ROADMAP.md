# Master Roadmap

> **Status:** `Milestone 1 (v0.1 Vertical Slice) Built on feat/v0.1-vertical-slice — Awaiting User Playtest, Art Preview & PR Sign-Off`  
> **Workflow (`D-011`):** Feature branch + Pull Request per milestone/phase, plain-English summary, green automated CI required, User approves merge.  
> **User Review Checkpoints:** Marked with **[USER PLAYTEST]** or **[USER ART PREVIEW]** — all other phases are verified end-to-end by automated tests.

---

## Milestone 1: `v0.1` — First Playable Vertical Slice (One Complete Floor)

**Goal:** Deliver one complete, Skyrim-feeling 3D floor from entrance to hidden staircase, proving the entire core loop, Blender art pipeline, and automated testing harness.

| Phase | Status | Scope | Automated Tests | User Checkpoint |
|---|---|---|---|---|
| **Phase 1: Engine, CI & Test Harness Foundation** | `Built (PR Ready)` | Scaffold Godot 4.7.2 project, data-driven folder architecture, seeded RNG, headless test runner (GUT 9.7.1), GitHub Actions CI, and headless Blender export/preview pipeline. | Boot smoke test, RNG determinism, data validator, hygiene checks, CI green. | PR approval only. |
| **Phase 2: Blender Modular Dungeon Kit (Batch 1)** | `Built (PR Ready)` | 15 first-pass Clean Stylized Dark Fantasy Nordic-ruin `.glb` models in Blender + Cycles studio preview (`art/previews/batch1_dungeon_kit.png`). | `.glb` bounds/header/triangle/preview validation (`scripts/validate-assets.py`). | **[USER ART PREVIEW]** Review `batch1_dungeon_kit.png`. |
| **Phase 3: Skyrim Character Controller & Camera** | `Built (PR Ready)` | 1st-person primary + `V` 3rd-person over-the-shoulder toggle, smooth movement, sprinting, jumping, stamina bar, interactive raycast reticle, and menu time-pause freeze. | Headless camera toggle, stamina & menu pause-freeze integration tests. | PR approval only. |
| **Phase 4: Procedural Nordic-Ruin Labyrinth** | `Built (PR Ready)` | Seeded multi-room 3D labyrinth generator placing modular kit pieces, torchlight, Entrance, hidden Staircase, Safe Room, Boss Arena + Treasure Vault, and Top Compass Bar. | 100-seed connectivity, special room placement, compass bearing & determinism tests. | PR approval only. |
| **Phase 5: Left/Right-Hand Combat & Blender Gear (Batch 2)** | `Built (PR Ready)` | Sword+shield, two-handed greatsword, offensive/healing spells (Magicka), and bow (hold/release draw); 8 Blender weapon/gear `.glb` models + `batch2_weapons_gear.png`. | Equip combos, melee/kill/block/stamina, spell/magicka, bow projectile & damage math tests. | **[USER ART PREVIEW]** Review `batch2_weapons_gear.png`. |
| **Phase 6: Enemies, AI, Safe Rooms & Boss Arena (Batch 3)** | `Built (PR Ready)` | 6 Blender actor `.glb` models (Player, Draugr Raider, Bone Archer, Sponsored Goblin Streamer, Iron Warden Boss, Vendor) + `batch3_characters_enemies.png`; Safe Room repulsion & Boss Gate seal/Vault unlock. | AI aggro/repulsion, boss seal/unlock lifecycle, combat-death trigger tests. | **[USER ART PREVIEW]** Review `batch3_characters_enemies.png`. |
| **Phase 7: Looting, Inventory, Vendor & Sponsored/Mythic Loot** | `Built (PR Ready)` | Interactive chests/corpses/containers/Quest Board, Skyrim equipment slots, rarity-scaled affixes + Sponsored/Mythic items, Inventory UI (with pause), Safe Room Vendor trading, Dungeon AI banners & 12 procedural WAV SFX. | Loot table/affix roll, corpse/chest/vendor interaction, equip stat & banner tests. | PR approval only. |
| **Phase 8: 5-Day Collapse Timer, Snapshot Reset & Save-and-Quit** | `Built (PR Ready)` | 5 in-game day floor timer (~30 min/day configurable), Floor-Entry Snapshot reset on collapse or combat death, Save-and-Quit anytime, zero-preview Floor 2 descent, and `` ` `` Audit Console. | Timer countdown, collapse reset, death reset, Floor 2 descent, snapshot & save/load round-trip tests. | **[USER PLAYTEST — `v0.1` Vertical Slice!]** First full hands-on playtest via [`docs/PLAYTEST_GUIDE.md`](PLAYTEST_GUIDE.md). |

---

## Future Milestones (High-Level — Refined After `v0.1` Playtest)

- **Milestone 2 (`v0.2` — Multi-Floor Variety & Deep Progression):**
  - Distinct themed floors (e.g., *The Ember Tier*, *The Permafrost*, *The Rot Gardens*, *The Foundry*) via modular material/lighting/prop swaps (still zero staircase previews!).
  - Full Hybrid Progression UI: Character Level-Up, Attribute allocation, branching Skill/Perk Trees, and Skyrim use-to-improve proficiency tracking.
  - Underground Towns with Quest Boards and Stash/Rest spots.
- **Milestone 3 (`v0.3` — Content Expansion & Visual Polish):**
  - Expanded enemy roster, mini-bosses, traps/levers, deep Sponsored/Mythic affix catalog, and expanded Dungeon AI snark & absurd achievements.
  - Blender art polish pass (higher-detail textures, lighting atmosphere, animations, VFX).
- **Milestone 4 (`v1.0` — Release & Packaging):**
  - Full balance & performance pass, optional open-source Dungeon AI TTS voice, optional Web export evaluation, and packaged Windows/Mac/Linux desktop builds.
