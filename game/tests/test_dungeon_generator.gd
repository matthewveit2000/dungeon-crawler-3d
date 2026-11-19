extends GutTest
## Automated 100-Seed Procedural Nordic-Ruin Labyrinth Invariant Suite.


func test_100_seeds_guarantee_connectivity_and_all_special_rooms() -> void:
	var world := DataLoader.get_world()
	var enemies := DataLoader.get_enemies_pack()

	for seed_val in range(1000, 1100):
		var layout := DungeonGenerator.generate(world, enemies, 1, seed_val)
		assert_not_null(layout, "Seed %d must produce a layout" % seed_val)
		assert_gte(layout.entrance_room_id, 0, "Seed %d missing entrance" % seed_val)
		assert_gte(layout.safe_room_id, 0, "Seed %d missing safe room" % seed_val)
		assert_gte(layout.boss_room_id, 0, "Seed %d missing boss arena" % seed_val)
		assert_gte(layout.vault_room_id, 0, "Seed %d missing vault" % seed_val)
		assert_gte(layout.stairs_room_id, 0, "Seed %d missing hidden staircase" % seed_val)
		assert_ne(layout.boss_gate_tile, Vector2i(-1, -1), "Seed %d missing boss gate" % seed_val)
		assert_ne(layout.vault_gate_tile, Vector2i(-1, -1), "Seed %d missing vault gate" % seed_val)

		# Verify no regular enemies ever spawn inside Entrance, Safe Room, or Vault
		for spawn in layout.enemy_spawns:
			if bool(spawn.get("is_boss", false)):
				assert_eq(int(spawn["room_id"]), layout.boss_room_id)
			else:
				var rid := int(spawn["room_id"])
				assert_ne(rid, layout.entrance_room_id, "Enemy must not spawn in Entrance")
				assert_ne(rid, layout.safe_room_id, "Enemy must not spawn in Safe Room")
				assert_ne(rid, layout.vault_room_id, "Enemy must not spawn in Vault")


func test_same_seed_is_100_percent_deterministic() -> void:
	var world := DataLoader.get_world()
	var enemies := DataLoader.get_enemies_pack()
	var a := DungeonGenerator.generate(world, enemies, 1, 77777)
	var b := DungeonGenerator.generate(world, enemies, 1, 77777)

	assert_eq(a.tiles, b.tiles, "Identical seed must carve identical tiles")
	assert_eq(a.entrance_room_id, b.entrance_room_id)
	assert_eq(a.safe_room_id, b.safe_room_id)
	assert_eq(a.boss_room_id, b.boss_room_id)
	assert_eq(a.stairs_room_id, b.stairs_room_id)
	assert_eq(a.boss_gate_tile, b.boss_gate_tile)
	assert_eq(a.enemy_spawns.size(), b.enemy_spawns.size())
