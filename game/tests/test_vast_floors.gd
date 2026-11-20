extends GutTest
## Vast floors (D-044): a floor is far bigger than one run can explore, its landmarks are sparse but always
## reachable and hinted on the compass, and only the decor around the player is ever live.

const WALK_SPEED := 5.4  # m/s, game/data/player.json movement.walk_speed
const FLOOR_SECONDS := 5.0 * 1800.0  # 5 in-game days x 30 real minutes


func _gen(seed_val: int) -> DungeonGenerator.FloorLayout:
	DataLoader.ensure_loaded()
	return DungeonGenerator.generate(DataLoader.get_world(), DataLoader.get_enemies_pack(), 1, seed_val)


func _walkable(lay: DungeonGenerator.FloorLayout) -> int:
	var n := 0
	for v in lay.tiles:
		if v != DungeonGenerator.TILE_VOID:
			n += 1
	return n


func _dist_m(lay: DungeonGenerator.FloorLayout, a: int, b: int) -> float:
	return Vector2(lay.rooms[a]["center"]).distance_to(Vector2(lay.rooms[b]["center"])) * lay.tile_size


func test_a_quarter_of_the_floor_takes_longer_to_walk_than_the_whole_floor_clock_allows() -> void:
	for s in [20261118, 11, 22, 33]:
		var lay := _gen(s)
		assert_gt(lay.rooms.size(), 400, "seed %d: hundreds of rooms" % s)
		var tiles := _walkable(lay)
		# Walking through a quarter of the tiles ONCE each, never backtracking, never fighting or looting,
		# already eats more than half of the floor clock; a real maze needs ~2x for backtracking.
		var quarter_walk_s := tiles * 0.25 * lay.tile_size / WALK_SPEED
		assert_gt(quarter_walk_s * 2.0, FLOOR_SECONDS, "seed %d: 25%% of %d tiles = %.0f min of perfect walking" % [s, tiles, quarter_walk_s / 60.0])


func test_landmarks_are_sparse_but_all_reachable() -> void:
	for s in [20261118, 44, 55, 66, 77]:
		var lay := _gen(s)
		assert_true(DungeonGenerator._validate_connectivity(lay), "seed %d: every landmark reachable from the entrance" % s)
		var span := Vector2(lay.width, lay.height).length() * lay.tile_size
		assert_gte(lay.stairs_room_ids.size(), 3, "seed %d: several stairwells" % s)
		assert_gte(lay.safe_room_ids.size(), 6, "seed %d: safe rooms spread over the map" % s)
		assert_gt(_dist_m(lay, lay.entrance_room_id, lay.boss_room_id), span * 0.35, "seed %d: boss arena is far from the entrance" % s)
		for i in range(lay.stairs_room_ids.size()):
			var a: int = lay.stairs_room_ids[i]
			assert_gt(_dist_m(lay, lay.entrance_room_id, a), span * 0.3, "seed %d: stairwell far from the entrance" % s)
			for j in range(i + 1, lay.stairs_room_ids.size()):
				assert_gt(_dist_m(lay, a, lay.stairs_room_ids[j]), span * 0.12, "seed %d: stairwells spread apart" % s)
		# The boss arena keeps exactly one way in: its gate
		var openings := 0
		var r: Rect2i = lay.rooms[lay.boss_room_id]["rect"]
		for x in range(r.position.x, r.end.x):
			for y in [r.position.y - 1, r.end.y]:
				if lay.is_walkable(x, y):
					openings += 1
		for y in range(r.position.y, r.end.y):
			for x in [r.position.x - 1, r.end.x]:
				if lay.is_walkable(x, y):
					openings += 1
		assert_eq(openings, 2, "seed %d: boss arena opens only to its gate and the vault gate" % s)


func test_compass_always_hints_the_nearest_stairwell_and_boss_gate() -> void:
	var lay := _gen(20261118)
	var ent := lay.tile_to_world(lay.rooms[lay.entrance_room_id]["center"])
	var cfg: Dictionary = DataLoader.get_world()["compass"]
	var hinted := {}
	for yaw_i in range(8):
		var a := float(yaw_i) / 8.0 * TAU
		for m in CompassSystem.compute_visible_markers(lay.landmarks, ent, Vector3(sin(a), 0, -cos(a)), cfg):
			if not bool(m["discovered"]):
				hinted[str(m["id"])] = int(hinted.get(str(m["id"]), 0)) + 1
	assert_true(hinted.has("stairs"), "a stairwell is hinted from the far-off entrance")
	assert_true(hinted.has("boss_arena"), "the boss gate is hinted from the far-off entrance")


func test_only_decor_near_the_player_is_live() -> void:
	var game := GameMain.new()
	game.run_seed = 20261118
	game.auto_load_save_on_ready = false
	game.save_path = "user://vast_test.json"
	add_child_autofree(game)
	await get_tree().process_frame
	var b := game.dungeon_builder
	var r := DungeonBuilder.STREAM_RADIUS
	assert_lte(b.streamed_chunk_count(), (2 * r + 1) * (2 * r + 1), "only chunks around the player are spawned")
	assert_gt(b.torch_count, 2000, "thousands of torches exist on the floor")
	assert_lt(b._managed_lights.size(), 400, "but only a few hundred lights are live")
	var far_enemies := 0
	for c in game.enemies_root.get_children():
		if (c as Node3D).global_position.distance_to(game.player.global_position) > GameMain.ENEMY_ACTIVE_RADIUS + 5.0:
			far_enemies += 1
			assert_false((c as Node3D).visible, "far enemies are frozen and hidden")
			break
	# Move across the map: old decor is freed, new decor spawns
	game.run_console_command("teleport boss")
	b.update_streaming(game.player.global_position)
	await get_tree().process_frame
	assert_lte(b.streamed_chunk_count(), (2 * r + 3) * (2 * r + 3), "chunks left behind are freed")
	assert_gt(b._managed_lights.size(), 0, "decor around the new position is live")
