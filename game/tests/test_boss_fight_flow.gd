extends GutTest
## Full boss-fight playthrough with real physics and real sword swings: walk in through the boss gate,
## fight until the boss dies, then walk back out through the boss gate and on into the treasure vault.

var game: GameMain = null


func _face(target: Vector3) -> void:
	var d := target - game.player.global_position
	game.player.rotation.y = atan2(-d.x, -d.z)


func _walk_to(target: Vector3, max_sec: float) -> float:
	var t := 0.0
	while t < max_sec:
		var d := target - game.player.global_position
		d.y = 0.0
		if d.length() < 0.8:
			break
		_face(target)
		game.player.step_simulation(1.0 / 60.0, false, {"move_vec": Vector2(0.0, -1.0)})
		game.step_simulation(1.0 / 60.0)
		await get_tree().physics_frame
		t += 1.0 / 60.0
	var rest := target - game.player.global_position
	rest.y = 0.0
	return rest.length()


func outward_v(a: Vector3, b: Vector3) -> Vector3:
	var d := a - b
	d.y = 0.0
	return d.normalized()


func test_real_boss_fight_opens_both_gates() -> void:
	game = GameMain.new()
	game.run_seed = 20261118
	game.auto_load_save_on_ready = false
	game.save_path = "user://boss_flow_test.json"
	add_child_autofree(game)
	await get_tree().physics_frame
	game.set_physics_process(false)
	game.player.god_mode = true
	# The boss is out of reach for a fresh crawler by design (D-046); fight it the way a scaled-up player would
	var blade := game.test_give_item("iron_longsword", "legendary")
	game.player.equip_from_inventory(game.player.inventory.find(blade), "right_hand")
	for c in game.enemies_root.get_children():
		if c != game.boss_actor:
			(c as Node3D).global_position = Vector3(0, -80, 0)
	var lay := game.current_layout
	var bgate := lay.tile_to_world(lay.boss_gate_tile)
	var boss_c := lay.tile_to_world(lay.rooms[lay.boss_room_id]["center"])
	# stand just outside the boss gate and walk in
	var outward := (bgate - boss_c)
	outward.y = 0.0
	outward = outward.normalized()
	game.player.global_position = bgate + outward * 3.0 + Vector3(0, 0.3, 0)
	await get_tree().physics_frame
	var miss_in := await _walk_to(bgate - outward * 5.0, 8.0)
	assert_lt(miss_in, 1.0, "walks in through the open boss gate")
	assert_true(game.dungeon_builder.boss_arena_sealed, "arena seals behind the player")
	# fight: swing at the boss until it falls
	var boss := game.boss_actor
	var t := 0.0
	while is_instance_valid(boss) and boss.current_health > 0.0 and t < 240.0:
		game.player.stamina = game.player.max_stamina
		var to_boss := boss.global_position - game.player.global_position
		to_boss.y = 0.0
		_face(boss.global_position)
		var mv := Vector2(0.0, -1.0) if to_boss.length() > 2.0 else Vector2.ZERO
		game.player.handle_hand_press("right_hand")
		for _i in range(3):
			game.player.step_simulation(1.0 / 60.0, false, {"move_vec": mv})
			game.step_simulation(1.0 / 60.0)
			await get_tree().physics_frame
		game.player.handle_hand_release("right_hand")
		for _i in range(30):
			game.player.step_simulation(1.0 / 60.0, false, {"move_vec": mv})
			game.step_simulation(1.0 / 60.0)
			await get_tree().physics_frame
		t += 33.0 / 60.0
	assert_true(not is_instance_valid(boss) or boss.current_health <= 0.0, "boss falls to real sword swings (%.0fs)" % t)
	for _i in range(60):
		game.step_simulation(1.0 / 60.0)
		await get_tree().physics_frame
	assert_true(game.boss_defeated_this_floor, "boss death registered")
	assert_false(game.dungeon_builder.boss_arena_sealed, "boss gate re-opens")
	assert_true(game.dungeon_builder.vault_unlocked, "vault unlocks")
	# leave through the boss gate, come back, and enter the vault
	var miss_out := await _walk_to(bgate + outward * 3.0, 15.0)
	assert_lt(miss_out, 1.0, "can walk back out through the boss gate (stuck at %s)" % game.player.global_position)
	var vgate := lay.tile_to_world(lay.vault_gate_tile)
	var vault_c := lay.tile_to_world(lay.rooms[lay.vault_room_id]["center"])
	# step around the boss's corpse (it lies where the boss fell) the way a player would
	var side := Vector3(0.0, 0.0, 3.5)
	await _walk_to(boss_c + side, 15.0)
	await _walk_to(vgate - outward_v(vgate, boss_c) * 4.0 + side, 15.0)
	await _walk_to(vgate - outward_v(vgate, boss_c) * 4.0, 15.0)
	var miss_v := await _walk_to(vgate, 15.0)
	assert_lt(miss_v, 1.0, "reaches the vault gate (stuck at %s)" % game.player.global_position)
	var miss_vc := await _walk_to(vault_c + Vector3(-1.5, 0, 0), 8.0)
	assert_lt(miss_vc, 1.2, "walks into the vault")


func test_gates_open_even_if_the_boss_vanishes_without_a_death_callback() -> void:
	game = GameMain.new()
	game.run_seed = 20261118
	game.auto_load_save_on_ready = false
	game.save_path = "user://boss_flow_test.json"
	add_child_autofree(game)
	await get_tree().physics_frame
	game.run_console_command("teleport boss")
	game.step_simulation(0.1)
	assert_true(game.dungeon_builder.boss_arena_sealed, "arena seals with a living boss")
	game.boss_actor.free()  # simulate a boss lost without the normal death handler running
	game.step_simulation(0.1)
	assert_true(game.boss_defeated_this_floor, "watchdog marks the vanished boss as beaten")
	assert_false(game.dungeon_builder.boss_arena_sealed, "watchdog re-opens the boss gate")
	assert_true(game.dungeon_builder.vault_unlocked, "watchdog opens the vault")
	assert_eq(game.dungeon_builder.vault_gate_node.collision_layer, 0, "open gate leaves every collision layer")
