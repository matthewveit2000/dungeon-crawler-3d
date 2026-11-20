extends GutTest
## Regression: after the boss falls, the player can physically walk from the arena into the treasure vault.

var game: GameMain = null


func _walk_to(target: Vector3, max_sec: float) -> float:
	var p := game.player
	var t := 0.0
	while t < max_sec:
		var d := target - p.global_position
		d.y = 0.0
		if d.length() < 0.8:
			break
		p.rotation.y = atan2(-d.x, -d.z)
		p.step_simulation(1.0 / 60.0, false, {"move_vec": Vector2(0.0, -1.0)})
		await get_tree().physics_frame
		t += 1.0 / 60.0
	var rest := target - p.global_position
	rest.y = 0.0
	return rest.length()


func _check_seed(seed_val: int) -> void:
	game = GameMain.new()
	game.run_seed = seed_val
	game.auto_load_save_on_ready = false
	game.save_path = "user://vault_access_test.json"
	add_child_autofree(game)
	await get_tree().physics_frame
	game.set_physics_process(false)
	for c in game.enemies_root.get_children():
		(c as Node3D).global_position = Vector3(0, -80, 0)
	# Real flow: walk into the arena (it seals and the boss wakes), then kill the boss
	game.run_console_command("teleport boss")
	game.step_simulation(0.1)
	assert_true(game.dungeon_builder.boss_arena_sealed, "seed %d: arena seals on entry" % seed_val)
	game.boss_actor.take_damage(99999.0)
	game.step_simulation(0.1)
	for _i in range(30):
		game.step_simulation(1.0 / 60.0)
		await get_tree().physics_frame
	var lay := game.current_layout
	var boss_c := lay.tile_to_world(lay.rooms[lay.boss_room_id]["center"])
	var gate := lay.tile_to_world(lay.vault_gate_tile)
	var vault_c := lay.tile_to_world(lay.rooms[lay.vault_room_id]["center"])
	# start in the middle of the arena and head for the vault doorway
	game.player.global_position = Vector3(boss_c.x, 0.3, boss_c.z)
	game.player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var miss_gate := await _walk_to(gate, 12.0)
	var miss_vault := await _walk_to(vault_c + Vector3(-1.5, 0, 0), 6.0)
	assert_lt(miss_gate, 1.0, "seed %d: player reaches the opened vault gate (missed by %.2f m, boss centre %s, gate %s, stuck at %s)" % [seed_val, miss_gate, boss_c, gate, game.player.global_position])
	assert_lt(miss_vault, 1.2, "seed %d: player walks into the treasure vault (missed by %.2f m)" % [seed_val, miss_vault])
	game.queue_free()
	await get_tree().process_frame


func test_vault_is_walkable_after_boss_defeat() -> void:
	for s in [20261118, 424242, 515151, 1001]:
		await _check_seed(s)
