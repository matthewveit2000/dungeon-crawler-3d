# User Feedback Log

> **Status:** `Living document — append-only` (rule `D-045`, see [`AGENTS.md`](../AGENTS.md) §4).
> Every comment, request, bug report or direction the User (Product Owner) gives is recorded here **before** work
> starts, with what was done and what now guards it against regressing. Before changing any system, search this
> log for it and make sure the change keeps every earlier request satisfied. Earlier pre-production alignment
> answers live in [`ALIGNMENT_LOG.md`](ALIGNMENT_LOG.md).

**How to add an entry:** next `FB-###` id, date, the User's words (verbatim or as close as possible), then each
distinct request as its own line with its status (`Done`, `Partial`, `Open`, `Process`), the decision it produced
(`D-###`), and the regression guard (automated test, or the manual check if it cannot be automated).

---

## 2026-11-20

### FB-001 — "Check all PRs is everything merged to main?"
- Process: audited PRs and branches. PR #4 (D-037 animation overhaul) was open. — `Process`

### FB-002 — "Merge it yourself"
- Process: merged PR #4 after confirming CI green and clean mergeability. — `Process`

### FB-003 — "Does deleting other branches lose their history forever? If not delete all merged branches"
- Answered (merged history lives in `main`); the cloud session cannot delete remote branches, so the User was given the steps. — `Process`

### FB-004 — "I want the main gimmick of the game to be a challenge to see if the player can power scale enough by end of the floor. They should always be able to reset their progress to any floor and each floor will ramp up in difficulty so it's important that they get good gear and level up heavily in between floors and not get behind"
- Core gimmick = power-scaling race; floors ramp up in difficulty. — `Done (design)` — `D-038`
- Always able to reset progress to the start of any floor reached. — `Open` (designed, not yet implemented)
- Guard: `D-038` in `AGENTS.md` core rules, `GAME_DESIGN.md` §3.1.

### FB-005 — "Every play through should use the same seed so the layout, loot, etc should be the same if they die and the floor resets"
- Fixed seed; identical layout and loot on every attempt; loot independent of opening order. — `Done` — `D-039`
- Guard: `test_d039_floor_reset_replays_identical_layout_and_loot`, `test_d039_container_loot_does_not_depend_on_open_order`.

### FB-006 — First-person animations: "the battle axe is facing side ways, the sword swings does feel like they are swinging away from the player, the hands are off, the hand is facing the player when casting spells, the bow draw looks off, etc. take a pass at reviewing all animations with a focus on the first person ones … from the perspective of the player. Do this in a branch and give me videos"
- Battleaxe edge forward, both fists on the wraps. — `Done` — `D-040`
- Sword cuts travel out away from the player. — `Done` — `D-040`
- Hands/forearms anatomically placed (arm IK, upper-arm sleeves). — `Done` — `D-040`
- Spell palms face the target. — `Done` — `D-040`
- Bow draw (nock on draw, anchor at cheek, arrow along the sightline). — `Done` — `D-040`
- Third-person animations reviewed (no changes needed). — `Done`
- Guard: `game/tests/test_fp_viewmodel.gd` (6 tests), `test_power_attack_charge_continuity_and_bow_sightline_alignment`; manual: `./scripts/fp-pose-probe.sh`, `./scripts/record-anim-review.sh`.

### FB-007 — "merge to main and then give me the command line to merge my local file"
- Merged; gave `git checkout main` / `git pull origin main` (+ `git stash` for Godot import churn). — `Process`

### FB-008 — "Merge everything"
- Merged PR #6 (D-039) after resolving doc conflicts. — `Process`

### FB-009 — "The game is too dark. Put way more light sources around. Merge everything to main once you're done."
- Denser, brighter torches; corner braziers; room fill lights; brighter ambient/exposure; less fog. — `Done` — `D-041`
- Guard: `test_dungeon_is_dressed_and_lit` (dense torches, braziers).

### FB-010 — "The boss loot room is not accessible even after beating the boss. Also I want the floor to feel larger and more dense."
- Vault access after the boss: not reproducible; vault landmark + self-heal added. — `Done` — `D-042`
- Larger, denser floors. — `Done` (superseded by FB-012) — `D-042`, `D-044`
- Guard: `test_vault_is_walkable_after_boss_defeat`.

### FB-011 — "The boss loot room is still blocked and now I can't leave the room either. Merge once done"
- Boss gates open first on boss death; watchdog opens gates whenever the boss is gone; arena only seals around a living boss; open gates leave all collision layers. — `Done` — `D-043`
- Guard: `test_real_boss_fight_opens_both_gates`, `test_gates_open_even_if_the_boss_vanishes_without_a_death_callback`.

### FB-012 — "Make the world way bigger. The player should not realistically be able to explore even 25% of the map in one run. Space out staircases, boss rooms, etc so they're sparse but so the player can still find them. Make sure this is also noted in your documentation"
- Vast floors (336x336 tiles, ~650 rooms); 25% takes longer than the floor clock allows. — `Done` — `D-044`
- Sparse landmarks (3 stairwells, boss + vault far away, 9 safe rooms), all reachable; compass far-sense. — `Done` — `D-044`
- Documented in `AGENTS.md`, vision, GDD, architecture, changelogs. — `Done`
- Guard: `game/tests/test_vast_floors.gd`.

### FB-013 — "Rings don't equip they just disappear, the game is too easy it should feel very hard at the beginning of floors and easier as the player scales their power in the floor, one handed items should be equipable to both hands (i.e. I should be able to duel wield spells, or have a spell and a shield, etc), the enemies should wonder and should attack at further distances, looting chests and bodies does not work in third person, the mini-map needs to lock onto the player, I want a test mode where I can spawn in anything including enemies, items, rooms, etc. I should able to do all game testing in this mode. Make sure now and going forward all comments I make are logged so they are can be referenced in the future and avoid regressing when making changes."
- Rings disappear instead of equipping. — `Done` — `D-046` — Guard: `test_rings_equip_into_visible_ring_slots_instead_of_vanishing`
- Very hard at the start of a floor, easier as the player scales within it. — `Done` — `D-046` — Guard: `test_floor_starts_very_hard_and_gets_easier_as_the_player_scales`
- Any one-handed item in either hand (dual spells, spell + shield, …). — `Done` — `D-046` — Guard: `test_one_handed_items_go_in_either_hand`
- Enemies wander and engage from further away. — `Done` — `D-046` — Guard: `test_enemies_wander_and_engage_from_further_away`
- Looting chests and bodies works in third person. — `Done` — `D-046` — Guard: `test_looting_works_in_third_person`
- Map locks onto / follows the player (map centred on the player + new corner minimap). — `Done` — `D-046` — Guard: `test_map_and_minimap_are_locked_on_the_player`
- Test Mode: spawn enemies, items, rooms, props; all game testing possible there. — `Done` — `D-047` — Guard: `test_test_mode_can_spawn_anything_and_never_touches_the_real_save`
- Log every comment, now and going forward, and check the log to avoid regressions. — `Done` — `D-045` (this file + `AGENTS.md` §4 rule)
