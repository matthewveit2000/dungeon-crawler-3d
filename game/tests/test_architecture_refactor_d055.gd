extends GutTest
## Automated verification suite for the D-055 / FB-020 All-in-One Architectural Refactor:
## Verifies EntityStats, StatusComponent, CombatActor + ActorLocomotion + ActorBrain + AbilityScaling,
## GroundZone, Barrier, AbilityExecutor, CombatResolver, ViewmodelRig, RarityTable, FloorTheme,
## modular DataLoader, and zero gameplay / determinism drift.

const DT := 1.0 / 60.0


func _make_test_game() -> GameMain:
	var g := GameMain.new()
	g.run_seed = 20261118
	g.auto_load_save_on_ready = false
	g.save_path = "user://d055_refactor_test.json"
	g.test_mode = true
	add_child_autofree(g)
	return g


func test_entity_stats_unified_resistances_knockback_and_control() -> void:
	var stats := EntityStats.new({
		"max_health": 200.0,
		"armor": 15.0,
		"fire_res": 0.5,
		"poison_res": 1.0,
		"frost_res": -0.5,
		"knockback_res": 0.6,
		"paralysis_res": 0.5,
		"mass": 2.0,
	}, "elite")

	# Modifiers: additive + multiplicative + timed expiry
	stats.add_modifier("buff_armor", "armor", 10.0, 1.2, 1.0)
	assert_almost_eq(stats.get_stat("armor"), 30.0, 0.01, "(15 + 10) * 1.2 = 30 armor")
	stats.tick(1.1)
	assert_almost_eq(stats.get_stat("armor"), 15.0, 0.01, "timed modifier expires cleanly")

	# Elemental resistance resolution
	assert_almost_eq(stats.resolve_elemental_damage(40.0, "physical"), 40.0, 0.01, "physical bypasses elemental res")
	assert_almost_eq(stats.resolve_elemental_damage(40.0, "fire"), 20.0, 0.01, "50% fire_res halves fire damage")
	assert_almost_eq(stats.resolve_elemental_damage(40.0, "poison"), 0.0, 0.01, "100% poison_res grants immunity")
	assert_almost_eq(stats.resolve_elemental_damage(40.0, "frost"), 60.0, 0.01, "-50% frost_res is vulnerability")

	# Power-gated knockback & paralysis resolution
	var kb_weak := stats.resolve_knockback(10.0, 0.3)
	assert_true(bool(kb_weak["resisted"]), "low knockback_power is resisted by high knockback_res")
	var kb_strong := stats.resolve_knockback(10.0, 0.85)
	assert_false(bool(kb_strong["resisted"]), "high knockback_power overcomes knockback_res")
	assert_gt(float(kb_strong["impulse"]), 0.0)

	var cc_weak := stats.resolve_control("paralyze", 3.0, 0.25)
	assert_true(bool(cc_weak["resisted"]), "low control_power is resisted by paralysis_res")
	var cc_strong := stats.resolve_control("paralyze", 3.0, 0.8)
	assert_false(bool(cc_strong["resisted"]), "high control_power lands paralysis")
	assert_gt(float(cc_strong["duration"]), 1.0)

	# Legacy boss resistance equivalence (exact 0.35x impulse/duration for bosses)
	var boss_stats := EntityStats.from_enemy_def({"is_boss": true, "max_health": 1000.0, "armor": 20.0})
	assert_eq(boss_stats.power_tier, "boss")
	var boss_kb := boss_stats.resolve_knockback(10.0)
	assert_almost_eq(float(boss_kb["impulse"]), 3.5, 0.01, "legacy boss knockback stays 0.35x")
	assert_false(bool(boss_kb["interrupts"]), "legacy knockback never interrupts boss")
	var boss_stun := boss_stats.resolve_control("stun", 2.0)
	assert_almost_eq(float(boss_stun["duration"]), 0.7, 0.01, "legacy boss stun stays 0.35x")


func test_status_component_shared_across_player_and_enemies() -> void:
	var stats := EntityStats.new({"poison_res": 0.5, "paralysis_res": 0.0})
	var sc := StatusComponent.new()

	sc.apply("poison", {"dps": 10.0, "duration": 2.0, "stacks": 2}, stats)
	sc.apply("poison", {"dps": 10.0, "duration": 2.0, "stacks": 2}, stats)
	assert_true(sc.has("poison"))
	var tick_res := sc.tick(1.0, stats)
	assert_almost_eq(float(tick_res["dot_damage"]), 10.0, 0.01, "2 stacks * 10 dps * (1 - 0.5 poison_res) = 10")

	sc.apply("haste", {"speed": 1.4, "attack_speed": 1.25, "duration": 4.0}, stats)
	assert_almost_eq(sc.speed_mult(), 1.4, 0.01, "haste raises speed multiplier")
	sc.apply("root", {"duration": 2.0}, stats)
	assert_almost_eq(sc.speed_mult(), 0.0, 0.01, "root immobilizes movement")
	sc.apply("paralyze", {"duration": 2.5, "control_power": 0.5}, stats)
	assert_true(sc.is_incapacitated(), "paralyze incapacitates actor")
	sc.apply("invulnerable", {"duration": 2.0}, stats)
	assert_true(sc.is_invulnerable())
	assert_almost_eq(sc.damage_taken_mult(), 0.0, 0.001, "invulnerable reduces damage taken to 0")


func test_combat_actor_factions_locomotion_brain_and_ability_scaling() -> void:
	# AbilityScaling merges level-gated ability tiers without mutating base definition
	var edef := {
		"id": "test_splitter",
		"traits": [{"id": "split_on_death", "count": 2, "depth": 1}],
		"ability_tiers": [
			{"min_level": 4, "traits": [{"id": "split_on_death", "count": 3, "depth": 2}]},
			{"min_level": 7, "traits": [{"id": "splatter_zone", "radius": 2.5}]},
		],
	}
	var t1 := AbilityScaling.resolve_traits(edef, 1)
	assert_eq(int(t1["split_on_death"]["count"]), 2, "Lv 1 keeps base split count")
	assert_false(t1.has("splatter_zone"))
	var t4 := AbilityScaling.resolve_traits(edef, 4)
	assert_eq(int(t4["split_on_death"]["count"]), 3, "Lv 4 upgrades split count")
	assert_eq(int(t4["split_on_death"]["depth"]), 2, "Lv 4 upgrades split depth")
	var t8 := AbilityScaling.resolve_traits(edef, 8)
	assert_true(t8.has("splatter_zone"), "Lv 8 unlocks Tier 3 ability")
	assert_eq(AbilityScaling.active_tier_for_level(edef, 8), 3)

	# ActorBrain Utility-Scoring AI (Runebound Arcanist readiness)
	var spells := [
		{"id": "bolt", "role": "offense", "magicka_cost": 15.0, "min_range": 0.0, "max_range": 24.0, "priority": 1.0},
		{"id": "heal", "role": "heal", "magicka_cost": 20.0, "priority": 1.0},
		{"id": "blink", "role": "escape", "magicka_cost": 15.0, "min_range": 2.0, "priority": 1.0},
	]
	var low_hp_pick := ActorBrain.pick_utility_action({"hp_ratio": 0.25, "magicka": 50.0, "target_dist": 12.0, "target_in_los": true}, spells)
	assert_eq(str(low_hp_pick.get("id", "")), "heal", "low HP caster prioritizes heal")
	var close_pick := ActorBrain.pick_utility_action({"hp_ratio": 0.9, "magicka": 50.0, "target_dist": 2.5, "target_in_los": true}, spells)
	assert_eq(str(close_pick.get("id", "")), "blink", "cornered caster prioritizes escape")
	var range_pick := ActorBrain.pick_utility_action({"hp_ratio": 0.9, "magicka": 50.0, "target_dist": 14.0, "target_in_los": true}, spells)
	assert_eq(str(range_pick.get("id", "")), "bolt", "healthy caster at range picks offense")
	var oom_pick := ActorBrain.pick_utility_action({"hp_ratio": 0.2, "magicka": 5.0, "target_dist": 10.0, "target_in_los": true}, spells)
	assert_true(oom_pick.is_empty(), "out-of-magicka caster picks no spell")

	# Faction hostility on CombatActor
	var enemy_a := CombatActor.new()
	add_child_autofree(enemy_a)
	enemy_a.faction = CombatActor.FACTION_ENEMY
	assert_true(enemy_a.is_hostile_to(CombatActor.FACTION_PLAYER))
	assert_true(enemy_a.is_hostile_to(CombatActor.FACTION_ALLY))
	assert_false(enemy_a.is_hostile_to(CombatActor.FACTION_ENEMY))
	var summon_a := CombatActor.new()
	add_child_autofree(summon_a)
	summon_a.faction = CombatActor.FACTION_ALLY
	assert_true(summon_a.is_hostile_to(CombatActor.FACTION_ENEMY))
	assert_false(summon_a.is_hostile_to(CombatActor.FACTION_PLAYER))


func test_ground_zone_and_one_way_barrier_primitives() -> void:
	var game := _make_test_game()
	await get_tree().process_frame
	game.set_physics_process(false)
	game.run_console_command("teleport combat")
	game.test_clear_enemies()

	var pos := game.player.global_position + Vector3(3.0, 0.0, 0.0)
	var e := game.spawn_enemy("draugr_raider", pos, -1, "gz_e", {}, 1)
	var start_hp := e.current_health
	var zone := game.spawn_ground_zone({
		"id": "poison_pool",
		"radius": 3.0,
		"duration": 2.0,
		"tick_interval": 0.5,
		"damage": 12.0,
		"damage_type": "poison",
		"status_kind": "poison",
		"status_params": {"dps": 4.0, "duration": 3.0, "stacks": 2},
		"affects_factions": ["enemy"],
		"color": "#3ad840",
	}, pos)
	var hits := zone.step_zone(0.55, [e, game.player])
	assert_eq(hits, 1, "ground zone affects enemy faction only, not player")
	assert_lt(e.current_health, start_hp, "ground zone deals poison damage")
	assert_true(e.has_status("poison"), "ground zone applies poison status")

	# One-Way Front Shield (IDEA-012) vs Solid Temporary Wall (IDEA-006)
	var one_way := game.spawn_barrier({
		"id": "aegis_curtain",
		"owner_faction": CombatActor.FACTION_PLAYER,
		"one_way_for_owner_projectiles": true,
		"allowed_projectile_kinds": ["spell", "arrow"],
		"duration": 5.0,
		"max_health": 100.0,
	}, pos + Vector3(0.0, 0.0, 2.0))
	assert_true(one_way.allows_projectile(true, "spell"), "player spells pass through one-way shield")
	assert_true(one_way.allows_projectile(true, "arrow"), "player arrows pass through one-way shield")
	assert_false(one_way.allows_projectile(false, "spell"), "enemy spells are blocked by one-way shield")

	var wall := game.spawn_barrier({
		"id": "stone_wall",
		"one_way_for_owner_projectiles": false,
		"duration": 5.0,
		"max_health": 50.0,
	}, pos + Vector3(0.0, 0.0, 4.0))
	assert_false(wall.allows_projectile(true, "arrow"), "solid wall blocks all projectiles")
	assert_true(wall.take_damage(60.0), "wall breaks when damage exceeds max_health")


func test_ability_executor_enrage_radial_fling_and_invulnerability() -> void:
	DataLoader.ensure_loaded()
	var game := _make_test_game()
	await get_tree().process_frame
	game.set_physics_process(false)
	game.run_console_command("teleport combat")
	game.test_clear_enemies()

	var exec := AbilityExecutor.new()
	var enrage_def := DataLoader.get_ability_def("enrage")
	assert_false(enrage_def.is_empty(), "abilities.json defines enrage")
	var r1 := exec.execute(enrage_def, {
		"magicka": 100.0,
		"stamina": 100.0,
		"stats": game.player.entity_stats,
		"status_comp": game.player.status_comp,
	})
	assert_true(bool(r1["ok"]), "enrage executes cleanly")
	assert_true(game.player.has_status("enrage"), "player gains enrage status")
	var r1_cd := exec.execute(enrage_def, {"magicka": 100.0, "stamina": 100.0})
	assert_false(bool(r1_cd["ok"]), "cooldown prevents immediate re-use")
	assert_eq(str(r1_cd["reason"]), "on_cooldown")

	# Brief Invulnerability blocks damage on PlayerController
	var invuln_def := DataLoader.get_ability_def("aegis_invulnerability")
	var r2 := exec.execute(invuln_def, {
		"magicka": 100.0,
		"stamina": 100.0,
		"stats": game.player.entity_stats,
		"status_comp": game.player.status_comp,
	})
	assert_true(bool(r2["ok"]))
	var hp_before := game.player.health
	var dmg_res := game.player.take_damage(50.0)
	assert_almost_eq(float(dmg_res["final_damage"]), 0.0, 0.001, "invulnerable player takes zero damage")
	assert_almost_eq(game.player.health, hp_before, 0.001)

	# Radial Knockback Fling pushes nearby enemy and deals damage
	var e := game.spawn_enemy("draugr_raider", game.player.global_position + Vector3(2.5, 0.1, 0.0), -1, "fling_e", {}, 1)
	var e_hp := e.current_health
	var fling_def := DataLoader.get_ability_def("shockwave_fling")
	var r3 := exec.execute(fling_def, {
		"magicka": 100.0,
		"stamina": 100.0,
		"stats": game.player.entity_stats,
		"origin": game.player.global_position,
		"targets": [e],
	})
	assert_true(bool(r3["ok"]))
	assert_eq(int(r3["affected"]), 1)
	assert_gt(e._knock_vel.length(), 2.0, "radial fling knocks nearby enemy back")
	assert_lt(e.current_health, e_hp, "radial fling damages nearby enemy")


func test_rarity_table_floor_theme_and_modular_data_loader() -> void:
	DataLoader.reload_all()
	assert_false(DataLoader.get_rarities_pack().is_empty(), "rarities.json loads")
	assert_false(DataLoader.get_themes_pack().is_empty(), "themes.json loads")
	assert_false(DataLoader.get_abilities_pack().is_empty(), "abilities.json loads")

	# FloorTheme inheritance: ember_catacombs inherits kit/dressing from nordic_catacombs + overrides palette
	var t1 := FloorTheme.resolve(DataLoader.get_floor_config(1))
	var t2 := FloorTheme.resolve(DataLoader.get_floor_config(2))
	assert_eq(t1.id, "nordic_catacombs")
	assert_eq(t2.id, "ember_catacombs")
	assert_eq(t2.kit_dir, t1.kit_dir, "ember_catacombs inherits kit_dir from nordic_catacombs")
	assert_ne(t2.torch_color, t1.torch_color, "ember_catacombs uses its own ember torch palette")
	assert_false(t2.dressing_for_role("combat").is_empty(), "ember_catacombs inherits room dressing")

	# RarityTable scarcity & multipliers
	var rar_pack := DataLoader.get_rarities_pack()
	var common_w := RarityTable.effective_enemy_spawn_weight({"rarity": "common"}, rar_pack)
	var rare_w := RarityTable.effective_enemy_spawn_weight({"rarity": "rare"}, rar_pack)
	assert_lt(rare_w, common_w, "rarer enemies have lower spawn weight")
	assert_gt(RarityTable.enemy_reward_multiplier({"rarity": "epic"}, rar_pack), 1.5, "rarer enemies yield higher rewards")


func test_zero_gameplay_drift_determinism_and_module_wiring() -> void:
	var game := _make_test_game()
	await get_tree().process_frame
	assert_not_null(game.combat_resolver, "GameMain owns CombatResolver")
	assert_not_null(game.ground_zones_root, "GameMain owns GroundZones container")
	assert_not_null(game.barriers_root, "GameMain owns Barriers container")
	assert_not_null(game.dungeon_builder.active_theme, "DungeonBuilder resolved FloorTheme")
	assert_not_null(game.player.viewmodel, "PlayerController owns ViewmodelRig")
	assert_not_null(game.player.entity_stats, "PlayerController owns EntityStats")
	assert_not_null(game.player.status_comp, "PlayerController owns StatusComponent")
	assert_not_null(game.player.fp_right_anchor, "ViewmodelRig exposes fp_right_anchor")
	assert_not_null(game.player.tp_visual, "ViewmodelRig exposes tp_visual")

	# Deterministic loot & floor replay sanity
	var r_a := SeededRng.new(777)
	var r_b := SeededRng.new(777)
	var l_a := LootGenerator.roll_loot(DataLoader.get_items_pack(), DataLoader.get_rarities_pack(), 1, r_a, "", true)
	var l_b := LootGenerator.roll_loot(DataLoader.get_items_pack(), DataLoader.get_rarities_pack(), 1, r_b, "", true)
	assert_eq(str(l_a["id"]), str(l_b["id"]), "identical seed produces identical item id")
	assert_eq(int(l_a["value"]), int(l_b["value"]), "identical seed produces identical item value")
