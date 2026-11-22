extends GutTest
## Phase 1 Tests: Tier 3 JSON DataLoader integrity and locked design invariants.


func test_all_packs_load_non_empty() -> void:
	DataLoader.reload_all()
	assert_false(DataLoader.get_world().is_empty(), "world.json must load")
	assert_false(DataLoader.get_player().is_empty(), "player.json must load")
	assert_false(DataLoader.get_items_pack().is_empty(), "items.json must load")
	assert_false(DataLoader.get_rarities_pack().is_empty(), "rarities.json must load")
	assert_false(DataLoader.get_balance_pack().is_empty(), "balance.json must load")
	assert_false(DataLoader.get_enemies_pack().is_empty(), "enemies.json must load")
	assert_false(DataLoader.get_dungeon_ai_pack().is_empty(), "dungeon_ai.json must load")
	assert_false(DataLoader.get_progression_pack().is_empty(), "progression.json must load")


func test_locked_design_rules_in_data() -> void:
	var world := DataLoader.get_world()
	assert_eq(int(world["floor_timer"]["days_per_floor"]), 5, "D-006: 5 in-game days per floor")
	assert_almost_eq(float(world["floor_timer"]["real_seconds_per_in_game_day"]), 1800.0, 0.01, "D-006: 30 min/day")
	assert_false(bool(world["stairs"]["show_next_floor_preview"]), "D-008: No staircase previews")
	var player := DataLoader.get_player()
	assert_eq(str(player["camera"]["default_mode"]), "first_person", "D-012: First-person primary")


func test_item_and_enemy_lookups_resolve() -> void:
	var sword := DataLoader.get_item_def("iron_longsword")
	assert_eq(str(sword.get("slot", "")), "right_hand")
	var boss := DataLoader.get_enemy_def("iron_warden_boss")
	assert_true(bool(boss.get("is_boss", false)))
	var floor2 := DataLoader.get_floor_config(2)
	assert_eq(int(floor2.get("floor_number", 0)), 2)
