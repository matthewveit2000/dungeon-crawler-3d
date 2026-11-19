# Master Roadmap

> **Status:** `Pre-Production Blueprint — Awaiting Final Sign-Off`  
> **Workflow (`D-011`):** One feature branch + Pull Request per phase, plain-English summary, green automated CI required, User approves merge.  
> **User Review Checkpoints:** Marked with **[USER PLAYTEST]** or **[USER ART PREVIEW]** — all other phases are verified end-to-end by automated tests.

---

## Milestone 1: `v0.1` — First Playable Vertical Slice (One Complete Floor)

**Goal:** Deliver one complete, Skyrim-feeling 3D floor from entrance to hidden staircase, proving the entire core loop, Blender art pipeline, and automated testing harness.

| Phase | Scope | Automated Tests | User Checkpoint |
|---|---|---|---|
| **Phase 1: Engine, CI & Test Harness Foundation** | Scaffold Godot 4 project, data-driven folder architecture, seeded RNG, headless test runner (GUT/GdUnit4), GitHub Actions CI, and headless Blender export/preview script. | Boot test, RNG determinism, data validator, CI green. | PR approval only (no manual playtest needed). |
| **Phase 2: Blender Modular Dungeon Kit (Batch 1)** | Build first-pass Clean Stylized Dark Fantasy Nordic-ruin modular kit in Blender (floors, walls, corners, arches, pillars, stairs, doors, torches, chests) + export `.glb` + render turntable previews. | `.glb` scale/bounds/snap/material validation. | **[USER ART PREVIEW]** Approve stylized dungeon look via rendered preview images. |
| **Phase 3: Skyrim Character Controller & Camera** | 1st-person primary + 3rd-person over-the-shoulder toggle, smooth movement, sprinting, jumping, stamina bar, interactive raycast reticle, and menu time-pause system. | Headless movement, collision, camera toggle, stamina & pause-freeze tests. | PR approval only. |
| **Phase 4: Procedural Nordic-Ruin Labyrinth** | Seeded multi-room 3D labyrinth generator placing modular kit pieces, lighting/torches, Entrance, hidden Staircase, 1 discoverable Safe Room, and 1 Boss Arena + Treasure Vault, plus Top Compass Bar. | 100-seed connectivity, placement, non-overlap, compass proximity & determinism tests. | PR approval only. |
| **Phase 5: Left/Right-Hand Combat & Blender Gear (Batch 2)** | Sword, shield, two-handed weapon, offensive/healing spells (Magicka), and bow (manual crosshair); Blender weapon/shield/spell-prop models + previews; unified damage/armor/stamina pipeline. | Equip combos, melee/block/stamina, spell/magicka, bow projectile & damage math tests. | **[USER ART PREVIEW]** Approve weapons/gear renders. |
| **Phase 6: Enemies, AI, Safe Rooms & Boss Arena (Batch 3)** | 2–3 distinct Blender enemies + 1 Floor Boss with animations; 3D navmesh AI, Safe Room enemy repulsion, Boss Arena door-seal on entry & Treasure Vault unlock on defeat. | AI aggro/repulsion, boss seal/unlock lifecycle, combat-death trigger tests. | **[USER ART PREVIEW]** Approve enemy & boss renders. |
| **Phase 7: Looting, Inventory, Vendor & Sponsored/Mythic Loot** | Interactive chests/corpses/containers, Skyrim equipment slots, rarity-scaled affixes + absurd Sponsored/Mythic items, Inventory UI (with pause), Safe Room Vendor trading, and Dungeon AI popup banners + procedural SFX. | Loot table/affix roll tests, equip stat recalculation, vendor economy & banner trigger tests. | PR approval only. |
| **Phase 8: 5-Day Collapse Timer, Snapshot Reset & Save-and-Quit** | 5 in-game day floor timer (~30 min/day configurable), Floor-Entry Snapshot reset on collapse or combat death, Save-and-Quit anytime, hidden staircase descent to Floor 2, and Debug/Audit Console shortcuts. | Timer countdown, collapse reset, death reset, snapshot integrity & save/load round-trip tests. | **[USER PLAYTEST — `v0.1` Vertical Slice!]** First full hands-on playtest of the complete Skyrim-meets-DCC floor loop. |

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
