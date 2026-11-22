extends GutTest
## Regression guards for User feedback FB-013 (docs/USER_FEEDBACK_LOG.md, decisions D-046 / D-047):
## rings equip, hard-then-easier difficulty, either-hand one-handed items, wandering long-range enemies,
## third-person looting, map/minimap locked on the player, and a Test Mode that can spawn anything.

var game: GameMain = null


func _make_game(test_mode: bool) -> GameMain:
	var g := GameMain.new()
	g.run_seed = 20261118
	g.auto_load_save_on_ready = false
	g.save_path = "user://fb013_test.json"
	g.test_mode = test_mode
	add_child_autofree(g)
	return g


func _give(g: GameMain, item_id: String) -> int:
	var it := g.test_give_item(item_id, "common")
	assert_false(it.is_empty(), "item %s exists" % item_id)
	return g.player.inventory.size() - 1


# --- Rings -----------------------------------------------------------------------------------------------
func test_rings_equip_into_visible_ring_slots_instead_of_vanishing() -> void:
	game = _make_game(true)
	var p := game.player
	var i1 := _give(game, "silver_focus_ring")
	assert_true(p.equip_from_inventory(i1))
	assert_true(p.equipment.has("ring_1"), "first ring goes to ring slot 1")
	assert_false(p.equipment.has("ring"), "never stored under the hidden 'ring' key")
	var i2 := _give(game, "silver_focus_ring")
	p.equip_from_inventory(i2)
	assert_true(p.equipment.has("ring_2"), "second ring goes to ring slot 2")
	p.equipment["ring"] = p.equipment["ring_1"].duplicate(true)
	p.equipment.erase("ring_1")
	p.normalize_equipment()
	assert_true(p.equipment.has("ring_1") and not p.equipment.has("ring"), "old saves with a hidden ring are repaired")


# --- Either hand -------------------------------------------------------------------------------------------
func test_one_handed_items_go_in_either_hand() -> void:
	game = _make_game(true)
	var p := game.player
	p.equipment.clear()
	p.equip_from_inventory(_give(game, "spell_firebolt"), "right_hand")
	p.equip_from_inventory(_give(game, "spell_chain_spark"), "left_hand")
	assert_eq(str(p.equipment["right_hand"]["id"]), "spell_firebolt", "spell in the right hand")
	assert_eq(str(p.equipment["left_hand"]["id"]), "spell_chain_spark", "dual-wielded spells")
	var m0 := p.magicka
	p.handle_hand_press("right_hand")
	p.handle_hand_release("right_hand")
	p.handle_hand_press("left_hand")
	assert_lt(p.magicka, m0 - 30.0, "both hands cast")
	# shield in the right hand + spell in the left, blocking with the right button
	p.equip_from_inventory(_give(game, "nordic_kite_shield"), "right_hand")
	assert_eq(str(p.equipment["right_hand"]["category"]), "shield", "shield in the right hand")
	p.step_simulation(1.0 / 60.0, false, {"right_held": true})
	assert_true(p.is_blocking, "right-hand shield blocks while held")
	# swords either side; bows stay two-handed
	p.equip_from_inventory(_give(game, "iron_longsword"), "left_hand")
	assert_eq(str(p.equipment["left_hand"]["id"]), "iron_longsword", "sword in the left hand")
	assert_false(CombatMath.is_one_handed(DataLoader.get_item_def("hunting_bow")), "bow is two-handed")
	for _i in range(5):
		p.step_simulation(1.0 / 60.0, false, {})
	assert_not_null(p._fp_right_weapon_holder, "right-hand shield has a first-person visual")


# --- Difficulty curve ------------------------------------------------------------------------------------------
func _duel(player_dmg: float, player_hits_per_s: float, player_hp: float, player_armor: float, edef: Dictionary) -> Dictionary:
	var pcfg := DataLoader.get_player()
	var e_mit := CombatMath.compute_armor_mitigation(float(edef.get("armor", 5.0)), pcfg)
	var p_mit := CombatMath.compute_armor_mitigation(player_armor, pcfg)
	var player_dps := player_dmg * (1.0 - e_mit) * player_hits_per_s
	var enemy_dps := float(edef["damage"]) * (1.0 - p_mit) / float(edef.get("attack_cooldown_sec", 1.4))
	return {"kill": float(edef["max_health"]) / player_dps, "die": player_hp / enemy_dps}


## Damage a player takes beating a pack of `n` enemies one at a time while all of them attack (FB-022: enemies come in
## 2.5x the numbers but each is much weaker, so difficulty is measured against a typical pack, not a lone enemy).
func _pack_taken(player_dmg: float, hits_per_s: float, player_armor: float, edef: Dictionary, n: int) -> float:
	var d := _duel(player_dmg, hits_per_s, 1.0, player_armor, edef)
	var enemy_dps := 1.0 / float(d["die"])  # per point of player health
	return enemy_dps * float(d["kill"]) * float(n * (n + 1)) / 2.0


func test_floor_starts_very_hard_and_gets_easier_as_the_player_scales() -> void:
	DataLoader.ensure_loaded()
	var pcfg := DataLoader.get_player()
	var hp := float(pcfg["stats"]["base_max_health"])
	var armor := float(pcfg["stats"]["base_armor"]) + 12.0 + 18.0  # starting tunic + shield
	var sword := float(DataLoader.get_item_def("iron_longsword")["damage"])
	var draugr := DataLoader.get_enemy_def("draugr_raider")
	var boss := DataLoader.get_enemy_def("iron_warden_boss")
	var pair := _pack_taken(sword, 1.3, armor, draugr, 2) / hp
	assert_gt(pair, 0.55, "fresh: a typical pack of two draugr is a near-even fight (costs %d%% of your health)" % int(pair * 100.0))
	assert_gt(_pack_taken(sword, 1.3, armor, draugr, 3), hp, "fresh: three at once overwhelm you")
	var vs_boss := _duel(sword, 1.3, hp, armor, boss)
	assert_gt(vs_boss["kill"], 3.0 * vs_boss["die"], "fresh: the boss is far out of reach")
	# Scaled within the floor: +10 levels (5 points into health), rare gear, proficiency and a damage perk
	var fresh := _duel(sword, 1.3, hp, armor, draugr)
	var scaled := _duel(sword * 1.45 * 1.37, 1.3, hp + 75.0, armor * 1.45 + 40.0, draugr)
	assert_gt(fresh["kill"] / scaled["kill"], 1.8, "scaling up kills draugr much faster")
	var scaled_pair := _pack_taken(sword * 1.45 * 1.37, 1.3, armor * 1.45 + 40.0, draugr, 2) / (hp + 75.0)
	assert_lt(scaled_pair, pair * 0.35, "and the same pack becomes clearly easier (%d%% -> %d%% of your health)" % [int(pair * 100.0), int(scaled_pair * 100.0)])


# --- Enemy AI ---------------------------------------------------------------------------------------------------
func test_enemies_wander_and_engage_from_further_away() -> void:
	game = _make_game(true)
	await get_tree().process_frame
	game.set_physics_process(false)  # drive the AI directly (the game loop would freeze an enemy this far away)
	var lay := game.current_layout
	var combat: Dictionary = {}
	for r in lay.rooms:
		if str(r["role"]) == "combat":
			combat = r
			break
	var c := lay.tile_to_world(combat["center"])
	game.player.global_position = lay.tile_to_world(lay.rooms[lay.stairs_room_id]["center"]) + Vector3(0, 0.3, 0)
	var e := game.spawn_enemy("draugr_raider", c + Vector3(0, 0.1, 0), int(combat["id"]))
	var start := e.global_position
	for _i in range(360):
		e.step_ai(1.0 / 60.0, false)
		await get_tree().physics_frame
	assert_eq(e.state, EnemyActor.AiState.IDLE, "out of sight it stays idle")
	assert_gt(e.global_position.distance_to(start), 0.8, "but wanders around its room")
	assert_gte(float(DataLoader.get_enemy_def("draugr_raider")["aggro_radius"]), 20.0, "melee enemies notice you from 20 m+")
	assert_gte(float(DataLoader.get_enemy_def("bone_archer")["attack_range"]), 20.0, "archers shoot from 20 m+")
	# in plain sight at 18 m it engages
	game.player.global_position = e.global_position + Vector3(0, 0.2, 0)
	e.global_position = e.global_position + Vector3(0, 0, 0)
	var far := e.global_position + (Vector3(1, 0, 0) * 18.0)
	if lay.is_walkable(lay.world_to_tile(far).x, lay.world_to_tile(far).y):
		game.player.global_position = far + Vector3(0, 0.2, 0)
	await get_tree().physics_frame
	for _i in range(20):
		e.step_ai(1.0 / 60.0, false)
		await get_tree().physics_frame
	assert_ne(e.state, EnemyActor.AiState.IDLE, "engages the player it can see")


# --- Third-person looting ------------------------------------------------------------------------------------------
func test_looting_works_in_third_person() -> void:
	game = _make_game(true)
	await get_tree().process_frame
	game.run_console_command("teleport combat")
	game.player.set_camera_mode("third_person")
	for kind in ["chest", "crate"]:
		var obj := game.test_spawn_object(kind) as InteractableObject
		for _i in range(4):
			game.player.step_simulation(1.0 / 60.0, false, {})
			await get_tree().physics_frame
		assert_eq(game.player._raycast_interactable(), obj, "%s is targetable in third person" % kind)
		assert_true(game.player.trigger_interact(), "%s loots in third person" % kind)
		obj.queue_free()
		await get_tree().process_frame


# --- Map locked on the player ------------------------------------------------------------------------------------
func test_map_and_minimap_are_locked_on_the_player() -> void:
	game = _make_game(true)
	await get_tree().process_frame
	game.run_console_command("teleport boss")
	game.step_simulation(1.0 / 60.0)
	game.open_exclusive_menu("map")
	await get_tree().process_frame
	var canvas := game.map_menu._canvas
	var centre := canvas.tile_to_screen(canvas.player_tile_f + Vector2(0.5, 0.5))
	assert_almost_eq(centre.distance_to(canvas.size * 0.5), 0.0, 1.0, "map opens centred on the player")
	game.close_all_menus()
	var mm := game.hud.minimap
	assert_not_null(mm, "HUD has a minimap")
	assert_almost_eq(mm.tile_to_screen(mm.player_tile_f).distance_to(mm.size * 0.5), 0.0, 0.5, "minimap is centred on the player")


# --- Test Mode ------------------------------------------------------------------------------------------------------
func test_test_mode_can_spawn_anything_and_never_touches_the_real_save() -> void:
	game = _make_game(true)
	await get_tree().process_frame
	assert_eq(game.save_path, GameMain.TEST_SAVE_PATH, "Test Mode always uses its own save file")
	var g2 := GameMain.new()
	GameMain.launch_test_mode = true
	add_child_autofree(g2)
	assert_true(g2.test_mode, "title-screen launch flag enters Test Mode")
	assert_eq(g2.save_path, GameMain.TEST_SAVE_PATH, "Test Mode uses its own save file")
	assert_not_null(g2.test_panel, "F1 tools panel exists")
	g2.queue_free()
	assert_lt(game.current_layout.width, 100, "compact test floor")
	var regular := 0
	for c in game.enemies_root.get_children():
		if not (c as EnemyActor).is_boss:
			regular += 1
	assert_eq(regular, 0, "test floor starts without regular enemies")
	for t in ["entrance", "combat", "safe", "boss", "vault", "stairs"]:
		assert_true(game.test_teleport(t).begins_with("Teleported"), "can go to the %s room" % t)
	game.run_console_command("teleport combat")
	for e in DataLoader.get_enemies_pack().get("enemies", []):
		assert_eq(game.test_spawn_enemy(str(e["id"]), 2).size(), 2, "spawns %s" % str(e["id"]))
	assert_gt(game.test_kill_enemies(), 0, "kills spawned enemies")
	for r in DataLoader.get_rarities_pack().get("rarities", []):
		for it in DataLoader.get_items_pack().get("items", []):
			assert_false(game.test_give_item(str(it["id"]), str(r["id"])).is_empty(), "gives %s (%s)" % [str(it["id"]), str(r["id"])])
	for kind in DungeonBuilder.TEST_OBJECTS:
		assert_not_null(game.test_spawn_object(kind), "spawns %s" % kind)
	var lvl := game.progression.level
	game.test_add_levels(3)
	assert_eq(game.progression.level, lvl + 3, "levels up on demand")
	assert_true(game.test_toggle("god"), "god mode")
	assert_true(game.test_toggle("ai"), "freeze AI")


func test_no_melee_enemy_can_out_range_the_players_melee() -> void:
	DataLoader.ensure_loaded()
	var reach := float(DataLoader.get_player()["combat"]["melee_range_meters"])
	for e in DataLoader.get_enemies_pack().get("enemies", []):
		if str(e.get("archetype", "melee")) == "ranged":
			continue
		var edge_reach := reach + maxf(0.6, float(e.get("radius", 0.5)) + 0.1)
		assert_lt(float(e["attack_range"]), edge_reach, "%s attacks from %.1f m but the player can hit back to %.1f m" % [str(e["id"]), float(e["attack_range"]), edge_reach])
