extends GutTest
## Automated Tests for Loot Rarity Scaling, Affix Rolling, Legendary Effects & Stat Aggregation.


func test_legendary_loot_always_rolls_legendary_effect_and_high_value() -> void:
	var items_pack := DataLoader.get_items_pack()
	var affixes_pack := DataLoader.get_affixes_pack()
	var rng := SeededRng.new(404)

	for i in range(15):
		var item := LootGenerator.roll_loot(items_pack, affixes_pack, 1, rng, "legendary", true)
		assert_eq(str(item["rarity"]), "legendary")
		assert_false(str(item.get("legendary_effect", "")).is_empty(), "Legendary loot must have a legendary_effect")
		assert_gt(int(item["value"]), 100)


func test_higher_rarity_scales_value_and_stats() -> void:
	var items_pack := DataLoader.get_items_pack()
	var affixes_pack := DataLoader.get_affixes_pack()
	var rng := SeededRng.new(808)

	var rare := LootGenerator.roll_loot(items_pack, affixes_pack, 2, rng, "rare", true)
	assert_eq(str(rare["rarity"]), "rare")
	assert_lte(rare["affixes"].size(), 2)
	assert_gt(int(rare["value"]), 0)


func test_aggregate_equipment_stats_sums_all_skyrim_slots() -> void:
	var eq := {
		"head": DataLoader.get_item_def("iron_horned_helm"),
		"chest": DataLoader.get_item_def("tattered_crawler_tunic"),
		"hands": DataLoader.get_item_def("thunderclap_gauntlets"),
		"ring": DataLoader.get_item_def("silver_focus_ring"),
		"amulet": DataLoader.get_item_def("bone_ward_amulet"),
	}
	var totals := LootGenerator.aggregate_equipment_stats(eq)
	# FB-022: worn items' level-1 passives count too (helm Iron Skin +2 armor, gauntlets Brutal +4 damage)
	assert_almost_eq(float(totals["armor"]), 42.0 + 2.0, 0.01)
	assert_almost_eq(float(totals["bonus_damage"]), 10.0 + 4.0, 0.01)
	assert_almost_eq(float(totals["bonus_health"]), 30.0, 0.01)
	assert_almost_eq(float(totals["bonus_magicka"]), 25.0, 0.01)
	assert_true(totals["legendary_effects"].has("explosive_crits"))
