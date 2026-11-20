extends GutTest
## Regression guards for User feedback FB-015 (docs/USER_FEEDBACK_LOG.md, decision D-049): discovery-driven loot
## (large variety, all Common for now), item mastery that grows stats and unlocks item-specific abilities,
## unique enemies with per-type level ranges, and the Bestiary.

const DT := 1.0 / 60.0

var game: GameMain = null


func _make_game(seed_val: int = 20261118) -> GameMain:
	var g := GameMain.new()
	g.run_seed = seed_val
	g.auto_load_save_on_ready = false
	g.save_path = "user://fb015_test.json"
	g.test_mode = true
	add_child_autofree(g)
	return g


func _equip(item_id: String, hand: String = "") -> Dictionary:
	game.test_give_item(item_id, "common")
	game.player.equip_from_inventory(game.player.inventory.size() - 1, hand)
	var slot := hand if not hand.is_empty() else ItemInfo.slot_for(DataLoader.get_item_def(item_id))
	return game.player.equipment.get(slot, {})


func _master(item: Dictionary, level: int) -> void:
	while MasterySystem.level_of(item) < level:
		MasterySystem.add_xp(item, float(MasterySystem.xp_to_next(MasterySystem.level_of(item))) + 0.01)


func _face_point(p: Vector3) -> void:
	var pl := game.player
	var d := p - pl.global_position
	pl.rotation.y = atan2(-d.x, -d.z)
	pl.pitch_rad = 0.0
	pl.head_pivot.rotation.x = 0.0


func _enemy_ahead(dist: float, side: float = 0.0, id: String = "draugr_raider") -> EnemyActor:
	var pl := game.player
	var fwd := -pl.global_transform.basis.z
	fwd.y = 0.0
	var right := Vector3(-fwd.z, 0, fwd.x)
	var e := game.spawn_enemy(id, pl.global_position + fwd.normalized() * dist + right * side + Vector3(0, 0.1, 0), -1, "", {}, 1)
	e.state = EnemyActor.AiState.IDLE
	return e


func _setup_arena() -> void:
	game = _make_game()
	await get_tree().process_frame
	game.set_physics_process(false)
	game.run_console_command("teleport combat")
	game.test_clear_enemies()
	game.player.equipment.clear()
	game.test_toggle("god")


# --- Loot variety, all Common ---------------------------------------------------------------------------------
func test_world_loot_is_all_common_and_varied() -> void:
	DataLoader.ensure_loaded()
	var ids := {}
	for i in range(400):
		var forced: String = ["", "rare", "legendary", "epic"][i % 4]
		var it := LootGenerator.roll_loot(DataLoader.get_items_pack(), DataLoader.get_affixes_pack(), 1, SeededRng.new(1000 + i),
			LootGenerator.world_rarity(DataLoader.get_affixes_pack(), forced), true)
		assert_eq(str(it.get("rarity", "")), "common", "every world drop is Common for now (%s)" % str(it.get("id")))
		assert_true((it.get("affixes", []) as Array).is_empty(), "no generic affix rolls")
		assert_ne(str(it.get("forced_rarity", "")), "legendary", "sponsored uniques stay out of the pool")
		ids[str(it["id"])] = true
	assert_gte(ids.size(), 28, "a large variety of different items drops (%d kinds)" % ids.size())


func test_every_gear_item_has_its_own_mastery_track() -> void:
	DataLoader.ensure_loaded()
	var lib: Dictionary = DataLoader.get_mastery_pack().get("abilities", {})
	var signatures := {}
	var count := 0
	for it in DataLoader.get_items_pack().get("items", []):
		if not MasterySystem.is_masterable(it) or str(it.get("forced_rarity", "")) == "legendary":
			continue
		count += 1
		var t: Array = it.get("mastery", [])
		assert_gte(t.size(), 3, "%s grows into at least 3 abilities" % str(it["id"]))
		var sig := []
		for e in t:
			assert_true(lib.has(str(e["ability"])), "%s: ability %s exists" % [str(it["id"]), str(e["ability"])])
			assert_false(MasterySystem.describe(str(e["ability"]), e).contains("{"), "%s description is fully filled" % str(e["ability"]))
			sig.append("%d:%s" % [int(e["level"]), str(e["ability"])])
		assert_false(signatures.has(str(sig)), "%s has a unique path (same as %s)" % [str(it["id"]), str(signatures.get(str(sig), ""))])
		signatures[str(sig)] = str(it["id"])
	assert_gte(count, 30, "30+ distinct weapons, spells, shields, armor and accessories")


# --- Mastery --------------------------------------------------------------------------------------------------
func test_mastery_grows_stats_and_unlocks_abilities_with_use() -> void:
	DataLoader.ensure_loaded()
	var sword := LootGenerator.make_base_item_instance(DataLoader.get_item_def("iron_longsword"), "m1")
	assert_eq(MasterySystem.level_of(sword), 1, "new items start at mastery 1")
	assert_true(MasterySystem.abilities(sword).is_empty(), "with no abilities yet")
	var base := MasterySystem.stat(sword, "damage")
	var res := MasterySystem.add_xp(sword, float(MasterySystem.xp_to_next(1)) + float(MasterySystem.xp_to_next(2)) + 0.5)
	assert_eq(res["levels"], [2, 3], "XP raises the level step by step")
	assert_eq(res["unlocked"].size(), 2, "and unlocks the abilities on those levels")
	assert_true(MasterySystem.has_ability(sword, "keen_edge") and MasterySystem.has_ability(sword, "dash_strike"), "Keen Edge + Lunge")
	assert_gt(MasterySystem.stat(sword, "damage"), base * 1.1, "and the weapon hits harder")
	_master(sword, 10)
	assert_eq(MasterySystem.level_of(sword), 10, "caps at the max level")
	assert_almost_eq(float(MasterySystem.abilities(sword)["dash_strike"]["distance"]), 5.5, 0.01, "later levels upgrade an ability")
	assert_eq(MasterySystem.next_unlock_level(sword), -1, "track complete")
	MasterySystem.add_xp(sword, 9999.0)
	assert_eq(MasterySystem.level_of(sword), 10, "no level past the cap")


func test_items_earn_mastery_from_hits_and_kills_in_game() -> void:
	await _setup_arena()
	var sword := _equip("iron_longsword", "right_hand")
	var e := _enemy_ahead(1.6)
	await get_tree().physics_frame
	for _i in range(3):
		game.player.stamina = game.player.max_stamina
		game.player._right_cooldown = 0.0
		game.player.handle_hand_press("right_hand")
		game.player.handle_hand_release("right_hand")
	assert_gt(float(sword.get("mastery_xp", 0.0)), 0.0, "hits earn mastery XP for the sword that landed them")
	game.test_give_item("hide_bracers")
	game.player.equip_from_inventory(game.player.inventory.size() - 1)
	var worn: Dictionary = game.player.equipment["hands"]
	sword = game.player.equipment["right_hand"]  # equipping rebuilds the equipment dictionaries
	var before := float(sword.get("mastery_xp", 0.0)) + float(MasterySystem.level_of(sword)) * 1000.0
	e.take_damage(99999.0)
	assert_gt(float(sword.get("mastery_xp", 0.0)) + float(MasterySystem.level_of(sword)) * 1000.0, before, "the killing blow earns kill XP")
	assert_gt(float(worn.get("mastery_xp", 0.0)), 0.0, "worn armor masters too")


# --- Abilities in action -----------------------------------------------------------------------------------------
func test_shock_learns_to_chain_to_multiple_enemies() -> void:
	await _setup_arena()
	var spark := _equip("spell_chain_spark", "left_hand")
	_master(spark, 4)
	var a := _enemy_ahead(5.0)
	var b := _enemy_ahead(7.0, 1.5)
	var c := _enemy_ahead(9.0, -1.5)
	await get_tree().physics_frame
	_face_point(a.global_position + Vector3(0, 1.0, 0))
	game.player.handle_hand_press("left_hand")
	for _i in range(40):
		await get_tree().physics_frame
	assert_lt(a.current_health, a.max_health, "the bolt hits the first enemy")
	assert_lt(b.current_health, b.max_health, "chains to a second")
	assert_lt(c.current_health, c.max_health, "and a third (Arc Chain, 2 jumps at mastery 4)")


func test_fire_learns_to_explode() -> void:
	await _setup_arena()
	var fire := _equip("spell_firebolt", "left_hand")
	var a := _enemy_ahead(6.0)
	var b := _enemy_ahead(6.0, 2.6)
	await get_tree().physics_frame
	_face_point(a.global_position + Vector3(0, 1.0, 0))
	game.player.handle_hand_press("left_hand")
	for _i in range(40):
		await get_tree().physics_frame
	assert_almost_eq(b.current_health, b.max_health, 0.01, "a fresh firebolt only scorches its target")
	_master(fire, 4)
	game.player._left_cooldown = 0.0
	game.player.magicka = game.player.max_magicka
	game.player.handle_hand_press("left_hand")
	for _i in range(40):
		await get_tree().physics_frame
	assert_lt(b.current_health, b.max_health, "a mastered firebolt detonates and hits the enemy beside it")
	assert_true(a.has_status("burn") or a.state == EnemyActor.AiState.DEAD, "and sets the target alight (Ignite)")


func test_one_handed_lunge_and_dual_wield_cross_guard() -> void:
	await _setup_arena()
	var pl := game.player
	var sword := _equip("iron_longsword", "right_hand")
	_master(sword, 3)
	var start := pl.global_position
	pl.stamina = pl.max_stamina
	pl.handle_hand_press("right_hand")
	for _i in range(40):
		pl.step_simulation(DT, false, {"right_held": true})
		await get_tree().physics_frame
	pl.handle_hand_release("right_hand")
	for _i in range(20):
		pl.step_simulation(DT, false, {})
		await get_tree().physics_frame
	assert_gt(Vector2(pl.global_position.x - start.x, pl.global_position.z - start.z).length(), 2.0, "power attack lunges forward (Lunge)")
	# Cross Guard: dual blades, off-hand mastered to 5
	var left := _equip("iron_longsword", "left_hand")
	_master(left, 5)
	pl.handle_hand_press("left_hand")
	for _i in range(20):
		pl.step_simulation(DT, false, {"left_held": true})
	assert_true(pl.is_cross_guarding and pl.is_blocking, "holding the off-hand blade crosses both blades")
	var hp := pl.health
	game.test_toggle("god")
	var res := pl.take_damage(40.0)
	assert_true(bool(res["was_blocked"]), "Cross Guard blocks")
	assert_lt(float(res["final_damage"]), 30.0, "and takes most of the hit")
	game.test_toggle("god")
	pl.health = hp
	pl.step_simulation(DT, false, {})
	assert_false(pl.is_cross_guarding, "release drops the guard")
	pl._left_cooldown = 0.0
	pl.handle_hand_press("left_hand")
	pl.step_simulation(DT, false, {})
	assert_gt(pl._left_cooldown, 0.0, "a quick tap still attacks")


func test_bow_learns_to_slow_time_on_full_draw() -> void:
	await _setup_arena()
	var pl := game.player
	var bow := _equip("hunting_bow", "right_hand")
	pl.handle_hand_press("right_hand")
	for _i in range(90):
		game.step_simulation(DT, {"right_held": true})
	assert_eq(game.world_time_scale, 1.0, "a fresh bow does not slow time")
	pl.handle_hand_release("right_hand")
	_master(bow, 4)
	pl._right_cooldown = 0.0
	pl.handle_hand_press("right_hand")
	for _i in range(90):
		game.step_simulation(DT, {"right_held": true})
	assert_lt(game.world_time_scale, 0.6, "Hunter's Focus slows the world at full draw")
	pl.handle_hand_release("right_hand")
	game.step_simulation(DT, {})
	assert_eq(game.world_time_scale, 1.0, "and time resumes on release")


func test_axe_bleeds_and_statuses_tick() -> void:
	await _setup_arena()
	var axe := _equip("bearded_hand_axe", "right_hand")
	_master(axe, 2)
	var e := _enemy_ahead(1.5)
	e.max_health = 5000.0
	e.current_health = 5000.0
	await get_tree().physics_frame
	game.player.handle_hand_press("right_hand")
	game.player.handle_hand_release("right_hand")
	assert_true(e.has_status("bleed"), "Rending Cuts makes the target bleed")
	var hp := e.current_health
	for _i in range(120):
		e.step_ai(DT, false)
	assert_lt(e.current_health, hp - 4.0, "bleeding keeps hurting over time")


# --- Enemies: unique types with level ranges -----------------------------------------------------------------------
func test_enemy_types_have_level_ranges_and_floors_introduce_new_ones() -> void:
	DataLoader.ensure_loaded()
	var pack := DataLoader.get_enemies_pack()
	var all: Array = pack.get("enemies", [])
	assert_gte(all.size(), 10, "10+ enemy types to discover")
	for e in all:
		assert_lte(int(e["level_min"]), int(e["level_max"]), "%s has a level range" % str(e["id"]))
		assert_false(str(e.get("lore", "")).is_empty(), "%s has Bestiary lore" % str(e["id"]))
		assert_false(str(e.get("weakness", "")).is_empty(), "%s has a weakness to study" % str(e["id"]))
	var f1 := []
	var f2 := []
	for e in all:
		if bool(e.get("is_boss", false)) or float(e.get("spawn_weight", 0.0)) <= 0.0:
			continue
		if EnemyLevels.eligible(e, 1, pack):
			f1.append(str(e["id"]))
		if EnemyLevels.eligible(e, 2, pack):
			f2.append(str(e["id"]))
	assert_gte(f1.size(), 6, "floor 1 already has variety: %s" % str(f1))
	var new_on_2: Array = f2.filter(func(x: String) -> bool: return not f1.has(x))
	assert_gt(new_on_2.size(), 0, "deeper floors introduce enemies you have not met: %s" % str(new_on_2))
	var rng := SeededRng.new(5)
	for e in all:
		for fl in [1, 2, 3]:
			if EnemyLevels.eligible(e, fl, pack):
				var l := EnemyLevels.roll_level(e, fl, pack, rng)
				var band := EnemyLevels.floor_band(fl, pack)
				assert_between(l, int(e["level_min"]), int(e["level_max"]), "%s rolls inside its own range" % str(e["id"]))
				assert_between(l, band.x, band.y, "and inside floor %d's band" % fl)


func test_spawned_levels_scale_stats_and_replay_identically() -> void:
	game = _make_game()
	await get_tree().process_frame
	var low := game.spawn_enemy("draugr_raider", game.player.global_position + Vector3(4, 0.1, 0), -1, "lvl_a", {}, 1)
	var high := game.spawn_enemy("draugr_raider", game.player.global_position + Vector3(-4, 0.1, 0), -1, "lvl_b", {}, 6)
	assert_eq(low.level, 1)
	assert_gt(high.max_health, low.max_health * 1.5, "a level 6 draugr is much tougher")
	assert_gt(high.damage, low.damage, "and hits harder")
	assert_true(high._name_label.text.begins_with("Lv 6"), "its level is shown over its head")
	var a := _make_game()
	var b := _make_game()
	await get_tree().process_frame
	var la := []
	var lb := []
	for e in a.enemies_root.get_children():
		la.append((e as EnemyActor).level)
	for e in b.enemies_root.get_children():
		lb.append((e as EnemyActor).level)
	assert_eq(la, lb, "same seed -> same enemy levels on every attempt (D-039)")


func test_enemy_traits_make_each_type_play_differently() -> void:
	await _setup_arena()
	game.test_toggle("god")
	var pl := game.player
	_equip("iron_longsword", "right_hand")
	var warden := _enemy_ahead(1.6, 0.0, "draugr_shieldwarden")
	var plain := _enemy_ahead(1.6, 3.0, "draugr_raider")
	warden.max_health = 9999.0
	warden.current_health = 9999.0
	warden.rotation.y = atan2(pl.global_position.x - warden.global_position.x, pl.global_position.z - warden.global_position.z)
	await get_tree().physics_frame
	game._apply_player_hit_to_enemy(warden, {"base_damage": 50.0, "crit_chance": 0.0}, "one_handed")
	var front_loss := 9999.0 - warden.current_health
	plain.max_health = 9999.0
	plain.current_health = 9999.0
	game._apply_player_hit_to_enemy(plain, {"base_damage": 50.0, "crit_chance": 0.0}, "one_handed")
	assert_lt(front_loss, (9999.0 - plain.current_health) * 0.6, "the Shieldwarden's shield soaks frontal hits")
	var frost := _enemy_ahead(2.0, -3.0, "frostbound_draugr")
	game._enemy_hit_player(frost, 10.0, true)
	assert_true(pl.is_slowed(), "Frostbound hits slow the crawler")
	var hype := _enemy_ahead(4.0, 0.0, "goblin_hype_man")
	hype._do_war_cry()
	assert_true(plain.has_status("rally"), "the Hype-Man's war cry rallies nearby enemies")


# --- Bestiary ----------------------------------------------------------------------------------------------------
func test_bestiary_records_discoveries_and_survives_floor_resets() -> void:
	await _setup_arena()
	var e := _enemy_ahead(3.0, 0.0, "bone_hexer")
	assert_eq(game.bestiary.knowledge("bone_hexer"), 0, "unknown before you meet it")
	e.state = EnemyActor.AiState.CHASE
	game._bestiary_scan_t = 0.0
	game.step_simulation(DT, {})
	assert_eq(game.bestiary.knowledge("bone_hexer"), 1, "sighted when it engages you")
	e.take_damage(99999.0)
	assert_eq(game.bestiary.knowledge("bone_hexer"), 2, "slain: stats and abilities revealed")
	for _i in range(Bestiary.STUDY_KILLS - 1):
		game.bestiary.record_kill("bone_hexer", 3, 1)
	assert_eq(game.bestiary.knowledge("bone_hexer"), 3, "studied after %d kills: weakness revealed" % Bestiary.STUDY_KILLS)
	game.reset_floor_to_snapshot("death")
	await get_tree().process_frame
	assert_eq(game.bestiary.knowledge("bone_hexer"), 3, "a floor reset never erases what you learned")
	assert_true(game.save_current_session(), "saves")
	var g2 := _make_game()
	g2.save_path = game.save_path
	await get_tree().process_frame
	assert_true(g2.load_saved_session(), "loads")
	assert_eq(g2.bestiary.knowledge("bone_hexer"), 3, "the Bestiary is saved with the session")


func test_bestiary_tab_lists_every_creature_with_unknowns_hidden() -> void:
	game = _make_game()
	await get_tree().process_frame
	game.bestiary.record_seen("draugr_raider", 2, 1)
	game.open_exclusive_menu("inventory")
	game.inventory_menu.open_tab(2)
	await get_tree().process_frame
	var page := game.inventory_menu.bestiary_page
	assert_true(page.is_visible_in_tree(), "Bestiary tab in the Character menu")
	var names := []
	for c in page._list.get_children():
		if not c.is_queued_for_deletion():
			names.append((c as Button).text)
	assert_eq(names.size(), DataLoader.get_enemies_pack()["enemies"].size(), "every creature has a page")
	assert_true(names.any(func(n: String) -> bool: return n.begins_with("Hollow Draugr Raider")), "met creatures are named")
	assert_true(names.has("???"), "unmet creatures stay a mystery")
	game.close_all_menus()


func test_item_card_shows_mastery_and_hides_undiscovered_abilities() -> void:
	DataLoader.ensure_loaded()
	var bow := LootGenerator.make_base_item_instance(DataLoader.get_item_def("hunting_bow"), "c1")
	_master(bow, 2)
	var card := ItemInfo.build_mastery(bow)
	add_child_autofree(card)
	var texts := []
	for row in card.get_children():
		for c in row.get_children():
			if c is Label:
				texts.append((c as Label).text)
	var joined := " | ".join(texts)
	assert_true(joined.contains("MASTERY 2 / 10"), "shows the mastery level")
	assert_true(joined.contains("Quick Draw"), "names discovered abilities")
	assert_true(joined.contains("???"), "keeps later abilities a mystery")
	assert_false(joined.contains("Hunter's Focus"), "does not spoil Hunter's Focus before mastery 4")
