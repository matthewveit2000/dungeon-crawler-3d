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
| **Phase 2: Blender Modular Dungeon Kit (Batch 1)** | `Built + Visual Polish` | 21 sculpted, PBR-textured Nordic-ruin `.glb` models in Blender 4.5.9 LTS (walls, pillars, archways, braziers, carpets, banners, sanctuary beacon, merchant stall, rune dais, chests, map board) + Cycles studio previews (`art/previews/batch1_kit_room.png`, `batch1_props.png` — rebuilt in Visual Overhaul v2). | `.glb` bounds/header/triangle/preview validation (`scripts/validate-assets.py`). | **[USER ART PREVIEW]** Review `batch1_kit_room.png` & `batch1_props.png`. |
| **Phase 3: Skyrim Character Controller & Camera** | `Built + Visual Polish` | 1st-person primary + `V` 3rd-person over-the-shoulder toggle with raycast wall-collision pullback, compact viewmodel framing, alternating 2-hit swings + blade trail, bow draw animation, smooth bob/FOV kick, and menu time-pause freeze. | Headless camera toggle, stamina, menu pause-freeze & live visual QA capture. | PR approval only. |
| **Phase 4: Hybrid Procedural + Handcrafted Labyrinth (`D-029`)** | `Built + Visual Polish` | Seeded multi-room 3D labyrinth weaving handcrafted custom rooms from `setpieces.json` (Entrance Antechamber, Safe Room Sanctuary, Boss Arena, Gilded Vault, Descent Stairwell) into procedural corridors + 6-light proximity lighting & Top Compass Bar. | 100-seed connectivity, setpiece placement, compass bearing & determinism tests. | PR approval only. |
| **Phase 5: Left/Right-Hand Combat & Blender Gear (Batch 2)** | `Built + Visual Polish` | Sword+shield, two-handed greatsword, offensive/healing spells (Magicka), and bow (hold/release draw); 11 sculpted PBR Blender weapon/gear `.glb` models + `batch2_weapons_gear.png`. | Equip combos, melee/kill/block/stamina, spell/magicka, bow projectile & damage math tests. | **[USER ART PREVIEW]** Review `batch2_weapons_gear.png`. |
| **Phase 6: Enemies, AI, Safe Rooms & Boss Arena (Batch 3)** | `Built + Visual Polish` | 6 sculpted PBR Blender actor `.glb` models (Player, Draugr Raider, Bone Archer, Goblin Glory-Hound, Iron Warden Boss, Vendor) + `batch3_characters.png` (rigged & animated in v2); Safe Room repulsion & Boss Gate seal/Vault unlock. | AI aggro/repulsion, boss seal/unlock lifecycle, combat-death trigger tests. | **[USER ART PREVIEW]** Review `batch3_characters.png`. |
| **Phase 7: Looting, Dark-Fantasy UI, Vendor & Tutorial Mode (`D-030`)** | `Built + Visual Polish` | Obsidian-and-gold dark-fantasy HUD/Inventory/Vendor/Pause menus (`UiTheme`), toggleable low-friction contextual Tutorial Mode (`tutorials.json` + `TutorialSystem`), rarity-scaled affixes + legendary gear, Safe Room Vendor trading, Dungeon AI toasts & 12 WAV SFX. | Loot table/affix roll, corpse/chest/vendor interaction, tutorial lifecycle & UI visual QA. | PR approval only. |
| **Phase 8: 5-Day Collapse Timer, Snapshot Reset & Visual QA (`D-028`)** | `Built + Visual Polish` | 5 in-game day floor timer (~30 min/day configurable), Floor-Entry Snapshot reset on collapse or combat death, Save-and-Quit anytime, zero-preview Floor 2 descent, `` ` `` Audit Console, and 11-shot + video live Player-POV Visual QA harness (`scripts/run-visual-qa.sh`). | Timer countdown, collapse reset, death reset, Floor 2 descent, snapshot & save/load round-trip (39 tests, 5,450 assertions). | **[USER PLAYTEST — `v0.1` Visual Overhaul!]** Hands-on playtest via [`docs/PLAYTEST_GUIDE.md`](PLAYTEST_GUIDE.md). |

---

### Visual Overhaul v2 (`D-031`–`D-036`) — `Built — Awaiting User Review`

Requested by the User after reviewing v0.1: every model, texture, animation, HUD element and menu rebuilt to an "AA-indie" bar, plus a quality-of-life suite (title screen, settings & key rebinding, accessibility, map, inventory comparisons). **[USER PLAYTEST + ART REVIEW]** via the PR screenshots and [`docs/PLAYTEST_GUIDE.md`](PLAYTEST_GUIDE.md).

---

## Future Milestones (High-Level — Refined After `v0.1` Playtest)

- **Milestone 2 (`v0.2` — Multi-Floor Variety & Deep Progression):**
  - Distinct themed floors (e.g., *The Ember Tier*, *The Permafrost*, *The Rot Gardens*, *The Foundry*) via modular material/lighting/prop swaps (still zero staircase previews!).
  - Full Hybrid Progression UI: Character Level-Up, Attribute allocation, branching Skill/Perk Trees, and Skyrim use-to-improve proficiency tracking.
  - Underground Towns with area maps and Stash/Rest spots.
- **Milestone 3 (`v0.3` — Content Expansion & Visual Polish):**
  - Expanded enemy roster, mini-bosses, traps/levers, deep legendary-effect affix catalog, and more of the dungeon's own snark.
  - Blender art polish pass (higher-detail textures, lighting atmosphere, animations, VFX).
- **Milestone 4 (`v1.0` — Release & Packaging):**
  - Full balance & performance pass, optional open-source Dungeon AI TTS voice, optional Web export evaluation, and packaged Windows/Mac/Linux desktop builds.
