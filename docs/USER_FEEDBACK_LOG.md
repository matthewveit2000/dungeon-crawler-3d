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

### FB-014 — "The chest and shield have holes in them. i.e. you can see inbetween the wood planks. The enemies get stuck on things. make their path finding better. Replace the rarities with normal RPG rarities. some of the weapons are still facing side ways in FPV. Note that blades face away from the player. Duel welding animations are broken in third person view. The item menu cuts off the side of the screen in some scenarios. maybe when I have too many items. The bow animation is broken in third person. The spell casting animation is broken in third person"
- Chest and shield: no see-through gaps between planks (inner linings / backing board). — `Done` — `D-048` — Guard: manual visual QA (props/gear close-ups)
- Enemies path around walls and props instead of getting stuck (A* + unstick). — `Done` — `D-048` — Guard: `test_enemy_paths_around_walls_to_reach_the_player`, `test_enemy_unsticks_itself_from_props_in_the_way`, `test_enemy_faces_where_it_walks_while_chasing`
- Normal RPG rarities (Common / Uncommon / Rare / Epic / Legendary). — `Done` — `D-048` — Guard: `test_rarities_are_the_normal_rpg_tiers`, `test_old_saves_with_sponsored_items_become_legendary`
- **Standing rule: blades face away from the player in first person** (edge forward, never the flat of a blade sideways at rest). — `Done` — `D-048` — Guard: `test_blades_face_away_from_the_player_at_rest`, `test_battleaxe_edge_faces_forward_at_rest_and_leads_the_chop`
- Dual-wield animations in third person (left blade swings, both on guard). — `Done` — `D-048` — Guard: `test_third_person_dual_wield_swings_the_hand_that_attacks`
- Item (inventory) menu never cuts off the screen side, however many items (cause: Interface Scale shrinking the layout space). — `Done` — `D-048` — Guard: `test_menus_fit_a_720p_screen` (incl. 150 % interface scale with a full bag)
- Bow animation in third person (draw-up clip, aim camera over the shoulder). — `Done` — `D-048` — Guard: `test_third_person_bow_draws_up_and_the_camera_frames_the_aim`
- Spell-casting animation in third person (casting hand thrusts; both for dual spells). — `Done` — `D-048` — Guard: `test_third_person_spells_cast_from_the_hand_holding_them`

### FB-015 — "I want the game to feel like you are constantly discovering new weapons, spells, armor, etc. I don't want generic tiered loot where one tier is the same. I want a large variety of loot with higher rarities having more powerful and unique powers. For now I want all loot to be common but with the ability to level up as you use it and later on we will add more interesting higher rarity loot with more unique and powerful abilities. As you level up loot it should not only come more powerful but it should gain new abilities, i.e. shock may gain the ability to chain to multiple mobs, fire may gain the ability to explode, maybe single hand weapons gain a dash attack and duel wield weapons gain a block, maybe bows gain a slow time on draw, things like this. I want the player to want to invest time into each weapon, skill, etc to see what new abilities they will gain. Same concept goes for enemies I want enemies to be unique like you are always discovering a new interesting enemy. I want enemies to have different levels with each type having a minimum and maximum possible level. We should add a bestiary to the game. Make these changes and document this idea."
- Discovery-driven loot: a large variety of distinct weapons, spells and armor instead of generic tiers (38 items, 21 new models, per-item drop weights). — `Done` — `D-049` — Guard: `test_world_loot_is_all_common_and_varied`, `test_every_gear_item_has_its_own_mastery_track`
- For now all loot drops Common; higher rarities (more powerful, unique powers) come later. — `Done` (higher rarities `Open`, future) — `D-049` — Guard: `test_world_loot_is_all_common_and_varied`
- Item mastery: every item levels up with use, growing stronger and unlocking new abilities (e.g. shock chains, fire explodes, one-handed dash attack, dual-wield block, bow slows time on draw). — `Done` — `D-049` — Guard: `test_mastery_grows_stats_and_unlocks_abilities_with_use`, `test_items_earn_mastery_from_hits_and_kills_in_game`, `test_shock_learns_to_chain_to_multiple_enemies`, `test_fire_learns_to_explode`, `test_one_handed_lunge_and_dual_wield_cross_guard`, `test_bow_learns_to_slow_time_on_full_draw`, `test_axe_bleeds_and_statuses_tick`, `test_item_card_shows_mastery_and_hides_undiscovered_abilities`
- Unique enemies: many distinct enemy types, each with its own minimum/maximum level. — `Done` — `D-049` — Guard: `test_enemy_types_have_level_ranges_and_floors_introduce_new_ones`, `test_spawned_levels_scale_stats_and_replay_identically`, `test_enemy_traits_make_each_type_play_differently`
- Bestiary in game. — `Done` — `D-049` — Guard: `test_bestiary_records_discoveries_and_survives_floor_resets`, `test_bestiary_tab_lists_every_creature_with_unknowns_hidden`
- Document the idea. — `Done` — `D-049` (`GAME_DESIGN.md` §6.1–6.2, `AGENTS.md` core rules, decision log, changelogs)

### FB-016 — "merge to main"
- Merged PR #15 (FB-015 / `D-049`) into `main` after CI passed (merge commit `295f1c7`). — `Process`

### FB-017 — "note that I always want you edit main directly. Just keep good notes so we can back track if needed"
- **Standing rule: work directly on `main`** (no feature branches or pull requests). — `Done` — `D-050`
- Keep good notes for backtracking: new `docs/WORK_LOG.md` (every change with commit SHA(s) and how to revert), plus `CHANGELOG.md` / domain changelogs and this log. — `Done` — `D-050`
- Guard: `AGENTS.md` workflow rule, `docs/ROLES_AND_GOVERNANCE.md` §6, `.cursorrules`, Copilot instructions.

### FB-018 — "You're going to help me brainstorm and document a variety of enemies, items, etc to put in the game. Enemies: As enemies level up their unique abilities should upgrade. (i.e. spells get better, split more time, etc) - I want an enemy that flys towards you and explodes on impact - I want an enemy that splits when you kill it - I want an enemy that casts spells. The enemy should spawn with a couple random spells and its AI should have a way of determining how to use them - I want an enemy that is tanky - I want an enemy throws rocks at you and runs away quickly when you get too close (goblin). Magic tomes: - I want a seeking missle. as it levels up the number of missle increases and as it levels up more each missle gets a different ability - I want a variety of magic tomes that summon mods to fight on your side. As this levels up you can summon higher levels and higher quantities of mobs - I want a spell that puts poinsion on the ground that damages enemies that walk on it - I want a spell that speeds to player up for a period - I want a spell that paralyzes enemies (as it levels up it paralyzes for longer and effects higher power enemies). Items: - I want a one handed weapon called the swift blade that launches the player forward before swinging. As it levels up it goes further and the launch ability has a faster cool down. - I want a two handed axe that knocks enemies back. as it level up it knocks them back further and works on more powerful enemies. I want it noted that a core idea of this game will be to build unique spells, enemies, weapons, areanas, etc so we need to keep the game as flexible as possible. All entities should have a variety of stats that help us manage the abilities (i.e. knockback resistance, poison resistance, fire resistance, mana, stamina, armor, etc). You are the technical lead so I will let you determine how to implement things but I want this noted so we keep it in mind when building the game. Don't edit the game itself just edit the documentation"
- Core architectural principle: keep the game maximally flexible & data-driven for continuously adding unique spells, enemies, weapons, arenas, and hazards; give all entities a rich unified stat & resistance sheet (knockback resistance, poison/fire/frost/shock/paralysis resistance, mana, stamina, armor, power tier, etc.). — `Done (design)` — `D-051` — Guard: `AGENTS.md`, `docs/ARCHITECTURE.md` §3, `docs/GAME_DESIGN.md` §6.3, `docs/CONTENT_CATALOG.md` §1.
- Enemies upgrade their unique abilities as they level up (not just HP/damage). — `Done (design)` / `Open (impl)` — `D-052`
- Planned enemy: Flying exploder (flies at player and explodes on impact, scaling with level). — `Done (design)` / `Open (impl)` — `D-052`
- Planned enemy: Splitter (splits on death; more splits/depth at higher levels). — `Done (design)` / `Open (impl)` — `D-052`
- Planned enemy: Adaptive spellcaster (spawns with 2+ seeded random spells and tactical AI that evaluates when/how to use them; upgrades spells with level). — `Done (design)` / `Open (impl)` — `D-052`
- Planned enemy: Tanky juggernaut (high HP/armor/knockback & CC resistance, scaling defensive abilities). — `Done (design)` / `Open (impl)` — `D-052`
- Planned enemy: Rock-throwing skirmisher goblin (throws rocks from range and sprints away when approached). — `Done (design)` / `Open (impl)` — `D-052`
- Planned magic tome: Seeking Missile (more missiles per level; higher levels give each missile a distinct secondary ability). — `Done (design)` / `Open (impl)` — `D-052`
- Planned magic tomes: Summoning family (summon allied mobs; mastery increases summon level and quantity). — `Done (design)` / `Open (impl)` — `D-052`
- Planned magic tome: Poison Ground (ground hazard zone damaging enemies that walk on it). — `Done (design)` / `Open (impl)` — `D-052`
- Planned magic tome: Haste / Swiftness (temporarily boosts player speed). — `Done (design)` / `Open (impl)` — `D-052`
- Planned magic tome: Paralyze (immobilizes enemies; mastery increases duration and max enemy power/resistance affected). — `Done (design)` / `Open (impl)` — `D-052`
- Planned item: Swift Blade (1H weapon that launches player forward before swinging; mastery increases lunge distance and lowers cooldown). — `Done (design)` / `Open (impl)` — `D-052`
- Planned item: Knockback 2H Axe (heavy 2H axe that knocks enemies back; mastery increases knockback distance and overcomes higher enemy knockback resistance / power tiers). — `Done (design)` / `Open (impl)` — `D-052`
- Documentation-only pass (zero edits to `game/` or `art/`). — `Done`


## 2026-11-21

### FB-022 — Feedback round (13 requests)
> "Enemies seem to have their life completely go away at around half health. I want way more enemies but make them less powerful to keep it scaled. Lets fully remove all direct references to dungeon crawler carl. The only thing I want kept is the dark atmosphere with goofy enemies and themes. Get rid of all references to it being a show to the syndicate, etc. I want a hot bar for weapons and consumables. enemies seem to walk in a stairstep pattern towards me. they should walk straight towards me unless it is part of their character (i.e. evading, running way, etc). I want each item to tell me what has to happen to level it up. I want a list of all temporary status effects on the player to be visable with count downs. I want an easy way to power scale the game. I'm thinking every entity, item, etc should have a scaling number that we can move up or down to scale it correctly. Consumable, ingredients, etc should stack in your inventory. When buying/selling stackable items you should be able to set the amount you want to buy/sell. Saferooms should have maps of the surrounding area, it should update the players map showing them points of interest, treasure, etc. All items should have a level 1 ability. Make boss fights more common"
> Follow-up in the same round: "in addition to my comments earlier I want damage over time to be more visable"
- Enemy health bars emptied at ~half health (cause: billboarded bar quads ignore scale, so the fill only slid sideways). Now one shader-drawn bar reads the exact ratio. — `Done` — `D-057` — Guard: `test_enemy_health_bar_drains_exactly_with_health`
- Way more enemies, each less powerful to keep it scaled (2.5× count; ~0.42× health, ~0.55× damage, ~0.45× xp/gold; spawned only near the player). — `Done` — `D-057` — Guard: `test_floors_have_far_more_but_weaker_enemies`, `test_enemies_are_created_only_near_the_player`
- Fully remove direct *Dungeon Crawler Carl* references; keep only the dark atmosphere with goofy enemies and themes; no show / Syndicate / sponsors. — `Done` (game, data, art, living docs; append-only history logs keep their records) — `D-057` — Guard: `test_no_tv_show_or_sponsor_theme_left_in_the_game`, `test_old_saves_with_renamed_items_still_load`
- Hotbar for weapons and consumables (keys 1–8, assign from the inventory). — `Done` — `D-057` — Guard: `test_hotbar_equips_weapons_and_uses_consumables`
- Enemies walk straight at the player instead of stair-stepping, unless it's their character (string-pulled paths; ranged kiting/fleeing unchanged). — `Done` — `D-057` — Guard: `test_enemies_walk_straight_at_the_player_across_open_ground`, `test_paths_are_string_pulled_into_straight_lines` (+ FB-014 pathfinding guards)
- Each item tells you what has to happen to level it up. — `Done` — `D-057` — Guard: `test_every_item_says_how_to_level_it_and_has_a_level_one_ability`
- Visible list of all temporary status effects on the player with countdowns. — `Done` — `D-057` — Guard: `test_status_effects_are_listed_with_countdowns`
- Easy power-scaling: a scaling number on every entity, item, etc. (`data/balance.json` globals × floor `power_scale` × per-enemy/per-item `power_scale`). — `Done` — `D-057` — Guard: `test_power_scale_knobs_scale_entities_and_items`
- Consumables, ingredients, etc. stack in the inventory (8 new consumables/ingredients with Blender models). — `Done` — `D-057` — Guard: `test_consumables_and_ingredients_stack_and_trade_in_any_amount`
- Buy/sell any amount of a stack at vendors (quantity box, −/+/Max). — `Done` — `D-057` — Guard: same test
- Safe rooms have maps of the surrounding area that update the player's map with points of interest and treasure (and champion lairs, landmarks). — `Done` — `D-057` — Guard: `test_safe_rooms_reveal_the_surrounding_area_and_points_of_interest`, `test_interactive_chest_area_map_vendor_and_audit_console_shortcuts`
- All items have a level-1 ability. — `Done` — `D-057` — Guard: `test_every_item_says_how_to_level_it_and_has_a_level_one_ability`
- Boss fights more common (champion lairs: titled mini-bosses with a boss health bar, roar, enrage and guaranteed loot). — `Done` — `D-057` — Guard: `test_champion_lairs_make_boss_fights_common`
- Damage over time more visible (burning / bleeding / poison / frost effects on the body, coloured tick numbers, status line under the name, DoT-coloured health bar). — `Done` — `D-057` — Guard: `test_damage_over_time_shows_numbers_effects_and_a_status_line`
- Regression check: the FB-013 guard "very hard at the start of a floor, easier as you scale" now measures a typical pack (two weak draugr ≈ the old single draugr; three overwhelm a fresh player) and still requires the same pack to become clearly easier once scaled. — `Done` — Guard: `test_floor_starts_very_hard_and_gets_easier_as_the_player_scales`
