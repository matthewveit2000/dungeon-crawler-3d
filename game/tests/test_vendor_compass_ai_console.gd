extends GutTest
## Automated Tests for Safe Room Vendor, Top Compass Bar, Dungeon AI Director & Debug Console.


func test_vendor_buy_and_sell_transactions() -> void:
	var items_pack := DataLoader.get_items_pack()
	var rarities_pack := DataLoader.get_rarities_pack()
	var rng := SeededRng.new(303)
	var vendor := VendorSystem.new(DataLoader.get_balance_pack())
	vendor.refresh_stock(items_pack, rarities_pack, 1, rng)
	assert_gte(vendor.stock.size(), 5)

	var inv: Array = []
	var price := vendor.get_buy_price(vendor.stock[0])
	var fail_res := vendor.buy_item(0, price - 1, inv)
	assert_false(bool(fail_res["ok"]))

	var ok_res := vendor.buy_item(0, price + 50, inv)
	assert_true(bool(ok_res["ok"]))
	assert_eq(int(ok_res["gold"]), 50)
	assert_eq(inv.size(), 1)

	var sell_res := vendor.sell_item(0, int(ok_res["gold"]), inv)
	assert_true(bool(sell_res["ok"]))
	assert_gt(int(sell_res["gold"]), 50)
	assert_eq(inv.size(), 0)


func test_compass_discovers_nearby_landmarks_and_projects_bearing() -> void:
	var cfg: Dictionary = DataLoader.get_world()["compass"]
	var landmarks: Array[Dictionary] = [
		{"id": "safe_room", "label": "Safe Room", "icon": "S", "world_pos": Vector3(0, 0, -20), "discovered": false},
		{"id": "stairs", "label": "Stairwell", "icon": "D", "world_pos": Vector3(0, 0, -90), "discovered": false},
	]
	var newly := CompassSystem.update_discoveries(landmarks, Vector3.ZERO, cfg)
	assert_eq(newly.size(), 1)
	assert_eq(str(newly[0]["id"]), "safe_room")
	assert_true(bool(landmarks[0]["discovered"]))
	assert_false(bool(landmarks[1]["discovered"]))

	# Looking straight North (-Z) puts Safe Room dead-center at normalized_x == 0
	var markers := CompassSystem.compute_visible_markers(landmarks, Vector3.ZERO, Vector3(0, 0, -1), cfg)
	assert_eq(markers.size(), 1)
	assert_almost_eq(float(markers[0]["normalized_x"]), 0.0, 0.01)


func test_dungeon_ai_director_formats_placeholders_and_respects_once_only() -> void:
	var rng := SeededRng.new(12)
	var ai := DungeonAiDirector.new(DataLoader.get_dungeon_ai_pack())
	var msg := ai.build_announcement("floor_enter", {"floor": 2}, rng)
	assert_true(str(msg["title"]).contains("2"))

	var first := ai.build_announcement("safe_room_discovered", {}, rng, true)
	var second := ai.build_announcement("safe_room_discovered", {}, rng, true)
	assert_false(first.is_empty())
	assert_true(second.is_empty(), "once_only achievement must not repeat on same floor")
	ai.reset_floor_flags()
	var after_reset := ai.build_announcement("safe_room_discovered", {}, rng, true)
	assert_false(after_reset.is_empty())


func test_debug_console_dispatches_commands_and_help() -> void:
	var help_out := DebugConsole.execute("help", {})
	assert_true(help_out.contains("teleport"))
	var called := {"arg": ""}
	var out := DebugConsole.execute("teleport stairs", {
		"teleport": func(args: Array[String]) -> String:
			called["arg"] = args[0]
			return "OK:" + args[0]
	})
	assert_eq(out, "OK:stairs")
	assert_eq(called["arg"], "stairs")
