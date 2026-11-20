extends GutTest
## Regression guards for User feedback FB-014 (docs/USER_FEEDBACK_LOG.md, decision D-048): enemies path around
## walls and props, normal RPG rarities, blades edge-forward in first person, third-person dual-wield / bow /
## spell animations, and an inventory that always fits the screen (see test_ui_and_visuals 720p test).

const DT := 1.0 / 60.0

var game: GameMain = null


func _make_game() -> GameMain:
	var g := GameMain.new()
	g.run_seed = 20261118
	g.auto_load_save_on_ready = false
	g.save_path = "user://fb014_test.json"
	g.test_mode = true
	add_child_autofree(g)
	return g


## Drives one enemy's chase directly (game loop off) until it is in attack range or `max_sec` passes.
func _chase(e: EnemyActor, max_sec: float) -> float:
	e.state = EnemyActor.AiState.CHASE
	var t := 0.0
	while t < max_sec:
		e._unseen_t = 0.0  # this test is about navigation, not about the enemy losing interest
		e.step_ai(DT, false)
		await get_tree().physics_frame
		t += DT
		var d := Vector2(e.global_position.x - game.player.global_position.x, e.global_position.z - game.player.global_position.z).length()
		if d <= e.attack_range + 0.3:
			return t
	return -1.0


# --- Pathfinding ---------------------------------------------------------------------------------------------
func test_enemy_paths_around_walls_to_reach_the_player() -> void:
	game = _make_game()
	await get_tree().process_frame
	game.set_physics_process(false)
	var lay := game.current_layout
	# Two tiles close as the crow flies but separated by solid wall: the straight line is blocked
	var best: Array = []
	for y in range(1, lay.height - 1):
		for x in range(1, lay.width - 1):
			if lay.get_tile(x, y) != DungeonGenerator.TILE_FLOOR:
				continue
			for d in [Vector2i(3, 0), Vector2i(0, 3), Vector2i(4, 0), Vector2i(0, 4)]:
				var b: Vector2i = Vector2i(x, y) + d
				if not lay.is_walkable(b.x, b.y) or lay.get_tile(b.x, b.y) != DungeonGenerator.TILE_FLOOR:
					continue
				var mid: Vector2i = Vector2i(x, y) + d / 2
				if lay.is_walkable(mid.x, mid.y):
					continue
				var path := lay.find_path(Vector2i(x, y), b)
				if path.size() >= 8 and path.size() <= 14 and path[-1] == b:
					best = [Vector2i(x, y), b, path.size()]
					break
			if not best.is_empty():
				break
		if not best.is_empty():
			break
	assert_false(best.is_empty(), "found a pair of tiles separated by a wall")
	if best.is_empty():
		return
	var path := lay.find_path(best[0], best[1])
	for t in path:
		assert_true(lay.is_walkable(t.x, t.y), "path only crosses walkable tiles")
	game.player.global_position = lay.tile_to_world(best[1]) + Vector3(0, 0.3, 0)
	var e := game.spawn_enemy("draugr_raider", lay.tile_to_world(best[0]) + Vector3(0, 0.1, 0), -1)
	await get_tree().physics_frame
	var took := await _chase(e, 20.0)
	assert_gt(took, 0.0, "enemy walked around the wall (%d-tile path) to reach the player" % int(best[2]))


func test_enemy_unsticks_itself_from_props_in_the_way() -> void:
	game = _make_game()
	await get_tree().process_frame
	game.set_physics_process(false)
	var lay := game.current_layout
	var room: Dictionary = {}
	for r in lay.rooms:
		var rect: Rect2i = r["rect"]
		if rect.size.x >= 5 and rect.size.y >= 4 and str(r["role"]) in ["combat", "entrance"]:
			room = r
			break
	assert_false(room.is_empty(), "an open room")
	var c := lay.tile_to_world(room["center"])
	# A long, low crate barricade between the enemy and the player (sight passes over it, feet do not)
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 1.0, 0.8)
	cs.shape = box
	wall.add_child(cs)
	game.add_child(wall)
	wall.global_position = c + Vector3(0, 0.5, 0)
	game.player.global_position = c + Vector3(0, 0.3, 3.0)
	var e := game.spawn_enemy("draugr_raider", c + Vector3(0.4, 0.1, -3.0), int(room["id"]))
	await get_tree().physics_frame
	var took := await _chase(e, 15.0)
	assert_gt(took, 0.0, "enemy got around the barricade instead of pushing into it forever")


func test_enemy_faces_where_it_walks_while_chasing() -> void:
	game = _make_game()
	await get_tree().process_frame
	game.set_physics_process(false)
	var lay := game.current_layout
	var room: Dictionary = {}
	for r in lay.rooms:
		if str(r["role"]) == "combat" and (r["rect"] as Rect2i).size.y >= 4:
			room = r
			break
	var c := lay.tile_to_world(room["center"])
	var half := float((room["rect"] as Rect2i).size.y) * lay.tile_size * 0.5 - 1.5
	game.player.global_position = c + Vector3(0, 0.3, half)
	var e := game.spawn_enemy("draugr_raider", c + Vector3(0, 0.1, -half), int(room["id"]))
	e.state = EnemyActor.AiState.CHASE
	for _i in range(25):
		e._unseen_t = 0.0
		e.step_ai(DT, false)
		await get_tree().physics_frame
	var v := Vector2(e.velocity.x, e.velocity.z)
	assert_gt(v.length(), 0.5, "chasing")
	var fwd := -e.global_transform.basis.z
	var face := Vector2(fwd.x, fwd.z).normalized()
	assert_gt(absf(face.dot(v.normalized())), 0.8, "body faces its direction of travel")


# --- Rarities ----------------------------------------------------------------------------------------------------
func test_rarities_are_the_normal_rpg_tiers() -> void:
	DataLoader.ensure_loaded()
	var ids: Array[String] = []
	for r in DataLoader.get_affixes_pack().get("rarities", []):
		ids.append(str(r["id"]))
	assert_eq(ids, ["common", "uncommon", "rare", "epic", "legendary"] as Array[String], "Common → Legendary")
	for id in ids:
		assert_true(UiTheme.RARITY_NAMES.has(id), "%s has a display name" % id)
	assert_false(UiTheme.RARITY_NAMES.has("sponsored"), "no Sponsored tier")
	for it in DataLoader.get_items_pack().get("items", []):
		assert_ne(str(it.get("forced_rarity", "")), "sponsored", "%s forced rarity is a normal tier" % str(it["id"]))
	for e in DataLoader.get_enemies_pack().get("enemies", []):
		assert_false(JSON.stringify(e).contains("\"sponsored\""), "%s drops use normal tiers" % str(e["id"]))


func test_old_saves_with_sponsored_items_become_legendary() -> void:
	game = _make_game()
	var p := game.player
	var it := game.test_give_item("iron_longsword", "epic")
	p.inventory[-1]["rarity"] = "sponsored"
	p.equipment["right_hand"] = it.duplicate(true)
	p.equipment["right_hand"]["rarity"] = "sponsored"
	p.normalize_equipment()
	assert_eq(str(p.inventory[-1]["rarity"]), "legendary", "bag item migrated")
	assert_eq(str(p.equipment["right_hand"]["rarity"]), "legendary", "equipped item migrated")


# --- First-person blades edge-forward --------------------------------------------------------------------------------
func _edge_away_score(pc: PlayerController, anchor: Node3D, holder: Node3D, reach: float) -> float:
	var w := anchor.transform * holder.transform
	var edge := w.basis.x.normalized()
	var blade := w.basis.y.normalized()
	var mid := (w.origin + blade * reach).normalized()
	# the best an edge can do is the eye ray projected off the blade axis
	var ideal := (mid - blade * mid.dot(blade)).normalized()
	return edge.dot(ideal)


func test_blades_face_away_from_the_player_at_rest() -> void:
	game = _make_game()
	await get_tree().process_frame
	var p := game.player
	p.set_camera_mode("first_person")
	for kit in [["iron_longsword", "", 0.55], ["iron_war_axe", "", 0.45], ["iron_longsword", "iron_longsword", 0.55]]:
		p.equipment.erase("right_hand")
		p.equipment.erase("left_hand")
		game.test_give_item(kit[0])
		p.equip_from_inventory(p.inventory.size() - 1, "right_hand")
		if str(kit[1]) != "":
			game.test_give_item(kit[1])
			p.equip_from_inventory(p.inventory.size() - 1, "left_hand")
		p._equip_raise = 0.0
		for _i in range(90):
			p.step_simulation(1.0 / 120.0, false, {})
		# double-edged swords may show either edge; the single-edged axe must show its cutting edge
		var s := _edge_away_score(p, p.fp_right_anchor, p._fp_right_weapon_holder, float(kit[2]))
		if str(kit[0]) != "iron_war_axe":
			s = absf(s)
		assert_gt(s, 0.85, "%s: right blade is seen edge-on (edge points away from the eye, %.2f)" % [kit[0], s])
		if str(kit[1]) != "":
			assert_not_null(p._fp_left_weapon_holder, "left blade has a first-person visual")
			var sl := absf(_edge_away_score(p, p.fp_left_anchor, p._fp_left_weapon_holder, float(kit[2])))
			assert_gt(sl, 0.85, "dual-wield: left blade is seen edge-on too (%.2f)" % sl)


# --- Third-person dual-wield / spells / bow --------------------------------------------------------------------------
func _equip(p: PlayerController, right_id: String, left_id: String) -> void:
	p.equipment.erase("right_hand")
	p.equipment.erase("left_hand")
	if right_id != "":
		game.test_give_item(right_id, "common")
		p.equip_from_inventory(p.inventory.size() - 1, "right_hand")
	if left_id != "":
		game.test_give_item(left_id, "common")
		p.equip_from_inventory(p.inventory.size() - 1, "left_hand")
	p.stamina = p.max_stamina
	p.magicka = p.max_magicka
	p._right_cooldown = 0.0
	p._left_cooldown = 0.0


## Grip socket position in the player's own space (-Z = where the player faces) at time t of a clip.
func _grip_at(p: PlayerController, clip: String, t: float, grip: String) -> Vector3:
	var cv := p.tp_visual
	cv.anim.play(clip, 0.0)
	cv.anim.seek(t, true)
	cv.anim.pause()
	await get_tree().process_frame
	var g := cv.model.find_child(grip + "*", true, false) as Node3D
	return p.to_local(g.global_position)


func _travel(p: PlayerController, clip: String, grip: String) -> float:
	var len := p.tp_visual.anim.get_animation(clip).length
	var a: Vector3 = await _grip_at(p, clip, 0.0, grip)
	var most := 0.0
	for k in range(1, 9):
		var b: Vector3 = await _grip_at(p, clip, len * float(k) / 9.0, grip)
		most = maxf(most, a.distance_to(b))
	return most


func test_third_person_dual_wield_swings_the_hand_that_attacks() -> void:
	game = _make_game()
	await get_tree().process_frame
	var p := game.player
	p.set_camera_mode("third_person")
	_equip(p, "iron_longsword", "iron_longsword")
	p.step_simulation(DT, false, {})
	assert_eq(p.tp_visual.state, "idle_dual", "both blades on guard")
	p.handle_hand_press("left_hand")
	assert_eq(p.tp_visual.oneshot, "attack_l", "left-hand attack plays the left swing")
	p._right_cooldown = 0.0
	p.handle_hand_press("right_hand")
	p.handle_hand_release("right_hand")
	assert_eq(p.tp_visual.oneshot, "attack_dual", "right swing keeps the left blade on guard")
	var l_moves: float = await _travel(p, "attack_l", "GripL")
	var r_still: float = await _travel(p, "attack_l", "GripR")
	assert_gt(l_moves, 0.5, "the left hand really swings (%.2f m)" % l_moves)
	assert_lt(r_still, l_moves * 0.5, "while the right blade stays roughly on guard (%.2f m)" % r_still)
	# guard: the left blade points forward like the right one, not straight up at the sky
	var g0: Vector3 = await _grip_at(p, "idle_dual", 0.0, "GripL")
	var lw := (p.tp_visual.model.find_child("GripL*", true, false) as Node3D).get_child(0) as Node3D
	var blade := (p.global_transform.basis.inverse() * lw.global_transform.basis.y).normalized()
	assert_lt(blade.y, 0.9, "left guard blade is not held vertically (%s)" % blade)
	assert_lt(blade.z, -0.3, "left guard blade points ahead of the player (%s)" % blade)
	assert_lt(g0.x, 0.0, "left hand on the player's left (x=%.2f)" % g0.x)


func test_third_person_spells_cast_from_the_hand_holding_them() -> void:
	game = _make_game()
	await get_tree().process_frame
	var p := game.player
	p.set_camera_mode("third_person")
	_equip(p, "spell_firebolt", "spell_chain_spark")
	p.handle_hand_press("right_hand")
	assert_eq(p.tp_visual.oneshot, "cast_r", "right-hand spell thrusts the right hand")
	p.handle_hand_press("left_hand")
	assert_eq(p.tp_visual.oneshot, "cast_dual", "both spells at once thrust both hands")
	for _i in range(60):
		p.step_simulation(DT, false, {})
	p.magicka = p.max_magicka
	p._left_cooldown = 0.0
	p._tp_cast_right_t = -10.0
	p.handle_hand_press("left_hand")
	assert_eq(p.tp_visual.oneshot, "cast", "left-hand spell thrusts the left hand")
	var r_rest: Vector3 = await _grip_at(p, "cast_r", 0.0, "GripR")
	var r_out: Vector3 = await _grip_at(p, "cast_r", 0.5, "GripR")
	assert_lt(r_out.z, r_rest.z - 0.3, "cast_r pushes the right hand out in front (%.2f -> %.2f)" % [r_rest.z, r_out.z])
	var l_out: Vector3 = await _grip_at(p, "cast_dual", 0.5, "GripL")
	var r2_out: Vector3 = await _grip_at(p, "cast_dual", 0.5, "GripR")
	assert_lt(l_out.z, -0.35, "cast_dual: left palm out front")
	assert_lt(r2_out.z, -0.35, "cast_dual: right palm out front")


func test_third_person_bow_draws_up_and_the_camera_frames_the_aim() -> void:
	game = _make_game()
	await get_tree().process_frame
	var p := game.player
	p.set_camera_mode("third_person")
	_equip(p, "hunting_bow", "")
	var cam0 := p.camera.position
	p.handle_hand_press("right_hand")
	p.step_simulation(DT, false, {})
	assert_eq(p.tp_visual.oneshot, "bow_draw", "drawing starts with the draw-up clip")
	for _i in range(60):
		p.step_simulation(DT, false, {})
		await get_tree().process_frame
	assert_eq(p.tp_visual.state, "draw_hold", "then holds at full draw")
	assert_lt(p.camera.position.z, cam0.z - 0.5, "camera eases in for the aim")
	assert_gt(p.camera.position.x, cam0.x, "over the right shoulder")
	var bow_k: Vector3 = await _grip_at(p, "draw_hold", 0.0, "GripL")
	assert_lt(bow_k.z, -0.45, "bow arm extended out in front at full draw (z=%.2f)" % bow_k.z)
	p.handle_hand_release("right_hand")
	for _i in range(60):
		p.step_simulation(DT, false, {})
	assert_lt(p._tp_aim_blend, 0.1, "camera returns after the shot")
