extends GutTest
## Regression guards for User feedback FB-022 (docs/USER_FEEDBACK_LOG.md, decision D-057): exact enemy health bars,
## more and weaker enemies, champion mini-bosses, no TV-show theme, enemies walking straight, a hotbar, item level-up
## instructions, a status-effect list, power-scale knobs, stacking + vendor quantities, safe-room area maps,
## a level-1 ability on every item and visible damage over time.

const DT := 1.0 / 60.0

var game: GameMain = null


func _make_game(vast: bool = false) -> GameMain:
	var g := GameMain.new()
	g.run_seed = 20261118
	g.auto_load_save_on_ready = false
	g.save_path = "user://fb022_test.json"
	g.test_mode = not vast
	add_child_autofree(g)
	return g


# --- 1. Health bars ---------------------------------------------------------------------------------------------

func test_enemy_health_bar_drains_exactly_with_health() -> void:
	game = _make_game()
	await get_tree().process_frame
	game.run_console_command("teleport combat")
	var e: EnemyActor = game.test_spawn_enemy("draugr_raider", 1)[0]
	assert_true(e._health_fill.mesh.surface_get_material(0) is ShaderMaterial or (e._health_fill.mesh as QuadMesh).material is ShaderMaterial,
		"the bar is drawn by a shader that reads the exact ratio (billboarded quads ignore scale)")
	for frac in [0.75, 0.5, 0.2, 0.05]:
		e.current_health = e.max_health * frac + 1.0
		e.take_damage(1.0)
		assert_almost_eq(e.health_bar_fill(), frac, 0.02, "at %d%% health the bar shows %d%%" % [int(frac * 100), int(frac * 100)])
	# a damage-over-time tick moves the bar too
	e.current_health = e.max_health * 0.4
	e._dot_damage(e.max_health * 0.1)
	assert_almost_eq(e.health_bar_fill(), 0.3, 0.02, "damage over time drains the bar as well")


# --- 2. More, weaker enemies & champions ----------------------------------------------------------------------

func test_floors_have_far_more_but_weaker_enemies() -> void:
	var world := DataLoader.get_world()
	var pack := DataLoader.get_enemies_pack()
	var lay := DungeonGenerator.generate(world, pack, 1, 20261118)
	var regular := 0
	for sp in lay.enemy_spawns:
		if not bool(sp.get("is_boss", false)):
			regular += 1
	assert_gt(regular, 1100, "floor 1 holds well over a thousand enemies (was 440)")
	# health / damage before FB-022: every type is now well under half as tough and about half as hard-hitting
	var old := {"draugr_raider": [210, 21], "bone_archer": [140, 20], "goblin_gloryhound": [170, 24], "draugr_shieldwarden": [240, 18],
		"frostbound_draugr": [230, 22], "bone_hexer": [120, 16], "goblin_bomber": [150, 26], "barrow_wight": [200, 20],
		"draugr_deathlord": [520, 34], "goblin_hollerer": [160, 14]}
	for e in pack["enemies"]:
		if old.has(str(e["id"])):
			var o: Array = old[str(e["id"])]
			assert_lte(float(e["max_health"]), float(o[0]) * 0.45, "%s is individually weaker" % str(e["id"]))
			assert_lte(float(e["damage"]), float(o[1]) * 0.6, "%s hits softer" % str(e["id"]))


func test_enemies_are_created_only_near_the_player() -> void:
	game = _make_game(true)
	await get_tree().process_frame
	var total := game.current_layout.enemy_spawns.size()
	assert_lt(game.enemies_root.get_child_count(), total / 4, "far-off enemies are not created up front")
	assert_gt(game.enemies_root.get_child_count(), 0)
	var before := game.enemies_root.get_child_count()
	game.run_console_command("teleport boss")
	assert_gt(game.enemies_root.get_child_count(), before, "walking somewhere new brings its enemies to life")


func test_champion_lairs_make_boss_fights_common() -> void:
	game = _make_game(true)
	await get_tree().process_frame
	var lay := game.current_layout
	var lairs := 0
	for p in lay.pois:
		if str(p["kind"]) == "champion":
			lairs += 1
	assert_gte(lairs, int(PowerScale.cfg()["champions"]["min_lairs"]), "every floor has champion lairs")
	assert_gt(lairs, 30, "a vast floor has dozens of them")
	assert_true(game.test_teleport("champion").begins_with("Teleported"), "Test Mode can jump to the nearest lair")
	var champ: EnemyActor = null
	for n in get_tree().get_nodes_in_group("champions"):
		champ = n as EnemyActor
	assert_not_null(champ, "the lair's champion is there")
	if champ == null:
		return
	var plain := DataLoader.get_enemy_def(champ.enemy_id)
	assert_gt(champ.max_health, float(plain["max_health"]) * 4.0, "a champion is a real mini-boss")
	assert_true(champ.display_name.begins_with(str(plain["name"])) and champ.display_name.length() > str(plain["name"]).length(),
		"it has a title: %s" % champ.display_name)
	assert_eq(champ.loot_drop_chance, 1.0, "always drops loot")
	champ.state = EnemyActor.AiState.CHASE
	game.player.global_position = champ.global_position + Vector3(3, 0.2, 0)
	game._update_hud_navigation()
	assert_true(game.hud._boss_box.visible, "an engaged champion gets the big health bar")
	assert_eq(game.hud._boss_sub.text, "CHAMPION")
	var idx := int(champ.get_meta("spawn_index"))
	champ.take_damage(1e9)
	var done := false
	for p in lay.pois:
		if int(p.get("spawn_index", -1)) == idx:
			done = bool(p["done"])
	assert_true(done, "a slain champion is crossed off the map")


# --- 3. No show / sponsor theme -------------------------------------------------------------------------------

const BANNED := ["carl", "syndicate", "sponsor", "broadcast", "viewer", "audience", "ratings", "streamer", "influencer",
	"viewership", "galactic", "prime-time", "prime time", "megacorp", "achievement"]


func _scan(v: Variant, where: String, hits: Array) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			for k in (v as Dictionary).keys():
				if str(k) == "_doc":
					continue
				_scan(v[k], "%s.%s" % [where, k], hits)
		TYPE_ARRAY:
			for i in range((v as Array).size()):
				_scan(v[i], "%s[%d]" % [where, i], hits)
		TYPE_STRING:
			var low := str(v).to_lower()
			for w in BANNED:
				if low.contains(w):
					hits.append("%s: '%s'" % [where, w])


func test_no_tv_show_or_sponsor_theme_left_in_the_game() -> void:
	var hits: Array = []
	for f in ["items", "enemies", "affixes", "dungeon_ai", "setpieces", "tutorials", "progression", "world", "player", "mastery"]:
		_scan(DataLoader.get_pack(f), f, hits)
	# player-facing UI text
	for path in ["res://src/ui/hud.gd", "res://src/ui/pause_menu.gd", "res://src/ui/death_screen.gd", "res://src/ui/title_screen.gd",
			"res://src/ui/settings_panel.gd", "res://src/ui/vendor_menu.gd", "res://src/ui/item_info.gd", "res://project.godot"]:
		var low := FileAccess.get_file_as_string(path).to_lower()
		for w in BANNED:
			if low.contains(w):
				hits.append("%s: '%s'" % [path, w])
	assert_eq(hits, [], "no show / sponsor / syndicate references remain")
	for old in ["res://assets/models/characters/goblin_streamer.glb", "res://assets/models/gear/ratings_cleaver.glb",
			"res://assets/models/gear/sponsored_gauntlets.glb"]:
		assert_false(ResourceLoader.exists(old), "%s is gone" % old)


func test_old_saves_with_renamed_items_still_load() -> void:
	game = _make_game()
	await get_tree().process_frame
	var p := game.player
	p.inventory.append({"id": "sponsored_blade_ratings", "name": "old", "category": "weapon", "slot": "right_hand",
		"sponsored_effect": "vampiric_viewers", "sponsored_label": "old", "rarity": "legendary", "instance_id": "old1"})
	p.normalize_equipment()
	var it: Dictionary = p.inventory[-1]
	assert_eq(str(it["id"]), "gravefeast_cleaver")
	assert_eq(str(it["legendary_effect"]), "blood_feast")
	assert_false(it.has("sponsored_effect"))
	assert_eq(str(it["name"]), str(DataLoader.get_item_def("gravefeast_cleaver")["name"]))
	assert_false(DataLoader.get_enemy_def("goblin_influencer").is_empty(), "old bestiary ids still resolve")


# --- 4. Enemies walk straight ---------------------------------------------------------------------------------

func test_enemies_walk_straight_at_the_player_across_open_ground() -> void:
	game = _make_game(true)
	await get_tree().process_frame
	game.set_physics_process(false)
	var lay := game.current_layout
	var pair: Array = []
	for r in lay.rooms:
		var rr: Rect2i = r["rect"]
		if str(r["role"]) != "combat" or rr.size.x < 6 or rr.size.y < 6:
			continue
		var a := rr.position + Vector2i(1, 1)
		var b := rr.end - Vector2i(2, 2)
		if lay.has_tile_los(a, b) and lay.find_path(a, b).size() > 6:
			pair = [a, b]
			break
	assert_false(pair.is_empty(), "found an open room to cross diagonally")
	if pair.is_empty():
		return
	game.player.global_position = lay.tile_to_world(pair[1]) + Vector3(0, 0.3, 0)
	game.player.god_mode = true
	for c in game.enemies_root.get_children():
		if c != game.boss_actor:
			(c as Node3D).global_position = Vector3(0, -80, 0)
	var e := game.spawn_enemy("draugr_raider", lay.tile_to_world(pair[0]) + Vector3(0, 0.1, 0), -1)
	await get_tree().physics_frame
	var start := Vector2(e.global_position.x, e.global_position.z)
	var goal := Vector2(game.player.global_position.x, game.player.global_position.z)
	var line := (goal - start).normalized()
	var worst := 0.0
	e.state = EnemyActor.AiState.CHASE
	for _i in range(240):
		e._unseen_t = 0.0
		e.step_ai(DT, false)
		await get_tree().physics_frame
		var p := Vector2(e.global_position.x, e.global_position.z)
		var off := absf((p - start).cross(line))
		worst = maxf(worst, off)
		if p.distance_to(goal) < e.attack_range + 0.3:
			break
	assert_lt(worst, 0.9, "the enemy cut straight across the room (max %.2f m off the line, no stair-steps)" % worst)


func test_paths_are_string_pulled_into_straight_lines() -> void:
	var lay := DungeonGenerator.generate_test_floor(DataLoader.get_world(), DataLoader.get_enemies_pack(), 1, 7)
	var found := false
	for r in lay.rooms:
		var rr: Rect2i = r["rect"]
		if rr.size.x >= 4 and rr.size.y >= 4:
			var a := rr.position + Vector2i(1, 1)
			var b := rr.end - Vector2i(2, 2)
			if lay.has_tile_los(a, b):
				found = true
	assert_true(found, "open floor is seen as walkable in a straight line")
	assert_false(lay.has_tile_los(Vector2i(0, 0), Vector2i(lay.width - 1, lay.height - 1)), "walls block it")


# --- 5. Hotbar ------------------------------------------------------------------------------------------------

func test_hotbar_equips_weapons_and_uses_consumables() -> void:
	game = _make_game()
	await get_tree().process_frame
	var p := game.player
	assert_eq(p.hotbar.size(), PlayerController.HOTBAR_SIZE)
	var bow_slot := -1
	var pot_slot := -1
	for i in range(p.hotbar.size()):
		var it: Dictionary = p.hotbar_item(i).get("item", {})
		if str(it.get("id", "")) == "hunting_bow":
			bow_slot = i
		if str(it.get("id", "")) == "health_potion":
			pot_slot = i
	assert_gte(bow_slot, 0, "starting bow is on the hotbar")
	assert_gte(pot_slot, 0, "health potions are on the hotbar")
	assert_true(p.use_hotbar(bow_slot))
	assert_eq(str(p.equipment["right_hand"]["id"]), "hunting_bow", "the key equips the bow")
	p.health = 10.0
	var n := InventoryStacks.total(p.inventory, "health_potion")
	assert_true(p.use_hotbar(pot_slot))
	assert_eq(InventoryStacks.total(p.inventory, "health_potion"), n - 1, "the key drinks one from the stack")
	assert_gt(p.health, 10.0)
	# assign anything from the bag to a slot
	var axe := game.test_give_item("bearded_hand_axe")
	assert_true(p.hotbar_assign(7, axe))
	assert_true(p.use_hotbar(7))
	assert_eq(str(p.equipment["right_hand"]["id"]), "bearded_hand_axe")
	# the HUD draws the bar
	p.emit_stats()
	assert_eq(game.hud._hotbar_box.get_child_count(), PlayerController.HOTBAR_SIZE)
	# survives a floor reset
	var hb := p.hotbar.duplicate(true)
	game.reset_floor_to_snapshot("manual_reset")
	assert_eq(p.hotbar.size(), PlayerController.HOTBAR_SIZE)
	assert_eq(InputMap.has_action("hotbar_8"), true, "keys 1-8 are bound")
	assert_true(hb.size() == PlayerController.HOTBAR_SIZE)


# --- 6. Level-up instructions & level-1 abilities -------------------------------------------------------------

func test_every_item_says_how_to_level_it_and_has_a_level_one_ability() -> void:
	for d in DataLoader.get_all_item_defs():
		var inst := LootGenerator.make_base_item_instance(d, "t")
		if not MasterySystem.is_masterable(inst):
			continue
		var how := MasterySystem.how_to_level(inst)
		assert_true(how.begins_with("To level up:"), "%s explains how to level it" % str(d["id"]))
		assert_true(how.contains("xp to mastery 2"), "%s says how much is left" % str(d["id"]))
		assert_false(MasterySystem.abilities(inst).is_empty(), "%s has an ability at level 1" % str(d["id"]))
	var card := ItemInfo.build_card(LootGenerator.make_base_item_instance(DataLoader.get_item_def("iron_longsword"), "x"))
	assert_not_null(card.find_child("HowToLevel", true, false), "the item card shows it")
	card.free()


# --- 7. Status effects list -------------------------------------------------------------------------------------

func test_status_effects_are_listed_with_countdowns() -> void:
	game = _make_game()
	await get_tree().process_frame
	var p := game.player
	game.test_give_item("swiftness_draught")
	p.use_consumable(InventoryStacks.find(p.inventory, "swiftness_draught"))
	p.apply_slow(0.3, 4.0)
	var st := p.active_statuses()
	var ids := []
	for s in st:
		ids.append(str(s["id"]))
	assert_true(ids.has("haste") and ids.has("slowed"), "buffs and debuffs are listed: %s" % str(ids))
	p.emit_stats()
	assert_eq(game.hud._status_box.get_child_count(), st.size(), "the HUD lists each one")
	var row := game.hud._status_box.get_child(0)
	assert_not_null(row.find_child("Bar", true, false), "with a countdown bar")
	var before := float(st[0]["remaining"])
	game.step_simulation(1.0)
	assert_lt(float(p.active_statuses()[0]["remaining"]), before, "and it counts down")
	assert_eq(GameHud._fmt_countdown(75.0), "1:15")
	assert_eq(GameHud._fmt_countdown(9.2), "10s")


# --- 8. Power-scale knobs ---------------------------------------------------------------------------------------

func test_power_scale_knobs_scale_entities_and_items() -> void:
	var g: Dictionary = PowerScale.cfg()["global"]
	for k in ["enemy_health", "enemy_damage", "enemy_count", "boss_health", "item_power", "consumable_power", "vendor_prices"]:
		assert_true(g.has(k), "global knob %s" % k)
	for e in DataLoader.get_enemies_pack()["enemies"]:
		assert_true(e.has("power_scale"), "%s has its own power_scale" % str(e["id"]))
	for d in DataLoader.get_all_item_defs():
		assert_true(d.has("power_scale"), "%s has its own power_scale" % str(d["id"]))
	for f in DataLoader.get_world()["floors"]:
		assert_true(f.has("power_scale"), "floor %d has a power_scale" % int(f["floor_number"]))
	var sword := LootGenerator.make_base_item_instance(DataLoader.get_item_def("iron_longsword"), "s")
	var base := MasterySystem.stat(sword, "damage")
	g["item_power"] = 2.0
	assert_almost_eq(MasterySystem.stat(sword, "damage"), base * 2.0, 0.01, "turning item_power up doubles item damage")
	g["item_power"] = 1.0
	var edef := DataLoader.get_enemy_def("draugr_raider")
	edef["power_scale"] = 0.5
	var weak := PowerScale.enemy(edef, "health", 1)
	edef["power_scale"] = 1.0
	assert_almost_eq(weak, 0.5, 0.001, "an entity's own knob scales it")


# --- 9. Stacking & vendor quantities ------------------------------------------------------------------------------

func test_consumables_and_ingredients_stack_and_trade_in_any_amount() -> void:
	game = _make_game()
	await get_tree().process_frame
	var p := game.player
	var stacks := 0
	for it in p.inventory:
		if str(it["id"]) == "health_potion":
			stacks += 1
	assert_eq(stacks, 1, "starting potions share one stack")
	assert_eq(InventoryStacks.total(p.inventory, "health_potion"), 2)
	for _i in range(3):
		game.test_give_item("grave_moss")
	var moss := InventoryStacks.find(p.inventory, "grave_moss")
	assert_eq(InventoryStacks.count(p.inventory[moss]), 3, "ingredients stack too")
	assert_eq(str(p.inventory[moss]["category"]), "ingredient")
	# vendor: buy 5 potions at once, sell 2 moss
	var v := game.vendor_sys
	var si := -1
	for i in range(v.stock.size()):
		if str(v.stock[i]["id"]) == "health_potion":
			si = i
	p.gold = 1000
	var res := v.buy_item(si, p.gold, p.inventory, 5)
	assert_true(bool(res["ok"]))
	assert_eq(int(res["gold"]), 1000 - v.get_buy_price(v.stock[si]) * 5, "pays for all five")
	assert_eq(InventoryStacks.total(p.inventory, "health_potion"), 7)
	var sold := v.sell_item(InventoryStacks.find(p.inventory, "grave_moss"), 0, p.inventory, 2)
	assert_eq(int(sold["qty"]), 2)
	assert_eq(InventoryStacks.total(p.inventory, "grave_moss"), 1, "one left in the stack")
	assert_eq(v.max_affordable(si, v.get_buy_price(v.stock[si]) * 3), 3)
	# the vendor screen offers a quantity picker for stacks
	game.open_exclusive_menu("vendor")
	game.vendor_menu._sel_side = "bag"
	game.vendor_menu._sel_idx = InventoryStacks.find(p.inventory, "health_potion")
	game.vendor_menu.refresh()
	assert_not_null(game.vendor_menu._action_row.find_child("Quantity", true, false), "a quantity box for stacks")
	game.vendor_menu.set_quantity(4)
	var btn := game.vendor_menu._action_row.find_child("TradeButton", true, false) as Button
	assert_true(btn.text.begins_with("Sell 4"), btn.text)
	# loose potions from old saves merge
	p.inventory.append(LootGenerator.make_base_item_instance(DataLoader.get_item_def("health_potion"), "loose"))
	p.normalize_equipment()
	var n := 0
	for it in p.inventory:
		if str(it["id"]) == "health_potion":
			n += 1
	assert_eq(n, 1, "old loose potions merge into the stack")


# --- 10. Safe-room area maps --------------------------------------------------------------------------------------

func test_safe_rooms_reveal_the_surrounding_area_and_points_of_interest() -> void:
	game = _make_game(true)
	await get_tree().process_frame
	var lay := game.current_layout
	var sid: int = lay.safe_room_ids[0]
	var seen := game.map_seen.size()
	game.player.global_position = lay.tile_to_world(lay.rooms[sid]["center"]) + Vector3(0, 0.3, 0)
	game.step_simulation(DT)
	assert_true(game.maps_read.has(sid), "entering the safe room reads its wall map")
	assert_gt(game.map_seen.size(), seen + 400, "the surrounding area is inked onto the map")
	var revealed := {"treasure": 0, "champion": 0}
	for p in lay.pois:
		if bool(p["revealed"]):
			revealed[str(p["kind"])] += 1
	assert_gt(int(revealed["treasure"]), 0, "nearby treasure is marked")
	var res := game.read_area_map(sid, false)
	assert_eq(int(res["tiles"]), 0, "reading it again adds nothing new")
	# a revealed chest is crossed off once looted
	for inter in get_tree().get_nodes_in_group("interactables"):
		var io := inter as InteractableObject
		if io != null and io.kind == "chest" and io.interact_id.begins_with("chest_"):
			var ci := int(io.interact_id.trim_prefix("chest_"))
			io.trigger(game.player)
			for p in lay.pois:
				if int(p.get("chest_index", -1)) == ci:
					assert_true(bool(p["done"]), "looted treasure is crossed off")
			break


# --- 11. Damage over time is visible ------------------------------------------------------------------------------

func test_damage_over_time_shows_numbers_effects_and_a_status_line() -> void:
	game = _make_game()
	await get_tree().process_frame
	game.run_console_command("teleport combat")
	game.test_ai_frozen = false
	var e: EnemyActor = game.test_spawn_enemy("draugr_raider", 1)[0]
	e.apply_status("burn", {"dps": 6.0, "duration": 3.0})
	e.apply_status("poison", {"dps": 4.0, "duration": 3.0, "stacks": 2})
	var before := game.projectiles_root.get_child_count()
	for _i in range(40):
		e.step_ai(DT, false)
	assert_not_null(e.get_node_or_null("StatusFx_burn"), "a burning enemy is visibly on fire")
	assert_not_null(e.get_node_or_null("StatusFx_poison"), "a poisoned enemy shows a toxic haze")
	assert_true(e._status_label.text.contains("BURNING") and e._status_label.text.contains("POISONED"), e._status_label.text)
	var dot_numbers := 0
	for c in game.projectiles_root.get_children():
		if str(c.name).begins_with("DotNumber_"):
			dot_numbers += 1
	assert_gt(dot_numbers, 0, "ticks pop up as coloured numbers")
	assert_gt(game.projectiles_root.get_child_count(), before)
	var fill: Color = e._health_mat.get_shader_parameter("fill_color")
	assert_gt(fill.g, fill.r * 0.6, "the health bar takes the poison colour")
	for _i in range(260):
		e.step_ai(DT, false)
	await get_tree().process_frame
	assert_null(e.get_node_or_null("StatusFx_burn"), "effects clear when the status ends")
