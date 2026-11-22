extends GutTest
## Regression guards for User feedback FB-025 (docs/USER_FEEDBACK_LOG.md, decision D-060):
## Unified inherent rarity system across items, enemies, rooms, chests, traps, and props;
## deeper-floor rarity scaling; rarity-capped mastery ceilings & ability counts;
## and pulling owned non-stackables from the loot & vendor pools (returning on sell / snapshot reset).

var game: GameMain = null


func _make_game(vast: bool = false) -> GameMain:
	var g := GameMain.new()
	g.run_seed = 20261118
	g.auto_load_save_on_ready = false
	g.save_path = "user://fb025_test.json"
	g.test_mode = not vast
	add_child_autofree(g)
	return g


func test_no_old_rarity_remainders_exist() -> void:
	DataLoader.ensure_loaded()
	assert_false(FileAccess.file_exists("res://data/affixes.json"), "legacy affixes.json is removed")
	var rar := DataLoader.get_rarities_pack()
	assert_false(rar.has("loot_rarities_enabled"), "common-only lock is gone")
	for it in DataLoader.get_all_item_defs():
		assert_false(it.has("drop_weight"), "%s has no legacy drop_weight" % str(it["id"]))
		assert_false(it.has("forced_rarity"), "%s has no legacy forced_rarity" % str(it["id"]))
		assert_false(it.has("floor_min"), "%s has no legacy floor_min" % str(it["id"]))
	for e in DataLoader.get_enemies_pack().get("enemies", []):
		assert_false(e.has("spawn_weight"), "%s has no legacy spawn_weight" % str(e["id"]))
	# No floor_mult stat/price drift
	var a := LootGenerator.roll_loot(DataLoader.get_items_pack(), rar, 1, SeededRng.new(11), "", true, "barrow_war_hammer")
	var b := LootGenerator.roll_loot(DataLoader.get_items_pack(), rar, 5, SeededRng.new(11), "", true, "barrow_war_hammer")
	assert_eq(int(a["value"]), int(b["value"]), "value does not change with floor")
	assert_almost_eq(float(a["damage"]), float(b["damage"]), 0.01, "damage does not change with floor")
	assert_false(a.has("affixes"), "no random prefixes/suffixes")


func test_everything_procedurally_generated_has_assigned_rarity() -> void:
	DataLoader.ensure_loaded()
	var valid := ["common", "uncommon", "rare", "epic", "legendary"]
	for it in DataLoader.get_all_item_defs():
		assert_true(valid.has(str(it.get("rarity", ""))), "item %s has a valid rarity" % str(it["id"]))
	for e in DataLoader.get_enemies_pack().get("enemies", []):
		assert_true(valid.has(str(e.get("rarity", ""))), "enemy %s has a valid rarity" % str(e["id"]))
	var theme_raw: Dictionary = DataLoader.get_theme_def("nordic_catacombs")
	for pool in ["room_variants", "chest_tiers", "trap_types", "container_types", "dressing_props", "wall_variants", "floor_variants", "ceiling_variants"]:
		var arr: Array = theme_raw.get(pool, [])
		assert_false(arr.is_empty(), "%s pool is non-empty" % pool)
		for entry in arr:
			assert_true(valid.has(str((entry as Dictionary).get("rarity", ""))), "%s.%s has valid rarity" % [pool, str((entry as Dictionary).get("id", ""))])

	var lay := DungeonGenerator.generate(DataLoader.get_world(), DataLoader.get_enemies_pack(), 1, 20261118)
	var variant_ids := {}
	for r in lay.rooms:
		if str(r["role"]) == "combat":
			assert_false(str(r.get("variant", "")).is_empty(), "combat room has a variant")
			assert_true(valid.has(str(r.get("rarity", ""))), "combat room has a rarity")
			variant_ids[str(r["variant"])] = true
	assert_gte(variant_ids.size(), 4, "floors generate multiple combat room variants (%s)" % str(variant_ids.keys()))


func test_higher_rarities_become_more_common_on_deeper_floors() -> void:
	DataLoader.ensure_loaded()
	var rar := DataLoader.get_rarities_pack()
	var f1_rare_share := _rarity_share(rar, 1, "rare") + _rarity_share(rar, 1, "epic") + _rarity_share(rar, 1, "legendary")
	var f5_rare_share := _rarity_share(rar, 5, "rare") + _rarity_share(rar, 5, "epic") + _rarity_share(rar, 5, "legendary")
	assert_gt(f5_rare_share, f1_rare_share * 1.5, "deeper floors shift odds strongly toward Rare/Epic/Legendary")

	# Verify generated floor rooms/chests reflect deeper-floor rarity boost
	var lay1 := DungeonGenerator.generate(DataLoader.get_world(), DataLoader.get_enemies_pack(), 1, 9090)
	var lay5 := DungeonGenerator.generate(DataLoader.get_world(), DataLoader.get_enemies_pack(), 5, 9090)
	var rare_rooms_1 := _count_rare_plus_rooms(lay1)
	var rare_rooms_5 := _count_rare_plus_rooms(lay5)
	assert_gt(rare_rooms_5, rare_rooms_1, "Floor 5 spawns more Rare+ rooms (%d) than Floor 1 (%d)" % [rare_rooms_5, rare_rooms_1])


func _rarity_share(rar: Dictionary, floor_num: int, rid: String) -> float:
	var total := 0.0
	var target := 0.0
	for r in rar["rarities"]:
		var w := RarityTable.rarity_weight_for_floor(r, floor_num, {}, rar)
		total += w
		if str(r["id"]) == rid:
			target = w
	return target / maxf(0.001, total)


func _count_rare_plus_rooms(lay: DungeonGenerator.FloorLayout) -> int:
	var n := 0
	for r in lay.rooms:
		if str(r["role"]) == "combat" and str(r.get("rarity", "common")) in ["rare", "epic", "legendary"]:
			n += 1
	return n


func test_lower_rarities_have_lower_mastery_ceilings_and_fewer_abilities() -> void:
	DataLoader.ensure_loaded()
	var rar := DataLoader.get_rarities_pack()
	var order := ["common", "uncommon", "rare", "epic", "legendary"]
	var prev_cap := 0
	var prev_ab := 0
	for rid in order:
		var cap := RarityTable.mastery_max_level(rid, rar)
		var ab := RarityTable.max_abilities(rid, rar)
		assert_gt(cap, prev_cap, "%s cap (%d) > previous (%d)" % [rid, cap, prev_cap])
		assert_gt(ab, prev_ab, "%s max abilities (%d) > previous (%d)" % [rid, ab, prev_ab])
		prev_cap = cap
		prev_ab = ab

	for it in DataLoader.get_all_item_defs():
		if not MasterySystem.is_masterable(it):
			continue
		var inst := LootGenerator.make_base_item_instance(it, "cap_" + str(it["id"]))
		var cap := RarityTable.mastery_max_level(inst, rar)
		MasterySystem.add_xp(inst, 999999.0)
		assert_eq(MasterySystem.level_of(inst), cap, "%s (%s) caps at Lv %d" % [str(it["id"]), str(it["rarity"]), cap])
		assert_lte((it.get("mastery", []) as Array).size(), RarityTable.max_abilities(inst, rar),
			"%s ability count within rarity cap" % str(it["id"]))


func test_owned_non_stackables_are_pulled_from_loot_and_vendor_pools() -> void:
	game = _make_game()
	await get_tree().process_frame
	var items_pack := DataLoader.get_items_pack()
	var rar_pack := DataLoader.get_rarities_pack()
	var p := game.player

	# 1. Starting gear is already excluded from roll_loot and vendor stock
	var owned := game._owned_non_stackable_ids()
	assert_true(owned.has("iron_longsword"), "equipped starting sword is marked owned")
	assert_true(owned.has("hunting_bow"), "bag starting bow is marked owned")
	for s in game.vendor_sys.stock:
		if not InventoryStacks.is_stackable(s):
			assert_false(owned.has(str(s["id"])), "vendor never stocks owned gear %s" % str(s["id"]))

	# 2. Rolling loot with owned exclusions never returns a duplicate
	var rng := SeededRng.new(777)
	for _i in range(40):
		var it := LootGenerator.roll_loot(items_pack, rar_pack, 2, rng, "", true, "", "", owned)
		if InventoryStacks.is_stackable(it):
			break
		assert_false(owned.has(str(it["id"])), "rolled item %s is not already owned" % str(it["id"]))
		owned[str(it["id"])] = true

	# 3. Exhausting a higher tier (legendary) steps downward (to epic/rare/..), NEVER upward
	var only_leg := {}
	for d in items_pack["items"]:
		if str(d.get("rarity", "")) == "legendary":
			only_leg[str(d["id"])] = true
	var down_roll := LootGenerator.roll_loot(items_pack, rar_pack, 1, SeededRng.new(55), "legendary", true, "", "", only_leg)
	assert_ne(str(down_roll.get("rarity", "")), "legendary", "empty legendary pool steps down")

	# Exhausting Common pool falls back to a stackable consumable/ingredient (never jumps UP to uncommon+)
	var only_common := {}
	for d in items_pack["items"]:
		if not InventoryStacks.is_stackable(d) and str(d.get("rarity", "")) == "common":
			only_common[str(d["id"])] = true
	var common_fb := LootGenerator.roll_loot(items_pack, rar_pack, 1, SeededRng.new(55), "common", true, "", "", only_common)
	assert_true(InventoryStacks.is_stackable(common_fb), "exhausted Common pool falls back to stackable instead of upgrading to Uncommon+")

	# 4. Selling an item returns it to the loot pool; Floor-Entry Snapshot restores pool on death/collapse
	p.inventory.clear()
	p.equipment.clear()
	var all_non_stack_except_one := {}
	for d in items_pack["items"]:
		if not InventoryStacks.is_stackable(d) and str(d["id"]) != "flanged_mace":
			all_non_stack_except_one[str(d["id"])] = true
	# Player buys/gets flanged_mace
	var mace := LootGenerator.make_base_item_instance(DataLoader.get_item_def("flanged_mace"), "mace1")
	p.add_to_inventory(mace)
	var after_get := LootGenerator.roll_loot(items_pack, rar_pack, 1, SeededRng.new(12), "uncommon", true, "", "", game._owned_non_stackable_ids().merged(all_non_stack_except_one))
	assert_true(InventoryStacks.is_stackable(after_get), "flanged_mace is pulled while owned")
	# Sell flanged_mace -> returns to pool
	var idx := InventoryStacks.find(p.inventory, "flanged_mace")
	var sold := game.vendor_sys.sell_item(idx, p.gold, p.inventory, 1)
	assert_true(bool(sold["ok"]))
	var after_sell := LootGenerator.roll_loot(items_pack, rar_pack, 1, SeededRng.new(12), "uncommon", true, "", "", game._owned_non_stackable_ids().merged(all_non_stack_except_one))
	assert_eq(str(after_sell["id"]), "flanged_mace", "selling returns flanged_mace to the loot pool")

	# 5. Death / floor collapse restores ownership snapshot
	game.enter_floor(1, true)
	var snapshot_owned := game._owned_non_stackable_ids()
	game.test_give_item("barrow_war_hammer")
	assert_true(game._owned_non_stackable_ids().has("barrow_war_hammer"))
	game.reset_floor_to_snapshot("death")
	assert_false(game._owned_non_stackable_ids().has("barrow_war_hammer"), "floor reset restores loot pool ownership to Floor-Entry Snapshot")
	assert_eq(game._owned_non_stackable_ids().size(), snapshot_owned.size())
